#!/usr/bin/env node
/**
 * Launch reset — backup + dry-run/execute for pre-launch cleanup.
 *
 * Usage:
 *   cd tools/admin
 *   node launch_reset.js backup
 *   node launch_reset.js dry-run
 *   node launch_reset.js execute   # destructive — only after approval
 *
 * Preserves: admin@admin.com, itayamar206@gmail.com (+ user docs, platformAdmin)
 * Preserves: all catalog collections (never deleted)
 * Does NOT touch: Firebase config, rules, indexes, Storage (unless future flag)
 */

const fs = require('fs');
const path = require('path');

const {
  PROJECT_ID,
  PRESERVE_AUTH_EMAILS,
  CATALOG_COLLECTIONS,
  BUSINESS_COLLECTIONS,
  initAdmin,
  listAllAuthUsers,
  countCollection,
  exportCollection,
  exportOrganizationsWithMemberships,
  exportProjectsWithAssignments,
  serializeDocData,
} = require('./lib/firebase_admin_client');

const DELETE_ROOT_COLLECTIONS = BUSINESS_COLLECTIONS.filter((c) => !CATALOG_COLLECTIONS.has(c));

function timestampDir() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

function backupRoot(customTs) {
  return path.join(__dirname, 'backups', `launch_reset_${customTs || timestampDir()}`);
}

function writeJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
}

async function listRootCollections(db) {
  const cols = await db.listCollections();
  return cols.map((c) => c.id).sort();
}

async function cmdBackup() {
  const { db, auth } = initAdmin();
  const outDir = backupRoot();
  const meta = {
    projectId: PROJECT_ID,
    createdAt: new Date().toISOString(),
    outDir,
    preserveAuthEmails: [...PRESERVE_AUTH_EMAILS],
    catalogCollections: [...CATALOG_COLLECTIONS],
  };
  writeJson(path.join(outDir, '_meta.json'), meta);

  const authUsers = await listAllAuthUsers(auth);
  writeJson(
    path.join(outDir, 'auth_users.json'),
    authUsers.map((u) => ({
      uid: u.uid,
      email: u.email,
      disabled: u.disabled,
      emailVerified: u.emailVerified,
      customClaims: u.customClaims || {},
      metadata: {
        creationTime: u.metadata.creationTime,
        lastSignInTime: u.metadata.lastSignInTime,
      },
    })),
  );

  const catalogCounts = {};
  for (const name of CATALOG_COLLECTIONS) {
    try {
      catalogCounts[name] = await countCollection(db, name);
    } catch {
      catalogCounts[name] = null;
    }
  }
  writeJson(path.join(outDir, 'catalog_counts.json'), catalogCounts);

  writeJson(
    path.join(outDir, 'organizations.json'),
    serializeDocData(await exportOrganizationsWithMemberships(db)),
  );
  writeJson(
    path.join(outDir, 'projects.json'),
    serializeDocData(await exportProjectsWithAssignments(db)),
  );

  const exportNames = [
    'users',
    'quoteRequests',
    'supplierQuotes',
    'quoteRequestItems',
    'supplierQuoteItems',
    'invitations',
    'projectAssignments',
    'supplierDirectory',
    'auditEvents',
    'orders',
    'history',
  ];

  for (const name of exportNames) {
    try {
      const docs = await exportCollection(db, name);
      writeJson(path.join(outDir, `${name}.json`), serializeDocData(docs));
    } catch (err) {
      writeJson(path.join(outDir, `${name}.json`), { error: err.message, docs: [] });
    }
  }

  const rootCollections = await listRootCollections(db);
  writeJson(path.join(outDir, 'root_collections.json'), rootCollections);

  console.log(JSON.stringify({ ok: true, backupPath: outDir, catalogCounts, rootCollections }, null, 2));
  return outDir;
}

async function countSubcollections(db) {
  let membershipCount = 0;
  const orgSnap = await db.collection('organizations').get();
  for (const orgDoc of orgSnap.docs) {
    const memSnap = await orgDoc.ref.collection('memberships').get();
    membershipCount += memSnap.size;
  }

  let assignmentCount = 0;
  const projectSnap = await db.collection('projects').get();
  for (const projectDoc of projectSnap.docs) {
    const assignSnap = await projectDoc.ref.collection('assignments').get();
    assignmentCount += assignSnap.size;
  }

  return { membershipCount, assignmentCount, orgCount: orgSnap.size, projectCount: projectSnap.size };
}

