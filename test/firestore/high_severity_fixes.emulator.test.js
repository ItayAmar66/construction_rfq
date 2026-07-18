#!/usr/bin/env node
/**
 * Firestore rules emulator tests — Phase 2 HIGH severity remediation.
 *
 * Covers the two rules-layer HIGH fixes:
 *   HIGH-1: canManageOrgMemberships now respects membership.revokes
 *           ('manageUsers') — a revoked admin loses server-side authority.
 *   HIGH-5: invitation acceptance now enforces expiresAt — a stale/leaked
 *           invite link can no longer be accepted indefinitely.
 *
 * Run from repo root:
 *   firebase emulators:exec --only firestore --project construction-rfq-rules-test \
 *     "cd test/firestore && npm install && node high_severity_fixes.emulator.test.js"
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { setLogLevel } = require('firebase/firestore');

setLogLevel('error');

const PROJECT_ID = 'construction-rfq-rules-test';
const CONTRACTOR_ORG = 'qa-contractor-org';

const UID_REVOKED_ADMIN = 'uid-revoked-admin';
const UID_ACTIVE_ADMIN = 'uid-active-admin';
const UID_TARGET_MEMBER = 'uid-target-member';
const UID_INVITEE_EXPIRED = 'uid-invitee-expired';
const UID_INVITEE_VALID = 'uid-invitee-valid';

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

function authedUser(uid) {
  return { sub: uid, email: `${uid}@test.com`, token: { email: `${uid}@test.com` } };
}

async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    const user = (uid, userType) =>
      db.collection('users').doc(uid).set({
        uid,
        userType,
        accountStatus: 'active',
        email: `${uid}@test.com`,
      });

    await user(UID_REVOKED_ADMIN, 'commercialCustomer');
    await user(UID_ACTIVE_ADMIN, 'commercialCustomer');
    await user(UID_TARGET_MEMBER, 'commercialCustomer');
    await user(UID_INVITEE_EXPIRED, 'commercialCustomer');
    await user(UID_INVITEE_VALID, 'commercialCustomer');

    await db.collection('organizations').doc(CONTRACTOR_ORG).set({
      type: 'contractor',
      status: 'active',
      name: CONTRACTOR_ORG,
    });

    const membership = (uid, roles, extra) =>
      db
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(uid)
        .set({
          uid,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles,
          ...(extra || {}),
        });

    // Same shape as the original finding: an admin whose manageUsers was
    // explicitly revoked (e.g. by the org owner) after being demoted from
    // full trust, but the role field itself still says contractorAdmin.
    await membership(UID_REVOKED_ADMIN, ['contractorAdmin'], {
      revokes: ['manageUsers'],
    });
    await membership(UID_ACTIVE_ADMIN, ['contractorAdmin']);
    await membership(UID_TARGET_MEMBER, ['engineer']);

    const invite = (id, extra) =>
      db.collection('invitations').doc(id).set({
        orgId: CONTRACTOR_ORG,
        role: 'engineer',
        status: 'pending',
        invitedByUid: UID_ACTIVE_ADMIN,
        email: `${extra.uid}@test.com`,
        ...extra,
      });

    await invite('invite-expired', {
      uid: UID_INVITEE_EXPIRED,
      expiresAt: new Date(Date.now() - 24 * 60 * 60 * 1000), // yesterday
    });
    await invite('invite-valid', {
      uid: UID_INVITEE_VALID,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // +30d
    });
  });
}

async function run() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });

  try {
    await seed(testEnv);

    const dbFor = (uid) =>
      testEnv.authenticatedContext(uid, authedUser(uid)).firestore();

    const dbRevokedAdmin = dbFor(UID_REVOKED_ADMIN);
    const dbActiveAdmin = dbFor(UID_ACTIVE_ADMIN);
    const dbInviteeExpired = dbFor(UID_INVITEE_EXPIRED);
    const dbInviteeValid = dbFor(UID_INVITEE_VALID);

    // ── HIGH-1: canManageOrgMemberships respects membership.revokes ─────
    await assertFails(
      dbRevokedAdmin
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_TARGET_MEMBER)
        .update({ roles: ['projectManager'], updatedAt: new Date() }),
    );
    console.log('PASS [HIGH-1] admin with manageUsers revoked cannot change a member\'s role');

    await assertSucceeds(
      dbActiveAdmin
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_TARGET_MEMBER)
        .update({ roles: ['projectManager'], updatedAt: new Date() }),
    );
    console.log('PASS [HIGH-1] admin without the revoke can still change a member\'s role');

    // ── HIGH-5: invitation acceptance enforces expiresAt ─────────────────
    await assertFails(
      dbInviteeExpired
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_INVITEE_EXPIRED)
        .set({
          uid: UID_INVITEE_EXPIRED,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles: ['engineer'],
          acceptedInvitationId: 'invite-expired',
        }),
    );
    console.log('PASS [HIGH-5] an expired invitation can no longer be accepted');

    await assertSucceeds(
      dbInviteeValid
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_INVITEE_VALID)
        .set({
          uid: UID_INVITEE_VALID,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles: ['engineer'],
          acceptedInvitationId: 'invite-valid',
        }),
    );
    console.log('PASS [HIGH-5] a non-expired invitation can still be accepted');

    console.log('\nAll HIGH severity remediation emulator tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
