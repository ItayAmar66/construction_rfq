#!/usr/bin/env python3
"""Forensic diagnostic for supplier quote create on a live RFQ.

Read-only by default. Pass --write-probe to attempt a direct Firestore create/update
using the same payload shape as SupplierQuoteRepository.submitSupplierQuote.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import UTC, datetime

API_KEY = 'AIzaSyAMI5ezgGSRZBU8IjklF9fXcBC_PAhqOhc'
PROJECT = 'construction-rfq-itay-20-2eee0'
EMAIL = 'qa.supplier.big.owner@test.com'
PASSWORD = 'Qa123456!'
REQUEST_ID = '232b63fc-f1d7-4e67-a8b8-7266875e9845'
SUPPLIER_ORG = 'DRy60MnQjwPQCe6ARmf08cqGsM12'
QUOTE_ID = f'{REQUEST_ID}__{SUPPLIER_ORG}'
PROBE = '--write-probe' in sys.argv


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


def get_doc(token: str, path: str) -> tuple[dict | None, int | None]:
    url = (
        f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        f'/databases/(default)/documents/{path}'
    )
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as err:
        return None, err.code


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


def firestore_write(token: str, method: str, url: str, body: dict) -> tuple[dict | None, str | None]:
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method=method,
    )
    try:
        return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as err:
        return None, f'HTTP {err.code}: {err.read().decode()[:1200]}'


def build_quote_payload(uid: str, customer_id: str, request_items: list) -> dict:
    line = request_items[0] if request_items else {
        'productId': 'probe-1',
        'productName': 'בדיקה',
        'requestedQuantity': 1,
        'unitPrice': 12345.0,
        'totalItemPrice': 12345.0,
    }
    qty = int(line.get('requestedQuantity') or line.get('quantity') or 1)
    unit = float(line.get('unitPrice', 12345))
    total = float(line.get('totalItemPrice', unit * qty))
    subtotal = total
    vat = round(subtotal * 0.17, 2)
    total_incl = subtotal + vat
    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    return {
        'requestId': REQUEST_ID,
        'quoteRequestId': REQUEST_ID,
        'customerId': customer_id,
        'supplierId': uid,
        'supplierOrgId': SUPPLIER_ORG,
        'supplierName': 'QA מנהל ספק גדול',
        'supplierType': 'commercialSupplier',
        'deliveryTime': '7 ימים',
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
        'items': [
            {
                'productId': str(line.get('productId', 'probe-1')),
                'productName': str(line.get('productName', 'בדיקה')),
                'requestedQuantity': qty,
                'unitPrice': unit,
                'totalItemPrice': total,
            }
        ],
        'createdAt': now,
    }


def _memberships_cg_denied(token: str, uid: str) -> bool:
    body = {
        'structuredQuery': {
            'from': [{'collectionId': 'memberships', 'allDescendants': True}],
            'where': {
                'fieldFilter': {
                    'field': {'fieldPath': 'uid'},
                    'op': 'EQUAL',
                    'value': {'stringValue': uid},
                }
            },
            'limit': 1,
        }
    }
    req = urllib.request.Request(
        f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents:runQuery',
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    )
    try:
        urllib.request.urlopen(req)
        return False
    except urllib.error.HTTPError as err:
        return err.code == 403


def parse_embedded_items(request_doc: dict) -> list[dict]:
    items = field(request_doc, 'items', []) or []
    out = []
    for raw in items:
        if isinstance(raw, dict) and 'mapValue' in raw:
            f = raw['mapValue']['fields']
            out.append({
                'productId': f.get('productId', {}).get('stringValue'),
                'productName': f.get('productName', {}).get('stringValue'),
                'quantity': int(f.get('quantity', {}).get('integerValue', '1')),
            })
    return out


def main() -> int:
    auth = sign_in(EMAIL, PASSWORD)
    uid = auth['localId']
    token = auth['idToken']

    user, user_err = get_doc(token, f'users/{uid}')
    membership, mem_err = get_doc(
        token, f'organizations/{SUPPLIER_ORG}/memberships/{uid}'
    )
    request, req_err = get_doc(token, f'quoteRequests/{REQUEST_ID}')
    quote, quote_err = get_doc(token, f'supplierQuotes/{QUOTE_ID}')

    invited = field(request, 'invitedSupplierOrgIds', []) or []
    responded = field(request, 'supplierIdsResponded', []) or []

    report = {
        'uid': uid,
        'membershipsCollectionGroup403': _memberships_cg_denied(token, uid),
        'userProfile': {
            'orgId': field(user, 'orgId'),
            'primaryOrgId': field(user, 'primaryOrgId'),
            'accountStatus': field(user, 'accountStatus'),
            'userType': field(user, 'userType'),
            'readError': user_err,
        },
        'membership': {
            'exists': membership is not None,
            'status': field(membership, 'status'),
            'roles': field(membership, 'roles'),
            'readError': mem_err,
        },
        'request': {
            'exists': request is not None,
            'status': field(request, 'status'),
            'invitedSupplierOrgIds': invited,
            'openToAllSuppliers': field(request, 'openToAllSuppliers'),
            'supplierIdsResponded': responded,
            'customerId': field(request, 'customerId'),
            'readError': req_err,
        },
        'quote': {
            'exists': quote is not None,
            'status': field(quote, 'status') if quote else None,
            'readError': quote_err,
            'quoteId': QUOTE_ID,
        },
        'checks': {
            'orgInvited': SUPPLIER_ORG in invited,
            'requestOpen': field(request, 'status') in ('נשלח', 'sent', 'התקבלו הצעות', 'quotesReceived'),
        },
    }

    if PROBE and request and not quote:
        payload = build_quote_payload(uid, field(request, 'customerId'), parse_embedded_items(request))
        body = {'fields': {k: fs_value(v) for k, v in payload.items()}}
        url = (
            f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
            f'/databases/(default)/documents/supplierQuotes?documentId={QUOTE_ID}'
        )
        _, create_err = firestore_write(token, 'POST', url, body)
        report['writeProbe'] = {'quoteCreateOnly': {'error': create_err}}

        if not create_err:
            # probe request update separately (mimics transaction second half)
            new_responded = list(dict.fromkeys(responded + [uid, SUPPLIER_ORG]))
            upd = {
                'fields': {
                    'status': fs_value('התקבלו הצעות'),
                    'supplierIdsResponded': fs_value(new_responded),
                    'updatedAt': fs_value(datetime.now(UTC).isoformat().replace('+00:00', 'Z')),
                }
            }
            mask = 'updateMask.fieldPaths=status&updateMask.fieldPaths=supplierIdsResponded&updateMask.fieldPaths=updatedAt'
            upd_url = (
                f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
                f'/databases/(default)/documents/quoteRequests/{REQUEST_ID}?{mask}'
            )
            _, upd_err = firestore_write(token, 'PATCH', upd_url, upd)
            report['writeProbe']['requestUpdateOnly'] = {'error': upd_err}

        quote2, _ = get_doc(token, f'supplierQuotes/{QUOTE_ID}')
        req2, _ = get_doc(token, f'quoteRequests/{REQUEST_ID}')
        report['afterProbe'] = {
            'quoteExists': quote2 is not None,
            'quoteStatus': field(quote2, 'status'),
            'supplierIdsResponded': field(req2, 'supplierIdsResponded', []),
            'requestStatus': field(req2, 'status'),
        }

    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
