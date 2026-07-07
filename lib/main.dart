import 'package:flutter/material.dart';
import 'models/models.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/role_select_screen.dart';
import 'screens/viewer/viewer_home_screen.dart';
import 'screens/scout/scout_home_screen.dart';
import 'screens/team/team_home_screen.dart';

void main() {
  runApp(const NasaSportApp());
}

class NasaSportApp extends StatelessWidget {
  const NasaSportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nasa Sport',
      debugShowCheckedModeBanner: false,
      theme: NasaTheme.theme,
      home: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          switch (AppState.instance.currentRole) {
            case UserRole.viewer:
              return const ViewerHomeScreen();
            case UserRole.scout:
              return const ScoutHomeScreen();
            case UserRole.team:
              return const TeamHomeScreen();
            case null:
              return const RoleSelectScreen();
          }
        },
      ),
    );
  }
}
