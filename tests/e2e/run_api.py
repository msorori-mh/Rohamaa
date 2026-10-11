"""Real Auth/REST/Storage regression tests, restricted to disposable localhost Supabase.

Only fixture provisioning uses service_role. Tests exercise real authenticated JWTs.
The CI job destroys the complete disposable stack in its always() cleanup step.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import secrets
import sys
import time
import unittest
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import uuid
import xml.etree.ElementTree as ET


class API:
    def __init__(self, url, key, token=None):
        parsed = urlparse(url)
        if parsed.scheme != 'http' or parsed.hostname not in ('127.0.0.1', 'localhost'):
            raise RuntimeError('TEST_ONLY: refusing a non-loopback Supabase endpoint')
        self.url, self.key, self.token = url.rstrip('/'), key, token or key

    def request(self, method, path, data=None, content_type='application/json'):
        payload = data if isinstance(data, bytes) else (json.dumps(data).encode() if data is not None else None)
        req = Request(self.url + path, data=payload, method=method, headers={
            'apikey': self.key, 'Authorization': 'Bearer ' + self.token,
            'Content-Type': content_type, 'Prefer': 'return=representation',
        })
        try:
            response = urlopen(req, timeout=30)
            status, body = response.status, response.read()
        except HTTPError as error:
            status, body = error.code, error.read()
        try:
            body = json.loads(body) if body else None
        except (ValueError, UnicodeDecodeError):
            body = {'binary_size': len(body)}
        return status, body

    def ok(self, method, path, data=None):
        status, body = self.request(method, path, data)
        if not 200 <= status < 300:
            raise AssertionError(f'{method} {path.split("?")[0]} returned {status}: {body}')
        return body

    def rpc(self, name, data=None):
        return self.ok('POST', '/rest/v1/rpc/' + name, data or {})


def bootstrap(status_file, runtime_file):
    status = json.loads(Path(status_file).read_text())
    url = status.get('API_URL') or status.get('api_url')
    anon = status.get('ANON_KEY') or status.get('anon_key')
    service = status.get('SERVICE_ROLE_KEY') or status.get('service_role_key')
    if not all((url, anon, service)):
        raise RuntimeError('Local Supabase status is missing API_URL/ANON_KEY/SERVICE_ROLE_KEY')
    root = API(url, service)
    run_id = uuid.uuid4().hex[:12]
    data = {'url': url, 'anon': anon, 'service': service, 'run_id': run_id, 'users': {}}
    areas = root.ok('GET', '/rest/v1/service_areas?select=id&active=eq.true&limit=1')
    if not areas:
        raise RuntimeError('No active service area after migrations')
    data['area_id'] = areas[0]['id']
    for name, role in [('donor', 'user'), ('recipient', 'user'), ('admin', 'admin'), ('courier', 'courier'), ('courier2', 'courier'), ('supervisor', 'supervisor'), ('suspended', 'user'), ('temporary', 'courier')]:
        email = f'test-only-{name}-{run_id}@example.test'
        password = 'TestOnly!9a' + secrets.token_hex(12)
        user = root.ok('POST', '/auth/v1/admin/users', {'email': email, 'password': password, 'email_confirm': True, 'user_metadata': {'full_name': 'TEST_ONLY ' + name}})
        uid = user['id']
        root.ok('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'role': role, 'full_name': 'TEST_ONLY ' + name, 'phone': '777000001', 'force_password_change': name == 'temporary', 'is_suspended': name == 'suspended'})
        if role == 'courier':
            root.ok('POST', '/rest/v1/couriers', {'user_id': uid, 'active': True})
        if role in ('courier', 'supervisor'):
            root.ok('POST', '/rest/v1/staff_area_assignments', {'user_id': uid, 'area_id': data['area_id'], 'is_primary': True})
        address = root.ok('POST', '/rest/v1/addresses', {'user_id': uid, 'service_area_id': data['area_id'], 'area': 'TEST_ONLY area', 'description': 'TEST_ONLY private address ' + name, 'latitude': 15.4, 'longitude': 45.3, 'is_default': True})[0]
        session = API(url, anon).ok('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        data['users'][name] = {'id': uid, 'email': email, 'password': password, 'token': session['access_token'], 'address_id': address['id']}
    Path(runtime_file).write_text(json.dumps(data))
    os.chmod(runtime_file, 0o600)
    defines = {'SUPABASE_URL': url, 'SUPABASE_ANON_KEY': anon}
    for name, user in data['users'].items():
        defines[name.upper() + '_EMAIL'] = user['email']
        defines[name.upper() + '_PASSWORD'] = user['password']
    defines_path = Path(runtime_file).with_name('ui-defines.json')
    defines_path.write_text(json.dumps(defines))
    os.chmod(defines_path, 0o600)
    print('Provisioned 8 TEST_ONLY users, roles and addresses on localhost.')


class EndToEnd(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(Path(os.environ['E2E_RUNTIME_FILE']).read_text())
        cls.root = API(cls.data['url'], cls.data['service'])
        cls.clients = {n: API(cls.data['url'], cls.data['anon'], u['token']) for n, u in cls.data['users'].items()}

    def user(self, name):
        return self.data['users'][name]

    def code(self):
        return 'TEST_ONLY-' + uuid.uuid4().hex

    def create_item(self, table, owner, **extra):
        # The server owns public_code and the initial status; like the app, send neither.
        payload = {'user_id': self.user(owner)['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY chair', 'address_id': self.user(owner)['address_id']}
        payload.update(extra)
        return self.clients[owner].ok('POST', '/rest/v1/' + table, payload)[0]

    PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jN1kAAAAASUVORK5CYII=')

    def disposable_user(self, label):
        """A throwaway regular user for destructive flows; never one of the shared fixtures."""
        email = f'test-only-{label}-{uuid.uuid4().hex[:12]}@example.test'
        password = 'TestOnly!9a' + secrets.token_hex(12)
        created = self.root.ok('POST', '/auth/v1/admin/users', {'email': email, 'password': password, 'email_confirm': True, 'user_metadata': {'full_name': 'TEST_ONLY ' + label}})
        uid = created['id']
        self.root.ok('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'full_name': 'TEST_ONLY ' + label, 'phone': '777000002'})
        address = self.root.ok('POST', '/rest/v1/addresses', {'user_id': uid, 'service_area_id': self.data['area_id'], 'label': 'TEST_ONLY home', 'area': 'TEST_ONLY area', 'description': 'TEST_ONLY private address ' + label, 'latitude': 15.4, 'longitude': 45.3, 'is_default': True})[0]
        session = API(self.data['url'], self.data['anon']).ok('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        return {'id': uid, 'email': email, 'password': password, 'address_id': address['id'], 'client': API(self.data['url'], self.data['anon'], session['access_token'])}

    def upload_donation_image(self, client, owner_id, donation_id):
        path = owner_id + '/' + donation_id + '/' + uuid.uuid4().hex + '.png'
        code, body = client.request('POST', '/storage/v1/object/donation-images/' + path, self.PNG, 'image/png')
        self.assertIn(code, (200, 201), body)
        client.ok('POST', '/rest/v1/donation_images', {'donation_id': donation_id, 'storage_path': path, 'sort_order': 0})
        return path

    def message(self, client, rpc, data):
        """The database error message of an RPC that must be rejected."""
        status, body = client.request('POST', '/rest/v1/rpc/' + rpc, data)
        self.assertEqual(status, 400, body)
        return (body or {}).get('message')

    def delivery(self, courier='courier', isolated_fixture=False):
        donation = self.create_item('donations', 'donor')
        need = self.create_item('needs', 'recipient')
        match = self.clients['admin'].rpc('admin_approve_match', {'p_donation_id': donation['id'], 'p_need_id': need['id']})
        self.clients['recipient'].rpc('user_respond_match_offer', {'p_match_id': match, 'p_accept': True})
        if isolated_fixture:
            # Separate authorization/transition coverage from the creation RPC.
            # The complete E2E and notification tests still require real creation.
            task = self.root.ok('POST', '/rest/v1/deliveries', {
                'public_code': self.code(), 'match_id': match,
                'courier_id': self.user(courier)['id'], 'status': 'assigned',
                'pickup_pin_hash': 'TEST_ONLY_NON_SECRET_HASH',
                'delivery_pin_hash': 'TEST_ONLY_NON_SECRET_HASH',
            })[0]
            return task['id'], donation['id'], need['id']
        task = self.clients['admin'].rpc('admin_create_delivery', {'p_match_id': match, 'p_courier_id': self.user(courier)['id']})[0]
        return task['delivery_id'], donation['id'], need['id']

    def denied(self, client, method, path, data=None):
        status, body = client.request(method, path, data)
        self.assertIn(status, (400, 401, 403), f'Expected explicit rejection; got {status}: {body}')
        self.assertNotEqual((body or {}).get('code'), 'PGRST202', 'Missing RPC is not an authorization pass')

    def test_auth_sessions_are_real_and_owned(self):
        for name in ('donor', 'recipient', 'admin', 'courier', 'supervisor'):
            with self.subTest(role=name):
                result = self.clients[name].ok('GET', '/auth/v1/user')
                self.assertEqual(result['id'], self.user(name)['id'])

    def test_profiles_cannot_be_read_by_another_user(self):
        rows = self.clients['donor'].ok('GET', '/rest/v1/profiles?id=eq.' + self.user('recipient')['id'])
        self.assertEqual(rows, [])

    def test_role_escalation_is_denied(self):
        self.denied(self.clients['donor'], 'PATCH', '/rest/v1/profiles?id=eq.' + self.user('donor')['id'], {'role': 'admin'})
        actual = self.root.ok('GET', '/rest/v1/profiles?select=role&id=eq.' + self.user('donor')['id'])
        self.assertEqual(actual[0]['role'], 'user')

    def test_address_read_and_update_are_owner_scoped(self):
        path = '/rest/v1/addresses?id=eq.' + self.user('recipient')['address_id']
        self.assertEqual(self.clients['donor'].ok('GET', path), [])
        self.assertEqual(self.clients['donor'].ok('PATCH', path, {'description': 'unauthorized'}), [])
        self.assertIn('recipient', self.root.ok('GET', path)[0]['description'])

    def test_donation_and_need_create_read_cancel(self):
        for table, owner, rpc, arg in [('donations', 'donor', 'user_cancel_donation', 'p_donation_id'), ('needs', 'recipient', 'user_cancel_need', 'p_need_id')]:
            with self.subTest(table=table):
                row = self.create_item(table, owner)
                other = 'recipient' if owner == 'donor' else 'donor'
                path = '/rest/v1/' + table + '?id=eq.' + row['id']
                self.assertEqual(self.clients[other].ok('GET', path), [])
                self.clients[owner].rpc(rpc, {arg: row['id']})
                self.assertEqual(self.clients[owner].ok('GET', path)[0]['status'], 'cancelled')

    def test_cannot_insert_item_owned_by_another_user(self):
        self.denied(self.clients['donor'], 'POST', '/rest/v1/donations', {'public_code': self.code(), 'user_id': self.user('recipient')['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY'})

    def test_item_initial_status_and_public_code_are_server_controlled(self):
        # The insert trigger overwrites whatever the client sends instead of trusting it.
        for table, owner, status, prefix in [('donations', 'donor', 'delivered', 'RHM-MRB-DON-'), ('needs', 'recipient', 'fulfilled', 'RHM-MRB-NEED-')]:
            with self.subTest(table=table):
                sent = self.code()
                row = self.clients[owner].ok('POST', '/rest/v1/' + table, {'public_code': sent, 'user_id': self.user(owner)['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY', 'status': status, 'created_at': '2000-01-01T00:00:00Z'})[0]
                self.assertEqual(row['status'], 'submitted', 'Client controlled initial status')
                self.assertNotEqual(row['public_code'], sent, 'Client controlled public code')
                self.assertTrue(row['public_code'].startswith(prefix), row['public_code'])
                self.assertFalse(row['created_at'].startswith('2000-01-01'), 'Client controlled queue age')
                stored = self.root.ok('GET', '/rest/v1/' + table + '?id=eq.' + row['id'])[0]
                self.assertEqual((stored['status'], stored['public_code']), ('submitted', row['public_code']))
                self.assertEqual(self.root.ok('GET', '/rest/v1/' + table + '?public_code=eq.' + sent), [])

    def test_service_role_inserts_keep_their_values(self):
        # Fixtures, migrations and SECURITY DEFINER RPCs must stay unaffected by the insert trigger.
        sent = self.code()
        row = self.root.ok('POST', '/rest/v1/donations', {'public_code': sent, 'user_id': self.user('donor')['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY', 'status': 'cancelled'})[0]
        self.assertEqual((row['public_code'], row['status']), (sent, 'cancelled'))

    def test_free_text_length_limits_are_enforced(self):
        donor = self.clients['donor']
        base = {'user_id': self.user('donor')['id'], 'category': 'furniture'}
        self.denied(donor, 'POST', '/rest/v1/donations', {**base, 'item_type': 'x' * 161})
        self.denied(donor, 'POST', '/rest/v1/donations', {**base, 'item_type': 'TEST_ONLY', 'description': 'x' * 2001})
        self.denied(donor, 'POST', '/rest/v1/needs', {**base, 'item_type': 'TEST_ONLY', 'reason': 'x' * 2001})
        self.denied(donor, 'POST', '/rest/v1/donations', {**base, 'item_type': 'TEST_ONLY', 'item_attributes': {'note': 'x' * 4001}})
        profile = '/rest/v1/profiles?id=eq.' + self.user('donor')['id']
        self.denied(donor, 'PATCH', profile, {'full_name': 'x' * 121})
        self.denied(donor, 'PATCH', profile, {'phone': '7' * 21})
        self.assertEqual(self.root.ok('GET', profile)[0]['full_name'], 'TEST_ONLY donor')
        address = '/rest/v1/addresses?id=eq.' + self.user('donor')['address_id']
        self.denied(donor, 'PATCH', address, {'description': 'x' * 2001})
        accepted = donor.ok('POST', '/rest/v1/donations', {**base, 'item_type': 'x' * 160, 'description': 'x' * 2000})[0]
        self.assertEqual(len(accepted['item_type']), 160)

    def test_owner_cannot_update_workflow_after_inventory_grant(self):
        row = self.create_item('donations', 'donor')
        self.denied(self.clients['donor'], 'PATCH', '/rest/v1/donations?id=eq.' + row['id'], {'status': 'delivered'})
        self.assertEqual(self.clients['donor'].ok('GET', '/rest/v1/donations?id=eq.' + row['id'])[0]['status'], 'submitted')
        updated = self.clients['donor'].ok('PATCH', '/rest/v1/donations?id=eq.' + row['id'], {'description': 'TEST_ONLY updated', 'updated_at': '2000-01-01T00:00:00Z'})[0]
        self.assertEqual(updated['description'], 'TEST_ONLY updated')
        self.assertFalse(updated['updated_at'].startswith('2000-01-01'))

    def test_contribution_creation_and_idempotent_admin_verification(self):
        row = self.clients['donor'].ok('POST', '/rest/v1/contributions', {'user_id': self.user('donor')['id'], 'amount_yer': 1000, 'payment_method': 'cash_to_courier'})[0]
        self.assertTrue(row['public_code'].startswith('RHM-MRB-CTR-'), row['public_code'])
        args = {'p_contribution_id': row['id'], 'p_verified': True, 'p_note': 'TEST_ONLY'}
        self.denied(self.clients['recipient'], 'POST', '/rest/v1/rpc/admin_verify_contribution', args)
        self.clients['admin'].rpc('admin_verify_contribution', args)
        before = self.root.ok('GET', '/rest/v1/audit_logs?entity_id=eq.' + row['id'])
        status, body = self.clients['admin'].request('POST', '/rest/v1/rpc/admin_verify_contribution', args)
        self.assertEqual(status, 400)
        self.assertEqual(body.get('message'), 'contribution is no longer pending')
        after = self.root.ok('GET', '/rest/v1/audit_logs?entity_id=eq.' + row['id'])
        self.assertEqual(len(after), len(before))
        self.assertEqual(self.clients['donor'].ok('GET', '/rest/v1/contributions?id=eq.' + row['id'])[0]['status'], 'verified')

    def test_contribution_cannot_be_created_as_verified(self):
        # Verification and courier acknowledgement fields are overwritten by the insert trigger.
        sent = self.code()
        row = self.clients['donor'].ok('POST', '/rest/v1/contributions', {'public_code': sent, 'user_id': self.user('donor')['id'], 'amount_yer': 1000, 'payment_method': 'cash_to_courier', 'status': 'verified', 'verified_by': self.user('donor')['id'], 'verified_at': '2000-01-01T00:00:00Z', 'courier_received': True, 'courier_confirmed_by': self.user('donor')['id'], 'courier_confirmed_at': '2000-01-01T00:00:00Z'})[0]
        stored = self.root.ok('GET', '/rest/v1/contributions?id=eq.' + row['id'])[0]
        self.assertEqual(stored['status'], 'pending')
        self.assertNotEqual(stored['public_code'], sent)
        for column in ('verified_by', 'verified_at', 'courier_received', 'courier_confirmed_by', 'courier_confirmed_at'):
            self.assertIsNone(stored[column], column)

    def test_contribution_invalid_amount_is_rejected(self):
        self.denied(self.clients['donor'], 'POST', '/rest/v1/contributions', {'user_id': self.user('donor')['id'], 'amount_yer': -1})

    def test_complete_delivery_lifecycle_and_privacy(self):
        task, donation, need = self.delivery()
        args = {'p_delivery_id': task}
        courier = self.clients['courier']
        self.assertEqual(self.clients['courier2'].rpc('courier_task_details', args), [])
        before = courier.rpc('courier_task_details', args)[0]
        for column in ('pickup_phone', 'pickup_description', 'pickup_latitude', 'dropoff_phone', 'dropoff_description'):
            self.assertIsNone(before[column], column)
        self.denied(self.clients['courier2'], 'POST', '/rest/v1/rpc/courier_respond_delivery', {**args, 'p_accept': True})
        self.assertEqual(courier.rpc('courier_respond_delivery', {**args, 'p_accept': True}), 'heading_to_pickup')
        self.assertIsNotNone(courier.rpc('courier_task_details', args)[0]['pickup_phone'])
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_start_dropoff', args)
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        self.assertTrue(courier.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'}))
        self.denied(courier, 'POST', '/rest/v1/rpc/verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'})
        courier.rpc('courier_start_dropoff', args)
        pin = self.clients['recipient'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'delivery'})
        self.assertTrue(courier.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'delivery'}))
        self.assertEqual(self.root.ok('GET', '/rest/v1/needs?id=eq.' + need)[0]['status'], 'fulfilled')
        self.assertEqual(self.root.ok('GET', '/rest/v1/donations?id=eq.' + donation)[0]['status'], 'delivered')

    def test_null_pin_does_not_change_delivery_state(self):
        task, _, _ = self.delivery()
        args = {'p_delivery_id': task}
        self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': True})
        self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        code, result = self.clients['courier'].request('POST', '/rest/v1/rpc/verify_delivery_pin', {**args, 'p_pin': None, 'p_kind': 'pickup'})
        state = self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]['status']
        self.assertEqual(state, 'heading_to_pickup', f'NULL changed state; response={code}/{result}')

    def test_courier_cannot_read_pin_hash_columns(self):
        task, _, _ = self.delivery(isolated_fixture=True)
        self.denied(self.clients['courier'], 'GET', '/rest/v1/deliveries?select=pickup_pin_hash,delivery_pin_hash&id=eq.' + task)

    def test_pin_attempt_limit_and_expiry(self):
        task, _, _ = self.delivery()
        args = {'p_delivery_id': task}
        courier = self.clients['courier']
        courier.rpc('courier_respond_delivery', {**args, 'p_accept': True})
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        wrong = '0000' if pin != '0000' else '0001'
        for _ in range(5):
            self.assertFalse(courier.rpc('verify_delivery_pin', {**args, 'p_pin': wrong, 'p_kind': 'pickup'}))
        self.assertFalse(courier.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'}))
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        self.root.ok('PATCH', '/rest/v1/deliveries?id=eq.' + task, {'pickup_pin_expires_at': '2000-01-01T00:00:00Z'})
        self.assertFalse(courier.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'}))
        self.assertEqual(self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]['status'], 'heading_to_pickup')

    def test_courier_decline_and_reassignment(self):
        task, _, _ = self.delivery(isolated_fixture=True)
        args = {'p_delivery_id': task}
        result = self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': False, 'p_reason': 'unavailable'})
        self.assertEqual(result, 'rescheduled')
        self.clients['admin'].rpc('admin_reassign_delivery', {**args, 'p_courier_id': self.user('courier2')['id']})
        self.assertEqual(self.clients['courier'].rpc('courier_task_details', args), [])
        self.assertEqual(self.clients['courier2'].rpc('courier_respond_delivery', {**args, 'p_accept': True}), 'heading_to_pickup')

    def test_temporary_password_cannot_accept_delivery(self):
        task, _, _ = self.delivery('temporary', isolated_fixture=True)
        self.denied(self.clients['temporary'], 'POST', '/rest/v1/rpc/courier_respond_delivery', {'p_delivery_id': task, 'p_accept': True})

    def test_inactive_courier_cannot_accept_delivery(self):
        task, _, _ = self.delivery()
        path = '/rest/v1/couriers?user_id=eq.' + self.user('courier')['id']
        self.root.ok('PATCH', path, {'active': False})
        try:
            self.denied(self.clients['courier'], 'POST', '/rest/v1/rpc/courier_respond_delivery', {'p_delivery_id': task, 'p_accept': True})
        finally:
            self.root.ok('PATCH', path, {'active': True})

    def test_suspended_account_cannot_create_need(self):
        self.denied(self.clients['suspended'], 'POST', '/rest/v1/needs', {'public_code': self.code(), 'user_id': self.user('suspended')['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY'})

    def test_service_offer_request_matching_and_consent(self):
        offer = self.clients['donor'].ok('POST', '/rest/v1/service_offers', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY plumbing', 'availability_mode': 'hours', 'available_hours': 2})[0]
        request = self.clients['recipient'].ok('POST', '/rest/v1/service_requests', {'public_code': self.code(), 'user_id': self.user('recipient')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY repair', 'details': 'TEST_ONLY details'})[0]
        self.clients['admin'].ok('PATCH', '/rest/v1/service_offers?id=eq.' + offer['id'], {'status': 'approved', 'verification_status': 'verified'})
        match = self.clients['admin'].ok('POST', '/rest/v1/service_matches', {'service_offer_id': offer['id'], 'service_request_id': request['id'], 'approved_by': self.user('admin')['id']})[0]
        self.clients['donor'].rpc('user_respond_service_match', {'p_match_id': match['id'], 'p_accept': True})
        self.assertEqual(self.clients['recipient'].rpc('user_respond_service_match', {'p_match_id': match['id'], 'p_accept': True}), 'accepted')

    def test_partner_registration_and_owner_isolation(self):
        partner = self.clients['donor'].rpc('user_register_service_partner', {'p_display_name': 'TEST_ONLY repair shop', 'p_partner_kind': 'repair_shop', 'p_description': 'TEST_ONLY', 'p_contact_phone': '777000001', 'p_monthly_case_capacity': 2, 'p_service_area_id': self.data['area_id'], 'p_terms_version': 'v1'})
        self.assertTrue(partner)
        rows = self.clients['recipient'].ok('GET', '/rest/v1/service_partners?id=eq.' + partner)
        self.assertEqual(rows, [])

    def test_notifications_are_owner_scoped(self):
        task, _, _ = self.delivery()
        own = self.clients['courier'].ok('GET', '/rest/v1/user_notifications?entity_id=eq.' + task)
        self.assertTrue(own, 'Assignment must generate an in-app notification')
        other = self.clients['courier2'].ok('GET', '/rest/v1/user_notifications?id=eq.' + own[0]['id'])
        self.assertEqual(other, [])

    def test_storage_rejects_other_user_path(self):
        path = '/storage/v1/object/donation-images/' + self.user('recipient')['id'] + '/test-only.bin'
        code, _ = self.clients['donor'].request('POST', path, b'TEST_ONLY', 'application/octet-stream')
        self.assertIn(code, (400, 401, 403))

    def test_storage_rejects_non_image_upload(self):
        path = '/storage/v1/object/donation-images/' + self.user('donor')['id'] + '/' + uuid.uuid4().hex + '.html'
        code, _ = self.clients['donor'].request('POST', path, b'<p>TEST_ONLY</p>', 'text/html')
        self.assertIn(code, (400, 401, 403), f'Unexpected non-image acceptance: {code}')

    def test_storage_accepts_owner_image(self):
        png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jN1kAAAAASUVORK5CYII=')
        path = '/storage/v1/object/donation-images/' + self.user('donor')['id'] + '/' + self.code() + '.png'
        code, _ = self.clients['donor'].request('POST', path, png, 'image/png')
        self.assertIn(code, (200, 201))

    def test_storage_rejects_oversized_image(self):
        path = '/storage/v1/object/donation-images/' + self.user('donor')['id'] + '/' + self.code() + '.png'
        code, _ = self.clients['donor'].request('POST', path, b'0' * 5242881, 'image/png')
        self.assertIn(code, (400, 413))

    def test_admin_queues_are_denied_to_regular_users(self):
        for rpc in ('admin_accepted_matches_queue', 'admin_delivery_dispatch_queue', 'admin_operations_overview'):
            with self.subTest(rpc=rpc):
                self.denied(self.clients['donor'], 'POST', '/rest/v1/rpc/' + rpc, {})
                self.assertIsInstance(self.clients['admin'].rpc(rpc), list)

    def test_concurrent_courier_acceptance_has_one_winner(self):
        task, _, _ = self.delivery(isolated_fixture=True)
        def accept():
            return self.clients['courier'].request('POST', '/rest/v1/rpc/courier_respond_delivery', {'p_delivery_id': task, 'p_accept': True})[0]
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: accept(), range(2)))
        self.assertEqual(sum(200 <= code < 300 for code in results), 1, results)
        events = self.root.ok('GET', '/rest/v1/delivery_events?delivery_id=eq.' + task + '&event_type=eq.courier_accepted')
        self.assertEqual(len(events), 1)

    def test_reviewed_need_publish_hide_republish(self):
        need = self.create_item('needs', 'recipient')
        params = {'p_need_id': need['id'], 'p_display_title': 'TEST_ONLY chair needed', 'p_display_detail': 'TEST_ONLY public description', 'p_city_label': 'مأرب'}
        card = self.clients['admin'].rpc('admin_publish_need_discovery_card', params)
        def visible():
            return {r['card_id'] for r in self.clients['donor'].rpc('discovery_need_cards_v2', {'p_limit': 100})}
        self.assertIn(card, visible())
        self.clients['admin'].rpc('admin_unpublish_need_discovery_card', {'p_card_id': card})
        self.assertNotIn(card, visible())
        card = self.clients['admin'].rpc('admin_publish_need_discovery_card', params)
        self.assertIn(card, visible())

    def test_inventory_grade_routes_and_work_orders(self):
        admin = self.clients['admin']
        warehouse = admin.rpc('admin_create_warehouse', {'p_code': 'T-' + uuid.uuid4().hex[:8], 'p_name': 'TEST_ONLY warehouse'})
        for grade, expected in [('A', 'ready_for_distribution'), ('B', 'cleaning_queued'), ('C', 'repair_queued'), ('D', 'recycling')]:
            with self.subTest(grade=grade):
                donation = self.create_item('donations', 'donor')
                item = admin.rpc('admin_receive_inventory_item', {'p_donation_id': donation['id'], 'p_warehouse_id': warehouse})
                self.assertEqual(admin.rpc('admin_inspect_inventory_item', {'p_inventory_item_id': item, 'p_grade': grade, 'p_estimated_cost_yer': 1000}), expected)
                self.denied(self.clients['donor'], 'POST', '/rest/v1/rpc/admin_inspect_inventory_item', {'p_inventory_item_id': item, 'p_grade': 'A'})
                if grade in ('B', 'C'):
                    work = admin.ok('GET', '/rest/v1/item_work_orders?inventory_item_id=eq.' + item)[0]
                    self.denied(admin, 'POST', '/rest/v1/rpc/admin_advance_item_work_order', {'p_work_order_id': work['id'], 'p_action': 'complete', 'p_actual_cost_yer': 1000})
                    admin.rpc('admin_advance_item_work_order', {'p_work_order_id': work['id'], 'p_action': 'start'})
                    self.assertEqual(admin.rpc('admin_advance_item_work_order', {'p_work_order_id': work['id'], 'p_action': 'complete', 'p_actual_cost_yer': 1000}), 'ready_for_distribution')
                if grade == 'D':
                    recycling = admin.ok('GET', '/rest/v1/item_recycling_records?inventory_item_id=eq.' + item)[0]
                    admin.rpc('admin_confirm_item_recycling', {'p_recycling_id': recycling['id'], 'p_material_type': 'metal', 'p_weight_kg': 1, 'p_proceeds_yer': 100})
                    self.assertEqual(admin.ok('GET', '/rest/v1/inventory_items?id=eq.' + item)[0]['status'], 'recycled')

    def test_account_deletion_request_is_idempotent(self):
        user = self.clients['donor']
        user.rpc('request_account_deletion')
        user.rpc('request_account_deletion')
        rows = user.ok('GET', '/rest/v1/account_deletion_requests?user_id=eq.' + self.user('donor')['id'])
        self.assertEqual(len(rows), 1)

    def test_edge_staff_creation_rejects_regular_user(self):
        self.denied(self.clients['donor'], 'POST', '/functions/v1/admin-create-staff', {'email': 'test-only-denied@example.test', 'password': 'TestOnly!Password9', 'role': 'courier', 'full_name': 'TEST_ONLY', 'area_ids': [self.data['area_id']]})

    def test_staff_password_change_flow(self):
        temporary = self.clients['temporary']
        uid = self.user('temporary')['id']
        profile = '/rest/v1/profiles?id=eq.' + uid
        first = 'ChangedTestOnly!9a' + secrets.token_hex(12)
        second = 'RotatedTestOnly!9b' + secrets.token_hex(12)
        path = '/functions/v1/staff-change-password'
        try:
            # An expired temporary password can no longer be exchanged.
            self.root.ok('PATCH', profile, {'force_password_change': True, 'temp_password_expires_at': '2000-01-01T00:00:00Z'})
            status, body = temporary.request('POST', path, {'password': first})
            self.assertEqual((status, (body or {}).get('error')), (403, 'temp_password_expired'))
            self.root.ok('PATCH', profile, {'temp_password_expires_at': '2999-01-01T00:00:00Z'})
            # First sign-in: the temporary session is the proof, no current password needed.
            temporary.ok('POST', path, {'password': first})
            row = self.root.ok('GET', profile)[0]
            self.assertFalse(row['force_password_change'])
            self.assertIsNone(row['temp_password_expires_at'])
            # A password change may end the session that made it, so continue as a fresh sign-in.
            anonymous = API(self.data['url'], self.data['anon'])
            credentials = {'email': self.user('temporary')['email'], 'password': first}
            session = anonymous.ok('POST', '/auth/v1/token?grant_type=password', credentials)
            staff = API(self.data['url'], self.data['anon'], session['access_token'])
            # From now on the current password is mandatory and must be correct.
            status, body = staff.request('POST', path, {'password': second})
            self.assertEqual((status, (body or {}).get('error')), (400, 'current_password_required'))
            status, body = staff.request('POST', path, {'password': second, 'current_password': 'WrongTestOnly!9z'})
            self.assertEqual((status, (body or {}).get('error')), (403, 'current_password_invalid'))
            status, body = staff.request('POST', path, {'password': first, 'current_password': first})
            self.assertEqual((status, (body or {}).get('error')), (400, 'password_unchanged'))
            status, body = staff.request('POST', path, {'password': 'short', 'current_password': first})
            self.assertEqual((status, (body or {}).get('error')), (400, 'password_too_short'))
            status, body = staff.request('POST', path, ['not', 'an', 'object'])
            self.assertEqual((status, (body or {}).get('error')), (400, 'invalid_body'))
            # Succeeding with the old password as current_password also proves the rejections changed nothing.
            staff.ok('POST', path, {'password': second, 'current_password': first})
            self.assertNotEqual(anonymous.request('POST', '/auth/v1/token?grant_type=password', credentials)[0], 200)
            self.assertEqual(anonymous.request('POST', '/auth/v1/token?grant_type=password', {**credentials, 'password': second})[0], 200)
            self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.staff_password_changed&entity_id=eq.' + uid)), 2)
        finally:
            # Restore only this TEST_ONLY account's flag for the separate enforcement test.
            self.root.ok('PATCH', profile, {'force_password_change': True, 'temp_password_expires_at': None})

    def test_staff_password_change_requires_current_password(self):
        # A regular (non-temporary) staff session alone must not be enough to take over the account.
        courier = self.clients['courier']
        path = '/functions/v1/staff-change-password'
        new = 'TakeoverTestOnly!9a' + secrets.token_hex(8)
        status, body = courier.request('POST', path, {'password': new})
        self.assertEqual((status, (body or {}).get('error')), (400, 'current_password_required'))
        status, body = courier.request('POST', path, {'password': new, 'current_password': 'WrongTestOnly!9z'})
        self.assertEqual((status, (body or {}).get('error')), (403, 'current_password_invalid'))
        self.denied(self.clients['donor'], 'POST', path, {'password': new, 'current_password': self.user('donor')['password']})
        self.assertEqual(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.staff_password_changed&entity_id=eq.' + self.user('courier')['id']), [], 'Rejected attempts must not change the password')

    def test_edge_staff_creation_by_admin_is_atomic(self):
        admin = self.clients['admin']
        path = '/functions/v1/admin-create-staff'
        email = f'test-only-staff-{uuid.uuid4().hex[:12]}@example.test'
        payload = {'email': email, 'password': 'TestOnly!9a' + secrets.token_hex(8), 'role': 'courier', 'full_name': 'TEST_ONLY new courier', 'area_ids': [self.data['area_id']]}
        for broken, error in [({'area_ids': ['not-a-uuid']}, 'invalid_area'), ({'area_ids': [str(uuid.uuid4())]}, 'invalid_area'), ({'role': 'admin'}, 'invalid_role'), ({'full_name': 'x' * 121}, 'full_name_too_long'), ({'area_ids': [str(uuid.uuid4()) for _ in range(21)]}, 'too_many_areas')]:
            with self.subTest(error=error, broken=list(broken)):
                status, body = admin.request('POST', path, {**payload, **broken})
                self.assertEqual((status, (body or {}).get('error')), (400, error))
        self.assertEqual(self.root.ok('GET', '/rest/v1/profiles?staff_email=eq.' + email), [], 'Rejected requests must not leave an account behind')
        status, body = admin.request('POST', path, payload)
        self.assertEqual(status, 201, body)
        self.assertNotIn('message', body)
        row = self.root.ok('GET', '/rest/v1/profiles?id=eq.' + body['id'])[0]
        self.assertEqual((row['role'], row['staff_email'], row['force_password_change'], row['staff_created_by']), ('courier', email, True, self.user('admin')['id']))
        self.assertIsNotNone(row['temp_password_expires_at'])
        self.assertTrue(self.root.ok('GET', '/rest/v1/couriers?user_id=eq.' + body['id'])[0]['active'])
        areas = self.root.ok('GET', '/rest/v1/staff_area_assignments?user_id=eq.' + body['id'])
        self.assertEqual([(a['area_id'], a['is_primary']) for a in areas], [(self.data['area_id'], True)])
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.create_staff_account&entity_id=eq.' + body['id'])), 1)
        status, body = admin.request('POST', path, payload)
        self.assertIn(status, (400, 409), body)
        self.assertIn((body or {}).get('error'), ('email_exists', 'create_user_failed'))
        self.assertNotIn('message', body)
        # The provisioning function is not an API endpoint for signed-in users.
        self.denied(admin, 'POST', '/rest/v1/rpc/admin_finalize_staff_account', {'p_admin_id': self.user('admin')['id'], 'p_user_id': self.user('donor')['id'], 'p_email': 'test-only-x@example.test', 'p_full_name': 'TEST_ONLY', 'p_role': 'courier', 'p_area_ids': [self.data['area_id']]})
        self.assertEqual(self.root.ok('GET', '/rest/v1/profiles?select=role&id=eq.' + self.user('donor')['id'])[0]['role'], 'user')

    def test_failure_after_pickup_resumes_at_dropoff_and_completes(self):
        task, donation, need = self.delivery()
        args = {'p_delivery_id': task}
        courier, courier2 = self.clients['courier'], self.clients['courier2']
        failure = {**args, 'p_party': 'beneficiary', 'p_reason_code': 'no_answer', 'p_note': 'TEST_ONLY nobody home', 'p_latitude': None, 'p_longitude': None}
        # Before acceptance the courier declines instead of reporting a failure.
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_report_delivery_failure', failure)
        courier.rpc('courier_respond_delivery', {**args, 'p_accept': True})
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        self.assertTrue(courier.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'}))
        courier.rpc('courier_start_dropoff', args)
        self.clients['recipient'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'delivery'})
        self.denied(courier2, 'POST', '/rest/v1/rpc/courier_report_delivery_failure', failure)
        self.assertTrue(courier.rpc('courier_report_delivery_failure', failure))
        state = self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]
        self.assertEqual(state['status'], 'rescheduled')
        self.assertIsNotNone(state['picked_up_at'])
        for column in ('pickup_pin_hash', 'delivery_pin_hash', 'pickup_pin_expires_at', 'delivery_pin_expires_at'):
            self.assertIsNone(state[column], column)
        # Nothing is possible for the courier until an admin reassigns.
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_report_delivery_failure', failure)
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_start_dropoff', args)
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_respond_delivery', {**args, 'p_accept': True})
        self.denied(courier, 'POST', '/rest/v1/rpc/verify_delivery_pin', {**args, 'p_pin': '0000', 'p_kind': 'delivery'})
        self.denied(self.clients['recipient'], 'POST', '/rest/v1/rpc/user_issue_handoff_pin', {**args, 'p_kind': 'delivery'})
        paused = courier.rpc('courier_task_details', args)[0]
        for column in ('pickup_phone', 'pickup_description', 'dropoff_phone', 'dropoff_description', 'dropoff_latitude'):
            self.assertIsNone(paused[column], column)
        self.assertIn(task, {r['delivery_id'] for r in self.clients['admin'].rpc('admin_delivery_dispatch_queue')})
        self.clients['admin'].rpc('admin_reassign_delivery', {**args, 'p_courier_id': self.user('courier2')['id']})
        self.assertEqual(courier.rpc('courier_task_details', args), [])
        offered = courier2.rpc('courier_task_details', args)[0]
        self.assertEqual(offered['status'], 'assigned')
        self.assertIsNone(offered['pickup_area'], 'A collected item must not be offered as a new pickup')
        self.assertIsNotNone(offered['dropoff_area'])
        self.assertIsNone(offered['dropoff_phone'])
        self.assertEqual(courier2.rpc('courier_respond_delivery', {**args, 'p_accept': True}), 'picked_up')
        resumed = courier2.rpc('courier_task_details', args)[0]
        self.assertIsNone(resumed['pickup_phone'])
        self.assertIsNotNone(resumed['dropoff_phone'])
        self.denied(self.clients['donor'], 'POST', '/rest/v1/rpc/user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        courier2.rpc('courier_start_dropoff', args)
        pin = self.clients['recipient'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'delivery'})
        self.assertTrue(courier2.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'delivery'}))
        self.assertEqual(self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]['status'], 'delivered')
        self.assertEqual(self.root.ok('GET', '/rest/v1/needs?id=eq.' + need)[0]['status'], 'fulfilled')
        self.assertEqual(self.root.ok('GET', '/rest/v1/donations?id=eq.' + donation)[0]['status'], 'delivered')
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/delivery_failures?delivery_id=eq.' + task)), 1)

    def test_failure_before_pickup_resumes_at_pickup(self):
        task, _, _ = self.delivery()
        args = {'p_delivery_id': task}
        self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': True})
        self.denied(self.clients['courier'], 'POST', '/rest/v1/rpc/courier_report_delivery_failure', {**args, 'p_party': 'nobody', 'p_reason_code': 'not_present'})
        self.clients['courier'].rpc('courier_report_delivery_failure', {**args, 'p_party': 'donor', 'p_reason_code': 'not_present'})
        self.clients['admin'].rpc('admin_reassign_delivery', {**args, 'p_courier_id': self.user('courier2')['id']})
        self.assertEqual(self.clients['courier2'].rpc('courier_respond_delivery', {**args, 'p_accept': True}), 'heading_to_pickup')

    def test_admin_cancel_delivery_releases_both_records(self):
        admin = self.clients['admin']
        # Never collected: the donation is offered again.
        task, donation, need = self.delivery()
        args = {'p_delivery_id': task}
        cancel = {**args, 'p_reason': 'TEST_ONLY stuck delivery'}
        self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': True})
        for name in ('donor', 'courier', 'supervisor'):
            self.denied(self.clients[name], 'POST', '/rest/v1/rpc/admin_cancel_delivery', cancel)
        self.denied(admin, 'POST', '/rest/v1/rpc/admin_cancel_delivery', {**args, 'p_reason': ' '})
        admin.rpc('admin_cancel_delivery', cancel)
        state = self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]
        self.assertEqual((state['status'], state['courier_id']), ('failed', None))
        self.assertEqual(self.root.ok('GET', '/rest/v1/matches?id=eq.' + state['match_id'])[0]['status'], 'cancelled')
        self.assertEqual(self.root.ok('GET', '/rest/v1/donations?id=eq.' + donation)[0]['status'], 'available')
        self.assertEqual(self.root.ok('GET', '/rest/v1/needs?id=eq.' + need)[0]['status'], 'waiting')
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.cancel_delivery&entity_id=eq.' + task)), 1)
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/delivery_events?event_type=eq.delivery_cancelled&delivery_id=eq.' + task)), 1)
        # A closed delivery is final.
        self.assertEqual(self.message(admin, 'admin_cancel_delivery', cancel), 'delivery is already closed')
        self.denied(admin, 'POST', '/rest/v1/rpc/admin_reassign_delivery', {**args, 'p_courier_id': self.user('courier2')['id']})
        self.assertEqual(self.clients['courier'].rpc('courier_task_details', args), [])
        self.assertNotIn(task, {r['delivery_id'] for r in admin.rpc('admin_delivery_dispatch_queue')})
        self.assertNotIn(task, {r['entity_id'] for r in admin.rpc('admin_operations_overview', {'p_limit': 100})})
        # Both records can be matched again.
        other = self.create_item('needs', 'recipient')
        self.assertTrue(admin.rpc('admin_approve_match', {'p_donation_id': donation, 'p_need_id': other['id']}))
        # Already collected: the item goes to staff review instead of back to the donor.
        task, donation, need = self.delivery()
        args = {'p_delivery_id': task}
        self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': True})
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        self.assertTrue(self.clients['courier'].rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'}))
        admin.rpc('admin_cancel_delivery', {**args, 'p_reason': 'TEST_ONLY recipient unreachable'})
        self.assertEqual(self.root.ok('GET', '/rest/v1/donations?id=eq.' + donation)[0]['status'], 'under_review')
        self.assertEqual(self.root.ok('GET', '/rest/v1/needs?id=eq.' + need)[0]['status'], 'waiting')
        self.assertIn(donation, {r['donation_id'] for r in admin.rpc('admin_inventory_intake_candidates')})

    def test_unissued_or_expired_pin_does_not_flag_courier(self):
        task, _, _ = self.delivery()
        args = {'p_delivery_id': task}
        courier = self.clients['courier']
        flags = '/rest/v1/risk_flags?rule_code=eq.INVALID_DELIVERY_PIN&delivery_id=eq.' + task
        courier.rpc('courier_respond_delivery', {**args, 'p_accept': True})
        # No PIN has been issued yet: a refusal, but not misconduct.
        self.assertFalse(courier.rpc('verify_delivery_pin', {**args, 'p_pin': '1234', 'p_kind': 'pickup'}))
        self.assertEqual(self.root.ok('GET', flags), [])
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        wrong = '0000' if pin != '0000' else '0001'
        self.assertFalse(courier.rpc('verify_delivery_pin', {**args, 'p_pin': wrong, 'p_kind': 'pickup'}))
        self.assertEqual(len(self.root.ok('GET', flags)), 1)
        self.root.ok('PATCH', '/rest/v1/deliveries?id=eq.' + task, {'pickup_pin_expires_at': '2000-01-01T00:00:00Z'})
        self.assertFalse(courier.rpc('verify_delivery_pin', {**args, 'p_pin': pin, 'p_kind': 'pickup'}))
        self.assertEqual(len(self.root.ok('GET', flags)), 1, 'An expired PIN is not courier misconduct')
        self.assertEqual(self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]['status'], 'heading_to_pickup')

    def test_pin_hash_is_salted_per_delivery(self):
        # The stored hash covers the delivery id, so it is never the bare hash of a 4-digit PIN.
        import hashlib
        task, _, _ = self.delivery()
        args = {'p_delivery_id': task}
        self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': True})
        pin = self.clients['donor'].rpc('user_issue_handoff_pin', {**args, 'p_kind': 'pickup'})
        stored = self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]['pickup_pin_hash']
        self.assertRegex(stored, '^[0-9a-f]{64}$')
        self.assertNotEqual(stored, hashlib.sha256(pin.encode()).hexdigest())
        self.assertEqual(stored, hashlib.sha256((task + ':' + pin).encode()).hexdigest())

    def test_cash_pledges_are_limited_to_the_assigned_courier(self):
        task, donation, need = self.delivery()
        args = {'p_delivery_id': task}
        courier, courier2 = self.clients['courier'], self.clients['courier2']
        pledge = self.clients['donor'].ok('POST', '/rest/v1/contributions', {'user_id': self.user('donor')['id'], 'amount_yer': 2000, 'payment_method': 'cash_to_courier', 'donation_id': donation})[0]
        need_pledge = self.clients['recipient'].ok('POST', '/rest/v1/contributions', {'user_id': self.user('recipient')['id'], 'amount_yer': 1000, 'payment_method': 'cash_to_courier', 'need_id': need})[0]
        # Linked to the donation by somebody who is not its owner: never shown to a courier.
        foreign = self.clients['recipient'].ok('POST', '/rest/v1/contributions', {'user_id': self.user('recipient')['id'], 'amount_yer': 3000, 'payment_method': 'cash_to_courier', 'donation_id': donation})[0]
        self.denied(self.clients['donor'], 'POST', '/rest/v1/rpc/courier_delivery_cash_pledges', args)
        self.assertEqual(courier.rpc('courier_delivery_cash_pledges', args), [], 'Not visible before the courier accepts')
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_confirm_cash_pledge', {'p_contribution_id': pledge['id'], 'p_received': True})
        courier.rpc('courier_respond_delivery', {**args, 'p_accept': True})
        rows = courier.rpc('courier_delivery_cash_pledges', args)
        self.assertEqual({r['contribution_id'] for r in rows}, {pledge['id'], need_pledge['id']})
        mine = next(r for r in rows if r['contribution_id'] == pledge['id'])
        self.assertEqual((mine['public_code'], mine['amount_yer'], mine['courier_received']), (pledge['public_code'], 2000, None))
        self.assertEqual(courier2.rpc('courier_delivery_cash_pledges', args), [])
        self.denied(courier2, 'POST', '/rest/v1/rpc/courier_confirm_cash_pledge', {'p_contribution_id': pledge['id'], 'p_received': True})
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_confirm_cash_pledge', {'p_contribution_id': foreign['id'], 'p_received': True})
        courier.rpc('courier_confirm_cash_pledge', {'p_contribution_id': pledge['id'], 'p_received': True})
        courier.rpc('courier_confirm_cash_pledge', {'p_contribution_id': need_pledge['id'], 'p_received': False})
        answers = {r['contribution_id']: r['courier_received'] for r in courier.rpc('courier_delivery_cash_pledges', args)}
        self.assertEqual(answers, {pledge['id']: True, need_pledge['id']: False})
        stored = self.root.ok('GET', '/rest/v1/contributions?id=eq.' + pledge['id'])[0]
        self.assertEqual((stored['status'], stored['courier_confirmed_by']), ('pending', self.user('courier')['id']))
        self.assertIsNotNone(stored['courier_confirmed_at'])
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.courier_confirm_cash_pledge&entity_id=eq.' + pledge['id'])), 1)
        # Admins see the courier's answer; the pledger cannot rewrite it.
        seen = self.clients['admin'].ok('GET', '/rest/v1/contributions?select=id,courier_received,courier_confirmed_by&id=eq.' + pledge['id'])[0]
        self.assertTrue(seen['courier_received'])
        self.denied(self.clients['donor'], 'PATCH', '/rest/v1/contributions?id=eq.' + pledge['id'], {'courier_received': False})
        self.clients['admin'].rpc('admin_verify_contribution', {'p_contribution_id': pledge['id'], 'p_verified': True, 'p_note': 'TEST_ONLY'})
        self.assertNotIn(pledge['id'], {r['contribution_id'] for r in courier.rpc('courier_delivery_cash_pledges', args)})
        self.denied(courier, 'POST', '/rest/v1/rpc/courier_confirm_cash_pledge', {'p_contribution_id': pledge['id'], 'p_received': False})

    def test_service_offer_and_request_withdrawal(self):
        donor, recipient = self.clients['donor'], self.clients['recipient']
        offer = donor.ok('POST', '/rest/v1/service_offers', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY withdrawn offer', 'availability_mode': 'hours', 'available_hours': 2})[0]
        request = recipient.ok('POST', '/rest/v1/service_requests', {'public_code': self.code(), 'user_id': self.user('recipient')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY cancelled request', 'details': 'TEST_ONLY details'})[0]
        self.denied(recipient, 'POST', '/rest/v1/rpc/user_withdraw_service_offer', {'p_offer_id': offer['id']})
        self.denied(donor, 'POST', '/rest/v1/rpc/user_cancel_service_request', {'p_request_id': request['id']})
        donor.rpc('user_withdraw_service_offer', {'p_offer_id': offer['id']})
        recipient.rpc('user_cancel_service_request', {'p_request_id': request['id']})
        self.assertEqual(donor.ok('GET', '/rest/v1/service_offers?id=eq.' + offer['id'])[0]['status'], 'cancelled')
        self.assertEqual(recipient.ok('GET', '/rest/v1/service_requests?id=eq.' + request['id'])[0]['status'], 'cancelled')
        self.assertEqual(self.message(donor, 'user_withdraw_service_offer', {'p_offer_id': offer['id']}), 'service offer cannot be withdrawn')
        self.assertEqual(self.message(recipient, 'user_cancel_service_request', {'p_request_id': request['id']}), 'service request cannot be cancelled')
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.withdraw_service_offer&entity_id=eq.' + offer['id'])), 1)
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.cancel_service_request&entity_id=eq.' + request['id'])), 1)
        self.assertTrue(donor.ok('GET', '/rest/v1/user_notifications?entity_id=eq.' + offer['id']), 'The status notification trigger must still fire')
        # Once matched, withdrawal goes through the consent flow instead.
        offer = donor.ok('POST', '/rest/v1/service_offers', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY matched offer', 'availability_mode': 'hours', 'available_hours': 2})[0]
        request = recipient.ok('POST', '/rest/v1/service_requests', {'public_code': self.code(), 'user_id': self.user('recipient')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY matched request', 'details': 'TEST_ONLY details'})[0]
        self.clients['admin'].ok('PATCH', '/rest/v1/service_offers?id=eq.' + offer['id'], {'status': 'matched', 'verification_status': 'verified'})
        self.clients['admin'].ok('PATCH', '/rest/v1/service_requests?id=eq.' + request['id'], {'status': 'matched'})
        self.denied(donor, 'POST', '/rest/v1/rpc/user_withdraw_service_offer', {'p_offer_id': offer['id']})
        self.denied(recipient, 'POST', '/rest/v1/rpc/user_cancel_service_request', {'p_request_id': request['id']})

    def test_donation_image_paths_are_admin_only(self):
        donor = self.clients['donor']
        donation = self.create_item('donations', 'donor')
        path = self.upload_donation_image(donor, self.user('donor')['id'], donation['id'])
        # A recorded path outside the donor's own folder is never handed to a reviewer.
        donor.ok('POST', '/rest/v1/donation_images', {'donation_id': donation['id'], 'storage_path': self.user('recipient')['id'] + '/forged.png', 'sort_order': 1})
        args = {'p_donation_id': donation['id']}
        for name in ('donor', 'recipient', 'courier', 'supervisor'):
            self.denied(self.clients[name], 'POST', '/rest/v1/rpc/admin_donation_image_paths', args)
        self.assertEqual(self.clients['admin'].rpc('admin_donation_image_paths', args), [{'storage_path': path}])
        self.assertEqual(self.clients['recipient'].ok('GET', '/rest/v1/donation_images?donation_id=eq.' + donation['id']), [])
        self.assertEqual(len(self.clients['admin'].ok('GET', '/rest/v1/donation_images?donation_id=eq.' + donation['id'])), 2)
        sign = '/storage/v1/object/sign/donation-images/' + path
        code, body = self.clients['admin'].request('POST', sign, {'expiresIn': 600})
        self.assertEqual(code, 200, body)
        self.assertTrue(body.get('signedURL') or body.get('signedUrl'), body)
        for name in ('recipient', 'courier'):
            code, body = self.clients[name].request('POST', sign, {'expiresIn': 600})
            self.assertIn(code, (400, 401, 403, 404), f'{name} signed a private donation photo: {body}')

    def test_my_account_state_reports_restrictions(self):
        suspended = self.clients['suspended'].rpc('my_account_state')
        self.assertEqual(len(suspended), 1)
        self.assertEqual((suspended[0]['role'], suspended[0]['is_suspended'], suspended[0]['force_password_change']), ('user', True, False))
        admin = self.clients['admin'].rpc('my_account_state')[0]
        self.assertEqual((admin['role'], admin['is_suspended'], admin['deletion_status']), ('admin', False, None))
        self.assertEqual(self.clients['supervisor'].rpc('my_account_state')[0]['role'], 'supervisor')
        self.denied(API(self.data['url'], self.data['anon']), 'POST', '/rest/v1/rpc/my_account_state', {})

    def test_account_deletion_request_can_be_cancelled_or_rejected(self):
        user, admin = self.clients['recipient'], self.clients['admin']
        request = user.rpc('request_account_deletion')
        self.assertEqual(user.rpc('my_account_state')[0]['deletion_status'], 'pending')
        self.assertIn(request, {r['request_id'] for r in admin.rpc('admin_account_deletion_queue')})
        self.assertIn(request, {r['entity_id'] for r in admin.rpc('admin_operations_overview', {'p_limit': 100}) if r['action_key'] == 'account_deletions'})
        for name in ('donor', 'courier', 'supervisor'):
            self.denied(self.clients[name], 'POST', '/rest/v1/rpc/admin_account_deletion_queue', {})
        user.rpc('cancel_account_deletion_request')
        self.assertNotEqual(user.rpc('my_account_state')[0]['deletion_status'], 'pending')
        self.assertEqual(self.root.ok('GET', '/rest/v1/account_deletion_requests?id=eq.' + request), [])
        self.assertEqual(self.message(user, 'cancel_account_deletion_request', {}), 'no pending deletion request')
        # Rejection goes through the Edge Function and leaves the account untouched.
        request = user.rpc('request_account_deletion')
        path = '/functions/v1/admin-delete-account'
        self.denied(self.clients['donor'], 'POST', path, {'request_id': request, 'approve': False})
        status, body = admin.request('POST', path, {'request_id': 'not-a-uuid', 'approve': False})
        self.assertEqual((status, (body or {}).get('error')), (400, 'invalid_request_id'))
        status, body = admin.request('POST', path, {'request_id': request, 'approve': 'yes'})
        self.assertEqual((status, (body or {}).get('error')), (400, 'invalid_approve'))
        status, body = admin.request('POST', path, {'request_id': request, 'approve': False, 'note': 'TEST_ONLY keep account'})
        self.assertEqual((status, body), (200, {'ok': True, 'status': 'rejected'}))
        self.assertEqual(user.rpc('my_account_state')[0]['deletion_status'], 'rejected')
        status, body = admin.request('POST', path, {'request_id': request, 'approve': True})
        self.assertEqual((status, (body or {}).get('error')), (409, 'request_not_open'))
        row = self.root.ok('GET', '/rest/v1/profiles?id=eq.' + self.user('recipient')['id'])[0]
        self.assertEqual((row['full_name'], row['is_suspended']), ('TEST_ONLY recipient', False))

    def test_account_deletion_prepare_scrubs_user_and_keeps_other_parties(self):
        admin = self.clients['admin']
        victim = self.disposable_user('leaver')
        client, uid = victim['client'], victim['id']
        own = {'user_id': uid, 'category': 'furniture', 'item_type': 'TEST_ONLY leaving', 'address_id': victim['address_id']}
        offered = client.ok('POST', '/rest/v1/donations', own)[0]
        in_delivery = client.ok('POST', '/rest/v1/donations', own)[0]
        own_need = client.ok('POST', '/rest/v1/needs', own)[0]
        service = client.ok('POST', '/rest/v1/service_requests', {'public_code': self.code(), 'user_id': uid, 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY leaving', 'details': 'TEST_ONLY details'})[0]
        pledge = client.ok('POST', '/rest/v1/contributions', {'user_id': uid, 'amount_yer': 1000, 'payment_method': 'cash_to_courier', 'donation_id': offered['id']})[0]
        spare = self.root.ok('POST', '/rest/v1/addresses', {'user_id': uid, 'area': 'TEST_ONLY area', 'description': 'TEST_ONLY spare address', 'is_default': False})[0]
        image = self.upload_donation_image(client, uid, offered['id'])
        # Another person's need is waiting on an offer of the leaving user's donation.
        waiting = self.create_item('needs', 'recipient')
        offer = admin.rpc('admin_approve_match', {'p_donation_id': offered['id'], 'p_need_id': waiting['id']})
        # A second donation is already on its way to another person.
        scheduled = self.create_item('needs', 'recipient')
        match = admin.rpc('admin_approve_match', {'p_donation_id': in_delivery['id'], 'p_need_id': scheduled['id']})
        self.clients['recipient'].rpc('user_respond_match_offer', {'p_match_id': match, 'p_accept': True})
        task = admin.rpc('admin_create_delivery', {'p_match_id': match, 'p_courier_id': self.user('courier')['id']})[0]['delivery_id']

        request = client.rpc('request_account_deletion')
        queued = next(r for r in admin.rpc('admin_account_deletion_queue') if r['request_id'] == request)
        self.assertEqual((queued['user_id'], queued['full_name'], queued['status']), (uid, 'TEST_ONLY leaver', 'pending'))
        self.assertGreaterEqual(queued['open_operations'], 4)
        prepare = {'p_request_id': request, 'p_note': 'TEST_ONLY requested by user'}
        for name in ('donor', 'courier', 'supervisor'):
            self.denied(self.clients[name], 'POST', '/rest/v1/rpc/admin_prepare_account_deletion', prepare)
        self.denied(client, 'POST', '/rest/v1/rpc/admin_prepare_account_deletion', prepare)
        self.denied(admin, 'POST', '/rest/v1/rpc/admin_complete_account_deletion', {'p_request_id': request})
        # A delivery in progress blocks deletion until it is finished or cancelled.
        self.assertEqual(self.message(admin, 'admin_prepare_account_deletion', prepare), 'delivery in progress')
        self.assertEqual(self.root.ok('GET', '/rest/v1/profiles?id=eq.' + uid)[0]['full_name'], 'TEST_ONLY leaver')
        admin.rpc('admin_cancel_delivery', {'p_delivery_id': task, 'p_reason': 'TEST_ONLY account deletion'})

        result = admin.rpc('admin_prepare_account_deletion', prepare)
        self.assertEqual(result['user_id'], uid)
        self.assertIn(image, result['storage_paths'])
        self.assertTrue(all(p.startswith(uid + '/') for p in result['storage_paths']), result)

        profile = self.root.ok('GET', '/rest/v1/profiles?id=eq.' + uid)[0]
        self.assertEqual((profile['full_name'], profile['phone'], profile['is_suspended']), (None, None, True))
        for table, row in [('donations', offered), ('donations', in_delivery), ('needs', own_need), ('service_requests', service)]:
            self.assertEqual(self.root.ok('GET', '/rest/v1/' + table + '?id=eq.' + row['id'])[0]['status'], 'cancelled', table)
        self.assertEqual(self.root.ok('GET', '/rest/v1/contributions?id=eq.' + pledge['id'])[0]['status'], 'rejected')
        self.assertEqual(self.root.ok('GET', '/rest/v1/addresses?id=eq.' + spare['id']), [], 'Unreferenced addresses are removed')
        kept = self.root.ok('GET', '/rest/v1/addresses?id=eq.' + victim['address_id'])[0]
        for column in ('label', 'description', 'latitude', 'longitude'):
            self.assertIsNone(kept[column], column)
        self.assertEqual(self.root.ok('GET', '/rest/v1/user_notifications?user_id=eq.' + uid), [])
        # The other party keeps its records and gets its place in the queue back.
        self.assertEqual(self.root.ok('GET', '/rest/v1/matches?id=eq.' + offer)[0]['status'], 'cancelled')
        for other in (waiting, scheduled):
            row = self.root.ok('GET', '/rest/v1/needs?id=eq.' + other['id'])[0]
            self.assertEqual((row['status'], row['user_id']), ('waiting', self.user('recipient')['id']))
        self.assertIn('recipient', self.root.ok('GET', '/rest/v1/addresses?id=eq.' + self.user('recipient')['address_id'])[0]['description'])
        self.assertEqual(self.root.ok('GET', '/rest/v1/deliveries?id=eq.' + task)[0]['status'], 'failed')

        self.assertEqual(self.root.ok('GET', '/rest/v1/account_deletion_requests?id=eq.' + request)[0]['status'], 'processing')
        state = client.rpc('my_account_state')[0]
        self.assertEqual((state['is_suspended'], state['deletion_status']), (True, 'processing'))
        self.denied(client, 'POST', '/rest/v1/needs', own)
        self.denied(client, 'POST', '/rest/v1/rpc/cancel_account_deletion_request', {})
        self.denied(admin, 'POST', '/rest/v1/rpc/admin_reject_account_deletion', {'p_request_id': request, 'p_note': 'TEST_ONLY too late'})
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.prepare_account_deletion&entity_id=eq.' + uid)), 1)
        # Completion is refused while the user's photos still exist.
        self.assertEqual(self.message(admin, 'admin_complete_account_deletion', {'p_request_id': request}), 'storage objects remain')

    def test_admin_delete_account_function_completes_deletion(self):
        admin = self.clients['admin']
        victim = self.disposable_user('deleted')
        client, uid = victim['client'], victim['id']
        donation = client.ok('POST', '/rest/v1/donations', {'user_id': uid, 'category': 'furniture', 'item_type': 'TEST_ONLY deleted', 'address_id': victim['address_id']})[0]
        image = self.upload_donation_image(client, uid, donation['id'])
        request = client.rpc('request_account_deletion')
        path = '/functions/v1/admin-delete-account'
        payload = {'request_id': request, 'approve': True, 'note': 'TEST_ONLY approved'}
        for name in ('donor', 'courier', 'supervisor'):
            self.denied(self.clients[name], 'POST', path, payload)
        self.denied(client, 'POST', path, payload)
        self.assertEqual(self.root.ok('GET', '/rest/v1/account_deletion_requests?id=eq.' + request)[0]['status'], 'pending')
        status, body = admin.request('POST', path, payload)
        self.assertEqual((status, body), (200, {'ok': True, 'status': 'completed'}))
        row = self.root.ok('GET', '/rest/v1/account_deletion_requests?id=eq.' + request)[0]
        self.assertEqual(row['status'], 'completed')
        self.assertIsNotNone(row['completed_at'])
        profile = self.root.ok('GET', '/rest/v1/profiles?id=eq.' + uid)[0]
        self.assertEqual((profile['full_name'], profile['phone'], profile['is_suspended']), (None, None, True))
        # Operational history survives; personal content does not.
        self.assertEqual(self.root.ok('GET', '/rest/v1/donations?id=eq.' + donation['id'])[0]['status'], 'cancelled')
        self.assertEqual(self.root.ok('GET', '/rest/v1/donation_images?donation_id=eq.' + donation['id']), [])
        code, _ = self.root.request('GET', '/storage/v1/object/donation-images/' + image)
        self.assertIn(code, (400, 404), 'The photo must be removed from storage')
        login = API(self.data['url'], self.data['anon']).request('POST', '/auth/v1/token?grant_type=password', {'email': victim['email'], 'password': victim['password']})
        self.assertNotEqual(login[0], 200, 'A deleted account must not be able to sign in')
        self.assertEqual(len(self.root.ok('GET', '/rest/v1/audit_logs?action=eq.complete_account_deletion&entity_id=eq.' + uid)), 1)
        status, body = admin.request('POST', path, payload)
        self.assertEqual((status, (body or {}).get('error')), (409, 'request_not_open'))


class XMLResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.records = []
    def addSuccess(self, test):
        super().addSuccess(test)
        self.records.append((test.id(), 'pass', ''))
    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.records.append((test.id(), 'failure', self._exc_info_to_string(err, test)))
    def addError(self, test, err):
        super().addError(test, err)
        self.records.append((test.id(), 'error', self._exc_info_to_string(err, test)))
    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        if err is not None:
            self.records.append((subtest.id(), 'failure', self._exc_info_to_string(err, test)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bootstrap', action='store_true')
    args = parser.parse_args()
    runtime = os.environ['E2E_RUNTIME_FILE']
    if args.bootstrap:
        bootstrap(os.environ['E2E_STATUS_FILE'], runtime)
    else:
        started = time.time()
        result = unittest.TextTestRunner(verbosity=2, resultclass=XMLResult).run(unittest.defaultTestLoader.loadTestsFromTestCase(EndToEnd))
        suite = ET.Element('testsuite', name='localhost-auth-rest-storage', tests=str(len(result.records)), failures=str(len(result.failures)), errors=str(len(result.errors)), time=str(round(time.time() - started, 3)))
        properties = ET.SubElement(suite, 'properties')
        ET.SubElement(properties, 'property', name='test_methods', value=str(result.testsRun))
        for name, outcome, detail in result.records:
            case = ET.SubElement(suite, 'testcase', name=name)
            if outcome != 'pass':
                ET.SubElement(case, outcome).text = detail
        Path('test-results').mkdir(exist_ok=True)
        ET.ElementTree(suite).write('test-results/api.xml', encoding='utf-8', xml_declaration=True)
        sys.exit(0 if result.wasSuccessful() else 1)
