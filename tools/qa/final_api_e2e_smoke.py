#!/usr/bin/env python3
"""Live API E2E smoke — full procurement → quote → approve → ship flow.

Uses Firestore/Auth REST payloads aligned with app repositories.
No deletes. Unique request id per run.

Usage:
  python3 tools/qa/final_api_e2e_smoke.py
"""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime

API_KEY = 'AIzaSyAMI5ezgGSRZBU8IjklF9fXcBC_PAhqOhc'
PROJECT = 'construction-rfq-itay-20-2eee0'
RUN_MARKER = 'FINAL-API-E2E'
CONTRACTOR_ORG = 'qbn1nbXnfHeSquhoo6X0KwV1tGk2'
PROJECT_ID = 'qa-proj-big-contractor'
QA_BIG = 'DRy60MnQjwPQCe6ARmf08cqGsM12'
QA_SMALL = 'C5EKNz88l2UBn506FmFUzfyMhFi2'

ACCOUNTS = {
    'engineer': ('qa.contractor.big.engineer@test.com', 'Qa123456!'),
    'procurement': ('qa.contractor.big.procurement@test.com', 'Qa123456!'),
    'big_supplier': ('qa.supplier.big.owner@test.com', 'Qa123456!'),
    'small_supplier': ('qa.supplier.small.owner@test.com', 'Qa123456!'),
}


def sign_in(email: str, password: str) -> dict:
    req = urllib.request.Request(
        f'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}',
        data=json.dumps(
            {'email': email, 'password': password, 'returnSecureToken': True}
        ).encode(),
        headers={'Content-Type': 'application/json'},
    )
    return json.loads(urllib.request.urlopen(req).read())


def fs_value(value):
    if value is None:
        return {'nullValue': None}
    if isinstance(value, bool):
        return {'booleanValue': value}
    if isinstance(value, int):
        return {'integerValue': str(value)}
    if isinstance(value, float):
        return {'doubleValue': value}
    if isinstance(value, list):
        return {'arrayValue': {'values': [fs_value(v) for v in value]}}
    if isinstance(value, dict):
        return {'mapValue': {'fields': {k: fs_value(v) for k, v in value.items()}}}
    return {'stringValue': str(value)}


def doc_path(collection: str, doc_id: str) -> str:
    return (
        f'projects/{PROJECT}/databases/(default)/documents/{collection}/{doc_id}'
    )


def get_doc(token: str, collection: str, doc_id: str) -> tuple[dict | None, int | None]:
    url = f'https://firestore.googleapis.com/v1/{doc_path(collection, doc_id)}'
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as err:
        return None, err.code


def create_doc(token: str, collection: str, doc_id: str, fields: dict) -> tuple[bool, str]:
    url = (
        f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        f'/databases/(default)/documents/{collection}?documentId={doc_id}'
    )
    body = {'fields': {k: fs_value(v) for k, v in fields.items()}}
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        urllib.request.urlopen(req)
        return True, ''
    except urllib.error.HTTPError as err:
        return False, f'HTTP {err.code}: {err.read().decode()[:800]}'


def patch_doc(token: str, collection: str, doc_id: str, fields: dict) -> tuple[bool, str]:
    mask = '&'.join(f'updateMask.fieldPaths={k}' for k in fields)
    url = (
        f'https://firestore.googleapis.com/v1/{doc_path(collection, doc_id)}?{mask}'
    )
    body = {'fields': {k: fs_value(v) for k, v in fields.items()}}
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='PATCH',
    )
    try:
        urllib.request.urlopen(req)
        return True, ''
    except urllib.error.HTTPError as err:
        return False, f'HTTP {err.code}: {err.read().decode()[:800]}'