async function buildLaunchPlan(auth, db) {
  const authUsers = await listAllAuthUsers(auth);
  const preserveAuth = [];
  const deleteAuth = [];
  const adminChecks = {};

  for (const email of PRESERVE_AUTH_EMAILS) {
    try {
      const user = await auth.getUserByEmail(email);
      adminChecks[email] = {
        exists: true,
        uid: user.uid,
        platformAdmin: user.customClaims?.platformAdmin === true,
      };
      preserveAuth.push({
        uid: user.uid,
        email: user.email,
        platformAdmin: user.customClaims?.platformAdmin === true,
      });
    } catch {
      adminChecks[email] = { exists: false, uid: null, platformAdmin: false };
    }
  }

  const preserveUids = new Set(preserveAuth.map((u) => u.uid));

  for (const user of authUsers) {
    const email = (user.email || '').trim().toLowerCase();
    if (PRESERVE_AUTH_EMAILS.has(email)) {
      continue;
    }
    deleteAuth.push({
      uid: user.uid,
      email: user.email || null,
    });
  }

  const userSnap = await db.collection('users').get();
  const preserveUserDocs = userSnap.docs
    .filter((doc) => preserveUids.has(doc.id))
    .map((doc) => ({
      id: doc.id,
      email: doc.data().email || null,
    }));
  const deleteUserDocs = userSnap.docs
    .filter((doc) => !preserveUids.has(doc.id))
    .map((doc) => ({
      id: doc.id,
      email: doc.data().email || null,
    }));

  const collectionCounts = {};
  for (const name of DELETE_ROOT_COLLECTIONS) {
    try {
      collectionCounts[name] = await countCollection(db, name);
    } catch {
      collectionCounts[name] = 0;
    }
  }

  const subcounts = await countSubcollections(db);

  const catalogCounts = {};
  for (const name of CATALOG_COLLECTIONS) {
    try {
      catalogCounts[name] = await countCollection(db, name);
    } catch {
      catalogCounts[name] = null;
    }
  }

  const rootCollections = await listRootCollections(db);
  const extraCollections = rootCollections.filter(
    (c) => !CATALOG_COLLECTIONS.has(c) && !DELETE_ROOT_COLLECTIONS.includes(c),
  );
  const extraCounts = {};
  for (const name of extraCollections) {
    try {
      extraCounts[name] = await countCollection(db, name);
    } catch {
      extraCounts[name] = null;
    }
  }

  const firestoreDocsToDelete = {
    ...collectionCounts,
    organizations: subcounts.orgCount,
    memberships: subcounts.membershipCount,
    projects: subcounts.projectCount,
    assignments: subcounts.assignmentCount,
    users: deleteUserDocs.length,
  };

  const firestoreTotal = Object.values(firestoreDocsToDelete).reduce((a, b) => a + (b || 0), 0);

  const checks = {
    adminAtAdminExists: adminChecks['admin@admin.com']?.exists === true,
    itayamarExists: adminChecks['itayamar206@gmail.com']?.exists === true,
    adminPlatformAdmin: adminChecks['admin@admin.com']?.platformAdmin === true,
    itayamarPlatformAdmin: adminChecks['itayamar206@gmail.com']?.platformAdmin === true,
    noAdminWillBeDeleted: !deleteAuth.some((u) =>
      PRESERVE_AUTH_EMAILS.has((u.email || '').trim().toLowerCase()),
    ),
    catalogDeleteCount: 0,
    storageDeleteCount: 0,
    storageTouched: false,
  };

  return {
    preserveAuthEmails: [...PRESERVE_AUTH_EMAILS],
    preserveAuth,
    preserveUserDocs,
    deleteAuth,
    deleteUserDocs,
    adminChecks,
    collectionCounts,
    subcounts,
    firestoreDocsToDelete,
    firestoreTotal,
    catalogCounts,
    catalogCollectionsPreserved: [...CATALOG_COLLECTIONS],
    extraCollections,
    extraCounts,
    checks,
    dryRunOnly: true,
  };
}

async function cmdDryRun() {
  const { auth, db } = initAdmin();
  const plan = await buildLaunchPlan(auth, db);
  console.log(JSON.stringify({ ok: true, mode: 'dry-run', plan }, null, 2));
  return plan;
}

