import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import '../cubit/dashboard_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(repository: context.read<CrmRepository>())..loadDashboard(),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  // ==========================================
  // 🌟 نافذة ذكية تطلب اسم الجهاز قبل ربطه
  // ==========================================
  void _showDeviceNameDialog(BuildContext context) {
    final nameController = TextEditingController();
    final cubit = context.read<DashboardCubit>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل جهاز جديد 📱'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'اسم الجهاز (مثال: هاتف المبيعات)',
            border: OutlineInputBorder(),
          ),
        ),
        actions:[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text('إلغاء', style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                cubit.toggleEngine(deviceName: nameController.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('تأكيد وربط'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🌟 النافذة السفلية (الأجهزة المرتبطة) - WhatsApp Style
  // ==========================================
  void _showLinkedDevicesBottomSheet(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BlocProvider.value(
        value: parentContext.read<DashboardCubit>(),
        child: const _LinkedDevicesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم (CRM)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions:[
          // 🌟 أيقونة الأجهزة المرتبطة
          BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.devices_other, color: Colors.white),
                tooltip: 'الأجهزة المرتبطة',
                onPressed: () => _showLinkedDevicesBottomSheet(context),
              );
            },
          ),
          // زر المزامنة اليدوية
          BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                tooltip: 'المزامنة اليدوية',
                onPressed: () => context.read<DashboardCubit>().syncDataToCloud(),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state is DashboardLoaded && state.engineStatusMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.engineStatusMessage!), duration: const Duration(seconds: 4)),
            );
          }
        },
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } 
          else if (state is DashboardLoaded) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:[
                  // 1. الإحصائيات العلوية
                  Row(
                    children:[
                      _buildStatCard('العملاء', state.contactsCount.toString(), Icons.people, Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatCard('المجموعات', state.groupsCount.toString(), Icons.group, Colors.orange),
                      const SizedBox(width: 8),
                      _buildStatCard('الحملات', state.schedulesCount.toString(), Icons.rocket, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 2. زر ربط الهاتف بالسحابة (FCM)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: state.isEngineRunning 
                          ?[BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 5)]
                          :[],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!state.isEngineRunning) {
                          _showDeviceNameDialog(context);
                        } else {
                          context.read<DashboardCubit>().toggleEngine();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        backgroundColor: state.isEngineRunning ? Colors.green[800] : Colors.blue[800], 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: state.isEngineRunning 
                          ? const RadarAnimation() 
                          : const Icon(Icons.phonelink_ring, size: 32),
                      label: Text(
                        state.isEngineRunning 
                            ? 'الهاتف مسجل وجاهز للإرسال 📡' 
                            : 'تسجيل هذا الهاتف للبدء ☁️📱', 
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3. سجل العمليات
                  const Text('سجل الإرسال الأخير:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: state.recentLogs.isEmpty
                        ? const Center(child: Text('لم يتم إرسال أي رسائل أوتوماتيكية بعد.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: state.recentLogs.length,
                            itemBuilder: (context, index) {
                              final log = state.recentLogs[index];
                              return ListTile(
                                leading: const Icon(Icons.mark_email_read, color: Colors.green),
                                title: Text(log.phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(log.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Text('${log.messageDate.month}/${log.messageDate.day} - ${log.messageDate.hour}:${log.messageDate.minute}', style: const TextStyle(fontSize: 12)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children:[
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: TextStyle(color: color.withOpacity(0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🌟 واجهة الأجهزة المرتبطة (Bottom Sheet)
// ==========================================
class _LinkedDevicesSheet extends StatelessWidget {
  const _LinkedDevicesSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoaded) {
          final devices = state.registeredDevices;
          final currentId = state.currentDeviceId;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 16
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                // شريط السحب العلوي (مظهر أنيق)
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                const Text('الأجهزة المرتبطة بالسحابة 📱☁️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0), 
                    child: Text('لا توجد أي أجهزة مرتبطة بهذا الحساب حالياً.', style: TextStyle(color: Colors.grey))
                  ),
                  
                // قائمة الأجهزة
                ...devices.map((device) {
                  final isCurrentDevice = device['device_id'] == currentId;
                  
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), 
                      side: BorderSide(color: isCurrentDevice ? Colors.green.withOpacity(0.5) : Colors.transparent)
                    ),
                    child: ListTile(
                      leading: Icon(isCurrentDevice ? Icons.phone_android : Icons.devices, color: isCurrentDevice ? Colors.green : Colors.grey[700], size: 32),
                      title: Text(device['device_name'] ?? 'جهاز غير معروف', style: TextStyle(fontWeight: isCurrentDevice ? FontWeight.bold : FontWeight.normal)),
                      subtitle: isCurrentDevice 
                          ? const Text('هذا الجهاز (متصل الآن)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)) 
                          : const Text('متصل بالسحابة', style: TextStyle(fontSize: 12)),
                      
                      // 🌟 زر الحذف يظهر فقط للأجهزة الأخرى (الشبحية)
                      trailing: isCurrentDevice 
                          ? null 
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'حذف هذا الجهاز',
                              onPressed: () {
                                context.read<DashboardCubit>().removeLinkedDevice(device['device_id']);
                              },
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
        return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
      }
    );
  }
}

// ==========================================
// أنيميشن الرادار (لزر التشغيل)
// ==========================================
class RadarAnimation extends StatefulWidget {
  const RadarAnimation({super.key});
  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}
class _RadarAnimationState extends State<RadarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: const Icon(Icons.radar, color: Colors.greenAccent, size: 40));
  }
}