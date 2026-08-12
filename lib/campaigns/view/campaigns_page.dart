import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:auto_sms/l10n/l10n.dart';
import '../cubit/campaigns_cubit.dart';

class CampaignsPage extends StatelessWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CampaignsCubit(
        repository: context.read<CrmRepository>(),
      )..loadCampaignsData(),
      child: const CampaignsView(),
    );
  }
}

class CampaignsView extends StatelessWidget {
  const CampaignsView({super.key});

  String _getLocalizedCampaignError(BuildContext context, String rawError) {
    final l10n = context.l10n;
    if (rawError.startsWith('errLoadCampaignsData:')) {
      return l10n.errLoadCampaignsData(rawError.substring('errLoadCampaignsData:'.length));
    }
    if (rawError.startsWith('errCreateGroup:')) {
      return l10n.errCreateGroup(rawError.substring('errCreateGroup:'.length));
    }
    if (rawError.startsWith('errCreateSchedule:')) {
      return l10n.errCreateSchedule(rawError.substring('errCreateSchedule:'.length));
    }
    if (rawError.startsWith('errDeleteGroup:')) {
      return l10n.errDeleteGroup(rawError.substring('errDeleteGroup:'.length));
    }
    if (rawError.startsWith('errEditGroup:')) {
      return l10n.errEditGroup(rawError.substring('errEditGroup:'.length));
    }
    if (rawError.startsWith('errDeleteSchedule:')) {
      return l10n.errDeleteSchedule(rawError.substring('errDeleteSchedule:'.length));
    }
    if (rawError.startsWith('errEditSchedule:')) {
      return l10n.errEditSchedule(rawError.substring('errEditSchedule:'.length));
    }
    if (rawError.startsWith('errToggleScheduleActive:')) {
      return l10n.errToggleScheduleActive(rawError.substring('errToggleScheduleActive:'.length));
    }
    return rawError;
  }

