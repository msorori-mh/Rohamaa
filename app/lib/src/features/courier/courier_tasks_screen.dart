import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/delivery_repository.dart';
import '../../domain/delivery_dispatch_rules.dart';
import '../auth/change_password_screen.dart';

class CourierTasksScreen extends StatefulWidget {
  const CourierTasksScreen({super.key});
  @override State<CourierTasksScreen> createState() => _CourierTasksScreenState();
}

class _CourierTasksScreenState extends State<CourierTasksScreen> {
  late Future<List<DeliveryTask>> _future;
  RealtimeChannel? _channel;
  @override
  void initState() {
    super.initState();
    _reload();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _channel = Supabase.instance.client
          .channel('courier-deliveries-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'courier_id', value: userId),
            callback: (_) {
              if (mounted) setState(_reload);
            },
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }
  void _reload() => _future = DeliveryRepository(Supabase.instance.client).myTasks();
  Future<void> _openTask(DeliveryTask task) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CourierTaskScreen(task: task)));
    if (mounted) setState(_reload);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مهام التوصيل'), actions: [
      IconButton(tooltip: 'تغيير كلمة المرور', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen(role: 'courier', requiredChange: false))), icon: const Icon(Icons.password_outlined)),
      IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
    ]),
    body: FutureBuilder<List<DeliveryTask>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المهام. تحقق من اتصالك وحاول مجددًا.'));
      final tasks = snapshot.data ?? const [];
      if (tasks.isEmpty) return const Center(child: Text('لا توجد مهام حاليًا.'));
      return RefreshIndicator(onRefresh: () async => setState(_reload), child: ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: tasks.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) { final task = tasks[index]; final pending = DeliveryDispatchRules.canRespond(task.status); return Card(child: ListTile(
          leading: Icon(pending ? Icons.notification_important_outlined : Icons.delivery_dining_outlined), title: Text(task.publicCode),
          subtitle: Text(DeliveryDispatchRules.statusLabel(task.status)), trailing: const Icon(Icons.chevron_left), onTap: () => _openTask(task),
        )); },
      ));
    }),
  );
}

class CourierTaskScreen extends StatefulWidget {
  const CourierTaskScreen({super.key, required this.task});
  final DeliveryTask task;
  @override State<CourierTaskScreen> createState() => _CourierTaskScreenState();
}

class _CourierTaskScreenState extends State<CourierTaskScreen> {
  late Future<CourierTaskDetails> _details;
  bool _busy = false;
  DeliveryRepository get _repo => DeliveryRepository(Supabase.instance.client);
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _details = _repo.details(widget.task.id);

