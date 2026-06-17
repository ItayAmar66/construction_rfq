#!/usr/bin/env python3
"""Live smoke: small contractor owner direct RFQ send (idempotent).

Uses the same Firestore document shape as RequestRepository.submitQuoteRequest.
Does not delete data. Re-running verifies an existing RUN_ID document.

Usage:
  python3 tools/qa/small_contractor_direct_send_smoke.py
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import UTC, datetime

API_KEY = 'AIzaSyAMI5ezgGSRZBU8IjklF9fXcBC_PAhqOhc'
PROJECT = 'construction-rfq-itay-20-2eee0'
EMAIL = 'qa.contractor.small.owner@test.com'
PASSWORD = 'Qa123456!'
RUN_ID = 'FINAL-SMOKE-SMALL-CONTRACTOR'
REQUEST_ID = RUN_ID
QA_BIG = 'DRy60MnQjwPQCe6ARmf08cqGsM12'
QA_SMALL = 'C5EKNz88l2UBn506FmFUzfyMhFi2'


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
        return {
            'mapValue': {
                'fields': {k: fs_value(v) for k, v in value.items()},
            },
        }
    return {'stringValue': str(value)}


def get_doc(token: str, path: str) -> dict | None:
    url = (
        f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        f'/databases/(default)/documents/{path}'
    )
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        return json.loads(urllib.request.urlopen(req).read())
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return None
        raise


def create_request(token: str, uid: str, org_id: str) -> str:
    now = datetime.now(UTC).isoformat().replace('+00:00', 'Z')
    fields = {
        'customerId': uid,
        'customerName': 'QA מנהל קבלן קטן',
        'customerPhone': '0500000000',
        'customerCity': 'תל אביב',
        'customerType': 'commercialCustomer',
        'status': 'נשלח',
        'notes': RUN_ID,
        'createdByUid': uid,
        'preparedByUid': uid,
        'submittedByUid': uid,
        'contractorOrgId': org_id,
        'items': [
            {
                'productId': 'manual-smoke-1',
                'productName': 'בלוק 20',
                'category': 'בלוקים',
                'unitType': 'יחידה',
                'quantity': 2,
                'isCatalogMatched': False,
            },
            {
                'productId': 'manual-smoke-2',
                'productName': 'צמנט',
                'category': 'צמנט',
                'unitType': 'שק',
                'quantity': 1,
                'isCatalogMatched': False,
            },
        ],
        'supplierIdsResponded': [],
        'seenBySupplierIds': [],
        'customerLastSeenStatus': 'נשלח',
        'requestType': 'regular',
        'tenderClosed': False,
        'openToAllSuppliers': False,
        'invitedSupplierOrgIds': [QA_BIG, QA_SMALL],
        'invitedSupplierNames': ['QA ספק גדול בע"מ', 'QA ספק קטן'],
        'createdAt': now,
        'updatedAt': now,
    }
    body = {'fields': {k: fs_value(v) for k, v in fields.items()}}
    url = (
        f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        f'/databases/(default)/documents/quoteRequests?documentId={REQUEST_ID}'
    )
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='POST',
    )
    res = json.loads(urllib.request.urlopen(req).read())
    return res['name'].split('/')[-1]


def field_string(doc: dict, key: str) -> str:
    return doc.get('fields', {}).get(key, {}).get('stringValue', '')


def field_string_array(doc: dict, key: str) -> list[str]:
    values = doc.get('fields', {}).get(key, {}).get('arrayValue', {}).get('values', [])
    return [v.get('stringValue', '') for v in values]


def verify(doc: dict) -> list[str]:
    errors: list[str] = []
    if field_string(doc, 'status') != 'נשלח':
        errors.append(f"status expected נשלח, got {field_string(doc, 'status')}")
    if field_string(doc, 'notes') != RUN_ID:
        errors.append('notes missing RUN_ID marker')
    invited = field_string_array(doc, 'invitedSupplierOrgIds')
    for org_id in (QA_BIG, QA_SMALL):
        if org_id not in invited:
            errors.append(f'missing invited org {org_id}')
    open_to_all = doc.get('fields', {}).get('openToAllSuppliers', {}).get('booleanValue')
    if open_to_all is not False:
        errors.append('openToAllSuppliers should be false')
    return errors


def main() -> int:
    auth = sign_in(EMAIL, PASSWORD)
    uid = auth['localId']
    token = auth['idToken']
    org_id = uid

    existing = get_doc(token, f'quoteRequests/{REQUEST_ID}')
    if existing:
        request_id = REQUEST_ID
        action = 'verified existing'
    else:
        try:
            request_id = create_request(token, uid, org_id)
            existing = get_doc(token, f'quoteRequests/{request_id}')
            action = 'created'
        except urllib.error.HTTPError as err:
            print(json.dumps({'ok': False, 'error': err.read().decode()}, ensure_ascii=False))
            return 1

    errors = verify(existing or {})
    supplier_checks = {}
    for email in (
        'qa.supplier.big.owner@test.com',
        'qa.supplier.small.owner@test.com',
    ):
        supplier_token = sign_in(email, PASSWORD)['idToken']
        supplier_doc = get_doc(supplier_token, f'quoteRequests/{request_id}')
        supplier_checks[email] = supplier_doc is not None
        if supplier_doc is None:
            errors.append(f'supplier cannot read request: {email}')

    result = {
        'ok': not errors,
        'action': action,
        'requestId': request_id,
        'runId': RUN_ID,
        'supplierReadable': supplier_checks,
        'errors': errors,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
