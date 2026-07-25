import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:android_id/android_id.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required CrmRepository repository})
      : _repository = repository,
        super(DashboardLoading());

  final CrmRepository _repository;
  final Telephony telephony = Telephony.instance;

  // ==========================================
  // 1. تحميل الإحصائيات والأجهزة
  // ==========================================
  Future<void> loadDashboard() async {
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      final logs = await _repository.getMessageLogs();

      final prefs = await SharedPreferences.getInstance();
      final isRunning = prefs.getBool('is_engine_running') ?? false;
      final currentDeviceId = prefs.getString('registered_device_id');

      // 🌟 جلب قائمة الأجهزة المرتبطة
      List<Map<String, dynamic>> devices =[];
      try {
        devices = await _repository.getRegisteredDevices();
      } catch (_) {}

      emit(DashboardLoaded(
        contactsCount: contacts.length,
        groupsCount: groups.length,
        schedulesCount: schedules.length,
        recentLogs: logs,
        isEngineRunning: isRunning,
        registeredDevices: devices, // 🌟 تمرير الأجهزة
        currentDeviceId: currentDeviceId, // 🌟 تمرير هوية هذا الجهاز
      ));
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'فشل تحميل البيانات: $e'));
      } else {
        // حالة نادرة جداً: فشل التحميل من أول مرة
        emit(DashboardLoaded(
          contactsCount: 0, groupsCount: 0, schedulesCount: 0, 
          recentLogs: [], registeredDevices: [], engineStatusMessage: 'فشل التحميل: $e'
        ));
      }
    }
  }

  // ==========================================
  // 2. تسجيل/فك ارتباط هذا الجهاز
  // ==========================================
  Future<void> toggleEngine({String? deviceName}) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      final isRunning = !currentState.isEngineRunning;

      emit(currentState.copyWith(
        engineStatusMessage: isRunning ? '🔄 جاري تسجيل الجهاز...' : '🛑 جاري فك الارتباط...',
        clearMessage: true,
      ));

      final prefs = await SharedPreferences.getInstance();

      if (isRunning && deviceName != null) {
        try {
          if (Platform.isAndroid) {
            final smsGranted = await telephony.requestPhoneAndSmsPermissions;
            if (smsGranted == null || !smsGranted) throw 'يجب الموافقة على صلاحية إرسال الـ SMS!';
          }

          FirebaseMessaging messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(alert: false, badge: false, sound: false, provisional: false);

          final fcmToken = await messaging.getToken();
          final String hardwareId = await const AndroidId().getId() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

          if (fcmToken != null) {
            final newDeviceId = await _repository.registerDevice(deviceName, fcmToken, hardwareId);
            if (newDeviceId != null) {
              await prefs.setString('registered_device_id', newDeviceId);
            }
          }

          await prefs.setBool('is_engine_running', true);
          await loadDashboard(); 

          if (state is DashboardLoaded) {
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: '📡 تم تسجيل الجهاز بنجاح!'));
          }

        } catch (e) {
          await prefs.setBool('is_engine_running', false);
          if (state is DashboardLoaded) {
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: '❌ فشل التسجيل: $e', isEngineRunning: false));
          }
        }
      } else {
        try {
          final existingId = prefs.getString('registered_device_id');
          if (existingId != null) {
            await _repository.removeDevice(existingId);
            await prefs.remove('registered_device_id'); 
          }
          await prefs.setBool('is_engine_running', false);
          await loadDashboard(); 

          if (state is DashboardLoaded) {
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: '🛑 تم فك ارتباط الهاتف بنجاح.', isEngineRunning: false));
          }
        } catch (e) {
          if (state is DashboardLoaded) {
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: '❌ فشل فك الارتباط: $e', isEngineRunning: true));
          }
        }
      }
    }
  }

  // ==========================================
  // 3. 🗑️ دالة حذف الأجهزة الشبحية (الأجهزة الأخرى)
  // ==========================================
  Future<void> removeLinkedDevice(String deviceId) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      emit(currentState.copyWith(engineStatusMessage: '🗑️ جاري حذف الجهاز...', clearMessage: true));

      try {
        await _repository.removeDevice(deviceId); // مسح من السحابة
        await loadDashboard(); // 🌟 إعادة تحميل القائمة
        
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: '✅ تم حذف الجهاز بنجاح!'));
        }
      } catch (e) {
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: '❌ فشل الحذف: $e'));
        }
      }
    }
  }

  // ==========================================
  // 4. المزامنة الذكية
  // ==========================================
  Future<void> syncDataToCloud() async {
  if (state is DashboardLoaded) {
    final currentState = state as DashboardLoaded;
    emit(currentState.copyWith(engineStatusMessage: '🔄 جاري المزامنة الذكية...', clearMessage: true));

  try {
        final wasDownloaded = await _repository.downloadIfCloudIsNewer();
        
        // 🌟 الرفع الدائم لضمان عدم ضياع سجلات الشبح
        await _repository.syncAllToCloud();
        
        await loadDashboard(); 
        
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: 
            wasDownloaded ? '✅ تمت المزامنة بنجاح (تنزيل ورفع)!' : '✅ تم رفع بياناتك للسحابة بنجاح!'
          ));
        }
      } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(engineStatusMessage: '❌ فشلت المزامنة: $e'));
      }
    }
  }
  }
}