  Future<Position?> _position() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Location is optional evidence; unavailable GPS must not block handoff.
      return null;
    }
  }

  Future<void> _accept(CourierTaskDetails details) => _run(
    () => _repo.respond(deliveryId: details.deliveryId, accept: true),
    success: 'تم قبول المهمة. يمكنك الآن التوجه إلى موقع الاستلام.',
  );

  Future<void> _reject(CourierTaskDetails details) async {
    var reason = 'unavailable';
    final confirmed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('الاعتذار عن المهمة؟'),
      content: DropdownButtonFormField<String>(initialValue: reason, decoration: const InputDecoration(labelText: 'سبب الاعتذار'), items: const [
        DropdownMenuItem(value: 'unavailable', child: Text('غير متاح الآن')),
        DropdownMenuItem(value: 'too_far', child: Text('الموقع بعيد')),
        DropdownMenuItem(value: 'vehicle_issue', child: Text('مشكلة في وسيلة النقل')),
        DropdownMenuItem(value: 'schedule_conflict', child: Text('تعارض في الوقت')),
        DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
      ], onChanged: (value) => setDialogState(() => reason = value ?? reason)),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد الاعتذار'))],
    )));
    if (confirmed != true || !mounted) return;
    await _run(() => _repo.respond(deliveryId: details.deliveryId, accept: false, reason: reason), success: 'تم إرسال اعتذارك، وستعود المهمة إلى فريق رحماء لإسنادها.', closeAfter: true);
  }

  Future<void> _verifyPin(CourierTaskDetails details, {required bool pickup}) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(pickup ? 'رمز الاستلام' : 'رمز التسليم'),
      content: TextField(controller: controller, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'أدخل الرمز المكوّن من 4 أرقام')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('تحقق'))],
    ));
    controller.dispose();
    if (pin == null || !RegExp(r'^\d{4}$').hasMatch(pin) || !mounted) return;
    setState(() => _busy = true);
    try {
      final position = await _position();
      final valid = await _repo.verifyPin(deliveryId: details.deliveryId, pin: pin, kind: pickup ? 'pickup' : 'delivery', latitude: position?.latitude, longitude: position?.longitude);
      if (!mounted) return;
      if (!valid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز غير صحيح أو انتهت صلاحيته أو محاولاته. اطلب رمزًا جديدًا.'))); return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pickup ? 'تم تأكيد الاستلام.' : 'تم تأكيد التسليم واكتملت المهمة.')));
      if (pickup) { setState(_reload); } else { Navigator.pop(context); }
    } catch (error) {
      debugPrint('Delivery PIN verification failed: $error');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر التحقق من الرمز. حاول مرة أخرى.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _startDropoff(CourierTaskDetails details) => _run(() => _repo.startDropoff(details.deliveryId), success: 'تم بدء مرحلة التسليم.');

  Future<void> _reportProblem(CourierTaskDetails details) async {
    var party = 'other'; var reason = 'other'; final note = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('تعذر إكمال المهمة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: party, decoration: const InputDecoration(labelText: 'الطرف المرتبط'), items: const [
          DropdownMenuItem(value: 'donor', child: Text('المتبرع')), DropdownMenuItem(value: 'beneficiary', child: Text('صاحب الطلب')),
          DropdownMenuItem(value: 'courier', child: Text('الموصل')), DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
        ], onChanged: (value) => setDialogState(() => party = value ?? party)), const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: reason, decoration: const InputDecoration(labelText: 'ما الذي حدث؟'), items: const [
          DropdownMenuItem(value: 'no_answer', child: Text('لا يوجد رد')), DropdownMenuItem(value: 'not_present', child: Text('الشخص غير موجود')),
          DropdownMenuItem(value: 'wrong_address', child: Text('العنوان غير صحيح')), DropdownMenuItem(value: 'item_not_ready', child: Text('التبرع غير جاهز')),
          DropdownMenuItem(value: 'item_rejected', child: Text('لم يتم قبول التبرع')), DropdownMenuItem(value: 'vehicle_issue', child: Text('مشكلة في وسيلة النقل')),
          DropdownMenuItem(value: 'weather', child: Text('حالة الطقس')), DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
        ], onChanged: (value) => setDialogState(() => reason = value ?? reason)), const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظة مختصرة — اختيارية')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال للفريق'))],
    )));
    if (confirmed != true || !mounted) { note.dispose(); return; }
    final position = await _position();
    await _run(() => _repo.reportFailure(deliveryId: details.deliveryId, party: party, reasonCode: reason, note: note.text.trim().isEmpty ? null : note.text.trim(), latitude: position?.latitude, longitude: position?.longitude), success: 'وصل البلاغ إلى الفريق لإعادة التنسيق.', closeAfter: true);
    note.dispose();
  }

  Future<void> _run(Future<Object?> Function() action, {required String success, bool closeAfter = false}) async {
    setState(() => _busy = true);
    try {
      await action(); if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      if (closeAfter) { Navigator.pop(context); } else { setState(_reload); }
    } catch (error) {
      debugPrint('Courier dispatch action failed: $error');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنفيذ الإجراء. حدّث المهمة وحاول مجددًا.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.task.publicCode)), body: FutureBuilder<CourierTaskDetails>(future: _details, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return const Center(child: Text('تعذر تحميل تفاصيل المهمة. حدّث الصفحة وحاول مجددًا.'));
    final details = snapshot.data!;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(DeliveryDispatchRules.statusLabel(details.status), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      const Text('تظهر لك البيانات الضرورية لكل مرحلة فقط.'), const SizedBox(height: 20),
      if (DeliveryDispatchRules.canRespond(details.status)) ...[
        _LocationCard(title: 'منطقة الاستلام', area: details.pickupArea), const SizedBox(height: 16),
        FilledButton.icon(key: const Key('courier-accept-assignment'), onPressed: _busy ? null : () => _accept(details), icon: const Icon(Icons.check_rounded), label: const Text('قبول المهمة')), const SizedBox(height: 8),
        OutlinedButton.icon(key: const Key('courier-reject-assignment'), onPressed: _busy ? null : () => _reject(details), icon: const Icon(Icons.close_rounded), label: const Text('الاعتذار عن المهمة')),
      ] else if (DeliveryDispatchRules.canVerifyPickup(details.status)) ...[
        _LocationCard(title: 'موقع الاستلام', area: details.pickupArea, description: details.pickupDescription, phone: details.pickupPhone, latitude: details.pickupLatitude, longitude: details.pickupLongitude), const SizedBox(height: 16),
        FilledButton.icon(onPressed: _busy ? null : () => _verifyPin(details, pickup: true), icon: const Icon(Icons.pin_outlined), label: Text(_busy ? 'جارٍ التحقق...' : 'تأكيد الاستلام بالرمز')),
        _ProblemButton(busy: _busy, onPressed: () => _reportProblem(details)),
      ] else if (DeliveryDispatchRules.canStartDropoff(details.status)) ...[
        _LocationCard(title: 'موقع التسليم', area: details.dropoffArea, description: details.dropoffDescription, phone: details.dropoffPhone, latitude: details.dropoffLatitude, longitude: details.dropoffLongitude), const SizedBox(height: 16),
        FilledButton.icon(onPressed: _busy ? null : () => _startDropoff(details), icon: const Icon(Icons.route_outlined), label: const Text('بدء التوجه للتسليم')),
        _ProblemButton(busy: _busy, onPressed: () => _reportProblem(details)),
      ] else if (DeliveryDispatchRules.canVerifyDropoff(details.status)) ...[
        _LocationCard(title: 'موقع التسليم', area: details.dropoffArea, description: details.dropoffDescription, phone: details.dropoffPhone, latitude: details.dropoffLatitude, longitude: details.dropoffLongitude), const SizedBox(height: 16),
        FilledButton.icon(onPressed: _busy ? null : () => _verifyPin(details, pickup: false), icon: const Icon(Icons.pin_outlined), label: Text(_busy ? 'جارٍ التحقق...' : 'تأكيد التسليم بالرمز')),
        _ProblemButton(busy: _busy, onPressed: () => _reportProblem(details)),
      ] else if (DeliveryDispatchRules.waitsForAdmin(details.status))
        const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('وصلت المشكلة إلى فريق رحماء. انتظر إعادة تنسيق المهمة.'))),
    ]);
  }));
}

class _ProblemButton extends StatelessWidget {
  const _ProblemButton({required this.busy, required this.onPressed});
  final bool busy; final VoidCallback onPressed;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8), child: TextButton.icon(onPressed: busy ? null : onPressed, icon: const Icon(Icons.report_problem_outlined), label: const Text('تعذر إكمال المهمة')));
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.title, this.area, this.description, this.phone, this.latitude, this.longitude});
  final String title; final String? area, description, phone; final double? latitude, longitude;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), Text(area ?? 'المنطقة غير محددة'),
    if (description?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 6), child: Text(description!)),
    if (phone?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 10), child: SelectableText('للتواصل عند الحاجة: $phone')),
    if (latitude != null && longitude != null) Padding(padding: const EdgeInsets.only(top: 10), child: SelectableText('الموقع: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}')),
  ])));
}
