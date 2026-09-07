import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/recovery_repository.dart';
import '../../domain/item_recovery_rules.dart';
import '../../theme/ruhamaa_theme.dart';

class RecoveryInventoryScreen extends StatefulWidget {
  const RecoveryInventoryScreen({super.key});
  @override State<RecoveryInventoryScreen> createState()=>_RecoveryInventoryScreenState();
}

class _RecoveryData {
  const _RecoveryData(this.summary,this.warehouses,this.incoming,this.queue);
  final RecoverySummary summary; final List<WarehouseItem> warehouses; final List<IntakeCandidate> incoming; final List<InventoryQueueItem> queue;
}

class _RecoveryInventoryScreenState extends State<RecoveryInventoryScreen> {
  late Future<_RecoveryData> _future;
  RecoveryRepository get _repo=>RecoveryRepository(Supabase.instance.client);
  @override void initState(){super.initState();_reload();}
  void _reload()=>_future=_load();
  Future<_RecoveryData> _load() async {
    final values=await Future.wait<dynamic>([_repo.summary(),_repo.warehouses(),_repo.intakeCandidates(),_repo.queue()]);
    return _RecoveryData(values[0] as RecoverySummary,values[1] as List<WarehouseItem>,values[2] as List<IntakeCandidate>,values[3] as List<InventoryQueueItem>);
  }
  Future<void> _run(Future<void> Function() action) async {
    try{await action();if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ الخطوة التشغيلية.')));setState(_reload);}}
    catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تنفيذ الخطوة: $error')));}
  }

  Future<void> _createWarehouse() async {
    final code=TextEditingController();final name=TextEditingController();final address=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('إضافة مستودع'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:code,decoration:const InputDecoration(labelText:'الرمز مثل MRB-01')),const SizedBox(height:10),TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المستودع')),const SizedBox(height:10),TextField(controller:address,maxLines:2,decoration:const InputDecoration(labelText:'وصف الموقع'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حفظ'))]));
    if(ok==true&&code.text.trim().length>=2&&name.text.trim().length>=3){await _run(()=>_repo.createWarehouse(code:code.text,name:name.text,addressNote:address.text));}
    code.dispose();name.dispose();address.dispose();
  }

  Future<void> _receive(IntakeCandidate item,List<WarehouseItem> warehouses) async {
    if(warehouses.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أنشئ مستودعًا نشطًا أولًا.')));return;}
    var warehouse=warehouses.first.id;final bin=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setDialog)=>AlertDialog(title:Text('استلام ${item.itemType}'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:warehouse,decoration:const InputDecoration(labelText:'المستودع'),items:warehouses.map((w)=>DropdownMenuItem(value:w.id,child:Text('${w.name} (${w.code})'))).toList(),onChanged:(value)=>setDialog(()=>warehouse=value??warehouse)),const SizedBox(height:10),TextField(controller:bin,decoration:const InputDecoration(labelText:'الرف/الموقع الداخلي — اختياري'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('تأكيد الاستلام'))])));
    if(ok==true)await _run(()=>_repo.receive(donationId:item.id,warehouseId:warehouse,binLocation:bin.text));bin.dispose();
  }

  Future<void> _inspect(InventoryQueueItem item) async {
    var grade='A';final note=TextEditingController();final cost=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setDialog)=>AlertDialog(title:const Text('نتيجة الفحص A–D'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:grade,decoration:const InputDecoration(labelText:'درجة الفحص'),items:ItemRecoveryRules.gradeLabels.entries.map((entry)=>DropdownMenuItem(value:entry.key,child:Text(entry.value))).toList(),onChanged:(value)=>setDialog(()=>grade=value??grade)),const SizedBox(height:10),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظة الفحص')),const SizedBox(height:10),if(grade=='B'||grade=='C')TextField(controller:cost,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'التكلفة التقديرية (ر.ي) — اختيارية'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('اعتماد التصنيف'))])));
    if(ok==true)await _run(()=>_repo.inspect(inventoryId:item.id,grade:grade,note:note.text,estimatedCostYer:int.tryParse(cost.text)));note.dispose();cost.dispose();
  }

  Future<void> _advanceWork(InventoryQueueItem item,String action) async {
    final cost=TextEditingController();final note=TextEditingController();
    final completing=action=='complete';
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(completing?'إكمال المعالجة':'بدء المعالجة'),content:Column(mainAxisSize:MainAxisSize.min,children:[if(completing)TextField(controller:cost,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'التكلفة الفعلية (ر.ي) — اختيارية')),if(completing)const SizedBox(height:10),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'ملاحظة تشغيلية — اختيارية'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(completing?'إكمال وإتاحة العطاء':'بدء العمل'))]));
    if(ok==true&&item.workOrderId!=null)await _run(()=>_repo.advanceWork(workOrderId:item.workOrderId!,action:action,actualCostYer:int.tryParse(cost.text),note:note.text));cost.dispose();note.dispose();
  }

  Future<void> _confirmRecycling(InventoryQueueItem item) async {
    final material=TextEditingController();final weight=TextEditingController();final proceeds=TextEditingController();final note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('تأكيد إعادة التدوير'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:material,decoration:const InputDecoration(labelText:'نوع المادة')),const SizedBox(height:10),TextField(controller:weight,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'الوزن بالكيلو — اختياري')),const SizedBox(height:10),TextField(controller:proceeds,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'العائد (ر.ي) — اختياري')),const SizedBox(height:10),TextField(controller:note,maxLines:2,decoration:const InputDecoration(labelText:'ملاحظة'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('تأكيد نهائي'))]));
    if(ok==true&&item.recyclingId!=null)await _run(()=>_repo.confirmRecycling(recyclingId:item.recyclingId!,materialType:material.text,weightKg:double.tryParse(weight.text),proceedsYer:int.tryParse(proceeds.text),note:note.text));material.dispose();weight.dispose();proceeds.dispose();note.dispose();
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('التأهيل والمخزون'),actions:[IconButton(onPressed:()=>setState(_reload),icon:const Icon(Icons.refresh_rounded),tooltip:'تحديث')]),body:FutureBuilder<_RecoveryData>(future:_future,builder:(context,snapshot){if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snapshot.hasError)return Center(child:Text('تعذر تحميل مسار التأهيل: ${snapshot.error}'));final data=snapshot.data!;return RefreshIndicator(onRefresh:()async=>setState(_reload),child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,16,16,40),children:[
    const _Intro(),const SizedBox(height:16),_Summary(summary:data.summary),const SizedBox(height:22),
    _Header(title:'المستودعات',actionLabel:'إضافة مستودع',onAction:_createWarehouse),const SizedBox(height:8),
    if(data.warehouses.isEmpty)const _Empty('لا يوجد مستودع بعد. أنشئ موقعًا قبل استلام الأشياء.') else ...data.warehouses.map((w)=>Card(child:ListTile(leading:const Icon(Icons.warehouse_outlined),title:Text(w.name),subtitle:Text(w.code),trailing:Icon(w.active?Icons.check_circle:Icons.pause_circle,color:w.active?RuhamaaColors.success:RuhamaaColors.textMuted)))),
    const SizedBox(height:22),const _Header(title:'وارد ينتظر الاستلام'),const SizedBox(height:8),
    if(data.incoming.isEmpty)const _Empty('لا توجد عطاءات جديدة تنتظر إدخال المخزون.') else ...data.incoming.map((item)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.move_to_inbox_outlined)),title:Text(item.itemType,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${item.code}${item.condition.isEmpty?'':' • ${item.condition}'}'),trailing:FilledButton(onPressed:()=>_receive(item,data.warehouses.where((w)=>w.active).toList()),child:const Text('استلام')))))),
    const SizedBox(height:22),const _Header(title:'طابور الفحص والمعالجة'),const SizedBox(height:8),
    if(data.queue.isEmpty)const _Empty('لا توجد أشياء داخل دورة التأهيل بعد.') else ...data.queue.map((item)=>_InventoryCard(item:item,onInspect:()=>_inspect(item),onStart:()=>_advanceWork(item,'start'),onComplete:()=>_advanceWork(item,'complete'),onRecycle:()=>_confirmRecycling(item))),
  ]));}));
}

