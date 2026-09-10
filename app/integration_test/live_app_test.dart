import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ruhamaa/src/app.dart';
import 'package:ruhamaa/src/features/contributions/contribution_screen.dart';
import 'package:ruhamaa/src/features/admin/delivery_assignment_screen.dart';

// Real app, real localhost Auth/REST. External Google consent and hardware are
// deliberately outside this desktop suite; no production URL can be supplied.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
  const donorEmail = String.fromEnvironment('DONOR_EMAIL');
  const donorPassword = String.fromEnvironment('DONOR_PASSWORD');
  const recipientEmail = String.fromEnvironment('RECIPIENT_EMAIL');
  const recipientPassword = String.fromEnvironment('RECIPIENT_PASSWORD');
  const adminEmail = String.fromEnvironment('ADMIN_EMAIL');
  const adminPassword = String.fromEnvironment('ADMIN_PASSWORD');
  const courierEmail = String.fromEnvironment('COURIER_EMAIL');
  const courierPassword = String.fromEnvironment('COURIER_PASSWORD');
  const supervisorEmail = String.fromEnvironment('SUPERVISOR_EMAIL');
  const supervisorPassword = String.fromEnvironment('SUPERVISOR_PASSWORD');

  setUpAll(() async {
    final parsed = Uri.parse(url);
    if (parsed.scheme != 'http' || !{'127.0.0.1', 'localhost'}.contains(parsed.host)) {
      throw StateError('TEST_ONLY: refusing non-loopback backend');
    }
    await Supabase.initialize(url: url, publishableKey: anon);
  });

  Future<void> settle(WidgetTester tester) async {
    // Do not wait for every animation: home includes decorative animation.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i > 15 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'Loading did not finish against the live local backend');
    // This label is an available reporting action, not a load-error message.
    expect(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('تعذر') && w.data != 'تعذر إكمال المهمة'), findsNothing,
        reason: 'An error UI is not a successful screen load');
  }

  Future<void> login(WidgetTester tester, String email, String password) async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (Supabase.instance.client.auth.currentUser?.email != email) {
      await Supabase.instance.client.auth.signOut();
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    }
    await tester.pumpWidget(ProviderScope(child: RuhamaaApp(key: UniqueKey())));
    await settle(tester);
  }

  Future<void> route(WidgetTester tester, String path) async {
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go(path);
    await settle(tester);
  }

  Future<void> refreshIfAvailable(WidgetTester tester) async {
    final refresh = find.byType(RefreshIndicator);
    if (refresh.evaluate().isNotEmpty) {
      var completed = false;
      Object? refreshError;
      final finished = tester.state<RefreshIndicatorState>(refresh.first).show().then(
        (_) { completed = true; },
        onError: (Object error) { refreshError = error; completed = true; },
      );
      for (var frame = 0; frame < 150 && !completed; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(completed, isTrue, reason: 'Refresh did not complete against localhost');
      await finished;
      expect(refreshError, isNull);
      await settle(tester);
    }
  }

  const userRoutes = <String, String>{
    '/home': 'HomeScreen',
    '/offers': 'MatchOffersScreen',
    '/handoffs': 'MyHandoffsScreen',
    '/account': 'AccountScreen',
    '/onboarding': 'OnboardingScreen',
    '/donate': 'CreateDonationV2Screen',
    '/need': 'CreateNeedV2Screen',
    '/verified-needs': 'NeedDiscoveryScreen',
    '/offer-service': 'CreatePersonalServiceOfferScreen',
    '/request-service': 'CreateServiceRequestScreen',
    '/my-services': 'MyServicesScreen',
    '/partners': 'PartnerHubV2Screen',
    '/legal': 'LegalScreen',
  };
  for (final entry in userRoutes.entries) {
    testWidgets('live user route ${entry.key}', (tester) async {
      await login(tester, donorEmail, donorPassword);
      await route(tester, entry.key);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == entry.value), findsOneWidget);
      await refreshIfAvailable(tester);
    });
  }

  testWidgets('live admin operations center', (tester) async {
    await login(tester, adminEmail, adminPassword);
    expect(find.text('لوحة إدارة رحماء'), findsOneWidget);
  });
  const adminTools = <String, String>{
    'التأهيل والمخزون': 'RecoveryInventoryScreen',
    'الاحتياجات الموثوقة': 'NeedDiscoveryAdminScreen',
    'مطابقة الأشياء': 'ItemMatchingV2Screen',
    'الوقت والمهارات': 'ServiceMatchingScreen',
    'جاهز للتوصيل': 'AcceptedMatchesScreen',
    'متابعة التوصيل': 'DeliveryOperationsScreen',
    'مراجعة المخاطر': 'RiskManagementScreen',
    'بلاغات الخدمات': 'ServiceIncidentManagementScreen',
    'شركاء رحماء': 'PartnerManagementScreen',
    'المساهمات التشغيلية': 'ContributionReviewScreen',
    'التقارير الأساسية': 'ReportsScreen',
    'المدن والمناطق': 'ServiceAreasScreen',
    'إضافة فريق': 'CreateStaffScreen',
    'المستخدمون والأدوار': 'UserManagementScreen',
  };
  for (final entry in adminTools.entries) {
    testWidgets('admin opens ${entry.value} from operations center', (tester) async {
      await login(tester, adminEmail, adminPassword);
      final tool = find.text(entry.key);
      await tester.scrollUntilVisible(tool, 400,
          scrollable: find.byType(Scrollable).first, maxScrolls: 100);
      await tester.pumpAndSettle();
      await tester.ensureVisible(tool);
      await tester.pumpAndSettle();
      expect(tool.hitTestable(), findsOneWidget);
      await tester.tap(tool);
      await settle(tester);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == entry.value), findsOneWidget);
      await refreshIfAvailable(tester);
    });
  }
  testWidgets('live courier tasks', (tester) async {
    await login(tester, courierEmail, courierPassword);
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'CourierTasksScreen'), findsOneWidget);
  });
  testWidgets('live supervisor dashboard', (tester) async {
    await login(tester, supervisorEmail, supervisorPassword);
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SupervisorHomeScreen'), findsOneWidget);
  });
  testWidgets('ordinary user cannot open admin screen', (tester) async {
    await login(tester, donorEmail, donorPassword);
    await route(tester, '/admin');
    expect(find.text('لوحة إدارة رحماء'), findsNothing);
  });
  testWidgets('contribution UI persists a pending contribution', (tester) async {
    await login(tester, donorEmail, donorPassword);
    final client = Supabase.instance.client;
    final before = await client.from('contributions').select('id').eq('user_id', client.auth.currentUser!.id);
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ContributionScreen()));
    await settle(tester);
    await tester.tap(find.text('1000 ريال'));
    await tester.pump();
    final submit = find.text('أسجّل رغبتي بالمساهمة بـ 1000 ريال');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await settle(tester);
    final after = await client.from('contributions').select('id,status').eq('user_id', client.auth.currentUser!.id);
    final previous = before.map((r) => r['id']).toSet();
    final added = after.where((r) => !previous.contains(r['id'])).toList();
    expect(added, hasLength(1));
    expect(added.single['status'], 'pending');
  });

  testWidgets('admin assigns and courier completes handoff through UI', (tester) async {
    final donor = SupabaseClient(url, anon);
    final recipient = SupabaseClient(url, anon);
    try {
      await donor.auth.signInWithPassword(email: donorEmail, password: donorPassword);
      await recipient.auth.signInWithPassword(email: recipientEmail, password: recipientPassword);
      final donorAddress = await donor.from('addresses').select('id').eq('user_id', donor.auth.currentUser!.id).limit(1).single();
      final recipientAddress = await recipient.from('addresses').select('id').eq('user_id', recipient.auth.currentUser!.id).limit(1).single();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final donation = await donor.from('donations').insert({'public_code': 'TEST_UI_D_$suffix', 'user_id': donor.auth.currentUser!.id, 'category': 'furniture', 'item_type': 'TEST_ONLY UI chair', 'address_id': donorAddress['id']}).select('id').single();
      final need = await recipient.from('needs').insert({'public_code': 'TEST_UI_N_$suffix', 'user_id': recipient.auth.currentUser!.id, 'category': 'furniture', 'item_type': 'TEST_ONLY UI chair', 'address_id': recipientAddress['id']}).select('id').single();
      await login(tester, adminEmail, adminPassword);
      final admin = Supabase.instance.client;
      final match = await admin.rpc('admin_approve_match', params: {'p_donation_id': donation['id'], 'p_need_id': need['id']});
      await recipient.rpc('user_respond_match_offer', params: {'p_match_id': match, 'p_accept': true});
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DeliveryAssignmentScreen(matchId: match as String)));
      await settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST_ONLY courier').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إرسال المهمة للموصل'));
      await settle(tester);
      expect(find.text('تم إنشاء مهمة التوصيل'), findsOneWidget);
      final task = await admin.from('deliveries').select('id,public_code,status').eq('match_id', match).single();
      await tester.tap(find.text('تم'));
      await settle(tester);
      await login(tester, courierEmail, courierPassword);
      final card = find.text(task['public_code'] as String);
      await tester.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await settle(tester);
      expect(find.text('777000001'), findsNothing);
      await tester.tap(find.byKey(const Key('courier-accept-assignment')));
      await settle(tester);
      for (final kind in ['pickup', 'delivery']) {
        if (kind == 'delivery') {
          await tester.tap(find.text('بدء التوجه للتسليم'));
          await settle(tester);
        }
        final owner = kind == 'pickup' ? donor : recipient;
        final pin = await owner.rpc('user_issue_handoff_pin', params: {'p_delivery_id': task['id'], 'p_kind': kind});
        final action = find.text(kind == 'pickup' ? 'تأكيد الاستلام بالرمز' : 'تأكيد التسليم بالرمز');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), pin as String);
        await tester.tap(find.text('تحقق'));
        for (var wait = 0; wait < 120; wait++) {
          await tester.pump(const Duration(milliseconds: 100));
          final finished = kind == 'pickup'
              ? find.text('بدء التوجه للتسليم').evaluate().isNotEmpty
              : find.byWidgetPredicate((w) => w.runtimeType.toString() == 'CourierTaskScreen').evaluate().isEmpty;
          if (finished) break;
        }
        await settle(tester);
      }
      final finalNeed = await recipient.from('needs').select('status').eq('id', need['id']).single();
      expect(finalNeed['status'], 'fulfilled');
    } finally {
      await donor.dispose();
      await recipient.dispose();
    }
  });
}
