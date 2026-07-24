#!/usr/bin/env node
/**
 * Adversarial Firestore rules emulator tests — full security review.
 *
 * Run from repo root:
 *   firebase emulators:exec --only firestore --project construction-rfq-rules-test \
 *     "cd test/firestore && node security_review.emulator.test.js"
 *
 * Prints PASS (rule behaved securely / legit action allowed) or a failure
 * marker (VULN = attack succeeded, FAIL = legit action blocked). Exit code is
 * non-zero if any problem is found. Each attack uses its own document so
 * checks are order-independent.
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
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');

// ---- identities ----------------------------------------------------------
const C1 = 'org-contractor-1';
const C2 = 'org-contractor-2';
const S1 = 'org-supplier-1';
const S2 = 'org-supplier-2';

const OWNER_C1 = 'owner-c1';
const PM_C1 = 'pm-c1';
const ENG_C1 = 'eng-c1';
const VIEW_C1 = 'view-c1';
const OWNER_C2 = 'owner-c2';
const PM_C2 = 'pm-c2';
const CUST1 = 'cust-1';
const OWNER_S1 = 'owner-s1';
const REP_S1 = 'rep-s1';
const OWNER_S2 = 'owner-s2';
const BLOCKED = 'blocked-user';
const OUTSIDER = 'outsider';
const NEWHIRE = 'newhire';    // legitimately invited engineer (verified email)
const ATTACKER = 'attacker';  // registers the invited email but UNVERIFIED

const INVITE_EMAIL = 'newhire@test.com';

// token with configurable email_verified
function ctx(testEnv, uid, email, verified) {
  return testEnv.authenticatedContext(uid, {
    email: email || `${uid}@test.com`,
    email_verified: verified !== false,
  }).firestore();
}

let vulns = 0, passes = 0;
async function expectDenied(label, promise) {
  try { await assertFails(promise); console.log(`  PASS  ${label}`); passes++; }
  catch { console.log(`  VULN  ${label}  -> attack SUCCEEDED`); vulns++; }
}
async function expectAllowed(label, promise) {
  try { await assertSucceeds(promise); console.log(`  PASS  ${label}`); passes++; }
  catch (e) { console.log(`  FAIL  ${label}  -> legit action BLOCKED: ${e.code || e}`); vulns++; }
}

async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = new Date();
    const user = (uid, userType, extra = {}) =>
      db.collection('users').doc(uid).set({
        uid, userType, accountStatus: 'active', email: `${uid}@test.com`, verified: false, ...extra,
      });
    await Promise.all([
      user(OWNER_C1, 'commercialCustomer', { primaryOrgId: C1 }),
      user(PM_C1, 'commercialCustomer', { primaryOrgId: C1 }),
      user(ENG_C1, 'commercialCustomer', { primaryOrgId: C1 }),
      user(VIEW_C1, 'commercialCustomer', { primaryOrgId: C1 }),
      user(OWNER_C2, 'commercialCustomer', { primaryOrgId: C2 }),
      user(PM_C2, 'commercialCustomer', { primaryOrgId: C2 }),
      user(CUST1, 'commercialCustomer', { primaryOrgId: C1 }),
      user(OWNER_S1, 'commercialSupplier', { primaryOrgId: S1 }),
      user(REP_S1, 'commercialSupplier', { primaryOrgId: S1 }),
      user(OWNER_S2, 'commercialSupplier', { primaryOrgId: S2 }),
      user(OUTSIDER, 'commercialCustomer', {}),
      user(BLOCKED, 'commercialCustomer', { accountStatus: 'blocked', primaryOrgId: C1 }),
    ]);
    const org = (orgId, type, ownerUid) =>
      db.collection('organizations').doc(orgId).set({ type, status: 'active', name: orgId, ownerUid });
    await Promise.all([
      org(C1, 'contractor', OWNER_C1), org(C2, 'contractor', OWNER_C2),
      org(S1, 'supplier', OWNER_S1), org(S2, 'supplier', OWNER_S2),
    ]);
    const mem = (orgId, uid, roles, orgType) =>
      db.collection('organizations').doc(orgId).collection('memberships').doc(uid)
        .set({ uid, orgId, orgType, status: 'active', roles });
    await Promise.all([
      mem(C1, OWNER_C1, ['contractorCompanyOwner'], 'contractor'),
      mem(C1, PM_C1, ['procurementManager'], 'contractor'),
      mem(C1, ENG_C1, ['engineer'], 'contractor'),
      mem(C1, VIEW_C1, ['contractorViewer'], 'contractor'),
      mem(C1, CUST1, ['procurementManager'], 'contractor'),
      mem(C2, OWNER_C2, ['contractorCompanyOwner'], 'contractor'),
      mem(C2, PM_C2, ['procurementManager'], 'contractor'),
      mem(S1, OWNER_S1, ['supplierOwner'], 'supplier'),
      mem(S1, REP_S1, ['supplierSalesRep'], 'supplier'),
      mem(S2, OWNER_S2, ['supplierOwner'], 'supplier'),
    ]);
    await db.collection('projects').doc('proj-c1').set({ orgId: C1, ownerUid: OWNER_C1, name: 'P', status: 'active', createdAt: now, updatedAt: now });
    await db.collection('projects').doc('proj-c2').set({ orgId: C2, ownerUid: OWNER_C2, name: 'P', status: 'active', createdAt: now, updatedAt: now });

    const items = [{ productId: 'p1', productName: 'Item', category: 'c', unitType: 'u', quantity: 5 }];
    const sqItems = [{ productId: 'p1', productName: 'Item', requestedQuantity: 5, unitPrice: 10, totalItemPrice: 50 }];
    const rfq = (id, extra) => db.collection('quoteRequests').doc(id).set({
      customerId: CUST1, customerName: 'C', customerPhone: '0', customerCity: 'X',
      customerType: 'commercialCustomer', contractorOrgId: C1, status: 'sent',
      items, supplierIdsResponded: [], createdAt: now, ...extra,
    });
    await rfq('rfq-c1-sent', { invitedSupplierIds: [OWNER_S1], invitedSupplierOrgIds: [S1], supplierIdsResponded: [REP_S1], lowestBid: 999 });
    await rfq('rfq-c1-pending', { status: 'ממתין לאישור רכש' });
    await rfq('rfq-c1-ordered', { status: 'הוזמנה', supplierIdsResponded: [OWNER_S1], approvedQuoteId: 'rfq-c1-ordered__' + S1, receiptStatus: 'pending_receipt' });
    await rfq('rfq-append', { invitedSupplierIds: [OWNER_S1], invitedSupplierOrgIds: [S1], supplierIdsResponded: [REP_S1] });
    await rfq('rfq-iso', { invitedSupplierIds: [OWNER_S1], invitedSupplierOrgIds: [S1] });

    await db.collection('supplierQuotes').doc('rfq-c1-sent__' + S1).set({ requestId: 'rfq-c1-sent', supplierId: OWNER_S1, supplierOrgId: S1, supplierName: 'S1', customerId: CUST1, status: 'נשלח', items: sqItems, totalPrice: 50, createdAt: now });
    await db.collection('supplierQuotes').doc('rfq-c1-ordered__' + S1).set({ requestId: 'rfq-c1-ordered', supplierId: OWNER_S1, supplierOrgId: S1, supplierName: 'S1', customerId: CUST1, status: 'אושרה', items: sqItems, totalPrice: 50, createdAt: now });

    await db.collection('invitations').doc('inv-eng-c1').set({ orgId: C1, email: INVITE_EMAIL, role: 'engineer', status: 'pending', invitedByUid: OWNER_C1, createdAt: now });
    await db.collection('invitations').doc('inv-eng-c1b').set({ orgId: C1, email: INVITE_EMAIL, role: 'engineer', status: 'pending', invitedByUid: OWNER_C1, createdAt: now });
  });
}

async function run() {
  const testEnv = await initializeTestEnvironment({ projectId: PROJECT_ID, firestore: { rules } });
  const db = (uid) => ctx(testEnv, uid);
  try {
    await seed(testEnv);

    console.log('\n== 1. Read another organization =========================');
    await expectDenied('C2 owner reads C1 org doc', db(OWNER_C2).collection('organizations').doc(C1).get());
    await expectDenied('C2 owner reads C1 membership', db(OWNER_C2).collection('organizations').doc(C1).collection('memberships').doc(PM_C1).get());
    await expectDenied('supplier reads contractor org C1', db(OWNER_S1).collection('organizations').doc(C1).get());
    await expectDenied('outsider reads C1 org', db(OUTSIDER).collection('organizations').doc(C1).get());

    console.log('\n== 2. Write another organization =========================');
    await expectDenied('C2 owner updates C1 org', db(OWNER_C2).collection('organizations').doc(C1).update({ name: 'hacked' }));
    await expectDenied('C1 owner updates own org (admin-only)', db(OWNER_C1).collection('organizations').doc(C1).update({ name: 'x' }));
    await expectDenied('C1 owner creates new org', db(OWNER_C1).collection('organizations').doc('org-new').set({ type: 'contractor', status: 'active', name: 'x', ownerUid: OWNER_C1 }));

    console.log('\n== 3. Modify foreign RFQs ===============================');
    await expectDenied('C2 procurement edits C1 RFQ items', db(PM_C2).collection('quoteRequests').doc('rfq-c1-sent').update({ items: [{ productId: 'p1', productName: 'x', category: 'c', unitType: 'u', quantity: 1 }] }));
    await expectDenied('C2 procurement cancels C1 RFQ', db(PM_C2).collection('quoteRequests').doc('rfq-c1-sent').update({ status: 'בוטלה' }));
    await expectDenied('outsider modifies C1 RFQ', db(OUTSIDER).collection('quoteRequests').doc('rfq-c1-sent').update({ status: 'בוטלה' }));
    await expectDenied('uninvited S2 patches C1 RFQ', db(OWNER_S2).collection('quoteRequests').doc('rfq-c1-sent').update({ supplierIdsResponded: [OWNER_S2], status: 'התקבלו הצעות' }));

    console.log('\n== 4. Modify / read foreign quotes =====================');
    await expectDenied('S2 modifies S1 quote status', db(OWNER_S2).collection('supplierQuotes').doc('rfq-c1-sent__' + S1).update({ status: 'אושרה' }));
    await expectDenied('S2 ships S1 quote', db(OWNER_S2).collection('supplierQuotes').doc('rfq-c1-ordered__' + S1).update({ status: 'נשלחה', shippedAt: new Date() }));
    await expectDenied('outsider reads S1 quote', db(OUTSIDER).collection('supplierQuotes').doc('rfq-c1-sent__' + S1).get());
    await expectDenied('competitor S2 reads S1 quote', db(OWNER_S2).collection('supplierQuotes').doc('rfq-c1-sent__' + S1).get());

    console.log('\n== 5. Modify deliveries ================================');
    await expectDenied('S2 ships C1/S1 order', db(OWNER_S2).collection('quoteRequests').doc('rfq-c1-ordered').update({ status: 'ממתין לאישור קבלה', receiptStatus: 'pending_receipt', shippedBySupplierId: OWNER_S2 }));
    await expectDenied('outsider confirms receipt', db(OUTSIDER).collection('quoteRequests').doc('rfq-c1-ordered').update({ status: 'התקבל במלואו', receiptStatus: 'received_full', receivedByUid: OUTSIDER }));
    await expectDenied('C2 procurement confirms C1 receipt', db(PM_C2).collection('quoteRequests').doc('rfq-c1-ordered').update({ status: 'התקבל במלואו', receiptStatus: 'received_full', receivedByUid: PM_C2 }));

    console.log('\n== 6. Approve foreign orders / procurement =============');
    await expectDenied('C2 procurement approves C1 RFQ', db(PM_C2).collection('quoteRequests').doc('rfq-c1-pending').update({ status: 'אושר על ידי רכש', procurementApprovedByUid: PM_C2 }));
    await expectDenied('C1 engineer approves C1 RFQ', db(ENG_C1).collection('quoteRequests').doc('rfq-c1-pending').update({ status: 'אושר על ידי רכש', procurementApprovedByUid: ENG_C1 }));
    await expectDenied('C1 viewer orders a supplier quote', db(VIEW_C1).collection('quoteRequests').doc('rfq-c1-sent').update({ status: 'הוזמנה', approvedQuoteId: 'rfq-c1-sent__' + S1 }));

    console.log('\n== 7. Elevate permissions ==============================');
    await expectDenied('engineer self-promotes to owner', db(ENG_C1).collection('organizations').doc(C1).collection('memberships').doc(ENG_C1).update({ roles: ['contractorCompanyOwner'], updatedByUid: ENG_C1 }));
    await expectDenied('procurement mgr self-promotes to owner', db(PM_C1).collection('organizations').doc(C1).collection('memberships').doc(PM_C1).update({ roles: ['contractorCompanyOwner'], updatedByUid: PM_C1 }));
    await expectDenied('procurement mgr promotes another to owner', db(PM_C1).collection('organizations').doc(C1).collection('memberships').doc(ENG_C1).update({ roles: ['contractorCompanyOwner'], updatedByUid: PM_C1 }));
    await expectDenied('engineer sets platformAdmin role', db(ENG_C1).collection('organizations').doc(C1).collection('memberships').doc(ENG_C1).update({ roles: ['platformAdmin'], updatedByUid: ENG_C1 }));
    await expectDenied('blocked user self-activates', db(BLOCKED).collection('users').doc(BLOCKED).update({ accountStatus: 'active' }));
    await expectDenied('engineer creates own owner membership', db(ENG_C1).collection('organizations').doc(C1).collection('memberships').doc(ENG_C1 + '2').set({ uid: ENG_C1, orgId: C1, orgType: 'contractor', status: 'active', roles: ['contractorCompanyOwner'] }));

    console.log('\n== 8. User profile immutables ==========================');
    await expectDenied('user changes own userType', db(ENG_C1).collection('users').doc(ENG_C1).update({ userType: 'commercialSupplier' }));
    await expectDenied('user flips own verified false->true', db(ENG_C1).collection('users').doc(ENG_C1).update({ verified: true, name: 'x' }));
    await expectDenied('user reads another user doc', db(ENG_C1).collection('users').doc(PM_C1).get());

    console.log('\n== 9. Invite owner illegally ===========================');
    await expectDenied('procurement mgr invites owner', db(PM_C1).collection('invitations').doc('h1').set({ orgId: C1, email: 'x@test.com', role: 'contractorCompanyOwner', status: 'pending', invitedByUid: PM_C1, createdAt: new Date() }));
    await expectDenied('procurement mgr invites procurementManager', db(PM_C1).collection('invitations').doc('h2').set({ orgId: C1, email: 'x@test.com', role: 'procurementManager', status: 'pending', invitedByUid: PM_C1, createdAt: new Date() }));
    await expectDenied('engineer invites anyone', db(ENG_C1).collection('invitations').doc('h3').set({ orgId: C1, email: 'x@test.com', role: 'engineer', status: 'pending', invitedByUid: ENG_C1, createdAt: new Date() }));
    await expectDenied('C2 owner invites into C1', db(OWNER_C2).collection('invitations').doc('h4').set({ orgId: C1, email: 'x@test.com', role: 'engineer', status: 'pending', invitedByUid: OWNER_C2, createdAt: new Date() }));

    console.log('\n== 10. FIX: unverified-email invitation hijack (HIGH) ===');
    const membershipAccept = (dbx) => dbx.collection('organizations').doc(C1).collection('memberships').doc(ATTACKER)
      .set({ uid: ATTACKER, orgId: C1, orgType: 'contractor', roles: ['engineer'], status: 'active', acceptedInvitationId: 'inv-eng-c1' });
    // attacker registers the invited email but token is UNVERIFIED
    await expectDenied('UNVERIFIED attacker reads pending invite by email', ctx(testEnv, ATTACKER, INVITE_EMAIL, false).collection('invitations').doc('inv-eng-c1').get());
    await expectDenied('UNVERIFIED attacker accepts invite -> joins org', ctx(testEnv, ATTACKER, INVITE_EMAIL, false).collection('organizations').doc(C1).collection('memberships').doc(ATTACKER)
      .set({ uid: ATTACKER, orgId: C1, orgType: 'contractor', roles: ['engineer'], status: 'active', acceptedInvitationId: 'inv-eng-c1' }));
    await expectDenied('UNVERIFIED attacker marks invite accepted', ctx(testEnv, ATTACKER, INVITE_EMAIL, false).collection('invitations').doc('inv-eng-c1').update({ status: 'accepted', acceptedByUid: ATTACKER }));
    // legit invitee with a VERIFIED matching email still works
    await expectAllowed('VERIFIED invitee reads pending invite', ctx(testEnv, NEWHIRE, INVITE_EMAIL, true).collection('invitations').doc('inv-eng-c1b').get());
    await expectAllowed('VERIFIED invitee accepts invite -> joins org', ctx(testEnv, NEWHIRE, INVITE_EMAIL, true).collection('organizations').doc(C1).collection('memberships').doc(NEWHIRE)
      .set({ uid: NEWHIRE, orgId: C1, orgType: 'contractor', roles: ['engineer'], status: 'active', acceptedInvitationId: 'inv-eng-c1b' }));

    console.log('\n== 11. FIX: supplier lowestBid / responded tamper (MED) =');
    await expectDenied('invited supplier WIPES competitor from responded', db(OWNER_S1).collection('quoteRequests').doc('rfq-append').update({ supplierIdsResponded: [OWNER_S1], status: 'התקבלו הצעות', updatedAt: new Date() }));
    await expectDenied('invited supplier forges NEGATIVE lowestBid', db(OWNER_S1).collection('quoteRequests').doc('rfq-append').update({ supplierIdsResponded: [REP_S1, OWNER_S1], lowestBid: -5, status: 'התקבלו הצעות', updatedAt: new Date() }));
    await expectAllowed('invited supplier APPENDS self + valid lowestBid', db(OWNER_S1).collection('quoteRequests').doc('rfq-append').update({ supplierIdsResponded: [REP_S1, OWNER_S1], lowestBid: 50, status: 'התקבלו הצעות', updatedAt: new Date() }));

    console.log('\n== 12. FIX: audit-event foreign-org forgery (MED) ======');
    await expectDenied('C1 member forges audit into foreign org C2', db(ENG_C1).collection('auditEvents').doc('f1').set({ actorUid: ENG_C1, orgId: C2, entityType: 'membership', entityId: 'x', action: 'deleted', summaryHebrew: 'זיוף' }));
    await expectDenied('outsider forges audit into org C1', db(OUTSIDER).collection('auditEvents').doc('f2').set({ actorUid: OUTSIDER, orgId: C1, entityType: 'membership', entityId: 'x', action: 'deleted', summaryHebrew: 'זיוף' }));
    await expectAllowed('C1 member writes audit for own org C1', db(PM_C1).collection('auditEvents').doc('ok1').set({ actorUid: PM_C1, orgId: C1, entityType: 'rfq', entityId: 'r', action: 'approved', summaryHebrew: 'אישור' }));
    await expectAllowed('supplier writes quote audit with contractor projectId (no orgId)', db(OWNER_S1).collection('auditEvents').doc('ok2').set({ actorUid: OWNER_S1, projectId: 'proj-c1', entityType: 'quote', entityId: 'q', action: 'submitted', summaryHebrew: 'הצעה' }));

    console.log('\n== 13. FIX: org owner overrides platform block (MED) ===');
    await expectDenied('C1 owner un-blocks platform-blocked member', db(OWNER_C1).collection('users').doc(BLOCKED).update({ accountStatus: 'active', updatedAt: new Date() }));
    await expectDenied('C1 owner sets a member to blocked', db(OWNER_C1).collection('users').doc(VIEW_C1).update({ accountStatus: 'blocked', updatedAt: new Date() }));
    await expectAllowed('C1 owner disables an active member (org-level)', db(OWNER_C1).collection('users').doc(VIEW_C1).update({ accountStatus: 'disabled', updatedAt: new Date() }));

    console.log('\n== 14. Isolation & intended-behaviour sanity ===========');
    await expectDenied('uninvited S2 reads non-open C1 RFQ', db(OWNER_S2).collection('quoteRequests').doc('rfq-iso').get());
    await expectAllowed('C1 procurement approves C1 pending RFQ', db(PM_C1).collection('quoteRequests').doc('rfq-c1-pending').update({ status: 'אושר על ידי רכש', procurementApprovedByUid: PM_C1, updatedAt: new Date() }));
    await expectAllowed('S1 owner reads own quote', db(OWNER_S1).collection('supplierQuotes').doc('rfq-c1-sent__' + S1).get());
    await expectAllowed('customer reads own RFQ', db(CUST1).collection('quoteRequests').doc('rfq-c1-sent').get());
    await expectAllowed('customer edits items on own SENT RFQ (by design editable)', db(CUST1).collection('quoteRequests').doc('rfq-c1-sent').update({ items: [{ productId: 'p1', productName: 'x', category: 'c', unitType: 'u', quantity: 2 }], updatedAt: new Date() }));
    await expectAllowed('C1 owner promotes engineer to procurementManager', db(OWNER_C1).collection('organizations').doc(C1).collection('memberships').doc(ENG_C1).update({ roles: ['procurementManager'], updatedByUid: OWNER_C1, updatedAt: new Date() }));

    console.log(`\n=========================================================`);
    console.log(`RESULT: ${passes} secure/expected, ${vulns} problem(s).`);
    console.log(`=========================================================\n`);
    if (vulns > 0) process.exitCode = 2;
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => { console.error(err); process.exit(1); });
