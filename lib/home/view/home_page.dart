import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_sms/campaigns/view/campaigns_page.dart';
import 'package:auto_sms/contacts/view/contacts_page.dart';
import 'package:auto_sms/dashboard/view/dashboard_page.dart';
import 'package:auto_sms/home/cubit/home_cubit.dart';
import 'package:auto_sms/l10n/l10n.dart';

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
    final l10n = context.l10n;
    final selectedTab = context.watch<HomeCubit>().state;
    final pages = const <Widget>[
      DashboardPage(),
      ContactsPage(),
      CampaignsPage(),
    ];

    return Scaffold(
      body: pages[selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          context.read<HomeCubit>().setTab(index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.navContacts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.rocket_launch_outlined),
            selectedIcon: const Icon(Icons.rocket_launch),
            label: l10n.navCampaigns,
          ),
        ],
      ),
    );
  }
}