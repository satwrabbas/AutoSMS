import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_sms/campaigns/view/campaigns_page.dart';
// استدعاء شاشة جهات الاتصال التي صنعناها
import 'package:auto_sms/contacts/view/contacts_page.dart';
import 'package:auto_sms/dashboard/view/dashboard_page.dart';
import 'package:auto_sms/home/cubit/home_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // رقم الصفحة المحددة حالياً
    final selectedTab = context.watch<HomeCubit>().state;

    // قائمة الشاشات (سنضيف الشاشات الأخرى لاحقاً)
    final pages =<Widget>[
   // 1. لوحة التحكم (🌟 تم استبدالها)
   const DashboardPage(),
   
   // 2. شاشة جهات الاتصال
   const ContactsPage(),
   
   // 3. شاشة الحملات
   const CampaignsPage(),
  ];

    return Scaffold(
      // نعرض الشاشة بناءً على الرقم المختار
      body: pages[selectedTab],
      
      // شريط التنقل السفلي
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          context.read<HomeCubit>().setTab(index); // تغيير الصفحة
        },
        destinations: const[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(Icons.rocket_launch),
            label: 'الحملات',
          ),
        ],
      ),
    );
  }
}