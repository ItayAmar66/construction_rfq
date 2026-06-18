const admin = require('firebase-admin');

const PROJECT_ID = 'construction-rfq-itay-20-2eee0';

const PRESERVE_AUTH_EMAILS = new Set([
  'admin@admin.com',
  'itayamar206@gmail.com',
]);

const CATALOG_COLLECTIONS = new Set([
  'catalogCategories',
  'catalogProducts',
  'catalogVariants',
  'catalogMeta',
  'products',
  'appMeta',
]);

const BUSINESS_COLLECTIONS = [
  'users',
  'organizations',
  'projects',
  'quoteRequests',
  'supplierQuotes',
  'quoteRequestItems',
  'supplierQuoteItems',
  'invitations',
  'projectAssignments',
  'supplierDirectory',
  'auditEvents',
];

function initAdmin() {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  return {
    db: admin.firestore(),
    auth: admin.auth(),
    admin,
  };
}

async function listAllAuthUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const result = await auth.listUsers(1000, pageToken);
    users.push(...result.users);
    pageToken = result.pageToken;
  } while (pageToken);
  return users;
}

async function countCollection(db, name) {
  const snap = await db.collection(name).count().get();
  return snap.data().count;
}

async function exportCollection(db, name, limit = 50000) {
  const snap = await db.collection(name).limit(limit).get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function exportOrganizationsWithMemberships(db) {
  const orgSnap = await db.collection('organizations').get();
  const orgs = [];
  for (const orgDoc of orgSnap.docs) {
    const membershipSnap = await orgDoc.ref.collection('memberships').get();
    orgs.push({
      id: orgDoc.id,
      ...orgDoc.data(),
      memberships: membershipSnap.docs.map((m) => ({
        id: m.id,
        ...m.data(),
      })),
    });
  }
  return orgs;
}

async function exportProjectsWithAssignments(db) {
  const projectSnap = await db.collection('projects').get();
  const projects = [];
  for (const projectDoc of projectSnap.docs) {
    const assignSnap = await projectDoc.ref.collection('assignments').get();
    projects.push({
      id: projectDoc.id,
      ...projectDoc.data(),
      assignments: assignSnap.docs.map((a) => ({
        id: a.id,
        ...a.data(),
      })),
    });
  }
  return projects;
}

function serializeFirestoreValue(value) {
  if (value == null) return value;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (value instanceof admin.firestore.GeoPoint) {
    return { latitude: value.latitude, longitude: value.longitude };
  }
  if (Array.isArray(value)) {
    return value.map(serializeFirestoreValue);
  }
  if (typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = serializeFirestoreValue(v);
    }
    return out;
  }
  return value;
}

function serializeDocData(data) {
  return serializeFirestoreValue(data);
}

module.exports = {
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
};
