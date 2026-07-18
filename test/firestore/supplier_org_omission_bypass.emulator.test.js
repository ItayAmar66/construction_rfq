#!/usr/bin/env node
/**
 * Firestore rules emulator test — verification and fix of a residual
 * concern flagged after the Phase 1 CRITICAL remediation: does
 * supplierQuoteCreateOrgAllowed let a supplier-org member with
 * createSupplierQuote REVOKED bypass that revoke by omitting supplierOrgId
 * from a raw SDK write (falling into the "solo supplier" branch, which
 * historically never checked org grants/revokes at all)?
 *
 * Finding: the bypass was REAL, confirmed here by actually exploiting it
 * against the unpatched rules before the fix below was applied.
 *   - Org-invited eligibility path: fully closed. supplierSoloCreateEligible
 *     now requires supplierInvitedOrgCanQuote (activeSupplierOrgCanQuote)
 *     instead of the membership-only supplierInvitedByOrg.
 *   - Open-to-all / personally-invited eligibility paths: closed whenever
 *     the acting supplier's users/{uid} profile records a primary
 *     supplierOrgId (supplierProfileOrgPermitsQuote, defense-in-depth).
 *     This is NOT a full guarantee — that profile field is not always
 *     populated (SupplierQuoteRepository falls back to a collectionGroup
 *     membership lookup precisely because of that) and Firestore rules
 *     cannot enumerate arbitrary org memberships without a known orgId to
 *     check against. That narrow residual gap is demonstrated and
 *     explicitly documented below, not silently left untested.
 *
 * Run from repo root:
 *   firebase emulators:exec --only firestore --project construction-rfq-rules-test \
 *     "cd test/firestore && npm install && node supplier_org_omission_bypass.emulator.test.js"
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

const SUPPLIER_ORG = 'qa-supplier-org-revoked';
const CUSTOMER_UID = 'uid-customer';

const UID_REVOKED_NO_PROFILE = 'uid-revoked-no-profile';
const UID_REVOKED_WITH_PROFILE = 'uid-revoked-with-profile';
const UID_AUTHORIZED = 'uid-authorized-supplier';
const UID_TRUE_INDIVIDUAL = 'uid-true-individual';

const REQ_ORG_INVITED = 'req-org-invited';
const REQ_OPEN_TO_ALL = 'req-open-to-all';

const rules = fs.readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

function authedUser(uid) {
  return { sub: uid, email: `${uid}@test.com`, token: { email: `${uid}@test.com` } };
}

async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await db.collection('users').doc(CUSTOMER_UID).set({
      uid: CUSTOMER_UID,
      userType: 'commercialCustomer',
      accountStatus: 'active',
      email: `${CUSTOMER_UID}@test.com`,
    });

    // Revoked, no supplierOrgId on the profile — the common/realistic case
    // (see SupplierQuoteRepository's collectionGroup fallback).
    await db.collection('users').doc(UID_REVOKED_NO_PROFILE).set({
      uid: UID_REVOKED_NO_PROFILE,
      userType: 'commercialSupplier',
      accountStatus: 'active',
      email: `${UID_REVOKED_NO_PROFILE}@test.com`,
    });

    // Revoked, but with supplierOrgId recorded on the profile (e.g. set
    // during admin approval) — the defense-in-depth path should catch this.
    await db.collection('users').doc(UID_REVOKED_WITH_PROFILE).set({
      uid: UID_REVOKED_WITH_PROFILE,
      userType: 'commercialSupplier',
      accountStatus: 'active',
      email: `${UID_REVOKED_WITH_PROFILE}@test.com`,
      supplierOrgId: SUPPLIER_ORG,
    });

    await db.collection('users').doc(UID_AUTHORIZED).set({
      uid: UID_AUTHORIZED,
      userType: 'commercialSupplier',
      accountStatus: 'active',
      email: `${UID_AUTHORIZED}@test.com`,
      supplierOrgId: SUPPLIER_ORG,
    });

    // A genuine org-less individual supplier — must remain unaffected.
    await db.collection('users').doc(UID_TRUE_INDIVIDUAL).set({
      uid: UID_TRUE_INDIVIDUAL,
      userType: 'privateSupplier',
      accountStatus: 'active',
      email: `${UID_TRUE_INDIVIDUAL}@test.com`,
    });

    await db.collection('organizations').doc(SUPPLIER_ORG).set({
      type: 'supplier',
      status: 'active',
      name: SUPPLIER_ORG,
    });

    const membership = (uid, roles, extra) =>
      db
        .collection('organizations')
        .doc(SUPPLIER_ORG)
        .collection('memberships')
        .doc(uid)
        .set({
          uid,
          orgId: SUPPLIER_ORG,
          orgType: 'supplier',
          status: 'active',
          roles,
          ...(extra || {}),
        });

    // Same shape as the original CRITICAL-1 repro: a role that would
    // normally grant createSupplierQuote (supplierSales), with the
    // permission explicitly revoked at the membership level.
    await membership(UID_REVOKED_NO_PROFILE, ['supplierSales'], {
      revokes: ['createSupplierQuote'],
    });
    await membership(UID_REVOKED_WITH_PROFILE, ['supplierSales'], {
      revokes: ['createSupplierQuote'],
    });
    await membership(UID_AUTHORIZED, ['supplierSales']);

    const baseRequest = (overrides) => ({
      customerId: CUSTOMER_UID,
      customerName: 'Customer',
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
      supplierIdsResponded: [],
      createdAt: new Date(),
      ...overrides,
    });

    // The request explicitly invited the supplier's ORG (not the
    // individual) — matches the original CRITICAL-1 finding's repro exactly.
    await db.collection('quoteRequests').doc(REQ_ORG_INVITED).set(
      baseRequest({ invitedSupplierOrgIds: [SUPPLIER_ORG] }),
    );

    // A second request open to all suppliers, with no org context at all —
    // used to probe the harder-to-close eligibility path.
    await db.collection('quoteRequests').doc(REQ_OPEN_TO_ALL).set(
      baseRequest({ openToAllSuppliers: true }),
    );
  });
}

function quotePayloadWithoutOrgId(requestId, supplierId) {
  return {
    requestId,
    quoteRequestId: requestId,
    customerId: CUSTOMER_UID,
    supplierId,
    // supplierOrgId deliberately omitted — this is the exploit vector.
    supplierName: 'Supplier',
    status: 'נשלח',
    items: [
      {
        productId: 'p1',
        productName: 'Item',
        requestedQuantity: 1,
        unitPrice: 50,
        totalItemPrice: 50,
      },
    ],
    totalPrice: 50,
    createdAt: new Date(),
  };
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

    const dbRevokedNoProfile = dbFor(UID_REVOKED_NO_PROFILE);
    const dbRevokedWithProfile = dbFor(UID_REVOKED_WITH_PROFILE);
    const dbAuthorized = dbFor(UID_AUTHORIZED);
    const dbTrueIndividual = dbFor(UID_TRUE_INDIVIDUAL);

    // Deterministic doc id when supplierOrgId is omitted falls back to
    // supplierId per supplierQuoteOrgKey — requestId__supplierId.
    const docId = (requestId, uid) => `${requestId}__${uid}`;

    // ── FIXED: org-invited eligibility now requires createSupplierQuote ──
    await assertFails(
      dbRevokedNoProfile
        .collection('supplierQuotes')
        .doc(docId(REQ_ORG_INVITED, UID_REVOKED_NO_PROFILE))
        .set(quotePayloadWithoutOrgId(REQ_ORG_INVITED, UID_REVOKED_NO_PROFILE)),
    );
    console.log('PASS revoked org member cannot bypass createSupplierQuote on an org-invited request by omitting supplierOrgId');

    await assertSucceeds(
      dbAuthorized
        .collection('supplierQuotes')
        .doc(docId(REQ_ORG_INVITED, UID_AUTHORIZED))
        .set(quotePayloadWithoutOrgId(REQ_ORG_INVITED, UID_AUTHORIZED)),
    );
    console.log('PASS authorized org member can still submit on an org-invited request even if supplierOrgId is omitted');

    // ── FIXED (defense-in-depth): profile supplierOrgId still gates ─────
    await assertFails(
      dbRevokedWithProfile
        .collection('supplierQuotes')
        .doc(docId(REQ_OPEN_TO_ALL, UID_REVOKED_WITH_PROFILE))
        .set(quotePayloadWithoutOrgId(REQ_OPEN_TO_ALL, UID_REVOKED_WITH_PROFILE)),
    );
    console.log('PASS revoked member with a recorded profile supplierOrgId is blocked on an open-to-all request too');

    await assertSucceeds(
      dbAuthorized
        .collection('supplierQuotes')
        .doc(docId(REQ_OPEN_TO_ALL, UID_AUTHORIZED))
        .set(quotePayloadWithoutOrgId(REQ_OPEN_TO_ALL, UID_AUTHORIZED)),
    );
    console.log('PASS authorized member with a recorded profile supplierOrgId is not incorrectly blocked');

    // ── Regression: genuine org-less individual suppliers are unaffected ─
    await assertSucceeds(
      dbTrueIndividual
        .collection('supplierQuotes')
        .doc(docId(REQ_OPEN_TO_ALL, UID_TRUE_INDIVIDUAL))
        .set(quotePayloadWithoutOrgId(REQ_OPEN_TO_ALL, UID_TRUE_INDIVIDUAL)),
    );
    console.log('PASS a true org-less individual supplier can still submit on an open-to-all request');

    // ── KNOWN, DOCUMENTED RESIDUAL GAP (not a regression, not silently
    // left untested): a revoked org member whose OWN users/{uid} profile
    // has no supplierOrgId recorded, submitting on a request that is open
    // to all suppliers (no specific org referenced anywhere in the write),
    // can still omit supplierOrgId and bypass their org's revoke. Firestore
    // rules cannot enumerate "does this uid belong to some org" without a
    // known orgId, and the app does not guarantee this profile field is
    // populated for every org member. Closing this completely would
    // require a data-model change (e.g. a Cloud Function keeping
    // users/{uid}.supplierOrgId authoritatively in sync) — out of scope.
    await assertSucceeds(
      dbRevokedNoProfile
        .collection('supplierQuotes')
        .doc(docId(REQ_OPEN_TO_ALL, UID_REVOKED_NO_PROFILE))
        .set(quotePayloadWithoutOrgId(REQ_OPEN_TO_ALL, UID_REVOKED_NO_PROFILE)),
    );
    console.log('DOCUMENTED (not fixed): revoked member with no profile supplierOrgId can still bypass via an open-to-all request — residual, architectural limitation, see comment above');

    console.log('\nAll supplierQuoteCreateOrgAllowed omission-bypass emulator tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
