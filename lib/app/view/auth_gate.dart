import 'package:cloud_storage_api/cloud_storage_api.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_sms/home/view/home_page.dart';
import 'package:auto_sms/login/view/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CrmRepository>();

    return StreamBuilder<AuthState>(
      stream: repository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // 🌟 نستخدم الشاشة الذكية الجديدة هنا لمنع التكرار
          return const WorkspaceInitializer();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// ==========================================
// 🌟 الشاشة الذكية للتهيئة (تعمل مرة واحدة فقط!)
// ==========================================
class WorkspaceInitializer extends StatefulWidget {
  const WorkspaceInitializer({super.key});

  @override
  State<WorkspaceInitializer> createState() => _WorkspaceInitializerState();
}

class _WorkspaceInitializerState extends State<WorkspaceInitializer> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    // 🌟 نستدعي دالة الشفاء الذاتي عند فتح التطبيق
    _initFuture = _initializeWorkspace();
  }

  // ==========================================
  // 🌟 دالة الشفاء الذاتي الذكية
  // ==========================================
  Future<void> _initializeWorkspace() async {
    final repository = context.read<CrmRepository>();
    try {
      // 1. تنزيل التحديثات السحابية أولاً إن وجدت
      await repository.downloadIfCloudIsNewer();
      
      // 2. 🌟 الرفع الدائم! (لضمان رفع أي رسائل أرسلها الشبح في الخلفية)
      await repository.syncAllToCloud();
    } catch (e) {
      print("⚠️ تعذرت المزامنة المبدئية: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 24),
                  Text('جاري تهيئة مساحة العمل...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('يتم الآن مزامنة بياناتك بأمان ☁️', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        
        return const HomePage();
      },
    );
  }
}