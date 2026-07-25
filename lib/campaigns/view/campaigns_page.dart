import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import '../cubit/campaigns_cubit.dart';

// ==========================================
// الصفحة الرئيسية للحملات
// ==========================================
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

  
  // 🌟 دالة إظهار رسالة تأكيد تسجيل الخروج
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children:[
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟', style: TextStyle(fontSize: 16)),
        actions:[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // إغلاق النافذة فقط
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext); // إغلاق النافذة
              context.read<CampaignsCubit>().logout(); // 🚀 استدعاء دالة الخروج من الكيوبت
            },
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  // 🔒 قفل الأمان الأول والثاني: التحقق قبل فتح نافذة الحملة
  void _validateAndShowScheduleDialog(
    BuildContext context,
    List<Group> groups,
    List<Map<String, dynamic>> devices, {
    Schedule? schedule,
  }) {
    if (groups.isEmpty) {
      _showSnackBar(context, 'يجب إنشاء مجموعة أولاً! 📁', Colors.orange);
      return;
    }

    if (devices.isEmpty) {
      _showSnackBar(
        context,
        'يجب ربط هاتف واحد على الأقل من (لوحة التحكم) قبل إنشاء حملة! 📱',
        Colors.redAccent,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // إذا تم اجتياز الأقفال، نفتح النافذة
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CampaignsCubit>(), // تمرير الـ Cubit للنافذة المنبثقة
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحملات والمجموعات', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          actions:[
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'تسجيل خروج',
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs:[
              Tab(icon: Icon(Icons.rocket_launch), text: 'الحملات'),
              Tab(icon: Icon(Icons.group), text: 'المجموعات'),
            ],
          ),
        ),
        body: BlocBuilder<CampaignsCubit, CampaignsState>(
          builder: (context, state) {
            if (state is CampaignsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CampaignsError) {
              return Center(
                child: Text(state.message, style: const TextStyle(color: Colors.red, fontSize: 16)),
              );
            } else if (state is CampaignsLoaded) {
              return TabBarView(
                children:[
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

  // ==========================================
  // واجهة تبويب الحملات (تصميم محمي من التداخل 🛡️)
  // ==========================================
  Widget _buildCampaignsTab(
    BuildContext context,
    List<Schedule> schedules,
    List<Group> groups,
    List<Map<String, dynamic>> devices,
  ) {
    return Scaffold(
      body: schedules.isEmpty
          ? const Center(child: Text('لا توجد حملات أتمتة بعد. قم بإنشاء حملة 🚀', style: TextStyle(fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: schedules.length,
              itemBuilder: (context, i) {
                final schedule = schedules[i];
                final groupName = groups.firstWhere((g) => g.id == schedule.groupId, orElse: () => const Group(id: '-1', name: 'مجموعة محذوفة', isDeleted: true)).name;
                final deviceName = devices.firstWhere((d) => d['device_id'] == schedule.targetDeviceId, orElse: () => {'device_name': 'جهاز غير محدد'})['device_name'];
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
                        children:[
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.sms, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          // 🌟 استخدام Expanded يمنع النص الطويل من دفع الزر خارج الشاشة
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:[
                                Text('مجموعة: $groupName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(schedule.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
                                const SizedBox(height: 8),
                                
                                // 🌟 ترتيب الجهاز والوقت عمودياً لتجنب التداخل إذا كان اسم الجهاز طويلاً جداً
                                Row(
                                  children:[
                                    const Icon(Icons.phone_android, size: 14, color: Colors.deepOrange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        deviceName, 
                                        style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis, // يضع ثلاث نقاط ... إذا كان الاسم طويلاً جداً
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children:[
                                    const Icon(Icons.calendar_month, size: 14, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Text('يوم ${schedule.sendDay} - الساعة $time', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 🌟 زر التشغيل والإيقاف (مع ألوان واضحة في حالتي التشغيل والإطفاء)
                          Switch(
                            value: schedule.isActive,
                            activeColor: Colors.teal,
                            inactiveThumbColor: Colors.grey, // لون الدائرة وهي مطفأة
                            inactiveTrackColor: Colors.grey.shade300, // لون المسار وهو مطفأ
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
        label: const Text('حملة جديدة'),
      ),
    );
  }

  // ==========================================
  // واجهة تبويب المجموعات
  // ==========================================
  Widget _buildGroupsTab(BuildContext context, List<Group> groups) {
    return Scaffold(
      body: groups.isEmpty
          ? const Center(child: Text('لا توجد مجموعات بعد. قم بإنشاء مجموعة 📁', style: TextStyle(fontSize: 16)))
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
        label: const Text('مجموعة جديدة'),
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

// ==========================================
// 💡 نافذة إضافة/تعديل الحملة (تم فصلها باحترافية)
// ==========================================
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
  late TimeOfDay _selectedTime; // 🌟 إضافة متغير الوقت

  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _isEditing ? widget.schedule!.message : '');
    _dayController = TextEditingController(text: _isEditing ? widget.schedule!.sendDay.toString() : '');
    
    // 🌟 تهيئة الوقت (من الحملة أو 9 صباحاً كافتراضي)
    _selectedTime = _isEditing 
        ? TimeOfDay(hour: widget.schedule!.sendHour, minute: widget.schedule!.sendMinute) 
        : const TimeOfDay(hour: 9, minute: 0);

    // تحديد المجموعة 
    _selectedGroup = _isEditing
        ? widget.groups.firstWhere((g) => g.id == widget.schedule!.groupId, orElse: () => widget.groups.first)
        : widget.groups.first;

    // تحديد الجهاز
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
          newSendHour: _selectedTime.hour, // 🌟 إرسال الساعة
          newSendMinute: _selectedTime.minute, // 🌟 إرسال الدقيقة
          newTargetDeviceId: _selectedDeviceId,
        );
      } else {
        cubit.createSchedule(
          groupId: _selectedGroup!.id,
          message: msg,
          sendDay: day,
          sendHour: _selectedTime.hour, // 🌟 إرسال الساعة
          sendMinute: _selectedTime.minute, // 🌟 إرسال الدقيقة
          targetDeviceId: _selectedDeviceId,
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEditing ? 'تعديل الحملة 🚀' : 'حملة أتمتة جديدة 🚀', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              DropdownButtonFormField<Group>(
                value: _selectedGroup,
                decoration: InputDecoration(labelText: 'اختر المجموعة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: widget.groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                onChanged: (val) => setState(() => _selectedGroup = val),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String?>(
                value: _selectedDeviceId,
                decoration: InputDecoration(labelText: 'الهاتف المرسل 📱', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: widget.devices.map((d) => DropdownMenuItem(value: d['device_id'] as String?, child: Text(d['device_name']))).toList(),
                onChanged: (val) => setState(() => _selectedDeviceId = val),
                validator: (val) => val == null ? 'يرجى اختيار هاتف للإرسال' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'نص الرسالة (SMS)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة نص الرسالة' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'يوم الإرسال (1 - 31)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'يرجى تحديد اليوم';
                  final day = int.tryParse(val);
                  if (day == null || day < 1 || day > 31) return 'أدخل رقماً صحيحاً بين 1 و 31';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 🌟 زر اختيار الوقت المحدث
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
                    children:[
                      const Icon(Icons.access_time, color: Colors.teal),
                      Text('وقت الإرسال: ${_selectedTime.format(context)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Icon(Icons.edit, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions:[
        if (_isEditing)
          TextButton(
            onPressed: () {
              context.read<CampaignsCubit>().deleteSchedule(widget.schedule!);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: _save,
          child: const Text('حفظ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ==========================================
// 💡 نافذة إضافة/تعديل المجموعة
// ==========================================
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEditing ? 'تعديل المجموعة' : 'مجموعة جديدة'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'اسم المجموعة', hintText: 'مثال: عملاء VIP', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم للمجموعة' : null,
        ),
      ),
      actions:[
        if (_isEditing)
          TextButton(
            onPressed: () {
              context.read<CampaignsCubit>().deleteGroup(widget.group!);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
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
          child: const Text('حفظ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}