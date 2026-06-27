#!/usr/bin/env node
/**
 * Admin onboarding — create single user or seed launch test structure.
 *
 * Usage:
 *   cd tools/admin
 *   node admin_onboarding.js create-user \
 *     --email "dimri.owner@test.com" \
 *     --password "123123" \
 *     --name "דימרי בעלים" \
 *     --org "launch-org-dimri" \
 *     --role "contractorCompanyOwner" \
 *     --userType "commercialCustomer"
 *
 *   node admin_onboarding.js seed-launch-test
 *
 * Password: tries 123123 first, falls back to Qa123456! on weak-password.
 */

const { initAdmin } = require('./lib/firebase_admin_client');

const PRIMARY_PASSWORD = '123123';
const FALLBACK_PASSWORD = 'Qa123456!';

const LAUNCH_MANIFEST = {
  contractorOrgs: [
    {
      id: 'launch-org-dimri',
      name: 'דימרי',
      project: { id: 'launch-proj-dimri', name: 'דימרי — פרויקט ראשי', cityOrArea: 'תל אביב' },
      users: [
        { email: 'dimri.owner@test.com', role: 'contractorCompanyOwner', label: 'דימרי בעלים' },
        { email: 'dimri.procurement@test.com', role: 'procurementManager', label: 'דימרי רכש' },
        { email: 'dimri.engineer@test.com', role: 'engineer', label: 'דימרי מהנדס' },
        { email: 'dimri.pm@test.com', role: 'projectManager', label: 'דימרי PM' },
      ],
    },
    {
      id: 'launch-org-afgad',
      name: 'אפגד',
      project: { id: 'launch-proj-afgad', name: 'אפגד — פרויקט ראשי', cityOrArea: 'חיפה' },
      users: [
        { email: 'afgad.owner@test.com', role: 'contractorCompanyOwner', label: 'אפגד בעלים' },
        { email: 'afgad.procurement@test.com', role: 'procurementManager', label: 'אפגד רכש' },
        { email: 'afgad.engineer@test.com', role: 'engineer', label: 'אפגד מהנדס' },
        { email: 'afgad.pm@test.com', role: 'projectManager', label: 'אפגד PM' },
      ],
    },
    {
      id: 'launch-org-shariki',
      name: 'שריקי',
      project: { id: 'launch-proj-shariki', name: 'שריקי — פרויקט ראשי', cityOrArea: 'ירושלים' },
      users: [
        { email: 'shariki.owner@test.com', role: 'contractorCompanyOwner', label: 'שריקי בעלים' },
        { email: 'shariki.procurement@test.com', role: 'procurementManager', label: 'שריקי רכש' },
        { email: 'shariki.engineer@test.com', role: 'engineer', label: 'שריקי מהנדס' },
        { email: 'shariki.pm@test.com', role: 'projectManager', label: 'שריקי PM' },
      ],
    },
  ],
  supplierOrgs: [
    {
      id: 'launch-org-frishman',
      name: 'פרישמן',
      city: 'תל אביב',
      users: [
        { email: 'frishman.owner@test.com', role: 'supplierOwner', label: 'פרישמן בעלים' },
        { email: 'frishman.procurement@test.com', role: 'supplierOps', label: 'פרישמן רכש' },
        { email: 'frishman.sales@test.com', role: 'supplierSalesRep', label: 'פרישמן מכירות' },
      ],
    },
    {
      id: 'launch-org-tubul',
      name: 'טובול',
      city: 'חיפה',
      users: [
        { email: 'tubul.owner@test.com', role: 'supplierOwner', label: 'טובול בעלים' },
        { email: 'tubul.procurement@test.com', role: 'supplierOps', label: 'טובול רכש' },
        { email: 'tubul.sales@test.com', role: 'supplierSalesRep', label: 'טובול מכירות' },
      ],
    },
    {
      id: 'launch-org-itay',
      name: 'איתי',
      city: 'באר שבע',
      users: [
        { email: 'itay.supplier.owner@test.com', role: 'supplierOwner', label: 'איתי בעלים' },
        { email: 'itay.supplier.procurement@test.com', role: 'supplierOps', label: 'איתי רכש' },
        { email: 'itay.supplier.sales@test.com', role: 'supplierSalesRep', label: 'איתי מכירות' },
      ],
    },
  ],
};

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const val = argv[i + 1];
    if (val && !val.startsWith('--')) {
      out[key] = val;
      i += 1;
    } else {
      out[key] = true;
    }
  }
  return out;
}

async function ensureAuthUser(auth, email, password) {
  try {
    const existing = await auth.getUserByEmail(email);
    await auth.updateUser(existing.uid, {
      password,
      emailVerified: true,
      disabled: false,
    });
    return { uid: existing.uid, passwordUsed: password };
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    try {
      const created = await auth.createUser({
        email,
        password,
        emailVerified: true,
        disabled: false,
      });
      return { uid: created.uid, passwordUsed: password };
    } catch (createErr) {
      if (
        createErr.code === 'auth/weak-password' &&
        password !== FALLBACK_PASSWORD
      ) {
        return ensureAuthUser(auth, email, FALLBACK_PASSWORD);
      }
      throw createErr;
    }
  }
}