def commit_writes(token: str, writes: list[dict]) -> tuple[bool, str]:
    url = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents:commit'
    req = urllib.request.Request(
        url,
        data=json.dumps({'writes': writes}).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        urllib.request.urlopen(req)
        return True, ''
    except urllib.error.HTTPError as err:
        return False, f'HTTP {err.code}: {err.read().decode()[:1200]}'


def field(doc: dict | None, key: str, default=None):
    if not doc:
        return default
    f = doc.get('fields', {}).get(key, {})
    if 'stringValue' in f:
        return f['stringValue']
    if 'booleanValue' in f:
        return f['booleanValue']
    if 'integerValue' in f:
        return int(f['integerValue'])
    if 'doubleValue' in f:
        return f['doubleValue']
    if 'arrayValue' in f:
        return [
            v.get('stringValue', v.get('integerValue', v.get('doubleValue')))
            for v in f['arrayValue'].get('values', [])
        ]
    return default


def query_catalog_variants(token: str, limit: int = 3) -> list[dict]:
    body = {
        'structuredQuery': {
            'from': [{'collectionId': 'catalogVariants'}],
            'where': {
                'fieldFilter': {
                    'field': {'fieldPath': 'isActive'},
                    'op': 'EQUAL',
                    'value': {'booleanValue': True},
                }
            },
            'limit': limit,
        }
    }
    req = urllib.request.Request(
        f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents:runQuery',
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    )
    rows = json.loads(urllib.request.urlopen(req).read())
    items = []
    for row in rows:
        if not row.get('document'):
            continue
        f = row['document']['fields']
        items.append(
            {
                'productId': f.get('productId', {}).get('stringValue', 'manual'),
                'productName': f.get('displayName', {}).get('stringValue', 'פריט'),
                'category': f.get('categoryPath', {}).get('stringValue', 'קטלוג'),
                'unitType': f.get('unitLabel', {}).get('stringValue', 'יחידה'),
                'quantity': 1,
                'variantId': row['document']['name'].split('/')[-1],
                'isCatalogMatched': True,
            }
        )
    return items


def embedded_item(line: dict, line_id: str) -> dict:
    return {
        'id': line_id,
        'productId': line['productId'],
        'productName': line['productName'],
        'category': line['category'],
        'unitType': line['unitType'],
        'quantity': line['quantity'],
        'variantId': line.get('variantId'),
        'isCatalogMatched': line.get('isCatalogMatched', True),
    }


def quote_line(product_name: str, qty: int, unit_price: float) -> dict:
    return {
        'productId': 'api-e2e-line',
        'productName': product_name,
        'requestedQuantity': qty,
        'unitPrice': unit_price,
        'totalItemPrice': unit_price * qty,
    }


def build_quote_fields(
    *,
    request_id: str,
    customer_id: str,
    supplier_uid: str,
    supplier_org: str,
    supplier_name: str,
    delivery: str,
    subtotal: float,
    items: list[dict],
) -> dict:
    vat = round(subtotal * 0.17, 2)
    total_incl = subtotal + vat
    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    return {
        'requestId': request_id,
        'quoteRequestId': request_id,
        'customerId': customer_id,
        'supplierId': supplier_uid,
        'supplierOrgId': supplier_org,
        'supplierName': supplier_name,
        'supplierType': 'commercialSupplier',
        'deliveryTime': delivery,
        'status': 'נשלח',
        'seenByCustomer': False,
        'seenOrderBySupplier': False,
        'subtotal': subtotal,
        'deliveryCost': 0,
        'vatRate': 17,
        'vatAmount': vat,
        'totalInclVat': total_incl,
        'totalPrice': total_incl,
        'validUntil': now,
        'paymentTerms': 'שוטף+30',
        'items': items,
        'createdAt': now,
    }


def submit_supplier_quote(
    token: str,
    *,
    quote_id: str,
    request_id: str,
    customer_id: str,
    supplier_uid: str,
    supplier_org: str,
    supplier_name: str,
    delivery: str,
    subtotal: float,
    request_status: str,
    responded: list[str],
) -> tuple[bool, str]:
    quote_fields = build_quote_fields(
        request_id=request_id,
        customer_id=customer_id,
        supplier_uid=supplier_uid,
        supplier_org=supplier_org,
        supplier_name=supplier_name,
        delivery=delivery,
        subtotal=subtotal,
        items=[quote_line('API E2E line', 1, subtotal)],
    )
    new_responded = list(dict.fromkeys(responded + [supplier_uid, supplier_org]))
    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    writes = [
        {
            'update': {
                'name': doc_path('supplierQuotes', quote_id),
                'fields': {k: fs_value(v) for k, v in quote_fields.items()},
            },
            'currentDocument': {'exists': False},
        },
        {
            'update': {
                'name': doc_path('quoteRequests', request_id),
                'fields': {
                    'status': fs_value('התקבלו הצעות'),
                    'supplierIdsResponded': fs_value(new_responded),
                    'updatedAt': fs_value(now),
                },
            },
            'updateMask': {
                'fieldPaths': ['status', 'supplierIdsResponded', 'updatedAt'],
            },
            'currentDocument': {'exists': True},
        },
    ]
    return commit_writes(token, writes)


def approve_quote(
    token: str,
    *,
    quote_id: str,
    request_id: str,
) -> tuple[bool, str]:
    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    writes = [
        {
            'update': {
                'name': doc_path('supplierQuotes', quote_id),
                'fields': {
                    'status': fs_value('אושרה'),
                    'seenOrderBySupplier': fs_value(False),
                },
            },
            'updateMask': {'fieldPaths': ['status', 'seenOrderBySupplier']},
            'currentDocument': {'exists': True},
        },
        {
            'update': {
                'name': doc_path('quoteRequests', request_id),
                'fields': {
                    'status': fs_value('הוזמנה'),
                    'approvedQuoteId': fs_value(quote_id),
                    'updatedAt': fs_value(now),
                },
            },
            'updateMask': {'fieldPaths': ['status', 'approvedQuoteId', 'updatedAt']},
            'currentDocument': {'exists': True},
        },
    ]
    return commit_writes(token, writes)


def mark_shipped(
    token: str,
    *,
    quote_id: str,
    request_id: str,
    supplier_uid: str,
) -> tuple[bool, str]:
    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    writes = [
        {
            'update': {
                'name': doc_path('supplierQuotes', quote_id),
                'fields': {'status': fs_value('נשלחה')},
            },
            'updateMask': {'fieldPaths': ['status']},
            'currentDocument': {'exists': True},
        },
        {
            'update': {
                'name': doc_path('quoteRequests', request_id),
                'fields': {
                    'status': fs_value('נשלחה'),
                    'shippedBySupplierId': fs_value(supplier_uid),
                    'shippedAt': fs_value(now),
                    'updatedAt': fs_value(now),
                },
            },
            'updateMask': {
                'fieldPaths': [
                    'status',
                    'shippedBySupplierId',
                    'shippedAt',
                    'updatedAt',
                ],
            },
            'currentDocument': {'exists': True},
        },
    ]
    return commit_writes(token, writes)


def main() -> int:
    results: dict = {'runMarker': RUN_MARKER, 'steps': {}, 'negatives': {}}
    request_id = f'{RUN_MARKER}-{int(time.time() * 1000)}'
    results['requestId'] = request_id

    eng_auth = sign_in(*ACCOUNTS['engineer'])
    eng_token = eng_auth['idToken']
    eng_uid = eng_auth['localId']
    eng_user, _ = get_doc(eng_token, 'users', eng_uid)
    eng_name = field(eng_user, 'fullName') or field(eng_user, 'name') or 'QA Engineer'

    catalog_lines = query_catalog_variants(eng_token, 3)
    if len(catalog_lines) < 2:
        catalog_lines = [
            {
                'productId': 'api-manual-1',
                'productName': 'בלוק 20',
                'category': 'בלוקים',
                'unitType': 'יחידה',
                'quantity': 2,
                'isCatalogMatched': False,
            },
            {
                'productId': 'api-manual-2',
                'productName': 'צמנט',
                'category': 'צמנט',
                'unitType': 'שק',
                'quantity': 1,
                'isCatalogMatched': False,
            },
        ]

    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    items = [
        embedded_item(line, f'line-{i + 1}')
        for i, line in enumerate(catalog_lines[:3])
    ]
    create_ok, create_err = create_doc(
        eng_token,
        'quoteRequests',
        request_id,
        {
            'customerId': eng_uid,
            'customerName': eng_name,
            'customerPhone': field(eng_user, 'phone') or '0500000000',
            'customerCity': field(eng_user, 'city') or 'תל אביב',
            'customerType': 'commercialCustomer',
            'status': 'ממתין לאישור רכש',
            'notes': RUN_MARKER,
            'createdByUid': eng_uid,
            'preparedByUid': eng_uid,
            'contractorOrgId': CONTRACTOR_ORG,
            'projectId': PROJECT_ID,
            'items': items,
            'supplierIdsResponded': [],
            'seenBySupplierIds': [],
            'customerLastSeenStatus': 'ממתין לאישור רכש',
            'requestType': 'regular',
            'tenderClosed': False,
            'openToAllSuppliers': True,
            'createdAt': now,
            'updatedAt': now,
        },
    )
    results['steps']['engineerCreate'] = {'ok': create_ok, 'error': create_err}

    # Negative: engineer cannot create sent RFQ directly
    neg_id = f'{request_id}-neg-sent'
    neg_ok, neg_err = create_doc(
        eng_token,
        'quoteRequests',
        neg_id,
        {
            'customerId': eng_uid,
            'customerName': eng_name,
            'customerPhone': '050',
            'customerCity': 'תל אביב',
            'customerType': 'commercialCustomer',
            'status': 'נשלח',
            'notes': f'{RUN_MARKER}-neg',
            'contractorOrgId': CONTRACTOR_ORG,
            'items': items[:1],
            'supplierIdsResponded': [],
            'invitedSupplierOrgIds': [QA_BIG, QA_SMALL],
            'openToAllSuppliers': False,
            'createdAt': now,
            'updatedAt': now,
        },
    )
    results['negatives']['engineerDirectSendDenied'] = {
        'ok': not neg_ok,
        'error': neg_err,
    }

    proc_auth = sign_in(*ACCOUNTS['procurement'])
    proc_token = proc_auth['idToken']
    proc_uid = proc_auth['localId']

    approve_ok, approve_err = patch_doc(
        proc_token,
        'quoteRequests',
        request_id,
        {
            'status': 'אושר על ידי רכש',
            'procurementApprovedByUid': proc_uid,
            'updatedAt': datetime.now(UTC).isoformat().replace('+00:00', 'Z'),
        },
    )
    results['steps']['procurementApprove'] = {'ok': approve_ok, 'error': approve_err}

    send_ok, send_err = patch_doc(
        proc_token,
        'quoteRequests',
        request_id,
        {
            'status': 'נשלח',
            'submittedByUid': proc_uid,
            'openToAllSuppliers': False,
            'invitedSupplierOrgIds': [QA_BIG, QA_SMALL],
            'invitedSupplierNames': ['QA ספק גדול בע"מ', 'QA ספק קטן'],
            'updatedAt': datetime.now(UTC).isoformat().replace('+00:00', 'Z'),
        },
    )
    results['steps']['procurementSend'] = {'ok': send_ok, 'error': send_err}

    req_after_send, _ = get_doc(proc_token, 'quoteRequests', request_id)
    results['requestAfterSend'] = {
        'status': field(req_after_send, 'status'),
        'customerId': field(req_after_send, 'customerId'),
        'invited': field(req_after_send, 'invitedSupplierOrgIds'),
        'openToAll': field(req_after_send, 'openToAllSuppliers'),
    }

    big_auth = sign_in(*ACCOUNTS['big_supplier'])
    big_token = big_auth['idToken']
    big_uid = big_auth['localId']
    big_quote_id = f'{request_id}__{QA_BIG}'
    customer_id = field(req_after_send, 'customerId')
    responded = field(req_after_send, 'supplierIdsResponded') or []

    big_ok, big_err = submit_supplier_quote(
        big_token,
        quote_id=big_quote_id,
        request_id=request_id,
        customer_id=customer_id,
        supplier_uid=big_uid,
        supplier_org=QA_BIG,
        supplier_name='QA מנהל ספק גדול',
        delivery='7 ימים',
        subtotal=12345.0,
        request_status=field(req_after_send, 'status'),
        responded=responded,
    )
    results['steps']['bigSupplierQuote'] = {
        'ok': big_ok,
        'error': big_err,
        'quoteId': big_quote_id,
    }

    dup_ok, dup_err = submit_supplier_quote(
        big_token,
        quote_id=big_quote_id,
        request_id=request_id,
        customer_id=customer_id,
        supplier_uid=big_uid,
        supplier_org=QA_BIG,
        supplier_name='QA מנהל ספק גדול',
        delivery='7 ימים',
        subtotal=99999.0,
        request_status='התקבלו הצעות',
        responded=responded + [big_uid, QA_BIG],
    )
    results['negatives']['bigDuplicateDenied'] = {'ok': not dup_ok, 'error': dup_err}

    req_after_big, _ = get_doc(proc_token, 'quoteRequests', request_id)
    responded = field(req_after_big, 'supplierIdsResponded') or []

    small_auth = sign_in(*ACCOUNTS['small_supplier'])
    small_token = small_auth['idToken']
    small_uid = small_auth['localId']
    small_quote_id = f'{request_id}__{QA_SMALL}'

    small_ok, small_err = submit_supplier_quote(
        small_token,
        quote_id=small_quote_id,
        request_id=request_id,
        customer_id=customer_id,
        supplier_uid=small_uid,
        supplier_org=QA_SMALL,
        supplier_name='QA מנהל ספק קטן',
        delivery='5 ימים',
        subtotal=12990.0,
        request_status=field(req_after_big, 'status'),
        responded=responded,
    )
    results['steps']['smallSupplierQuote'] = {
        'ok': small_ok,
        'error': small_err,
        'quoteId': small_quote_id,
    }

    big_q, _ = get_doc(big_token, 'supplierQuotes', big_quote_id)
    small_q, _ = get_doc(small_token, 'supplierQuotes', small_quote_id)
    results['steps']['quoteCompareRead'] = {
        'ok': big_q is not None and small_q is not None,
        'bigTotal': field(big_q, 'totalPrice'),
        'smallTotal': field(small_q, 'totalPrice'),
    }

    eng_approve_ok, eng_approve_err = approve_quote(
        eng_token,
        quote_id=small_quote_id,
        request_id=request_id,
    )
    results['negatives']['engineerApproveDenied'] = {
        'ok': not eng_approve_ok,
        'error': eng_approve_err,
    }

    approve_q_ok, approve_q_err = approve_quote(
        proc_token,
        quote_id=big_quote_id,
        request_id=request_id,
    )
    results['steps']['quoteApproval'] = {
        'ok': approve_q_ok,
        'error': approve_q_err,
        'approvedQuoteId': big_quote_id,
        'approvedSupplierOrgId': QA_BIG,
    }

    ship_ok, ship_err = mark_shipped(
        big_token,
        quote_id=big_quote_id,
        request_id=request_id,
        supplier_uid=big_uid,
    )
    results['steps']['approvedSupplierShipped'] = {'ok': ship_ok, 'error': ship_err}

    req_after_ship, _ = get_doc(proc_token, 'quoteRequests', request_id)
    results['afterShip'] = {
        'requestStatus': field(req_after_ship, 'status'),
        'approvedQuoteId': field(req_after_ship, 'approvedQuoteId'),
    }

    unapproved_ship_ok, unapproved_ship_err = mark_shipped(
        small_token,
        quote_id=small_quote_id,
        request_id=request_id,
        supplier_uid=small_uid,
    )
    results['negatives']['unapprovedShipDenied'] = {
        'ok': not unapproved_ship_ok,
        'error': unapproved_ship_err,
    }

    second_ok, second_err = approve_quote(
        proc_token,
        quote_id=small_quote_id,
        request_id=request_id,
    )
    req_after_second, _ = get_doc(proc_token, 'quoteRequests', request_id)
    second_blocked = (
        not second_ok
        or field(req_after_second, 'approvedQuoteId') == big_quote_id
    )
    results['negatives']['secondApprovalDenied'] = {
        'ok': second_blocked,
        'error': second_err,
        'approvedQuoteIdAfter': field(req_after_second, 'approvedQuoteId'),
    }

    uninvited_auth = sign_in('qa.contractor.small.owner@test.com', 'Qa123456!')
    uninvited_token = uninvited_auth['idToken']
    uninvited_uid = uninvited_auth['localId']
    fake_quote_id = f'{request_id}__{uninvited_uid}'
    uninv_ok, uninv_err = submit_supplier_quote(
        uninvited_token,
        quote_id=fake_quote_id,
        request_id=request_id,
        customer_id=customer_id,
        supplier_uid=uninvited_uid,
        supplier_org=uninvited_uid,
        supplier_name='Uninvited',
        delivery='3 ימים',
        subtotal=100.0,
        request_status='התקבלו הצעות',
        responded=responded,
    )
    results['negatives']['uninvitedSupplierDenied'] = {
        'ok': not uninv_ok,
        'error': uninv_err,
    }

    final_req, _ = get_doc(proc_token, 'quoteRequests', request_id)
    final_big_q, _ = get_doc(big_token, 'supplierQuotes', big_quote_id)
    results['final'] = {
        'requestStatus': field(final_req, 'status'),
        'approvedQuoteId': field(final_req, 'approvedQuoteId'),
        'bigQuoteStatus': field(final_big_q, 'status'),
        'customerIdPreserved': field(final_req, 'customerId') == eng_uid,
    }

    results['ok'] = all(
        [
            results['steps']['engineerCreate']['ok'],
            results['steps']['procurementApprove']['ok'],
            results['steps']['procurementSend']['ok'],
            results['steps']['bigSupplierQuote']['ok'],
            results['steps']['smallSupplierQuote']['ok'],
            results['steps']['quoteCompareRead']['ok'],
            results['steps']['quoteApproval']['ok'],
            results['steps']['approvedSupplierShipped']['ok'],
            results['negatives']['engineerDirectSendDenied']['ok'],
            results['negatives']['bigDuplicateDenied']['ok'],
            results['negatives']['uninvitedSupplierDenied']['ok'],
            results['negatives']['unapprovedShipDenied']['ok'],
            results['negatives']['secondApprovalDenied']['ok'],
            results['negatives']['engineerApproveDenied']['ok'],
            results['afterShip']['requestStatus'] == 'נשלחה',
            results['afterShip']['approvedQuoteId'] == big_quote_id,
            results['final']['bigQuoteStatus'] == 'נשלחה',
            results['final']['customerIdPreserved'],
        ]
    )

    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0 if results['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
