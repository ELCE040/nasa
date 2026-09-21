import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import 'viewer_home_tab.dart';
import 'viewer_fixtures_tab.dart';
import 'viewer_news_tab.dart';
import 'viewer_standings_tab.dart';
import 'viewer_more_tab.dart';

class ViewerHomeScreen extends StatefulWidget {
  const ViewerHomeScreen({super.key});
  @override
  State<ViewerHomeScreen> createState() => _ViewerHomeScreenState();
}

class _ViewerHomeScreenState extends State<ViewerHomeScreen> {
  int _index = 0;

  static const _titles = [
    'Naysasport',
    'Fixtures',
    'News',
    'Standings',
    'More'
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ViewerHomeTab(onOpenFixtures: () => setState(() => _index = 1)),
      const ViewerFixturesTab(),
      const ViewerNewsTab(),
      const ViewerStandingsTab(),
      const ViewerMoreTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _index == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_soccer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_titles[_index]),
                ],
              )
            : Text(_titles[_index]),
        actions: const [AppRefreshButton(), RoleSwitcherButton()],
      ),
      body: RefreshIndicator(
        onRefresh: AppState.instance.refreshCurrentData,
        notificationPredicate: (_) => true,
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.sports_soccer), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'Fixtures'),
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined), label: 'News'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined), label: 'Standings'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