async function deleteCollectionDocs(db, collectionName, stats) {
  const snap = await db.collection(collectionName).get();
  stats.collections[collectionName] = snap.size;
  if (snap.empty) return;
  let batch = db.batch();
  let ops = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    ops += 1;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();
}

async function deleteOrganizations(db, stats) {
  const orgSnap = await db.collection('organizations').get();
  let membershipDeletes = 0;
  for (const orgDoc of orgSnap.docs) {
    const memSnap = await orgDoc.ref.collection('memberships').get();
    membershipDeletes += memSnap.size;
    let batch = db.batch();
    let ops = 0;
    for (const mem of memSnap.docs) {
      batch.delete(mem.ref);
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    await orgDoc.ref.delete();
  }
  stats.organizations = orgSnap.size;
  stats.memberships = membershipDeletes;
}

async function deleteProjects(db, stats) {
  const projectSnap = await db.collection('projects').get();
  let assignmentDeletes = 0;
  for (const projectDoc of projectSnap.docs) {
    const assignSnap = await projectDoc.ref.collection('assignments').get();
    assignmentDeletes += assignSnap.size;
    let batch = db.batch();
    let ops = 0;
    for (const assign of assignSnap.docs) {
      batch.delete(assign.ref);
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    await projectDoc.ref.delete();
  }
  stats.projects = projectSnap.size;
  stats.assignments = assignmentDeletes;
}

async function cmdExecute({ confirm }) {
  if (!confirm) {
    console.error('Blocked: launch reset execute requires --confirm');
    console.error('  cd tools/admin && node launch_reset.js backup');
    console.error('  cd tools/admin && node launch_reset.js dry-run');
    console.error('  cd tools/admin && node launch_reset.js execute --confirm');
    process.exit(1);
  }

  const { db, auth } = initAdmin();
  const plan = await buildLaunchPlan(auth, db);

  for (const key of ['adminAtAdminExists', 'itayamarExists', 'adminPlatformAdmin', 'itayamarPlatformAdmin', 'noAdminWillBeDeleted']) {
    if (!plan.checks[key]) {
      throw new Error(`Pre-flight check failed: ${key}`);
    }
  }

  const backupPath = await cmdBackup();
  const stats = { collections: {}, authDeleted: 0, userDocsDeleted: 0, backupPath };

  for (const name of [
    'quoteRequests',
    'supplierQuotes',
    'quoteRequestItems',
    'supplierQuoteItems',
    'invitations',
    'projectAssignments',
    'supplierDirectory',
    'auditEvents',
  ]) {
    await deleteCollectionDocs(db, name, stats);
  }
  await deleteProjects(db, stats);
  await deleteOrganizations(db, stats);

  const preserveUids = new Set(plan.preserveAuth.map((u) => u.uid));
  const userSnap = await db.collection('users').get();
  let batch = db.batch();
  let ops = 0;
  for (const doc of userSnap.docs) {
    if (preserveUids.has(doc.id)) continue;
    batch.delete(doc.ref);
    stats.userDocsDeleted += 1;
    ops += 1;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  for (const target of plan.deleteAuth) {
    await auth.deleteUser(target.uid);
    stats.authDeleted += 1;
  }

  const catalogCountsAfter = {};
  for (const name of CATALOG_COLLECTIONS) {
    catalogCountsAfter[name] = await countCollection(db, name);
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        mode: 'execute',
        stats,
        catalogCountsBefore: plan.catalogCounts,
        catalogCountsAfter,
        catalogUnchanged: Object.keys(plan.catalogCounts).every(
          (k) => plan.catalogCounts[k] === catalogCountsAfter[k],
        ),
      },
      null,
      2,
    ),
  );
}

async function main() {
  const args = process.argv.slice(2);
  const [command] = args;
  const confirm = args.includes('--confirm');

  if (command === 'backup') return cmdBackup();
  if (command === 'dry-run') return cmdDryRun();
  if (command === 'execute') return cmdExecute({ confirm });

  console.error('Usage: node launch_reset.js <backup|dry-run|execute>');
  process.exit(1);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.stack || err.message || err);
    process.exit(1);
  });
}

module.exports = { cmdBackup, cmdDryRun, buildLaunchPlan, backupRoot };
