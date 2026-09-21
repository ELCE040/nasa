import 'package:flutter/material.dart';
import 'models/models.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/role_select_screen.dart';
import 'screens/viewer/viewer_home_screen.dart';
import 'screens/scout/scout_home_screen.dart';
import 'screens/team/team_home_screen.dart';

void main() {
  runApp(const NaysaApp());
}

class NaysaApp extends StatelessWidget {
  const NaysaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final useTeamBranding = state.currentRole == UserRole.team;
        return MaterialApp(
          title: 'NAYSA Sport',
          debugShowCheckedModeBanner: false,
          theme: NasaTheme.theme(
            primary: useTeamBranding ? state.teamBrandPrimary : null,
            secondary: useTeamBranding ? state.teamBrandSecondary : null,
          ),
          home: AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) {
              final state = AppState.instance;

              // Show branded splash while booting
              if (state.isLoading) {
                return const _SplashScreen();
              }

              if (state.loadError != null) {
                return _ErrorScreen(error: state.loadError!);
              }

              switch (state.currentRole) {
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
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NasaColors.pitchDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: NasaColors.sun.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: NasaColors.gold, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_soccer,
                    color: NasaColors.gold,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NAYSA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sports for everyone',
              style: TextStyle(
                color: NasaColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: NasaColors.gold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NasaColors.pitchDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: NasaColors.earth, size: 64),
              const SizedBox(height: 24),
              const Text(
                'SYSTEM OFFLINE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => AppState.instance.reload(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NasaColors.gold,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                child: const Text('RETRY CONNECTION'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
