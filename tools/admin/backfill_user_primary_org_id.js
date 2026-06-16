#!/usr/bin/env node
/**
 * Backfill users/{uid}.primaryOrgId + orgId from organization membership docs.
 *
 * Usage:
 *   cd tools/admin
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
 *   node backfill_user_primary_org_id.js --dry-run
 *   node backfill_user_primary_org_id.js
 *   node backfill_user_primary_org_id.js qa.contractor.big.procurement@test.com
 *   node backfill_user_primary_org_id.js --all-users --dry-run
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

function parseArgs(argv) {
  const dryRun = argv.includes('--dry-run');
  const allUsers = argv.includes('--all-users');
  const emails = argv
    .filter((arg) => !arg.startsWith('--'))
    .map((email) => email.trim().toLowerCase())
    .filter((email) => email.includes('@'));

  return { dryRun, allUsers, emails };
}

function hasCorrectOrgFields(userData, orgId) {
  if (!userData || !orgId) return false;
  return userData.primaryOrgId === orgId && userData.orgId === orgId;
}

async function resolveOrgId(db, uid) {
  const memberships = await db
    .collectionGroup('memberships')
    .where('uid', '==', uid)
    .limit(1)
    .get();

  if (!memberships.empty) {
    const doc = memberships.docs[0];
    const data = doc.data() || {};
    return data.orgId || doc.ref.parent.parent.id;
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

async function listTargetEmails(db, auth, { allUsers, emails }) {
  if (emails.length > 0) return [...new Set(emails)];
  if (!allUsers) return [...QA_EMAILS];

  const snap = await db.collection('users').get();
  const discovered = [];
  for (const doc of snap.docs) {
    const email = (doc.data().email || '').trim().toLowerCase();
    if (email.includes('@')) discovered.push(email);
  }
  return [...new Set(discovered)];
}

async function backfillUser(db, auth, email, { dryRun, stats }) {
  stats.scanned += 1;

  try {
    const authUser = await auth.getUserByEmail(email);
    const uid = authUser.uid;
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    const orgId = await resolveOrgId(db, uid);

    if (!orgId) {
      stats.skipped += 1;
      console.log(`skip ${email}: no membership org found`);
      return;
    }

    if (userSnap.exists && hasCorrectOrgFields(userSnap.data(), orgId)) {
      stats.skipped += 1;
      console.log(`skip ${email}: primaryOrgId already correct (${orgId})`);
      return;
    }

    const payload = {
      orgId,
      primaryOrgId: orgId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (dryRun) {
      stats.updated += 1;
      console.log(`[dry-run] would update ${email} -> primaryOrgId=${orgId}`);
      return;
    }

    await userRef.set(payload, { merge: true });
    stats.updated += 1;
    console.log(`updated ${email} -> primaryOrgId=${orgId}`);
  } catch (err) {
    stats.errors += 1;
    console.error(`error ${email}: ${err.message || err}`);
  }
}

async function main() {
  const { dryRun, allUsers, emails } = parseArgs(process.argv.slice(2));

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }

  const db = admin.firestore();
  const auth = admin.auth();
  const targets = await listTargetEmails(db, auth, { allUsers, emails });
  const stats = { scanned: 0, updated: 0, skipped: 0, errors: 0 };

  console.log(`mode: ${dryRun ? 'dry-run' : 'apply'}`);
  console.log(`targets: ${targets.length}`);

  for (const email of targets) {
    await backfillUser(db, auth, email, { dryRun, stats });
  }

  console.log('---');
  console.log(`users scanned: ${stats.scanned}`);
  console.log(`users updated: ${stats.updated}`);
  console.log(`users skipped: ${stats.skipped}`);
  console.log(`errors: ${stats.errors}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
