#!/usr/bin/env node
/**
 * Firestore rules emulator tests — Phase 1 CRITICAL security remediation.
 *
 * Covers the 6 verified CRITICAL findings from the production security
 * audit, each with an authorized-succeeds and an unauthorized-fails case:
 *   1. Tender bid supplierOrgId / createSupplierQuote permission bypass
 *   2. Customer directly approving/rejecting a supplier quote
 *   3. Customer overwriting quoteRequests.approvedQuoteId
 *   4. quoteRequestCreateAllowed trusting client-supplied contractorOrgId/projectId
 *   5. quoteRequestItems / supplierQuoteItems readable by any signed-in user
 *   6. Non-owner admin inviting (and an invitee accepting) an Owner-role invitation
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

const CONTRACTOR_ORG = 'qa-contractor-org';
const OTHER_CONTRACTOR_ORG = 'qa-other-contractor-org';
const SUPPLIER_ORG_A = 'qa-supplier-org-a';

const UID_PRIVATE_CUSTOMER = 'uid-private-customer';
const UID_ORG_ENGINEER = 'uid-org-engineer';
const UID_PROCUREMENT_MGR = 'uid-procurement-mgr';
const UID_ORG_ADMIN = 'uid-org-admin';
const UID_ORG_OWNER = 'uid-org-owner';
const UID_SUPPLIER_OWNER = 'uid-supplier-owner';
const UID_SUPPLIER_REVOKED = 'uid-supplier-revoked';
const UID_OUTSIDER = 'uid-outsider';
const UID_INVITEE_A = 'uid-invitee-a';
const UID_INVITEE_B = 'uid-invitee-b';

const REQ_PRIVATE = 'req-private';
const REQ_ORG = 'req-org';
const REQ_TENDER = 'req-tender';
const OTHER_PROJECT = 'project-other-org';

const QUOTE_PRIVATE = 'quote-private';
const QUOTE_ORG = 'quote-org';

function authedUser(uid) {
  return { sub: uid, email: `${uid}@test.com`, token: { email: `${uid}@test.com` } };
}

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

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

    await user(UID_PRIVATE_CUSTOMER, 'privateCustomer');
    await user(UID_ORG_ENGINEER, 'commercialCustomer');
    await user(UID_PROCUREMENT_MGR, 'commercialCustomer');
    await user(UID_ORG_ADMIN, 'commercialCustomer');
    await user(UID_ORG_OWNER, 'commercialCustomer');
    await user(UID_SUPPLIER_OWNER, 'commercialSupplier');
    await user(UID_SUPPLIER_REVOKED, 'commercialSupplier');
    await user(UID_OUTSIDER, 'commercialCustomer');
    await user(UID_INVITEE_A, 'commercialCustomer');
    await user(UID_INVITEE_B, 'commercialCustomer');

    const org = async (orgId, type) => {
      await db.collection('organizations').doc(orgId).set({
        type,
        status: 'active',
        name: orgId,
        ownerUid: orgId === CONTRACTOR_ORG ? UID_ORG_OWNER : 'seed',
      });
    };
    await org(CONTRACTOR_ORG, 'contractor');
    await org(OTHER_CONTRACTOR_ORG, 'contractor');
    await org(SUPPLIER_ORG_A, 'supplier');

    const membership = async (orgId, uid, roles, extra) => {
      await db
        .collection('organizations')
        .doc(orgId)
        .collection('memberships')
        .doc(uid)
        .set({
          uid,
          orgId,
          orgType: orgId === SUPPLIER_ORG_A ? 'supplier' : 'contractor',
          status: 'active',
          roles,
          ...(extra || {}),
        });
    };
    await membership(CONTRACTOR_ORG, UID_ORG_ENGINEER, ['engineer']);
    await membership(CONTRACTOR_ORG, UID_PROCUREMENT_MGR, ['procurementManager']);
    await membership(CONTRACTOR_ORG, UID_ORG_ADMIN, ['contractorAdmin']);
    await membership(CONTRACTOR_ORG, UID_ORG_OWNER, ['contractorOwner']);
    await membership(SUPPLIER_ORG_A, UID_SUPPLIER_OWNER, ['supplierOwner']);
    // Same role a legitimate sales rep would have, but with the permission
    // explicitly revoked — the exact shape CRITICAL-1 exploited when
    // supplierOrgId was omitted (the revoke was never checked).
    await membership(SUPPLIER_ORG_A, UID_SUPPLIER_REVOKED, ['supplierSales'], {
      revokes: ['createSupplierQuote'],
    });

    await db.collection('projects').doc(OTHER_PROJECT).set({
      orgId: OTHER_CONTRACTOR_ORG,
      ownerUid: UID_ORG_OWNER,
      name: 'Other org project',
      status: 'active',
    });

    const baseRequest = (overrides) => ({
      customerName: 'Customer',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercialCustomer',
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
      ...overrides,
    });

    // Private/self-service request — no contractorOrgId. The customer is
    // allowed to approve/reject and set approvedQuoteId directly.
    await db.collection('quoteRequests').doc(REQ_PRIVATE).set(baseRequest({
      customerId: UID_PRIVATE_CUSTOMER,
      customerType: 'privateCustomer',
      status: 'quotesReceived',
    }));

    // Org-linked request — approval must go through procurement only.
    await db.collection('quoteRequests').doc(REQ_ORG).set(baseRequest({
      customerId: UID_ORG_ENGINEER,
      contractorOrgId: CONTRACTOR_ORG,
      status: 'quotesReceived',
    }));

    await db.collection('quoteRequests').doc(REQ_TENDER).set(baseRequest({
      customerId: UID_PRIVATE_CUSTOMER,
      customerType: 'privateCustomer',
      status: 'sent',
      invitedSupplierOrgIds: [SUPPLIER_ORG_A],
    }));

    const quoteItems = [
      {
        productId: 'p1',
        productName: 'Item',
        requestedQuantity: 1,
        unitPrice: 100,
        totalItemPrice: 100,
      },
    ];

    await db.collection('supplierQuotes').doc(QUOTE_PRIVATE).set({
      requestId: REQ_PRIVATE,
      quoteRequestId: REQ_PRIVATE,
      customerId: UID_PRIVATE_CUSTOMER,
      supplierId: UID_SUPPLIER_OWNER,
      supplierOrgId: SUPPLIER_ORG_A,
      supplierName: 'Supplier',
      status: 'נשלח',
      items: quoteItems,
      totalPrice: 100,
      createdAt: new Date(),
    });

    await db.collection('supplierQuotes').doc(QUOTE_ORG).set({
      requestId: REQ_ORG,
      quoteRequestId: REQ_ORG,
      customerId: UID_ORG_ENGINEER,
      supplierId: UID_SUPPLIER_OWNER,
      supplierOrgId: SUPPLIER_ORG_A,
      supplierName: 'Supplier',
      status: 'נשלח',
      items: quoteItems,
      totalPrice: 100,
      createdAt: new Date(),
    });

    await db.collection('quoteRequestItems').doc('item-private').set({
      quoteRequestId: REQ_PRIVATE,
      productId: 'p1',
      productName: 'Item',
      quantity: 1,
    });

    await db.collection('supplierQuoteItems').doc('item-quote-private').set({
      supplierQuoteId: QUOTE_PRIVATE,
      productId: 'p1',
      productName: 'Item',
      requestedQuantity: 1,
      unitPrice: 100,
      totalItemPrice: 100,
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

    const dbFor = (uid) =>
      testEnv.authenticatedContext(uid, authedUser(uid)).firestore();

    const dbPrivateCustomer = dbFor(UID_PRIVATE_CUSTOMER);
    const dbOrgEngineer = dbFor(UID_ORG_ENGINEER);
    const dbProcurementMgr = dbFor(UID_PROCUREMENT_MGR);
    const dbOrgAdmin = dbFor(UID_ORG_ADMIN);
    const dbOrgOwner = dbFor(UID_ORG_OWNER);
    const dbSupplierOwner = dbFor(UID_SUPPLIER_OWNER);
    const dbSupplierRevoked = dbFor(UID_SUPPLIER_REVOKED);
    const dbOutsider = dbFor(UID_OUTSIDER);
    const dbInviteeA = dbFor(UID_INVITEE_A);
    const dbInviteeB = dbFor(UID_INVITEE_B);

    // ── CRITICAL-1: tender bid supplierOrgId / createSupplierQuote ──────
    const tenderQuotePayload = (supplierId, supplierOrgId) => ({
      requestId: REQ_TENDER,
      quoteRequestId: REQ_TENDER,
      customerId: UID_PRIVATE_CUSTOMER,
      supplierId,
      supplierOrgId,
      supplierName: 'Supplier',
      status: 'נשלח',
      isTenderBid: true,
      bidVersion: 1,
      items: [
        {
          productId: 'p1',
          productName: 'Item',
          requestedQuantity: 1,
          unitPrice: 90,
          totalItemPrice: 90,
        },
      ],
      totalPrice: 90,
      createdAt: new Date(),
    });

    await assertSucceeds(
      dbSupplierOwner
        .collection('supplierQuotes')
        .doc(`${REQ_TENDER}__${SUPPLIER_ORG_A}`)
        .set(tenderQuotePayload(UID_SUPPLIER_OWNER, SUPPLIER_ORG_A)),
    );
    console.log('PASS [1] authorized supplier org member submits tender bid with supplierOrgId');

    await assertFails(
      dbSupplierRevoked
        .collection('supplierQuotes')
        .doc(`${REQ_TENDER}__${SUPPLIER_ORG_A}`)
        .set(tenderQuotePayload(UID_SUPPLIER_REVOKED, SUPPLIER_ORG_A)),
    );
    console.log('PASS [1] supplier with createSupplierQuote revoked cannot submit tender bid');

    // ── CRITICAL-2: customer cannot approve/reject supplier quotes ──────
    await assertSucceeds(
      dbPrivateCustomer.collection('supplierQuotes').doc(QUOTE_PRIVATE).update({
        status: 'אושרה',
      }),
    );
    console.log('PASS [2] private/orgless customer can approve their own quote directly');

    await assertFails(
      dbOrgEngineer.collection('supplierQuotes').doc(QUOTE_ORG).update({
        status: 'אושרה',
      }),
    );
    console.log('PASS [2] customer on an org-linked request cannot approve a quote directly');

    await assertSucceeds(
      dbProcurementMgr.collection('supplierQuotes').doc(QUOTE_ORG).update({
        status: 'אושרה',
      }),
    );
    console.log('PASS [2] procurement manager can still approve the org-linked quote');

    // ── CRITICAL-3: customer cannot overwrite approvedQuoteId ────────────
    await assertSucceeds(
      dbPrivateCustomer.collection('quoteRequests').doc(REQ_PRIVATE).update({
        status: 'ordered',
        approvedQuoteId: QUOTE_PRIVATE,
      }),
    );
    console.log('PASS [3] private/orgless customer can set approvedQuoteId on their own request');

    await assertFails(
      dbOrgEngineer.collection('quoteRequests').doc(REQ_ORG).update({
        approvedQuoteId: QUOTE_ORG,
      }),
    );
    console.log('PASS [3] customer on an org-linked request cannot overwrite approvedQuoteId');

    await assertFails(
      dbPrivateCustomer.collection('quoteRequests').doc(REQ_PRIVATE).update({
        status: 'ordered',
        approvedQuoteId: QUOTE_ORG,
      }),
    );
    console.log('PASS [3] approvedQuoteId pointing at a different request is rejected');

    // ── CRITICAL-4: quoteRequestCreateAllowed org/project validation ────
    const draftRequest = (overrides) => ({
      customerId: UID_OUTSIDER,
      customerName: 'Outsider',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercialCustomer',
      status: 'draft',
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
      ...overrides,
    });

    await assertFails(
      dbOutsider.collection('quoteRequests').doc('req-injected-org').set(
        draftRequest({ contractorOrgId: OTHER_CONTRACTOR_ORG }),
      ),
    );
    console.log('PASS [4] non-member cannot inject a request into another org via contractorOrgId');

    await assertFails(
      dbOutsider.collection('quoteRequests').doc('req-injected-project').set(
        draftRequest({ projectId: OTHER_PROJECT }),
      ),
    );
    console.log('PASS [4] non-member cannot inject a request into another org via projectId');

    await assertSucceeds(
      dbOrgEngineer.collection('quoteRequests').doc('req-legit-org').set(
        draftRequest({
          customerId: UID_ORG_ENGINEER,
          contractorOrgId: CONTRACTOR_ORG,
        }),
      ),
    );
    console.log('PASS [4] real org member can still create an RFQ tied to their own org');

    // ── CRITICAL-5: quoteRequestItems / supplierQuoteItems read scoping ─
    await assertSucceeds(
      dbPrivateCustomer.collection('quoteRequestItems').doc('item-private').get(),
    );
    console.log('PASS [5] request owner can read their own quoteRequestItems doc');

    await assertFails(
      dbOutsider.collection('quoteRequestItems').doc('item-private').get(),
    );
    console.log('PASS [5] unrelated signed-in user cannot read another org\'s quoteRequestItems doc');

    await assertSucceeds(
      dbSupplierOwner.collection('supplierQuoteItems').doc('item-quote-private').get(),
    );
    console.log('PASS [5] quote-owning supplier can read their own supplierQuoteItems doc');

    await assertFails(
      dbOutsider.collection('supplierQuoteItems').doc('item-quote-private').get(),
    );
    console.log('PASS [5] unrelated signed-in user cannot read another supplier\'s quote item');

    // ── CRITICAL-6: only Owner/platform admin can invite Owner role ─────
    const invitePayload = (role, invitedByUid, email) => ({
      orgId: CONTRACTOR_ORG,
      role,
      status: 'pending',
      invitedByUid,
      email,
    });

    await assertFails(
      dbOrgAdmin.collection('invitations').doc('invite-admin-owner').set(
        invitePayload('contractorOwner', UID_ORG_ADMIN, `${UID_INVITEE_A}@test.com`),
      ),
    );
    console.log('PASS [6] non-owner admin cannot create an Owner-role invitation');

    await assertSucceeds(
      dbOrgAdmin.collection('invitations').doc('invite-admin-engineer').set(
        invitePayload('engineer', UID_ORG_ADMIN, `${UID_INVITEE_A}@test.com`),
      ),
    );
    console.log('PASS [6] admin can still invite a non-owner role');

    await assertSucceeds(
      dbOrgOwner.collection('invitations').doc('invite-owner-owner').set(
        invitePayload('contractorOwner', UID_ORG_OWNER, `${UID_INVITEE_B}@test.com`),
      ),
    );
    console.log('PASS [6] existing owner can invite a co-owner');

    // Defense-in-depth: an owner-role invite whose recorded inviter is not
    // (any longer) an owner must be rejected at accept time too, even
    // though invite.role is otherwise immutable post-creation.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('invitations')
        .doc('invite-forged-owner')
        .set(invitePayload('contractorOwner', UID_ORG_ADMIN, `${UID_INVITEE_A}@test.com`));
    });

    await assertFails(
      dbInviteeA
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_INVITEE_A)
        .set({
          uid: UID_INVITEE_A,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles: ['contractorOwner'],
          acceptedInvitationId: 'invite-forged-owner',
        }),
    );
    console.log('PASS [6] accepting a forged owner invite (non-owner inviter) is rejected');

    await assertSucceeds(
      dbInviteeB
        .collection('organizations')
        .doc(CONTRACTOR_ORG)
        .collection('memberships')
        .doc(UID_INVITEE_B)
        .set({
          uid: UID_INVITEE_B,
          orgId: CONTRACTOR_ORG,
          orgType: 'contractor',
          status: 'active',
          roles: ['contractorOwner'],
          acceptedInvitationId: 'invite-owner-owner',
        }),
    );
    console.log('PASS [6] accepting a legitimate owner invite (owner inviter) succeeds');

    console.log('\nAll CRITICAL security remediation emulator tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
