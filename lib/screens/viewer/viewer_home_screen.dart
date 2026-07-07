import 'package:flutter/material.dart';
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
    'Nasa Sport',
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
        title: Text(_titles[_index]),
        actions: const [RoleSwitcherButton()],
      ),
      body: IndexedStack(index: _index, children: tabs),
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
