#!/usr/bin/env node
/**
 * Firestore rules emulator tests — Phase 6 MEDIUM data-integrity remediation.
 *
 * Covers the 3 verified MEDIUM findings:
 *   1. approvedQuoteId may only reference a quote in an approvable
 *      live/submitted ('sent') status.
 *   2. receiptChecklist must reference only the request's own order items,
 *      by position/id, with receivedQuantity bounded by orderedQuantity and
 *      a receiptStatus consistent with the checklist's actual outcome.
 *   3. Receipt confirmation is race-safe: because rules re-evaluate against
 *      the live server document (not a client's stale read), a second write
 *      racing against an already-final receipt is rejected — this is what
 *      makes the transactional client-side confirm (quote_service.dart)
 *      safe under two-tab concurrency.
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
const CONTRACTOR_ORG = 'qa-di-contractor-org';
const SUPPLIER_ORG = 'qa-di-supplier-org';

const UID_CUSTOMER = 'uid-di-customer';
const UID_PROCUREMENT_MGR = 'uid-di-procurement-mgr';
const UID_OUTSIDER = 'uid-di-outsider';
const UID_SUPPLIER = 'uid-di-supplier';

function authedUser(uid) {
  return { sub: uid, email: `${uid}@test.com`, token: { email: `${uid}@test.com` } };
}

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

const ORDER_ITEMS = [
  {
    id: 'item-1',
    productId: 'p1',
    productName: 'Cement bags',
    category: 'cat',
    unitType: 'unit',
    quantity: 5,
  },
  {
    id: 'item-2',
    productId: 'p2',
    productName: 'Rebar',
    category: 'cat',
    unitType: 'unit',
    quantity: 3,
  },
];

function fullChecklist() {
  return [
    { itemId: 'item-1', productName: 'Cement bags', receivedQuantity: 5, condition: 'ok' },
    { itemId: 'item-2', productName: 'Rebar', receivedQuantity: 3, condition: 'ok' },
  ];
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

    await user(UID_CUSTOMER, 'commercialCustomer');
    await user(UID_PROCUREMENT_MGR, 'commercialCustomer');
    await user(UID_OUTSIDER, 'commercialCustomer');
    await user(UID_SUPPLIER, 'commercialSupplier');

    await db.collection('organizations').doc(CONTRACTOR_ORG).set({
      type: 'contractor',
      status: 'active',
      name: CONTRACTOR_ORG,
      ownerUid: UID_PROCUREMENT_MGR,
    });
    await db.collection('organizations').doc(SUPPLIER_ORG).set({
      type: 'supplier',
      status: 'active',
      name: SUPPLIER_ORG,
      ownerUid: UID_SUPPLIER,
    });

    await db
      .collection('organizations')
      .doc(CONTRACTOR_ORG)
      .collection('memberships')
      .doc(UID_PROCUREMENT_MGR)
      .set({
        uid: UID_PROCUREMENT_MGR,
        orgId: CONTRACTOR_ORG,
        orgType: 'contractor',
        status: 'active',
        roles: ['procurementManager'],
      });

    const baseRequest = (overrides) => ({
      customerId: UID_CUSTOMER,
      customerName: 'Customer',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercialCustomer',
      contractorOrgId: CONTRACTOR_ORG,
      items: ORDER_ITEMS,
      supplierIdsResponded: [],
      createdAt: new Date(),
      ...overrides,
    });

    // Direct customer approvedQuoteId writes are only allowed on org-less
    // (private/self-service) requests — org-linked requests must go through
    // procurement (see qrCustomerApprovedQuoteIdChangeAllowed in
    // firestore.rules). These two fixtures intentionally omit
    // contractorOrgId so they exercise that direct-approval path.
    const privateRequest = (overrides) => {
      const data = baseRequest(overrides);
      delete data.contractorOrgId;
      return data;
    };

    // ── docs for the approvedQuoteId findings ─────────────────────────
    await db.collection('quoteRequests').doc('req-approve-sent').set(
      privateRequest({ status: 'quotesReceived' }),
    );
    await db.collection('quoteRequests').doc('req-approve-rejected').set(
      privateRequest({ status: 'quotesReceived' }),
    );

    await db.collection('supplierQuotes').doc('quote-sent').set({
      requestId: 'req-approve-sent',
      quoteRequestId: 'req-approve-sent',
      customerId: UID_CUSTOMER,
      supplierId: UID_SUPPLIER,
      supplierOrgId: SUPPLIER_ORG,
      supplierName: 'Supplier',
      status: 'נשלח',
      items: [],
      totalPrice: 100,
      createdAt: new Date(),
    });
    await db.collection('supplierQuotes').doc('quote-rejected').set({
      requestId: 'req-approve-rejected',
      quoteRequestId: 'req-approve-rejected',
      customerId: UID_CUSTOMER,
      supplierId: UID_SUPPLIER,
      supplierOrgId: SUPPLIER_ORG,
      supplierName: 'Supplier',
      status: 'נדחתה',
      items: [],
      totalPrice: 100,
      createdAt: new Date(),
    });

    // ── docs for the receipt-checklist findings ───────────────────────
    const receiptRequest = (id, overrides) =>
      db.collection('quoteRequests').doc(id).set(baseRequest({
        status: 'shipped',
        receiptStatus: 'pending_receipt',
        ...overrides,
      }));

    await receiptRequest('req-receipt-authorized');
    await receiptRequest('req-receipt-unauthorized');
    await receiptRequest('req-receipt-malformed');
    await receiptRequest('req-receipt-excessive');
    await receiptRequest('req-receipt-stale', { status: 'ordered', receiptStatus: null });
    await receiptRequest('req-receipt-duplicate');
    await receiptRequest('req-receipt-concurrent-a');
    await receiptRequest('req-receipt-concurrent-b');
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

    const dbCustomer = dbFor(UID_CUSTOMER);
    const dbProcurementMgr = dbFor(UID_PROCUREMENT_MGR);
    const dbOutsider = dbFor(UID_OUTSIDER);

    // ── FIX 1: approvedQuoteId must reference an approvable quote ──────
    await assertSucceeds(
      dbCustomer.collection('quoteRequests').doc('req-approve-sent').update({
        status: 'ordered',
        approvedQuoteId: 'quote-sent',
      }),
    );
    console.log('PASS [1] approvedQuoteId can reference a live "sent" quote');

    await assertFails(
      dbCustomer.collection('quoteRequests').doc('req-approve-rejected').update({
        status: 'ordered',
        approvedQuoteId: 'quote-rejected',
      }),
    );
    console.log('PASS [1] approvedQuoteId cannot reference an already-rejected quote');

    // ── FIX 2: receipt checklist integrity ──────────────────────────────
    const receiptPayload = (checklist, overrides) => ({
      status: 'receivedFull',
      receiptStatus: 'received_full',
      receiptChecklist: checklist,
      receivedAt: new Date(),
      receivedByUid: UID_PROCUREMENT_MGR,
      updatedAt: new Date(),
      ...overrides,
    });

    // authorized
    await assertSucceeds(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-authorized')
        .update(receiptPayload(fullChecklist())),
    );
    console.log('PASS [2] authorized org member confirms a matching full receipt');

    // unauthorized (no membership / no grant)
    await assertFails(
      dbOutsider
        .collection('quoteRequests')
        .doc('req-receipt-unauthorized')
        .update(receiptPayload(fullChecklist(), { receivedByUid: UID_OUTSIDER })),
    );
    console.log('PASS [2] unauthorized outsider cannot confirm receipt');

    // malformed: fabricated item id not present on the order
    await assertFails(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-malformed')
        .update(receiptPayload([
          { itemId: 'item-1', productName: 'Cement bags', receivedQuantity: 5, condition: 'ok' },
          { itemId: 'item-fabricated', productName: 'Fake', receivedQuantity: 1, condition: 'ok' },
        ])),
    );
    console.log('PASS [2] fabricated item id in checklist is rejected');

    // excessive quantity: receivedQuantity > orderedQuantity
    await assertFails(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-excessive')
        .update(receiptPayload([
          { itemId: 'item-1', productName: 'Cement bags', receivedQuantity: 6, condition: 'ok' },
          { itemId: 'item-2', productName: 'Rebar', receivedQuantity: 3, condition: 'ok' },
        ])),
    );
    console.log('PASS [2] receivedQuantity exceeding orderedQuantity is rejected');

    // status/checklist mismatch: reports full receipt while an item is short
    await assertFails(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-excessive')
        .update(receiptPayload([
          { itemId: 'item-1', productName: 'Cement bags', receivedQuantity: 4, condition: 'missing_quantity' },
          { itemId: 'item-2', productName: 'Rebar', receivedQuantity: 3, condition: 'ok' },
        ])),
    );
    console.log('PASS [2] receiptStatus=received_full inconsistent with a short item is rejected');

    // stale status: request hasn't been shipped yet
    await assertFails(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-stale')
        .update(receiptPayload(fullChecklist())),
    );
    console.log('PASS [2] confirming receipt before shipment (stale status) is rejected');

    // duplicate confirmation
    await assertSucceeds(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-duplicate')
        .update(receiptPayload(fullChecklist())),
    );
    await assertFails(
      dbProcurementMgr
        .collection('quoteRequests')
        .doc('req-receipt-duplicate')
        .update(receiptPayload(fullChecklist())),
    );
    console.log('PASS [2] duplicate confirmation on an already-final receipt is rejected');

    // ── FIX 3: concurrent (two-tab) confirmation ────────────────────────
    // Two "tabs" racing to confirm the same shipment: rules validate
    // against the live server document at commit time, so whichever write
    // lands second sees the first write's already-final state and fails —
    // the same guarantee the transactional client wrapper relies on.
    const concurrentRef = dbProcurementMgr
      .collection('quoteRequests')
      .doc('req-receipt-concurrent-a');
    const [first, second] = await Promise.allSettled([
      concurrentRef.update(receiptPayload(fullChecklist())),
      concurrentRef.update(receiptPayload(fullChecklist())),
    ]);
    const outcomes = [first.status, second.status].sort();
    if (JSON.stringify(outcomes) !== JSON.stringify(['fulfilled', 'rejected'])) {
      throw new Error(
        `expected exactly one of the two concurrent confirmations to win, got: ${outcomes.join(', ')}`,
      );
    }
    console.log('PASS [3] exactly one of two concurrent receipt confirmations succeeds');

    console.log('\nAll medium data-integrity fix tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error('FAIL', err);
  process.exit(1);
});