  void _showLogoutConfirmation(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.logoutTitle),
          ],
        ),
        content: Text(l10n.logoutConfirmation, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext); 
              context.read<CampaignsCubit>().logout(); 
            },
            child: Text(l10n.logoutButton, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _validateAndShowScheduleDialog(
    BuildContext context,
    List<Group> groups,
    List<Map<String, dynamic>> devices, {
    Schedule? schedule,
  }) {
    final l10n = context.l10n;
    if (groups.isEmpty) {
      _showSnackBar(context, l10n.mustCreateGroupFirst, Colors.orange);
      return;
    }
    if (devices.isEmpty) {
      _showSnackBar(
        context,
        l10n.mustLinkDeviceFirst,
        Colors.redAccent,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CampaignsCubit>(), 
        child: _ScheduleDialogWidget(
          groups: groups,
          devices: devices,
          schedule: schedule,
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.campaignsAndGroupsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: l10n.logoutTooltip,
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: const Icon(Icons.rocket_launch), text: l10n.navCampaigns),
              Tab(icon: const Icon(Icons.group), text: l10n.tabGroups),
            ],
          ),
        ),
        body: BlocBuilder<CampaignsCubit, CampaignsState>(
          builder: (context, state) {
            if (state is CampaignsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CampaignsError) {
              return Center(
                child: Text(
                  _getLocalizedCampaignError(context, state.message), 
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              );
            } else if (state is CampaignsLoaded) {
              return TabBarView(
                children: [
                  _buildCampaignsTab(context, state.schedules, state.groups, state.devices),
                  _buildGroupsTab(context, state.groups),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildCampaignsTab(
    BuildContext context,
    List<Schedule> schedules,
    List<Group> groups,
    List<Map<String, dynamic>> devices,
  ) {
    final l10n = context.l10n;

    return Scaffold(
      body: schedules.isEmpty
          ? Center(child: Text(l10n.noCampaignsYet, style: const TextStyle(fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: schedules.length,
              itemBuilder: (context, i) {
                final schedule = schedules[i];
                final groupName = groups.firstWhere(
                  (g) => g.id == schedule.groupId, 
                  orElse: () => Group(id: '-1', name: l10n.deletedGroup, isDeleted: true),
                ).name;
                final deviceName = devices.firstWhere(
                  (d) => d['device_id'] == schedule.targetDeviceId, 
                  orElse: () => {'device_name': l10n.unspecifiedDevice},
                )['device_name'];
                final time = TimeOfDay(hour: schedule.sendHour, minute: schedule.sendMinute).format(context);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _validateAndShowScheduleDialog(context, groups, devices, schedule: schedule),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.sms, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.groupLabel(groupName), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(schedule.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_android, size: 14, color: Colors.deepOrange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        deviceName, 
                                        style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month, size: 14, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.scheduleTimeFormat(schedule.sendDay, time), 
                                      style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: schedule.isActive,
                            activeColor: Colors.teal,
                            inactiveThumbColor: Colors.grey, 
                            inactiveTrackColor: Colors.grey.shade300, 
                            onChanged: (_) => context.read<CampaignsCubit>().toggleScheduleActive(schedule),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _validateAndShowScheduleDialog(context, groups, devices),
        icon: const Icon(Icons.add),
        label: Text(l10n.newCampaign),
      ),
    );
  }

  Widget _buildGroupsTab(BuildContext context, List<Group> groups) {
    final l10n = context.l10n;

    return Scaffold(
      body: groups.isEmpty
          ? Center(child: Text(l10n.noGroupsYet, style: const TextStyle(fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.folder, color: Colors.white)),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () => _showGroupDialog(context, group: group),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newGroup),
      ),
    );
  }

  void _showGroupDialog(BuildContext context, {Group? group}) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CampaignsCubit>(),
        child: _GroupDialogWidget(group: group),
      ),
    );
  }
}

class _ScheduleDialogWidget extends StatefulWidget {
  final List<Group> groups;
  final List<Map<String, dynamic>> devices;
  final Schedule? schedule;

  const _ScheduleDialogWidget({required this.groups, required this.devices, this.schedule});

  @override
  State<_ScheduleDialogWidget> createState() => _ScheduleDialogWidgetState();
}

class _ScheduleDialogWidgetState extends State<_ScheduleDialogWidget> {
  final _formKey = GlobalKey<FormState>(); 
  late TextEditingController _messageController;
  late TextEditingController _dayController;
  Group? _selectedGroup;
  String? _selectedDeviceId;
  late TimeOfDay _selectedTime; 
  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _isEditing ? widget.schedule!.message : '');
    _dayController = TextEditingController(text: _isEditing ? widget.schedule!.sendDay.toString() : '');
    _selectedTime = _isEditing 
        ? TimeOfDay(hour: widget.schedule!.sendHour, minute: widget.schedule!.sendMinute) 
        : const TimeOfDay(hour: 9, minute: 0);
    _selectedGroup = _isEditing
        ? widget.groups.firstWhere((g) => g.id == widget.schedule!.groupId, orElse: () => widget.groups.first)
        : widget.groups.first;

    if (_isEditing && widget.schedule!.targetDeviceId != null) {
      final deviceExists = widget.devices.any((d) => d['device_id'] == widget.schedule!.targetDeviceId);
      _selectedDeviceId = deviceExists ? widget.schedule!.targetDeviceId : widget.devices.first['device_id'];
    } else if (widget.devices.isNotEmpty) {
      _selectedDeviceId = widget.devices.first['device_id'];
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate() && _selectedGroup != null && _selectedDeviceId != null) {
      final cubit = context.read<CampaignsCubit>();
      final day = int.parse(_dayController.text);
      final msg = _messageController.text.trim();
      if (_isEditing) {
        cubit.editSchedule(
          originalSchedule: widget.schedule!,
          newMessage: msg,
          newSendDay: day,
          newSendHour: _selectedTime.hour, 
          newSendMinute: _selectedTime.minute, 
          newTargetDeviceId: _selectedDeviceId,
        );
      } else {
        cubit.createSchedule(
          groupId: _selectedGroup!.id,
          message: msg,
          sendDay: day,
          sendHour: _selectedTime.hour, 
          sendMinute: _selectedTime.minute, 
          targetDeviceId: _selectedDeviceId,
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEditing ? l10n.editCampaignTitle : l10n.newCampaignTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Group>(
                value: _selectedGroup,
                decoration: InputDecoration(labelText: l10n.selectGroupLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: widget.groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                onChanged: (val) => setState(() => _selectedGroup = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _selectedDeviceId,
                decoration: InputDecoration(labelText: l10n.sendingPhoneLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: widget.devices.map((d) => DropdownMenuItem(value: d['device_id'] as String?, child: Text(d['device_name']))).toList(),
                onChanged: (val) => setState(() => _selectedDeviceId = val),
                validator: (val) => val == null ? l10n.pleaseSelectDevice : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.smsMessageLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                validator: (val) => val == null || val.trim().isEmpty ? l10n.pleaseEnterMessage : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.sendDayLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                validator: (val) {
                  if (val == null || val.isEmpty) return l10n.pleaseSpecifyDay;
                  final day = int.tryParse(val);
                  if (day == null || day < 1 || day > 31) return l10n.enterValidDayNumber;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.access_time, color: Colors.teal),
                      Text(
                        l10n.sendingTimeFormat(_selectedTime.format(context)), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Icon(Icons.edit, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: () {
              context.read<CampaignsCubit>().deleteSchedule(widget.schedule!);
              Navigator.pop(context);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: _save,
          child: Text(l10n.save, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _GroupDialogWidget extends StatefulWidget {
  final Group? group;
  const _GroupDialogWidget({this.group});

  @override
  State<_GroupDialogWidget> createState() => _GroupDialogWidgetState();
}

class _GroupDialogWidgetState extends State<_GroupDialogWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _isEditing ? widget.group!.name : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEditing ? l10n.editGroupTitle : l10n.newGroupTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.groupNameLabel, 
            hintText: l10n.groupNameHint, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          validator: (val) => val == null || val.trim().isEmpty ? l10n.pleaseEnterGroupName : null,
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: () {
              context.read<CampaignsCubit>().deleteGroup(widget.group!);
              Navigator.pop(context);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final cubit = context.read<CampaignsCubit>();
              final name = _nameController.text.trim();
              _isEditing ? cubit.editGroup(widget.group!, name) : cubit.createGroup(name);
              Navigator.pop(context);
            }
          },
          child: Text(l10n.save, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}