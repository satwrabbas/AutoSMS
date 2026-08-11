import 'package:cloud_storage_api/cloud_storage_api.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_sms/home/view/home_page.dart';
import 'package:auto_sms/l10n/l10n.dart';
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
          return const WorkspaceInitializer();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

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
    _initFuture = _initializeWorkspace();
  }

  Future<void> _initializeWorkspace() async {
    final repository = context.read<CrmRepository>();
    try {
      await repository.downloadIfCloudIsNewer();
      await repository.syncAllToCloud();
    } catch (e) {
      print("⚠️ Initial sync failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 24),
                  Text(
                    l10n.initializingWorkspace,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.syncingDataSafely,
                    style: const TextStyle(color: Colors.grey),
                  ),
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