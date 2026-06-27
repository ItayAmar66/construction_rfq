#!/usr/bin/env node
/**
 * Firestore rules emulator tests — supplier quote eligibility (P0).
 *
 * Run from repo root:
 *   firebase emulators:exec --only firestore --project construction-rfq-rules-test \
 *     "cd test/firestore && npm install && npm test"
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
const REQUEST_ID = 'req-targeted-ab';
const ORG_A = 'qa-supplier-a-org';
const ORG_B = 'qa-supplier-b-org';
const ORG_C = 'qa-supplier-c-org';
const UID_A = 'uid-supplier-a';
const UID_B = 'uid-supplier-b';
const UID_C = 'uid-supplier-c';
const UID_ENGINEER = 'uid-engineer';

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

function supplierUser(uid) {
  return {
    uid,
    email: `${uid}@test.com`,
    token: { email: `${uid}@test.com` },
  };
}

function quotePayload(requestId, supplierId, supplierOrgId) {
  return {
    requestId,
    supplierId,
    supplierOrgId,
    supplierName: 'Supplier',
    customerId: UID_ENGINEER,
    status: 'נשלח',
    items: [
      {
        productId: 'p1',
        productName: 'Item',
        requestedQuantity: 1,
        unitPrice: 100,
        totalItemPrice: 100,
      },
    ],
    totalPrice: 100,
    createdAt: new Date(),
  };
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

    await user(UID_ENGINEER, 'commercialCustomer');
    await user(UID_A, 'commercialSupplier');
    await user(UID_B, 'commercialSupplier');
    await user(UID_C, 'commercialSupplier');

    const org = async (orgId, type) => {
      await db.collection('organizations').doc(orgId).set({
        type,
        status: 'active',
        name: orgId,
      });
    };
    await org(ORG_A, 'supplier');
    await org(ORG_B, 'supplier');
    await org(ORG_C, 'supplier');

    const membership = async (orgId, uid, roles) => {
      await db
        .collection('organizations')
        .doc(orgId)
        .collection('memberships')
        .doc(uid)
        .set({
          uid,
          orgId,
          orgType: 'supplier',
          status: 'active',
          roles,
        });
    };

    await membership(ORG_A, UID_A, ['supplierOwner']);
    await membership(ORG_B, UID_B, ['supplierOwner']);
    await membership(ORG_C, UID_C, ['supplierOwner']);

    await db.collection('quoteRequests').doc(REQUEST_ID).set({
      customerId: UID_ENGINEER,
      customerName: 'Engineer',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercialCustomer',
      status: 'sent',
      items: [
        {
          productId: 'p1',
          productName: 'Item',
          category: 'cat',
          unitType: 'unit',
          quantity: 1,
        },
      ],
      invitedSupplierOrgIds: [ORG_A, ORG_B],
      invitedSupplierIds: [UID_A, UID_B],
      supplierIdsResponded: [],
      createdAt: new Date(),
    });

    await db.collection('quoteRequests').doc('req-open-all').set({
      customerId: UID_ENGINEER,
      customerName: 'Engineer',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercialCustomer',
      status: 'sent',
      openToAllSuppliers: true,
      items: [
        {
          productId: 'p1',
          productName: 'Item',
          category: 'cat',
          unitType: 'unit',
          quantity: 1,
        },
      ],
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

    const dbA = testEnv.authenticatedContext(UID_A, supplierUser(UID_A)).firestore();
    const dbB = testEnv.authenticatedContext(UID_B, supplierUser(UID_B)).firestore();
    const dbC = testEnv.authenticatedContext(UID_C, supplierUser(UID_C)).firestore();
    const dbEngineer = testEnv
      .authenticatedContext(UID_ENGINEER, supplierUser(UID_ENGINEER))
      .firestore();

    const quoteIdA = `${REQUEST_ID}__${ORG_A}`;
    const quoteIdB = `${REQUEST_ID}__${ORG_B}`;
    const quoteIdC = `${REQUEST_ID}__${ORG_C}`;

    await assertSucceeds(
      dbA.collection('supplierQuotes').doc(quoteIdA).set(
        quotePayload(REQUEST_ID, UID_A, ORG_A),
      ),
    );
    console.log('PASS Supplier A invited can create quote');

    await assertSucceeds(
      dbB.collection('supplierQuotes').doc(quoteIdB).set(
        quotePayload(REQUEST_ID, UID_B, ORG_B),
      ),
    );
    console.log('PASS Supplier B invited can create quote');

    await assertFails(
      dbC.collection('supplierQuotes').doc(quoteIdC).set(
        quotePayload(REQUEST_ID, UID_C, ORG_C),
      ),
    );
    console.log('PASS Supplier C non-invited direct quote denied');

    await assertFails(
      dbC.collection('quoteRequests').doc(REQUEST_ID).update({
        supplierIdsResponded: [UID_C],
        status: 'התקבלו הצעות',
      }),
    );
    console.log('PASS Supplier C linked request patch denied');

    await assertFails(
      dbA.collection('supplierQuotes').doc(quoteIdA).set(
        quotePayload(REQUEST_ID, UID_A, ORG_A),
      ),
    );
    console.log('PASS duplicate quote denied');

    await assertFails(
      dbEngineer.collection('supplierQuotes').doc(quoteIdA).set(
        quotePayload(REQUEST_ID, UID_ENGINEER, ORG_A),
      ),
    );
    console.log('PASS contractor/engineer cannot create supplier quote');

    const openQuoteId = `req-open-all__${ORG_C}`;
    await assertSucceeds(
      dbC.collection('supplierQuotes').doc(openQuoteId).set(
        quotePayload('req-open-all', UID_C, ORG_C),
      ),
    );
    console.log('PASS openToAll allows active supplier org quote');

    console.log('\nAll supplier quote eligibility emulator tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
