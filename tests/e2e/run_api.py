"""Real Auth/REST/Storage regression tests, restricted to disposable localhost Supabase.

Only fixture provisioning uses service_role. Tests exercise real authenticated JWTs.
The CI job destroys the complete disposable stack in its always() cleanup step.
"""
import argparse
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
        payload = {'public_code': self.code(), 'user_id': self.user(owner)['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY chair', 'address_id': self.user(owner)['address_id']}
        payload.update(extra)
        return self.clients[owner].ok('POST', '/rest/v1/' + table, payload)[0]

    def delivery(self, courier='courier'):
        donation = self.create_item('donations', 'donor')
        need = self.create_item('needs', 'recipient')
        match = self.clients['admin'].rpc('admin_approve_match', {'p_donation_id': donation['id'], 'p_need_id': need['id']})
        self.clients['recipient'].rpc('user_respond_match_offer', {'p_match_id': match, 'p_accept': True})
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

    def test_item_initial_status_is_server_controlled(self):
        for table, owner, status in [('donations', 'donor', 'delivered'), ('needs', 'recipient', 'fulfilled')]:
            with self.subTest(table=table):
                response, body = self.clients[owner].request('POST', '/rest/v1/' + table, {'public_code': self.code(), 'user_id': self.user(owner)['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY', 'status': status})
                self.assertIn(response, (400, 401, 403), f'Client controlled initial status: {response}')

    def test_contribution_creation_and_idempotent_admin_verification(self):
        row = self.clients['donor'].ok('POST', '/rest/v1/contributions', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'amount_yer': 1000, 'payment_method': 'cash_to_courier'})[0]
        args = {'p_contribution_id': row['id'], 'p_verified': True, 'p_note': 'TEST_ONLY'}
        self.denied(self.clients['recipient'], 'POST', '/rest/v1/rpc/admin_verify_contribution', args)
        self.clients['admin'].rpc('admin_verify_contribution', args)
        before = self.root.ok('GET', '/rest/v1/audit_logs?entity_id=eq.' + row['id'])
        self.clients['admin'].rpc('admin_verify_contribution', args)
        after = self.root.ok('GET', '/rest/v1/audit_logs?entity_id=eq.' + row['id'])
        self.assertEqual(len(after), len(before))
        self.assertEqual(self.clients['donor'].ok('GET', '/rest/v1/contributions?id=eq.' + row['id'])[0]['status'], 'verified')

    def test_contribution_cannot_be_created_as_verified(self):
        self.denied(self.clients['donor'], 'POST', '/rest/v1/contributions', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'amount_yer': 1000, 'status': 'verified', 'verified_by': self.user('donor')['id']})

    def test_contribution_invalid_amount_is_rejected(self):
        self.denied(self.clients['donor'], 'POST', '/rest/v1/contributions', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'amount_yer': -1})

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
        task, _, _ = self.delivery()
        self.denied(self.clients['courier'], 'GET', '/rest/v1/deliveries?select=pickup_pin_hash,delivery_pin_hash&id=eq.' + task)

    def test_courier_decline_and_reassignment(self):
        task, _, _ = self.delivery()
        args = {'p_delivery_id': task}
        result = self.clients['courier'].rpc('courier_respond_delivery', {**args, 'p_accept': False, 'p_reason': 'unavailable'})
        self.assertEqual(result, 'rescheduled')
        self.clients['admin'].rpc('admin_reassign_delivery', {**args, 'p_courier_id': self.user('courier2')['id']})
        self.assertEqual(self.clients['courier'].rpc('courier_task_details', args), [])
        self.assertEqual(self.clients['courier2'].rpc('courier_respond_delivery', {**args, 'p_accept': True}), 'heading_to_pickup')

    def test_temporary_password_cannot_accept_delivery(self):
        task, _, _ = self.delivery('temporary')
        self.denied(self.clients['temporary'], 'POST', '/rest/v1/rpc/courier_respond_delivery', {'p_delivery_id': task, 'p_accept': True})

    def test_suspended_account_cannot_create_need(self):
        self.denied(self.clients['suspended'], 'POST', '/rest/v1/needs', {'public_code': self.code(), 'user_id': self.user('suspended')['id'], 'category': 'furniture', 'item_type': 'TEST_ONLY'})

    def test_service_offer_request_matching_and_consent(self):
        offer = self.clients['donor'].ok('POST', '/rest/v1/service_offers', {'public_code': self.code(), 'user_id': self.user('donor')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY plumbing', 'availability_mode': 'hours', 'available_hours': 2})[0]
        request = self.clients['recipient'].ok('POST', '/rest/v1/service_requests', {'public_code': self.code(), 'user_id': self.user('recipient')['id'], 'service_area_id': self.data['area_id'], 'category': 'plumbing', 'service_type': 'repair', 'title': 'TEST_ONLY repair', 'details': 'TEST_ONLY details'})[0]
        self.clients['admin'].ok('PATCH', '/rest/v1/service_offers?id=eq.' + offer['id'], {'status': 'approved', 'verification_status': 'verified'})
        match = self.clients['admin'].ok('POST', '/rest/v1/service_matches', {'service_offer_id': offer['id'], 'service_request_id': request['id'], 'approved_by': self.user('admin')['id']})[0]
        self.clients['donor'].rpc('user_respond_service_match', {'p_match_id': match['id'], 'p_accept': True})
        self.assertEqual(self.clients['recipient'].rpc('user_respond_service_match', {'p_match_id': match['id'], 'p_accept': True}), 'accepted')

    def test_partner_registration_and_unapproved_offer_rejection(self):
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

    def test_admin_queues_are_denied_to_regular_users(self):
        for rpc in ('admin_accepted_matches_queue', 'admin_delivery_dispatch_queue', 'admin_operations_overview'):
            with self.subTest(rpc=rpc):
                self.denied(self.clients['donor'], 'POST', '/rest/v1/rpc/' + rpc, {})
                self.assertIsInstance(self.clients['admin'].rpc(rpc), list)


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
        suite = ET.Element('testsuite', name='localhost-auth-rest-storage', tests=str(result.testsRun), failures=str(len(result.failures)), errors=str(len(result.errors)), time=str(round(time.time() - started, 3)))
        for name, outcome, detail in result.records:
            case = ET.SubElement(suite, 'testcase', name=name)
            if outcome != 'pass':
                ET.SubElement(case, outcome).text = detail
        Path('test-results').mkdir(exist_ok=True)
        ET.ElementTree(suite).write('test-results/api.xml', encoding='utf-8', xml_declaration=True)
        sys.exit(0 if result.wasSuccessful() else 1)
