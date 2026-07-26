#!/usr/bin/env node
/**
 * Firestore rules emulator tests — tender counter-bid deterministic doc id (P0).
 *
 * Covers the fix for: submitTenderCounterBid previously wrote to a random
 * uuid doc id, which firestore.rules' supplierQuoteDeterministicDocId always
 * rejected. The fix uses `${requestId}__${orgKey}__v${bidVersion}` ids for
 * isTenderBid:true docs (see supplierQuoteTenderBidVersionSuffixValid).
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

const PROJECT_ID = 'construction-rfq-tender-rules-test';
const REQUEST_ID = 'req-tender-ab';
const ORG_A = 'qa-tender-supplier-a-org';
const ORG_B = 'qa-tender-supplier-b-org';
const ORG_C = 'qa-tender-supplier-c-org';
const UID_A = 'uid-tender-supplier-a';
const UID_B = 'uid-tender-supplier-b';
const UID_C = 'uid-tender-supplier-c';
const UID_ENGINEER = 'uid-tender-engineer';

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

function supplierUser(uid) {
  return {
    email: `${uid}@test.com`,
    email_verified: true,
  };
}

function tenderBidPayload({ requestId, supplierId, supplierOrgId, bidVersion, totalPrice }) {
  return {
    requestId,
    quoteRequestId: requestId,
    supplierId,
    supplierOrgId,
    supplierName: 'Tender Supplier',
    customerId: UID_ENGINEER,
    status: 'נשלח',
    isTenderBid: true,
    bidVersion,
    items: [
      {
        productId: 'p1',
        productName: 'Item',
        requestedQuantity: 1,
        unitPrice: totalPrice,
        totalItemPrice: totalPrice,
      },
    ],
    totalPrice,
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

    const org = async (orgId) => {
      await db.collection('organizations').doc(orgId).set({
        type: 'supplier',
        status: 'active',
        name: orgId,
      });
    };
    await org(ORG_A);
    await org(ORG_B);
    await org(ORG_C);

    const membership = async (orgId, uid) => {
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
          roles: ['supplierOwner'],
        });
    };
    await membership(ORG_A, UID_A);
    await membership(ORG_B, UID_B);
    await membership(ORG_C, UID_C);

    await db.collection('quoteRequests').doc(REQUEST_ID).set({
      customerId: UID_ENGINEER,
      customerName: 'Engineer',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercialCustomer',
      status: 'sent',
      isTender: true,
      isTenderActive: true,
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

    const bidIdA_v1 = `${REQUEST_ID}__${ORG_A}__v1`;
    const bidIdB_v1 = `${REQUEST_ID}__${ORG_B}__v1`;
    const bidIdC_v1 = `${REQUEST_ID}__${ORG_C}__v1`;

    // 1. Invited supplier can create its own valid v1 bid.
    await assertSucceeds(
      dbA.collection('supplierQuotes').doc(bidIdA_v1).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_A,
          supplierOrgId: ORG_A,
          bidVersion: 1,
          totalPrice: 1000,
        }),
      ),
    );
    console.log('PASS invited supplier A can create its own tender bid (v1, deterministic id)');

    // 2. Legal counter-bid (re-bid) update succeeds: A retires v1 then creates v2.
    await assertSucceeds(
      dbA.collection('supplierQuotes').doc(bidIdA_v1).update({ status: 'לא מעודכנת' }),
    );
    const bidIdA_v2 = `${REQUEST_ID}__${ORG_A}__v2`;
    await assertSucceeds(
      dbA.collection('supplierQuotes').doc(bidIdA_v2).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_A,
          supplierOrgId: ORG_A,
          bidVersion: 2,
          totalPrice: 900,
        }),
      ),
    );
    console.log('PASS supplier A counter-bid (v2) succeeds after retiring v1');

    // 3. Unrelated (non-invited) supplier cannot create a bid on this tender.
    await assertFails(
      dbC.collection('supplierQuotes').doc(bidIdC_v1).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_C,
          supplierOrgId: ORG_C,
          bidVersion: 1,
          totalPrice: 500,
        }),
      ),
    );
    console.log('PASS non-invited supplier C cannot create a tender bid');

    // 4. Supplier B invited, creates its own bid.
    await assertSucceeds(
      dbB.collection('supplierQuotes').doc(bidIdB_v1).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_B,
          supplierOrgId: ORG_B,
          bidVersion: 1,
          totalPrice: 950,
        }),
      ),
    );
    console.log('PASS invited supplier B can create its own tender bid');

    // 5. Supplier cannot overwrite another supplier's bid doc (wrong id/owner combo).
    await assertFails(
      dbA.collection('supplierQuotes').doc(bidIdB_v1).update({ status: 'לא מעודכנת' }),
    );
    console.log('PASS supplier A cannot alter supplier B\'s bid');

    await assertFails(
      dbA.collection('supplierQuotes').doc(`${REQUEST_ID}__${ORG_B}__v2`).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_A,
          supplierOrgId: ORG_B,
          bidVersion: 2,
          totalPrice: 1,
        }),
      ),
    );
    console.log('PASS supplier A cannot forge a bid under org B\'s key');

    // 6. Contractor/customer cannot forge supplier bid data.
    await assertFails(
      dbEngineer.collection('supplierQuotes').doc(`${REQUEST_ID}__${ORG_A}__v3`).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_ENGINEER,
          supplierOrgId: ORG_A,
          bidVersion: 3,
          totalPrice: 1,
        }),
      ),
    );
    console.log('PASS contractor cannot forge a supplier tender bid');

    // 7. Invalid requestId/org combination (mismatched suffix vs payload) denied.
    await assertFails(
      dbB.collection('supplierQuotes').doc(`${REQUEST_ID}__${ORG_A}__v9`).set(
        tenderBidPayload({
          requestId: REQUEST_ID,
          supplierId: UID_B,
          supplierOrgId: ORG_B,
          bidVersion: 9,
          totalPrice: 1,
        }),
      ),
    );
    console.log('PASS mismatched requestId/org doc-id combination denied');

    // 8. Foreign organization cannot read another org's tender bid.
    await assertFails(dbC.collection('supplierQuotes').doc(bidIdA_v2).get());
    console.log('PASS foreign organization cannot read another org\'s tender bid');

    console.log('\nAll tender-bid deterministic-id emulator tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
