import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';
import 'team_dashboard_tab.dart';
import 'team_roster_tab.dart';
import 'team_fixtures_tab.dart';
import 'team_finances_tab.dart';
import 'team_more_tab.dart';

class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({super.key});
  @override
  State<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends State<TeamHomeScreen> {
  int _index = 0;

  static const _titles = [
    'Club Dashboard',
    'Roster',
    'Fixtures',
    'Finances',
    'More'
  ];

  static const _tabs = [
    TeamDashboardTab(),
    TeamRosterTab(),
    TeamFixturesTab(),
    TeamFinancesTab(),
    TeamMoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [RoleSwitcherButton()],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined), label: 'Roster'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'Fixtures'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined), label: 'Finances'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
