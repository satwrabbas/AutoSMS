import 'package:cloud_storage_api/cloud_storage_api.dart'; // ☁️ استدعاء حزمة السحابة
import 'package:crm_repository/crm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:auto_sms/app/view/auth_gate.dart'; // 🌟 استدعاء البوابة
import 'package:auto_sms/l10n/l10n.dart';

class App extends StatelessWidget {
  const App({
    required this.database,
    required this.cloudClient, // 🌟 التطبيق الآن يستقبل عميل السحابة
    super.key,
  });

  final AppDatabase database; 
  final CloudStorageClient cloudClient; // 🌟 تعريف المتغير

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      // 🌟 نعطي المدير (CrmRepository) كلا المفتاحين ليعمل باحترافية!
      create: (context) => CrmRepository(
        localStorage: database,
        cloudStorage: cloudClient,
      ),
      child: MaterialApp(
        theme: ThemeData(
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF13B9FF)),
          colorScheme: ColorScheme.fromSwatch(
            accentColor: const Color(0xFF13B9FF),
          ),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AuthGate(), // 🌟 التطبيق يبدأ من البوابة      
      ),
    );
  }
}