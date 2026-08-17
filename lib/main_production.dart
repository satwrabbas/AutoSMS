import 'dart:ui'; 
import 'package:flutter/widgets.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; 
import 'package:crm_repository/crm_repository.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:auto_sms/app/app.dart';
import 'package:auto_sms/app/config/env_config.dart';
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
  
  // 🌟 1. Prevent duplicate Firebase initialization in background isolate
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      print("⚠️ Background Firebase init error: $e");
    }
  }

  // 2. Stop Drift warnings during background execution
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 3. Initialize Supabase in background isolate
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
  } catch (_) {
    // Already initialized in isolate
  }

  // 🌟 Wait for user auth session recovery (max 5 seconds)
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

    // Setup local database, cloud client, and repository
    final database = AppDatabase();
    final cloudClient = CloudStorageClient();
    final repository = CrmRepository(localStorage: database, cloudStorage: cloudClient);
    final telephony = Telephony.instance;

    final allContacts = await database.getAllContacts();
    final targetContacts = allContacts.where((c) => c.groupId == groupId).toList();

    if (targetContacts.isEmpty) return;

    print("🚀 Sending [$smsBody] to ${targetContacts.length} contacts...");

    const uuid = Uuid(); 

    for (var contact in targetContacts) {
      bool isSent = false;
      int retryCount = 0;
      const int maxRetries = 3; 

      while (!isSent && retryCount < maxRetries) {
        try {
          print("➤ Attempting SMS to ${contact.phone}...");
          telephony.sendSms(to: contact.phone, message: smsBody);
          isSent = true; 
        } catch (e) {
          retryCount++;
          print("⚠️ Send failed (Attempt $retryCount of $maxRetries): $e");
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(seconds: 5)); 
          }
        }
      }

      // Save log to local database
      try {
        await database.insertMessage(MessagesCompanion(
          id: drift.Value(uuid.v4()),
          phone: drift.Value(contact.phone),
          body: drift.Value(isSent ? smsBody : "❌ Send failed: $smsBody"),
          type: drift.Value(isSent ? 'sent_auto_fcm' : 'failed_auto_fcm'),
          messageDate: drift.Value(DateTime.now()),
        ));
        print("✅ Log saved locally for: ${contact.phone}");
      } catch (dbError) {
        print("⚠️ Failed to save log locally: $dbError");
      }

      await Future.delayed(const Duration(seconds: 1)); 
    }

    // Silent Cloud Sync
    print("☁️ Syncing logs to cloud...");
    try {
      await repository.syncAllToCloud();
      print("✅ Logs synced to cloud successfully!");
    } catch (syncError) {
      print("⚠️ Cloud sync failed, will sync next time app opens: $syncError");
    }

  } catch (e) {
    print("❌ Fatal error in background task: $e");
  }
}

// ==========================================
// 🚀 Main Entry Point
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌟 1. Prevent [core/duplicate-app] error on startup
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("⚠️ Firebase initialization warning: $e");
  }

  // 2. Register background listener
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Register foreground listener
  FirebaseMessaging.onMessage.listen((message) {
    print('🔔 Signal received while app is in foreground!');
    _firebaseMessagingBackgroundHandler(message);
  });

  // 4. Initialize Supabase safely
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
  } catch (e) {
    print("⚠️ Supabase initialization warning: $e");
  }

  final database = AppDatabase();
  final cloudClient = CloudStorageClient();

  bootstrap(() => App(
    database: database,
    cloudClient: cloudClient, 
  ));
}