#!/usr/bin/env node
/**
 * Manual QA reset — backup, cleanup, seed, verify.
 *
 * Usage:
 *   cd tools/admin
 *   node manual_qa_reset.js inspect          # same as manual_qa_inspect.js
 *   node manual_qa_reset.js backup
 *   node manual_qa_reset.js cleanup --dry-run
 *   node manual_qa_reset.js cleanup --execute
 *   node manual_qa_reset.js seed
 *   node manual_qa_reset.js verify
 *
 * Requires Application Default Credentials or GOOGLE_APPLICATION_CREDENTIALS.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

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

const QA_PASSWORD = 'Qa123456!';
const AUTH_API_KEY = process.env.FIREBASE_WEB_API_KEY || 'AIzaSyAMI5ezgGSRZBU8IjklF9fXcBC_PAhqOhc';

const QA_EMAIL_RE =
  /^(qa\.|test\.)|@test\.com$|@example\.com$|qa\.contractor|qa\.supplier|full\.qa\.|\.qa\d|hierarchy\.|stress\.|fullflow/i;

const DELETE_COLLECTIONS = BUSINESS_COLLECTIONS.filter((c) => !CATALOG_COLLECTIONS.has(c));

function classifyAuthUser(user) {
  const email = (user.email || '').trim().toLowerCase();
  if (!email) return 'unknown_no_email';
  if (PRESERVE_AUTH_EMAILS.has(email)) return 'preserve_admin';
  if (QA_EMAIL_RE.test(email)) return 'delete_candidate_qa';
  return 'needs_confirmation';
}

function timestampDir() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

function backupRoot(customTs) {
  return path.join(__dirname, 'backups', `manual_qa_reset_${customTs || timestampDir()}`);
}

function writeJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
}

async function cmdBackup() {
  const { db, auth, admin } = initAdmin();
  const outDir = backupRoot();
  const meta = {
    projectId: PROJECT_ID,
    createdAt: new Date().toISOString(),
    outDir,
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
    catalogCounts[name] = await countCollection(db, name);
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

  for (const name of [
    'users',
    'quoteRequests',
    'supplierQuotes',
    'quoteRequestItems',
    'supplierQuoteItems',
    'invitations',
    'projectAssignments',
    'supplierDirectory',
    'auditEvents',
  ]) {
    const docs = await exportCollection(db, name);
    writeJson(path.join(outDir, `${name}.json`), serializeDocData(docs));
  }

  console.log(JSON.stringify({ ok: true, backupPath: outDir, catalogCounts }, null, 2));
  return outDir;
}

async function deleteCollectionDocs(db, collectionName, dryRun, stats) {
  const snap = await db.collection(collectionName).get();
  stats.collections[collectionName] = snap.size;
  if (dryRun || snap.empty) return;
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

async function deleteOrganizations(db, dryRun, stats) {
  const orgSnap = await db.collection('organizations').get();
  let membershipDeletes = 0;
  for (const orgDoc of orgSnap.docs) {
    const memSnap = await orgDoc.ref.collection('memberships').get();
    membershipDeletes += memSnap.size;
    if (!dryRun) {
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
  }
  stats.organizations = orgSnap.size;
  stats.memberships = membershipDeletes;
}

async function deleteProjects(db, dryRun, stats) {
  const projectSnap = await db.collection('projects').get();
  let assignmentDeletes = 0;
  for (const projectDoc of projectSnap.docs) {
    const assignSnap = await projectDoc.ref.collection('assignments').get();
    assignmentDeletes += assignSnap.size;
    if (!dryRun) {
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
  }
  stats.projects = projectSnap.size;
  stats.projectAssignments = assignmentDeletes;
}

async function buildCleanupPlan(auth, db) {
  const authUsers = await listAllAuthUsers(auth);
  const preserveUids = new Set();
  const deleteAuth = [];
  const needsConfirmation = [];

  for (const user of authUsers) {
    const bucket = classifyAuthUser(user);
    if (bucket === 'preserve_admin' || bucket === 'needs_confirmation') {
      if (user.email) preserveUids.add(user.uid);
      if (bucket === 'needs_confirmation') {
        needsConfirmation.push({
          uid: user.uid,
          email: user.email,
        });
      }
    } else if (bucket === 'delete_candidate_qa' || bucket === 'unknown_no_email') {
      deleteAuth.push({
        uid: user.uid,
        email: user.email,
        bucket,
      });
    }
  }

  const userSnap = await db.collection('users').get();
  const deleteUserDocs = userSnap.docs
    .filter((doc) => !preserveUids.has(doc.id))
    .map((doc) => ({ id: doc.id, email: doc.data().email || null }));

  const counts = {};
  for (const name of DELETE_COLLECTIONS) {
    counts[name] = await countCollection(db, name);
  }

  return {
    preserveAuthEmails: [...PRESERVE_AUTH_EMAILS],
    preserveUids: [...preserveUids],
    deleteAuth,
    deleteUserDocs,
    needsConfirmation,
    collectionCounts: counts,
  };
}

async function cmdCleanup({ dryRun, execute }) {
  const { db, auth } = initAdmin();
  const plan = await buildCleanupPlan(auth, db);
  const stats = {
    mode: dryRun ? 'dry-run' : execute ? 'execute' : 'plan-only',
    collections: {},
    authDeleted: 0,
    userDocsDeleted: 0,
  };

  if (plan.needsConfirmation.length > 0) {
    plan.warning =
      'NEEDS_CONFIRMATION users will be preserved (auth + user doc). Review before execute.';
  }

  if (!dryRun && !execute) {
    console.log(JSON.stringify({ plan }, null, 2));
    return;
  }

  // Firestore business cleanup (preserved user docs for admins + NEEDS_CONFIRMATION)
  await deleteCollectionDocs(db, 'quoteRequests', dryRun, stats);
  await deleteCollectionDocs(db, 'supplierQuotes', dryRun, stats);
  await deleteCollectionDocs(db, 'quoteRequestItems', dryRun, stats);
  await deleteCollectionDocs(db, 'supplierQuoteItems', dryRun, stats);
  await deleteCollectionDocs(db, 'invitations', dryRun, stats);
  await deleteCollectionDocs(db, 'projectAssignments', dryRun, stats);
  await deleteCollectionDocs(db, 'supplierDirectory', dryRun, stats);
  await deleteCollectionDocs(db, 'auditEvents', dryRun, stats);
  await deleteProjects(db, dryRun, stats);
  await deleteOrganizations(db, dryRun, stats);

  const userSnap = await db.collection('users').get();
  const preserve = new Set(plan.preserveUids);
  stats.userDocsDeleted = userSnap.docs.filter((d) => !preserve.has(d.id)).length;
  if (execute) {
    let batch = db.batch();
    let ops = 0;
    for (const doc of userSnap.docs) {
      if (preserve.has(doc.id)) continue;
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

  for (const target of plan.deleteAuth) {
    if (dryRun) continue;
    await auth.deleteUser(target.uid);
    stats.authDeleted += 1;
  }

  const catalogCounts = {};
  for (const name of CATALOG_COLLECTIONS) {
    catalogCounts[name] = await countCollection(db, name);
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        dryRun,
        execute,
        plan,
        stats,
        catalogCountsAfter: catalogCounts,
      },
      null,
      2,
    ),
  );
}

const SEED_MANIFEST = {
  contractorOrgs: [
    {
      id: 'qa-org-contractor-alpha',
      name: 'בדיקות קבלן אלפא בע"מ',
      project: {
        id: 'qa-proj-alpha',
        name: 'בדיקות פרויקט אלפא',
        cityOrArea: 'תל אביב',
      },
      users: [
        { email: 'qa.alpha.owner@test.com', role: 'contractorCompanyOwner', label: 'מנהל חברה', userType: 'commercialCustomer' },
        { email: 'qa.alpha.procurement1@test.com', role: 'procurementManager', label: 'רכש 1', userType: 'commercialCustomer' },
        { email: 'qa.alpha.procurement2@test.com', role: 'procurementManager', label: 'רכש 2', userType: 'commercialCustomer' },
        { email: 'qa.alpha.engineer1@test.com', role: 'engineer', label: 'מהנדס 1', userType: 'commercialCustomer' },
        { email: 'qa.alpha.engineer2@test.com', role: 'engineer', label: 'מהנדס 2', userType: 'commercialCustomer' },
        { email: 'qa.alpha.viewer@test.com', role: 'contractorViewer', label: 'צפייה בלבד', userType: 'commercialCustomer' },
      ],
    },
    {
      id: 'qa-org-contractor-beta',
      name: 'בדיקות קבלן בטא בע"מ',
      project: {
        id: 'qa-proj-beta',
        name: 'בדיקות פרויקט בטא',
        cityOrArea: 'חיפה',
      },
      users: [
        { email: 'qa.beta.owner@test.com', role: 'contractorCompanyOwner', label: 'מנהל חברה', userType: 'commercialCustomer' },
        { email: 'qa.beta.procurement@test.com', role: 'procurementManager', label: 'רכש', userType: 'commercialCustomer' },
        { email: 'qa.beta.engineer@test.com', role: 'engineer', label: 'מהנדס', userType: 'commercialCustomer' },
      ],
    },
  ],
  supplierOrgs: [
    {
      id: 'qa-org-supplier-a',
      name: 'בדיקות ספק גדול בע"מ',
      city: 'תל אביב',
      users: [
        { email: 'qa.supplierA.owner@test.com', role: 'supplierOwner', label: 'מנהל ספק', userType: 'commercialSupplier' },
        { email: 'qa.supplierA.sales1@test.com', role: 'supplierSalesRep', label: 'איש מכירות', userType: 'commercialSupplier' },
        { email: 'qa.supplierA.viewer@test.com', role: 'supplierViewer', label: 'צפייה בלבד', userType: 'commercialSupplier' },
      ],
    },
    {
      id: 'qa-org-supplier-b',
      name: 'בדיקות ספק קטן בע"מ',
      city: 'חיפה',
      users: [
        { email: 'qa.supplierB.owner@test.com', role: 'supplierOwner', label: 'מנהל ספק', userType: 'commercialSupplier' },
        { email: 'qa.supplierB.sales@test.com', role: 'supplierSalesRep', label: 'איש מכירות', userType: 'commercialSupplier' },
      ],
    },
    {
      id: 'qa-org-supplier-c',
      name: 'בדיקות ספק לא מוזמן בע"מ',
      city: 'באר שבע',
      users: [
        { email: 'qa.supplierC.owner@test.com', role: 'supplierOwner', label: 'מנהל ספק', userType: 'commercialSupplier' },
      ],
    },
  ],
  specialUsers: [
    {
      email: 'qa.noaccess@test.com',
      label: 'ללא הרשאות',
      userType: 'commercialCustomer',
      accountStatus: 'active',
      membership: false,
    },
    {
      email: 'qa.pending@test.com',
      label: 'ממתין לאישור',
      userType: 'commercialCustomer',
      accountStatus: 'pendingApproval',
      membership: false,
    },
  ],
};

async function ensureAuthUser(auth, email, password) {
  try {
    const existing = await auth.getUserByEmail(email);
    await auth.updateUser(existing.uid, {
      password,
      emailVerified: true,
      disabled: false,
    });
    return existing.uid;
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const created = await auth.createUser({
      email,
      password,
      emailVerified: true,
      disabled: false,
    });
    return created.uid;
  }
}

async function upsertUserDoc(db, admin, uid, payload) {
  await db.collection('users').doc(uid).set(
    {
      ...payload,
      uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function upsertMembership(db, admin, orgId, orgType, uid, role, meta) {
  await db
    .collection('organizations')
    .doc(orgId)
    .collection('memberships')
    .doc(uid)
    .set(
      {
        uid,
        orgId,
        orgType,
        roles: [role],
        status: 'active',
        projectIds: meta.projectIds || [],
        email: meta.email,
        displayName: meta.displayName,
        createdBy: meta.createdBy || uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function cmdSeed() {
  const { db, auth, admin } = initAdmin();
  const created = {
    users: [],
    contractorOrgs: [],
    supplierOrgs: [],
    projects: [],
  };

  for (const orgDef of SEED_MANIFEST.contractorOrgs) {
    let ownerUid = null;
  const memberUids = [];

    for (const userDef of orgDef.users) {
      const uid = await ensureAuthUser(auth, userDef.email, QA_PASSWORD);
      memberUids.push({ uid, ...userDef });
      if (userDef.role === 'contractorCompanyOwner') ownerUid = uid;

      await upsertUserDoc(db, admin, uid, {
        name: userDef.label,
        fullName: userDef.label,
        email: userDef.email,
        phone: '0500000000',
        userType: userDef.userType,
        city: orgDef.project.cityOrArea,
        verified: true,
        accountStatus: 'active',
        orgId: orgDef.id,
        primaryOrgId: orgDef.id,
      });
      created.users.push({ email: userDef.email, uid, orgId: orgDef.id, role: userDef.role });
    }

    ownerUid = ownerUid || memberUids[0].uid;
    await db.collection('organizations').doc(orgDef.id).set(
      {
        type: 'contractor',
        name: orgDef.name,
        ownerUid,
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    created.contractorOrgs.push({ id: orgDef.id, name: orgDef.name, ownerUid });

    const projectId = orgDef.project.id;
    const managerUids = memberUids
      .filter((u) => ['contractorCompanyOwner', 'procurementManager', 'projectManager'].includes(u.role))
      .map((u) => u.uid);

    await db.collection('projects').doc(projectId).set(
      {
        ownerUid,
        orgId: orgDef.id,
        companyName: orgDef.name,
        name: orgDef.project.name,
        cityOrArea: orgDef.project.cityOrArea,
        location: orgDef.project.cityOrArea,
        status: 'active',
        managerUids,
        createdBy: ownerUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    created.projects.push({ id: projectId, orgId: orgDef.id, name: orgDef.project.name });

    for (const member of memberUids) {
      await upsertMembership(db, admin, orgDef.id, 'contractor', member.uid, member.role, {
        email: member.email,
        displayName: member.label,
        createdBy: ownerUid,
        projectIds: [projectId],
      });
      await db
        .collection('projects')
        .doc(projectId)
        .collection('assignments')
        .doc(member.uid)
        .set(
          {
            projectId,
            orgId: orgDef.id,
            uid: member.uid,
            role: member.role,
            displayName: member.label,
            email: member.email,
            assignedByUid: ownerUid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
    }
  }

  for (const orgDef of SEED_MANIFEST.supplierOrgs) {
    let ownerUid = null;
    const memberUids = [];

    for (const userDef of orgDef.users) {
      const uid = await ensureAuthUser(auth, userDef.email, QA_PASSWORD);
      memberUids.push({ uid, ...userDef });
      if (userDef.role === 'supplierOwner') ownerUid = uid;

      await upsertUserDoc(db, admin, uid, {
        name: userDef.label,
        fullName: userDef.label,
        email: userDef.email,
        phone: '0500000001',
        userType: userDef.userType,
        city: orgDef.city,
        verified: true,
        accountStatus: 'active',
        orgId: orgDef.id,
        primaryOrgId: orgDef.id,
        supplierOrgId: orgDef.id,
      });
      created.users.push({ email: userDef.email, uid, orgId: orgDef.id, role: userDef.role });
    }

    ownerUid = ownerUid || memberUids[0].uid;
    await db.collection('organizations').doc(orgDef.id).set(
      {
        type: 'supplier',
        name: orgDef.name,
        ownerUid,
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    created.supplierOrgs.push({ id: orgDef.id, name: orgDef.name, ownerUid });

    for (const member of memberUids) {
      await upsertMembership(db, admin, orgDef.id, 'supplier', member.uid, member.role, {
        email: member.email,
        displayName: member.label,
        createdBy: ownerUid,
        projectIds: [],
      });
    }

    await db.collection('supplierDirectory').doc(ownerUid).set(
      {
        uid: ownerUid,
        orgId: orgDef.id,
        displayName: orgDef.name,
        city: orgDef.city,
        categoryIds: [],
        serviceAreas: [orgDef.city],
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  for (const userDef of SEED_MANIFEST.specialUsers) {
    const uid = await ensureAuthUser(auth, userDef.email, QA_PASSWORD);
    await upsertUserDoc(db, admin, uid, {
      name: userDef.label,
      fullName: userDef.label,
      email: userDef.email,
      phone: '0500000002',
      userType: userDef.userType,
      city: 'תל אביב',
      verified: false,
      accountStatus: userDef.accountStatus,
    });
    created.users.push({
      email: userDef.email,
      uid,
      accountStatus: userDef.accountStatus,
      membership: userDef.membership,
    });
  }

  console.log(JSON.stringify({ ok: true, created }, null, 2));
}

function authSignIn(email, password) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    });
    const req = https.request(
      {
        hostname: 'identitytoolkit.googleapis.com',
        path: `/v1/accounts:signInWithPassword?key=${AUTH_API_KEY}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(JSON.parse(data));
          } else {
            reject(new Error(`sign-in ${email}: HTTP ${res.statusCode} ${data}`));
          }
        });
      },
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function cmdVerify() {
  const { db, auth } = initAdmin();
  const report = {
    authSignIn: {},
    memberships: {},
    projects: {},
    supplierDirectory: {},
    catalog: {},
    admins: {},
    special: {},
  };

  const allSeedEmails = [
    ...SEED_MANIFEST.contractorOrgs.flatMap((o) => o.users.map((u) => u.email)),
    ...SEED_MANIFEST.supplierOrgs.flatMap((o) => o.users.map((u) => u.email)),
    ...SEED_MANIFEST.specialUsers.map((u) => u.email),
  ];

  for (const email of allSeedEmails) {
    try {
      const result = await authSignIn(email, QA_PASSWORD);
      report.authSignIn[email] = { ok: true, uid: result.localId };
    } catch (err) {
      report.authSignIn[email] = { ok: false, error: err.message };
    }
  }

  for (const adminEmail of PRESERVE_AUTH_EMAILS) {
    const user = await auth.getUserByEmail(adminEmail);
    report.admins[adminEmail] = {
      uid: user.uid,
      platformAdmin: user.customClaims?.platformAdmin === true,
    };
  }

  for (const email of allSeedEmails) {
    const authUser = await auth.getUserByEmail(email);
    const userDoc = await db.collection('users').doc(authUser.uid).get();
    const memSnap = await db.collectionGroup('memberships').where('uid', '==', authUser.uid).get();
    report.memberships[email] = {
      userDoc: userDoc.exists,
      primaryOrgId: userDoc.data()?.primaryOrgId || null,
      accountStatus: userDoc.data()?.accountStatus || null,
      membershipCount: memSnap.size,
      roles: memSnap.docs.map((d) => d.data().roles || []),
    };
  }

  const supplierOrgs = await db
    .collection('organizations')
    .where('type', '==', 'supplier')
    .where('status', '==', 'active')
    .get();
  report.supplierDirectory.orgCount = supplierOrgs.size;
  report.supplierDirectory.orgNames = supplierOrgs.docs.map((d) => d.data().name);

  const projects = await db.collection('projects').get();
  report.projects.count = projects.size;
  report.projects.ids = projects.docs.map((d) => d.id);

  for (const name of CATALOG_COLLECTIONS) {
    report.catalog[name] = await countCollection(db, name);
  }

  report.special.noaccess = report.memberships['qa.noaccess@test.com'];
  report.special.pending = report.memberships['qa.pending@test.com'];

  const ok =
    Object.values(report.authSignIn).every((v) => v.ok) &&
    report.memberships['qa.noaccess@test.com']?.membershipCount === 0 &&
    report.memberships['qa.pending@test.com']?.accountStatus === 'pendingApproval' &&
    supplierOrgs.size >= 3 &&
    projects.size >= 2;

  console.log(JSON.stringify({ ok, report }, null, 2));
  if (!ok) process.exit(1);
}

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const dryRun = rest.includes('--dry-run');
  const execute = rest.includes('--execute');

  if (command === 'backup') return cmdBackup();
  if (command === 'cleanup') return cmdCleanup({ dryRun, execute });
  if (command === 'seed') return cmdSeed();
  if (command === 'verify') return cmdVerify();

  console.error(
    'Usage: node manual_qa_reset.js <backup|cleanup|seed|verify> [--dry-run|--execute]',
  );
  process.exit(1);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.stack || err.message || err);
    process.exit(1);
  });
}

module.exports = { buildCleanupPlan, SEED_MANIFEST, cmdBackup, cmdCleanup, cmdSeed, cmdVerify };
