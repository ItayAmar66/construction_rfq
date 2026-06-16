#!/usr/bin/env node
/**
 * Backfill users/{uid}.primaryOrgId + orgId from organizations/*/memberships/{uid}.
 *
 * Usage:
 *   cd tools/admin
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
 *   node backfill_user_primary_org_id.js
 *   node backfill_user_primary_org_id.js qa.contractor.big.procurement@test.com
 */

const admin = require('firebase-admin');

const PROJECT_ID = 'construction-rfq-itay-20-2eee0';

const QA_EMAILS = [
  'qa.contractor.big.owner@test.com',
  'qa.contractor.small.owner@test.com',
  'qa.contractor.big.procurement@test.com',
  'qa.contractor.big.engineer@test.com',
  'qa.supplier.big.owner@test.com',
  'qa.supplier.big.procurement@test.com',
  'qa.supplier.small.owner@test.com',
];

async function resolveOrgId(db, uid) {
  const memberships = await db.collectionGroup('memberships').where('uid', '==', uid).get();
  if (!memberships.empty) {
    const data = memberships.docs[0].data();
    return data.orgId || memberships.docs[0].ref.parent.parent.id;
  }

  const direct = await db
    .collection('organizations')
    .doc(uid)
    .collection('memberships')
    .doc(uid)
    .get();
  if (direct.exists) {
    const data = direct.data() || {};
    return data.orgId || uid;
  }

  return null;
}

async function backfillUser(db, auth, email) {
  const user = await auth.getUserByEmail(email);
  const orgId = await resolveOrgId(db, user.uid);
  if (!orgId) {
    console.warn(`skip ${email}: no membership org found`);
    return;
  }

  await db.collection('users').doc(user.uid).set(
    {
      orgId,
      primaryOrgId: orgId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`updated ${email} -> primaryOrgId=${orgId}`);
}

async function main() {
  const emails = process.argv.length > 2
    ? process.argv.slice(2).map((e) => e.trim().toLowerCase())
    : QA_EMAILS;

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }

  const db = admin.firestore();
  const auth = admin.auth();

  for (const email of emails) {
    await backfillUser(db, auth, email);
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
