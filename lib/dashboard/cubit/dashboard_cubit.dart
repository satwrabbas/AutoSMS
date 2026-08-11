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

  Future<void> loadDashboard() async {
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      final logs = await _repository.getMessageLogs();
      final prefs = await SharedPreferences.getInstance();
      final isRunning = prefs.getBool('is_engine_running') ?? false;
      final currentDeviceId = prefs.getString('registered_device_id');

      List<Map<String, dynamic>> devices = [];
      try {
        devices = await _repository.getRegisteredDevices();
      } catch (_) {}

      emit(DashboardLoaded(
        contactsCount: contacts.length,
        groupsCount: groups.length,
        schedulesCount: schedules.length,
        recentLogs: logs,
        isEngineRunning: isRunning,
        registeredDevices: devices,
        currentDeviceId: currentDeviceId,
      ));
    } catch (e) {
      if (state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusLoadingFailed:$e'));
      } else {
        emit(DashboardLoaded(
          contactsCount: 0,
          groupsCount: 0,
          schedulesCount: 0,
          recentLogs: [],
          registeredDevices: [],
          engineStatusMessage: 'statusLoadingFailed:$e',
        ));
      }
    }
  }

  Future<void> toggleEngine({String? deviceName}) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      final isRunning = !currentState.isEngineRunning;
      emit(currentState.copyWith(
        engineStatusMessage: isRunning ? 'statusRegisteringDevice' : 'statusUnlinkingDevice',
        clearMessage: true,
      ));
      final prefs = await SharedPreferences.getInstance();
      if (isRunning && deviceName != null) {
        try {
          if (Platform.isAndroid) {
            final smsGranted = await telephony.requestPhoneAndSmsPermissions;
            if (smsGranted == null || !smsGranted) throw 'statusSmsPermissionRequired';
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
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusDeviceRegisteredSuccess'));
          }
        } catch (e) {
          await prefs.setBool('is_engine_running', false);
          if (state is DashboardLoaded) {
             final errStr = e.toString().startsWith('status') ? e.toString() : 'statusRegistrationFailed:$e';
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: errStr, isEngineRunning: false));
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
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusDeviceUnlinkedSuccess', isEngineRunning: false));
          }
        } catch (e) {
          if (state is DashboardLoaded) {
             emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusUnlinkFailed:$e', isEngineRunning: true));
          }
        }
      }
    }
  }

  Future<void> removeLinkedDevice(String deviceId) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      emit(currentState.copyWith(engineStatusMessage: 'statusDeletingDevice', clearMessage: true));
      try {
        await _repository.removeDevice(deviceId);
        await loadDashboard();
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusDeviceDeletedSuccess'));
        }
      } catch (e) {
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusDeleteFailed:$e'));
        }
      }
    }
  }

  Future<void> syncDataToCloud() async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      emit(currentState.copyWith(engineStatusMessage: 'statusSyncing', clearMessage: true));
      try {
        final wasDownloaded = await _repository.downloadIfCloudIsNewer();
        await _repository.syncAllToCloud();
        await loadDashboard(); 
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: 
            wasDownloaded ? 'statusSyncSuccessFull' : 'statusSyncSuccessUpload'
          ));
        }
      } catch (e) {
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(engineStatusMessage: 'statusSyncFailed:$e'));
        }
      }
    }
  }
}