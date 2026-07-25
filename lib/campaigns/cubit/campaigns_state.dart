part of 'campaigns_cubit.dart';

abstract class CampaignsState {}

class CampaignsInitial extends CampaignsState {}

class CampaignsLoading extends CampaignsState {}

class CampaignsLoaded extends CampaignsState {
  final List<Group> groups;
  final List<Schedule> schedules;
  final List<Map<String, dynamic>> devices; // 🌟 قائمة الأجهزة المسجلة

  CampaignsLoaded({
    required this.groups, 
    required this.schedules, 
    required this.devices, // 🌟
  });
}

class CampaignsError extends CampaignsState {
  final String message;
  CampaignsError({required this.message});
}


// we fucked up