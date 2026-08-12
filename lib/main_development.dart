import 'dart:ui'; 
import 'package:flutter/widgets.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; 
import 'package:crm_repository/crm_repository.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:auto_sms/app/app.dart';
import 'package:auto_sms/app/config/env_config.dart'; // 🌟 Added EnvConfig import
import 'package:auto_sms/bootstrap.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:auto_sms/firebase_options.dart';
import 'package:drift/drift.dart' as drift;
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';

// ==========================================
// BACKGROUND FCM MESSAGE HANDLER FOR SILENT DISPATCHING.
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized(); 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 1. إيقاف تحذيرات Drift لكي لا ترتبك قاعدة البيانات عند فتح التطبيق
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2. تهيئة Supabase في الخلفية باستخدام EnvConfig 🔑
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // 🌟 جديد: إجبار الشبح على انتظار استعادة جلسة المستخدم (بحد أقصى 5 ثوانٍ)
  int waitCount = 0;
  while (Supabase.instance.client.auth.currentUser == null && waitCount < 10) {
    await Future.delayed(const Duration(milliseconds: 500));
    waitCount++;
  }

  try {
    final data = message.data;
    final String? groupId = data['group_id']?.toString(); 
    final String? smsBody = data['message']?.toString();

    if (groupId == null || smsBody == null) return;

    // 3. تجهيز الأدوات (القاعدة المحلية + عميل السحابة + المدير + الـ SMS)
    final database = AppDatabase();
    final cloudClient = CloudStorageClient();
    final repository = CrmRepository(localStorage: database, cloudStorage: cloudClient);
    final telephony = Telephony.instance;

    final allContacts = await database.getAllContacts();
    final targetContacts = allContacts.where((c) => c.groupId == groupId).toList();

    if (targetContacts.isEmpty) return;

    print("🚀 جاري إرسال [$smsBody] إلى ${targetContacts.length} عميل...");

    const uuid = Uuid(); 

    for (var contact in targetContacts) {
      bool isSent = false;
      int retryCount = 0;
      const int maxRetries = 3; 

      // 🌟 حلقة الإرسال 
      while (!isSent && retryCount < maxRetries) {
        try {
          print("➤ محاولة إرسال SMS للرقم ${contact.phone}...");
          telephony.sendSms(to: contact.phone, message: smsBody);
          isSent = true; 
        } catch (e) {
          retryCount++;
          print("⚠️ فشل الإرسال (المحاولة $retryCount من $maxRetries): $e");
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(seconds: 5)); 
          }
        }
      }

      // 🌟 محاولة الحفظ في قاعدة البيانات المحلية
      try {
        await database.insertMessage(MessagesCompanion(
          id: drift.Value(uuid.v4()),
          phone: drift.Value(contact.phone),
          body: drift.Value(isSent ? smsBody : "❌ فشل الإرسال: $smsBody"),
          type: drift.Value(isSent ? 'sent_auto_fcm' : 'failed_auto_fcm'),
          messageDate: drift.Value(DateTime.now()),
        ));
        print("✅ تم كتابة السجل في قاعدة البيانات للرقم: ${contact.phone}");
      } catch (dbError) {
        print("⚠️ تم الإرسال ولكن تعذر الحفظ محلياً: $dbError");
      }

      await Future.delayed(const Duration(seconds: 1)); 
    }

    // 🌟 4. المزامنة الصامتة في الخلفية!
    print("☁️ جاري رفع سجلات الإرسال الجديدة إلى السحابة...");
    try {
      await repository.syncAllToCloud();
      print("✅ تم رفع السجلات للسحابة بنجاح!");
    } catch (syncError) {
      print("⚠️ تعذر الرفع للسحابة، سيتم الرفع لاحقاً عند فتح التطبيق: $syncError");
    }

  } catch (e) {
    print("❌ حدث خطأ جذري في مهمة الخلفية: $e");
  }
}

// ==========================================
// 🚀 نقطة انطلاق التطبيق (Main)
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة فايربيس
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. تسجيل دالة الاستماع في الخلفية (عند إغلاق التطبيق)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. تسجيل دالة الاستماع في الواجهة (والتطبيق مفتوح)
  FirebaseMessaging.onMessage.listen((message) {
    print('🔔 إشارة وصلت والتطبيق مفتوح!');
    _firebaseMessagingBackgroundHandler(message);
  });

  // 4. تهيئة Supabase باستخدام EnvConfig 🔑
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  final database = AppDatabase();
  final cloudClient = CloudStorageClient();

  bootstrap(() => App(
    database: database,
    cloudClient: cloudClient, 
  ));
}