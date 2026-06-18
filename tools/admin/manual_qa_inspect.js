#!/usr/bin/env node
/**
 * Phase 1 — read-only inspection for manual QA reset.
 *
 * Usage:
 *   cd tools/admin
 *   node manual_qa_inspect.js
 */

const {
  PROJECT_ID,
  PRESERVE_AUTH_EMAILS,
  CATALOG_COLLECTIONS,
  BUSINESS_COLLECTIONS,
  initAdmin,
  listAllAuthUsers,
  countCollection,
  exportOrganizationsWithMemberships,
} = require('./lib/firebase_admin_client');

const QA_EMAIL_RE =
  /^(qa\.|test\.)|@test\.com$|@example\.com$|qa\.contractor|qa\.supplier/i;

function classifyAuthUser(user) {
  const email = (user.email || '').trim().toLowerCase();
  if (!email) return 'unknown_no_email';
  if (PRESERVE_AUTH_EMAILS.has(email)) return 'preserve_admin';
  if (QA_EMAIL_RE.test(email)) return 'delete_candidate_qa';
  return 'needs_confirmation';
}

async function main() {
  const { db, auth } = initAdmin();
  const report = {
    projectId: PROJECT_ID,
    generatedAt: new Date().toISOString(),
    auth: {},
    collections: {},
    catalog: {},
    organizations: [],
    preserve: {
      authEmails: [...PRESERVE_AUTH_EMAILS],
      catalogCollections: [...CATALOG_COLLECTIONS],
    },
    deletePlan: {
      authUsers: [],
      firestoreCollections: BUSINESS_COLLECTIONS.filter(
        (c) => !CATALOG_COLLECTIONS.has(c),
      ),
    },
    needsConfirmation: [],
    unknownCollections: [],
  };

  const authUsers = await listAllAuthUsers(auth);
  report.auth.total = authUsers.length;
  report.auth.byClass = {
    preserve_admin: [],
    delete_candidate_qa: [],
    needs_confirmation: [],
    unknown_no_email: [],
  };

  for (const user of authUsers) {
    const bucket = classifyAuthUser(user);
    const entry = {
      uid: user.uid,
      email: user.email || null,
      disabled: user.disabled,
      customClaims: user.customClaims || {},
    };
    report.auth.byClass[bucket].push(entry);
    if (bucket === 'delete_candidate_qa') {
      report.deletePlan.authUsers.push(entry);
    } else if (bucket === 'needs_confirmation') {
      report.needsConfirmation.push(entry);
    }
  }

  for (const adminEmail of PRESERVE_AUTH_EMAILS) {
    const admin = authUsers.find(
      (u) => (u.email || '').toLowerCase() === adminEmail,
    );
    if (!admin) {
      report.needsConfirmation.push({
        type: 'missing_admin',
        email: adminEmail,
      });
    } else {
      report.auth.admins = report.auth.admins || [];
      report.auth.admins.push({
        email: adminEmail,
        uid: admin.uid,
        platformAdmin: admin.customClaims?.platformAdmin === true,
        customClaims: admin.customClaims || {},
      });
    }
  }

  const allCollections = [...CATALOG_COLLECTIONS, ...BUSINESS_COLLECTIONS];
  for (const name of allCollections) {
    try {
      const count = await countCollection(db, name);
      const bucket = CATALOG_COLLECTIONS.has(name) ? report.catalog : report.collections;
      bucket[name] = count;
    } catch (err) {
      report.unknownCollections.push({ name, error: err.message });
    }
  }

  const orgs = await exportOrganizationsWithMemberships(db);
  report.organizations = orgs.map((o) => ({
    id: o.id,
    name: o.name,
    type: o.type,
    ownerUid: o.ownerUid,
    status: o.status,
    membershipCount: (o.memberships || []).length,
  }));

  report.summary = {
    authPreserve: report.auth.byClass.preserve_admin.length,
    authDeleteCandidates: report.auth.byClass.delete_candidate_qa.length,
    authNeedsConfirmation: report.auth.byClass.needs_confirmation.length,
    organizationCount: orgs.length,
    quoteRequests: report.collections.quoteRequests ?? 0,
    supplierQuotes: report.collections.supplierQuotes ?? 0,
    projects: report.collections.projects ?? 0,
  };

  console.log(JSON.stringify(report, null, 2));
}

main().catch((err) => {
  console.error(err.stack || err.message || err);
  process.exit(1);
});
