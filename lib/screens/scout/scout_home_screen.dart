import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import 'scout_discover_tab.dart';
import 'scout_watchlist_tab.dart';
import 'scout_alerts_tab.dart';
import 'scout_account_tab.dart';

class ScoutHomeScreen extends StatefulWidget {
  const ScoutHomeScreen({super.key});
  @override
  State<ScoutHomeScreen> createState() => _ScoutHomeScreenState();
}

class _ScoutHomeScreenState extends State<ScoutHomeScreen> {
  int _index = 0;

  static const _titles = [
    'Discover Players',
    'Watchlist',
    'Alerts',
    'Scout Account'
  ];

  static const _tabs = [
    ScoutDiscoverTab(),
    ScoutWatchlistTab(),
    ScoutAlertsTab(),
    ScoutAccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [AppRefreshButton(), RoleSwitcherButton()],
      ),
      body: RefreshIndicator(
        onRefresh: AppState.instance.refreshCurrentData,
        notificationPredicate: (_) => true,
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.travel_explore), label: 'Discover'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_outline), label: 'Watchlist'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}
