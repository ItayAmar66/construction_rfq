#!/usr/bin/env node
/**
 * Firestore rules emulator tests — release blockers.
 *
 * Covers two fixes:
 *   1. quoteRequests `allow update` no longer blows Firestore's
 *      expression-evaluation budget: canApproveProcurementForRequest() and
 *      the project-doc get() it depends on were each being evaluated
 *      redundantly (up to 3x / 4x) across the procurement status-transition
 *      branches. Legitimate customer/supplier/procurement updates must
 *      still succeed, and unauthorized/cross-org updates must still fail.
 *   2. Privilege escalation via membership update / owner-approval create:
 *      a non-owner contractorAdmin/supplierAdmin could grant another member
 *      (or themselves) the contractorOwner/supplierOwner role. Only an
 *      existing org Owner or a platform admin may grant Owner.
 *
 * Run from repo root:
 *   firebase emulators:exec --only firestore --project construction-rfq-rules-test \
 *     "cd test/firestore && npm test"
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

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

function authedUser(uid) {
  return { sub: uid, email: `${uid}@test.com`, token: { email: `${uid}@test.com` } };
}

// ── quoteRequests / procurement fixtures ──────────────────────────────────
const CUSTOMER_UID = 'rb-customer';
const UNAUTH_UID = 'rb-unauthorized';
const SUPPLIER_UID = 'rb-supplier';

const CONTRACTOR_ORG = 'rb-contractor-org';
const OTHER_CONTRACTOR_ORG = 'rb-other-contractor-org';

const UID_PROCUREMENT = 'rb-procurement-manager';
const UID_OTHER_ORG_PROCUREMENT = 'rb-other-org-procurement-manager';

const FS_PROJECT_ID = 'rb-project';
const REQUEST_PROC_ID = 'rb-request-procurement';
const REQUEST_SUPPLIER_ID = 'rb-request-supplier';

// ── membership fixtures ─────────────────────────────────────────────────
const UID_OWNER = 'rb-owner';
const UID_ADMIN = 'rb-admin';
const UID_COLLEAGUE = 'rb-colleague';
const UID_PENDING_APPROVAL = 'rb-pending-approval';
const UID_PLATFORM_ADMIN = 'rb-platform-admin';

async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    const user = (uid, userType, extra) =>
      db.collection('users').doc(uid).set({
        uid,
        userType,
        accountStatus: 'active',
        email: `${uid}@test.com`,
        ...(extra || {}),
      });

    await user(CUSTOMER_UID, 'commercialCustomer');
    await user(UNAUTH_UID, 'commercialCustomer');
    await user(SUPPLIER_UID, 'commercialSupplier');
    await user(UID_PROCUREMENT, 'commercialCustomer');
    await user(UID_OTHER_ORG_PROCUREMENT, 'commercialCustomer');
    await user(UID_OWNER, 'commercialCustomer');
    await user(UID_ADMIN, 'commercialCustomer');
    await user(UID_COLLEAGUE, 'commercialCustomer');
    await user(UID_PLATFORM_ADMIN, 'commercialCustomer');
    await user(UID_PENDING_APPROVAL, 'commercialCustomer', {
      accountStatus: 'pendingApproval',
      requestedOrgId: CONTRACTOR_ORG,
    });

    // ── organizations + memberships ──────────────────────────────────────
    await db.collection('organizations').doc(CONTRACTOR_ORG).set({
      type: 'contractor',
      status: 'active',
      name: CONTRACTOR_ORG,
    });
    await db.collection('organizations').doc(OTHER_CONTRACTOR_ORG).set({
      type: 'contractor',
      status: 'active',
      name: OTHER_CONTRACTOR_ORG,
    });

    const membership = (orgId, uid, roles, extra) =>
      db
        .collection('organizations')
        .doc(orgId)
        .collection('memberships')
        .doc(uid)
        .set({
          uid,
          orgId,
          orgType: 'contractor',
          status: 'active',
          roles,
          ...(extra || {}),
        });

    await membership(CONTRACTOR_ORG, UID_PROCUREMENT, ['procurementManager']);
    await membership(OTHER_CONTRACTOR_ORG, UID_OTHER_ORG_PROCUREMENT, ['procurementManager']);
    await membership(CONTRACTOR_ORG, UID_OWNER, ['contractorOwner']);
    await membership(CONTRACTOR_ORG, UID_ADMIN, ['contractorAdmin']);
    await membership(CONTRACTOR_ORG, UID_COLLEAGUE, ['engineer']);

    // ── project linking the request to CONTRACTOR_ORG ───────────────────
    await db.collection('projects').doc(FS_PROJECT_ID).set({
      orgId: CONTRACTOR_ORG,
      status: 'active',
      name: FS_PROJECT_ID,
    });

    // ── quoteRequests: org-linked request pending procurement approval.
    // Exercises canApproveProcurementForRequest() -> requestContractorOrgId()
    // -> the membership/role-check chain that was blowing the expression
    // budget. contractorOrgId is set directly (rather than only via
    // projectId) to keep this scenario aligned with the equivalent
    // already-passing case in critical_security_fixes.emulator.test.js.
    await db.collection('quoteRequests').doc(REQUEST_PROC_ID).set({
      customerId: CUSTOMER_UID,
      customerName: 'RB Customer',
      customerPhone: '0500000000',
      customerCity: 'Tel Aviv',
      customerType: 'commercialCustomer',
      contractorOrgId: CONTRACTOR_ORG,
      projectId: FS_PROJECT_ID,
      status: 'ממתין לאישור רכש',
      items: [{ id: 'item-1' }],
      supplierIdsResponded: [],
      createdAt: new Date(),
    });

    // ── quoteRequests: an open request any supplier can respond to.
    await db.collection('quoteRequests').doc(REQUEST_SUPPLIER_ID).set({
      customerId: CUSTOMER_UID,
      customerName: 'RB Customer',
      customerPhone: '0500000000',
      customerCity: 'Tel Aviv',
      customerType: 'commercialCustomer',
      status: 'נשלח',
      openToAllSuppliers: true,
      items: [{ id: 'item-1' }],
      supplierIdsResponded: [],
      createdAt: new Date(),
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
    const platformAdminDbFor = (uid) => {
      const base = authedUser(uid);
      return testEnv
        .authenticatedContext(uid, {
          ...base,
          platformAdmin: true,
          token: { ...base.token, platformAdmin: true },
        })
        .firestore();
    };

    const dbUnauthorized = dbFor(UNAUTH_UID);
    const dbSupplier = dbFor(SUPPLIER_UID);
    const dbProcurement = dbFor(UID_PROCUREMENT);
    const dbOtherOrgProcurement = dbFor(UID_OTHER_ORG_PROCUREMENT);
    const dbOwner = dbFor(UID_OWNER);
    const dbAdmin = dbFor(UID_ADMIN);
    const dbPlatformAdmin = platformAdminDbFor(UID_PLATFORM_ADMIN);

    // ── Task 1: quoteRequests update expression-limit fix ────────────────

    // Legitimate procurement-manager RFQ approval succeeds (also proves the
    // rule doesn't hit the expression-evaluation budget on the
    // canApproveProcurementForRequest()-heavy branch).
    await assertSucceeds(
      dbProcurement
        .collection('quoteRequests')
        .doc(REQUEST_PROC_ID)
        .update({
          status: 'אושר על ידי רכש',
          procurementApprovedByUid: UID_PROCUREMENT,
          updatedAt: new Date(),
        }),
    );
    console.log('PASS [quoteRequests] legitimate procurement RFQ approval succeeds');

    // Legitimate supplier response update succeeds.
    await assertSucceeds(
      dbSupplier
        .collection('quoteRequests')
        .doc(REQUEST_SUPPLIER_ID)
        .update({
          seenBySupplierIds: [SUPPLIER_UID],
        }),
    );
    console.log('PASS [quoteRequests] legitimate supplier seenBySupplierIds update succeeds');

    // Unauthorized user cannot update the request at all.
    await assertFails(
      dbUnauthorized
        .collection('quoteRequests')
        .doc(REQUEST_PROC_ID)
        .update({
          status: 'אושר על ידי רכש',
          procurementApprovedByUid: UNAUTH_UID,
          updatedAt: new Date(),
        }),
    );
    console.log('PASS [quoteRequests] unauthorized user update fails');

    // A procurement manager from an unrelated (cross-org) contractor org
    // cannot approve someone else's request.
    await assertFails(
      dbOtherOrgProcurement
        .collection('quoteRequests')
        .doc(REQUEST_PROC_ID)
        .update({
          status: 'אושר על ידי רכש',
          procurementApprovedByUid: UID_OTHER_ORG_PROCUREMENT,
          updatedAt: new Date(),
        }),
    );
    console.log('PASS [quoteRequests] cross-org procurement manager update fails');

    // ── Task 2: membership privilege-escalation fix ──────────────────────

    // Non-owner admin cannot promote a colleague to contractorOwner via the
    // membership-update path (third-party promotion attack).
    await assertFails(
      dbAdmin
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_COLLEAGUE)
        .update({
          roles: ['contractorOwner'],
          updatedAt: new Date(),
          updatedByUid: UID_ADMIN,
        }),
    );
    console.log('PASS [membership] non-owner admin cannot promote a colleague to Owner');

    // Non-owner admin cannot self-promote to contractorOwner either.
    await assertFails(
      dbAdmin
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_ADMIN)
        .update({
          roles: ['contractorOwner'],
          updatedAt: new Date(),
          updatedByUid: UID_ADMIN,
        }),
    );
    console.log('PASS [membership] non-owner admin cannot self-promote to Owner');

    // Non-owner admin cannot create an Owner membership via the
    // owner-approval-create path either.
    await assertFails(
      dbAdmin
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_PENDING_APPROVAL)
        .set({
          uid: UID_PENDING_APPROVAL,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles: ['contractorOwner'],
        }),
    );
    console.log('PASS [membership] non-owner admin cannot create an Owner membership via owner-approval');

    // An existing org Owner CAN grant Owner to a colleague — the legitimate
    // operation must remain allowed.
    await assertSucceeds(
      dbOwner
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_COLLEAGUE)
        .update({
          roles: ['contractorOwner'],
          updatedAt: new Date(),
          updatedByUid: UID_OWNER,
        }),
    );
    console.log('PASS [membership] existing owner can promote a colleague to Owner');

    // A platform admin CAN approve an Owner-role membership via the
    // owner-approval-create path.
    await assertSucceeds(
      dbPlatformAdmin
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_PENDING_APPROVAL)
        .set({
          uid: UID_PENDING_APPROVAL,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles: ['contractorOwner'],
        }),
    );
    console.log('PASS [membership] platform admin can create an Owner membership via owner-approval');

    console.log('\nAll release-blocker emulator tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