class _Intro extends StatelessWidget{const _Intro();@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:RuhamaaColors.softGreen,borderRadius:BorderRadius.circular(18)),child:const Text('كل عطاء يُفحص قبل إعادة توزيعه: A جاهز، B تنظيف، C إصلاح، D تدوير. الغذاء والدواء خارج هذه المرحلة.',style:TextStyle(height:1.5,fontWeight:FontWeight.w700)));}
class _Summary extends StatelessWidget{const _Summary({required this.summary});final RecoverySummary summary;@override Widget build(BuildContext context)=>Wrap(spacing:8,runSpacing:8,children:[_Chip('فحص',summary.awaitingInspection),_Chip('تنظيف',summary.cleaning),_Chip('إصلاح',summary.repairing),_Chip('جاهز',summary.ready),_Chip('مُدوّر',summary.recycled),_Chip('تكلفة التأهيل',summary.repairCostYer,suffix:' ر.ي'),_Chip('عائد التدوير',summary.recyclingProceedsYer,suffix:' ر.ي')]);}
class _Chip extends StatelessWidget{const _Chip(this.label,this.value,{this.suffix=''});final String label;final int value;final String suffix;@override Widget build(BuildContext context)=>Chip(label:Text('$label: $value$suffix',style:const TextStyle(fontWeight:FontWeight.w800)));}
class _Header extends StatelessWidget{const _Header({required this.title,this.actionLabel,this.onAction});final String title;final String? actionLabel;final VoidCallback? onAction;@override Widget build(BuildContext context)=>Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900))),if(onAction!=null)TextButton.icon(onPressed:onAction,icon:const Icon(Icons.add),label:Text(actionLabel!))]);}
class _Empty extends StatelessWidget{const _Empty(this.text);final String text;@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Text(text,style:const TextStyle(color:RuhamaaColors.textMuted))));}
class _InventoryCard extends StatelessWidget{const _InventoryCard({required this.item,required this.onInspect,required this.onStart,required this.onComplete,required this.onRecycle});final InventoryQueueItem item;final VoidCallback onInspect,onStart,onComplete,onRecycle;@override Widget build(BuildContext context){final copy=ItemRecoveryRules.status(item.status);final action=switch(copy.nextAction){'inspect'=>(onInspect,'تسجيل الفحص'),'start_work'=>(onStart,'بدء المعالجة'),'complete_work'=>(onComplete,'إكمال المعالجة'),'confirm_recycling'=>(onRecycle,'تأكيد التدوير'),_=>(null,'')};return Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(item.itemType,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),Text('${item.code} • ${item.warehouseName}${item.binLocation.isEmpty?'':' • ${item.binLocation}'}',style:const TextStyle(color:RuhamaaColors.textMuted)),const SizedBox(height:10),Text(copy.label,style:const TextStyle(color:RuhamaaColors.primaryDark,fontWeight:FontWeight.w800)),if(item.grade.isNotEmpty)Text(ItemRecoveryRules.gradeLabels[item.grade]??item.grade,style:const TextStyle(color:RuhamaaColors.textMuted)),if(action.$1!=null)...[const SizedBox(height:12),FilledButton(onPressed:action.$1,child:Text(action.$2))]]))));}}