async function upsertUserDoc(db, admin, uid, payload) {
  await db.collection('users').doc(uid).set(
    {
      ...payload,
      uid,
      name: payload.fullName || payload.name,
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

async function cmdCreateUser(args) {
  const email = (args.email || '').trim().toLowerCase();
  const password = args.password || PRIMARY_PASSWORD;
  const fullName = (args.name || '').trim();
  const orgId = (args.org || '').trim();
  const role = (args.role || '').trim();
  const userType = (args.userType || 'commercialCustomer').trim();
  const phone = (args.phone || '0500000000').trim();
  const city = (args.city || 'ישראל').trim();

  if (!email || !fullName || !orgId || !role) {
    throw new Error('Missing required: --email --name --org --role');
  }

  const { db, auth, admin } = initAdmin();
  const orgSnap = await db.collection('organizations').doc(orgId).get();
  if (!orgSnap.exists) {
    throw new Error(`Organization not found: ${orgId}`);
  }
  const orgType = orgSnap.data().type;
  const isSupplier = orgType === 'supplier';

  const { uid, passwordUsed } = await ensureAuthUser(auth, email, password);

  await upsertUserDoc(db, admin, uid, {
    fullName,
    email,
    phone,
    userType,
    city,
    verified: true,
    accountStatus: 'active',
    orgId,
    primaryOrgId: orgId,
    ...(isSupplier ? { supplierOrgId: orgId } : {}),
  });

  await upsertMembership(db, admin, orgId, orgType, uid, role, {
    email,
    displayName: fullName,
    createdBy: uid,
    projectIds: [],
  });

  if (role === 'contractorCompanyOwner' || role === 'supplierOwner') {
    await db.collection('organizations').doc(orgId).set(
      {
        ownerUid: uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  if (isSupplier && role === 'supplierOwner') {
    await db.collection('supplierDirectory').doc(uid).set(
      {
        uid,
        orgId,
        displayName: orgSnap.data().name || fullName,
        city,
        categoryIds: [],
        serviceAreas: [city],
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        uid,
        email,
        orgId,
        role,
        passwordUsed,
        weakPasswordFallback: passwordUsed === FALLBACK_PASSWORD,
      },
      null,
      2,
    ),
  );
}

async function cmdSeedLaunchTest() {
  const { db, auth, admin } = initAdmin();
  const created = { users: [], contractorOrgs: [], supplierOrgs: [], projects: [] };

  for (const orgDef of LAUNCH_MANIFEST.contractorOrgs) {
    let ownerUid = null;
    const memberUids = [];

    for (const userDef of orgDef.users) {
      const { uid, passwordUsed } = await ensureAuthUser(
        auth,
        userDef.email,
        PRIMARY_PASSWORD,
      );
      memberUids.push({ uid, ...userDef, passwordUsed });
      if (userDef.role === 'contractorCompanyOwner') ownerUid = uid;

      await upsertUserDoc(db, admin, uid, {
        fullName: userDef.label,
        email: userDef.email,
        phone: '0500000000',
        userType: 'commercialCustomer',
        city: orgDef.project.cityOrArea,
        verified: true,
        accountStatus: 'active',
        orgId: orgDef.id,
        primaryOrgId: orgDef.id,
      });
      created.users.push({
        email: userDef.email,
        uid,
        orgId: orgDef.id,
        role: userDef.role,
        passwordUsed,
      });
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
      .filter((u) =>
        ['contractorCompanyOwner', 'procurementManager', 'projectManager'].includes(u.role),
      )
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

  for (const orgDef of LAUNCH_MANIFEST.supplierOrgs) {
    let ownerUid = null;
    const memberUids = [];

    for (const userDef of orgDef.users) {
      const { uid, passwordUsed } = await ensureAuthUser(
        auth,
        userDef.email,
        PRIMARY_PASSWORD,
      );
      memberUids.push({ uid, ...userDef, passwordUsed });
      if (userDef.role === 'supplierOwner') ownerUid = uid;

      await upsertUserDoc(db, admin, uid, {
        fullName: userDef.label,
        email: userDef.email,
        phone: '0500000001',
        userType: 'commercialSupplier',
        city: orgDef.city,
        verified: true,
        accountStatus: 'active',
        orgId: orgDef.id,
        primaryOrgId: orgDef.id,
        supplierOrgId: orgDef.id,
      });
      created.users.push({
        email: userDef.email,
        uid,
        orgId: orgDef.id,
        role: userDef.role,
        passwordUsed,
      });
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

  console.log(JSON.stringify({ ok: true, created }, null, 2));
}

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);

  if (command === 'create-user') return cmdCreateUser(args);
  if (command === 'seed-launch-test') return cmdSeedLaunchTest();

  console.error(
    'Usage:\n' +
      '  node admin_onboarding.js create-user --email ... --password ... --name ... --org ... --role ... [--userType ...]\n' +
      '  node admin_onboarding.js seed-launch-test',
  );
  process.exit(1);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.stack || err.message || err);
    process.exit(1);
  });
}

module.exports = { LAUNCH_MANIFEST, cmdCreateUser, cmdSeedLaunchTest };
