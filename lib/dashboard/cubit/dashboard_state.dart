part of 'dashboard_cubit.dart';

abstract class DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int contactsCount;
  final int groupsCount;
  final int schedulesCount;
  final List<Message> recentLogs;
  final bool isEngineRunning;
  final String? engineStatusMessage;
  
  // 🌟 الحقول الجديدة لإدارة الأجهزة
  final List<Map<String, dynamic>> registeredDevices;
  final String? currentDeviceId;

  DashboardLoaded({
    required this.contactsCount,
    required this.groupsCount,
    required this.schedulesCount,
    required this.recentLogs,
    this.isEngineRunning = false,
    this.engineStatusMessage,
    required this.registeredDevices,
    this.currentDeviceId,
  });

  // 🌟 دالة مساعدة لتسهيل تحديث الحالة بشكل نظيف
  DashboardLoaded copyWith({
    int? contactsCount, 
    int? groupsCount, 
    int? schedulesCount, 
    List<Message>? recentLogs,
    bool? isEngineRunning, 
    String? engineStatusMessage, 
    List<Map<String, dynamic>>? registeredDevices, 
    String? currentDeviceId, 
    bool clearMessage = false,
  }) {
    return DashboardLoaded(
      contactsCount: contactsCount ?? this.contactsCount,
      groupsCount: groupsCount ?? this.groupsCount,
      schedulesCount: schedulesCount ?? this.schedulesCount,
      recentLogs: recentLogs ?? this.recentLogs,
      isEngineRunning: isEngineRunning ?? this.isEngineRunning,
      engineStatusMessage: clearMessage ? null : engineStatusMessage ?? this.engineStatusMessage,
      registeredDevices: registeredDevices ?? this.registeredDevices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
    );
  }
}