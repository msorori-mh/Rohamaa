import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/delivery_repository.dart';
import '../auth/change_password_screen.dart';

class CourierTasksScreen extends StatefulWidget {
  const CourierTasksScreen({super.key});
  @override State<CourierTasksScreen> createState() => _CourierTasksScreenState();
}

class _CourierTasksScreenState extends State<CourierTasksScreen> {
  late Future<List<DeliveryTask>> _future;
  @override void initState(){super.initState();_reload();}
  void _reload(){_future=DeliveryRepository(Supabase.instance.client).myTasks();}

  Future<void> _openTask(DeliveryTask task) async {
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>CourierTaskScreen(task:task)));
    if(mounted)setState(_reload);
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('مهام التوصيل'),
      actions:[
        IconButton(tooltip:'تغيير كلمة المرور',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ChangePasswordScreen(role:'courier',requiredChange:false))),icon:const Icon(Icons.password_outlined)),
        IconButton(tooltip:'تسجيل الخروج',onPressed:()=>Supabase.instance.client.auth.signOut(),icon:const Icon(Icons.logout)),
      ],
    ),
    body:FutureBuilder<List<DeliveryTask>>(future:_future,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError)return Center(child:Text('تعذر تحميل المهام: ${snapshot.error}'));
      final tasks=snapshot.data??const[];
      if(tasks.isEmpty)return const Center(child:Text('لا توجد مهام حالياً'));
      return RefreshIndicator(onRefresh:()async=>setState(_reload),child:ListView.separated(padding:const EdgeInsets.all(16),itemCount:tasks.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,index){final task=tasks[index];return Card(child:ListTile(title:Text(task.publicCode),subtitle:Text(_statusLabel(task.status)),trailing:const Icon(Icons.chevron_left),onTap:()=>_openTask(task)));}));
    }),
  );

  static String _statusLabel(String s)=>switch(s){'assigned'=>'مهمة جديدة','heading_to_pickup'=>'في الطريق للاستلام','picked_up'=>'تم الاستلام','heading_to_recipient'=>'في الطريق للتسليم','rescheduled'=>'أعيدت الجدولة',_=>s};
}

class CourierTaskScreen extends StatefulWidget {
  const CourierTaskScreen({super.key,required this.task});
  final DeliveryTask task;
  @override State<CourierTaskScreen> createState()=>_CourierTaskScreenState();
}

class _CourierTaskScreenState extends State<CourierTaskScreen>{
  late Future<CourierTaskDetails> _details;
  bool _busy=false;
  @override void initState(){super.initState();_details=DeliveryRepository(Supabase.instance.client).details(widget.task.id);}

  Future<Position?> _position() async{
    var p=await Geolocator.checkPermission();
    if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
    if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return null;
    return Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high));
  }

  Future<void> _verify(CourierTaskDetails d) async{
    final pickup=d.status=='assigned'||d.status=='heading_to_pickup'||d.status=='rescheduled';
    final controller=TextEditingController();
    final pin=await showDialog<String>(context:context,builder:(context)=>AlertDialog(title:Text(pickup?'رمز الاستلام':'رمز التسليم'),content:TextField(controller:controller,keyboardType:TextInputType.number,maxLength:4,decoration:const InputDecoration(labelText:'PIN من 4 أرقام')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,controller.text.trim()),child:const Text('تحقق'))]));
    controller.dispose(); if(pin==null||pin.length!=4||!mounted)return;
    setState(()=>_busy=true);
    try{
      final pos=await _position();
      final ok=await DeliveryRepository(Supabase.instance.client).verifyPin(deliveryId:d.deliveryId,pin:pin,kind:pickup?'pickup':'delivery',latitude:pos?.latitude,longitude:pos?.longitude);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?(pickup?'تم تأكيد الاستلام':'تم تأكيد التسليم'):'الرمز غير صحيح')));
      if(ok){if(pickup){setState(()=>_details=DeliveryRepository(Supabase.instance.client).details(d.deliveryId));}else{Navigator.pop(context);}}
    }finally{if(mounted)setState(()=>_busy=false);}
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.task.publicCode)),body:FutureBuilder<CourierTaskDetails>(future:_details,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text('تعذر تحميل تفاصيل المهمة: ${s.error}'));final d=s.data!;final pickup=d.status=='assigned'||d.status=='heading_to_pickup'||d.status=='rescheduled';return ListView(padding:const EdgeInsets.all(20),children:[
    const Text('تظهر لك فقط البيانات اللازمة لتنفيذ المهمة. لا تظهر قصة الحالة أو هوية الطرف الآخر.',style:TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:20),
    _LocationCard(title:pickup?'موقع الاستلام':'موقع التسليم',area:pickup?d.pickupArea:d.dropoffArea,description:pickup?d.pickupDescription:d.dropoffDescription,phone:pickup?d.pickupPhone:d.dropoffPhone,latitude:pickup?d.pickupLatitude:d.dropoffLatitude,longitude:pickup?d.pickupLongitude:d.dropoffLongitude),
    const SizedBox(height:20),FilledButton.icon(onPressed:_busy?null:()=>_verify(d),icon:const Icon(Icons.pin_outlined),label:Text(_busy?'جارٍ التحقق...':pickup?'تأكيد الاستلام بالرمز':'تأكيد التسليم بالرمز'))
  ]);}));
}

class _LocationCard extends StatelessWidget{
  const _LocationCard({required this.title,this.area,this.description,this.phone,this.latitude,this.longitude});
  final String title;final String? area,description,phone;final double? latitude,longitude;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Text(area??'المنطقة غير محددة'),if(description?.isNotEmpty==true)Padding(padding:const EdgeInsets.only(top:6),child:Text(description!)),if(phone?.isNotEmpty==true)Padding(padding:const EdgeInsets.only(top:10),child:SelectableText('للتواصل التشغيلي عند الضرورة: $phone')),if(latitude!=null&&longitude!=null)Padding(padding:const EdgeInsets.only(top:10),child:SelectableText('GPS: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'))])));
}
