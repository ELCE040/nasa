import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NasaColors.pitchDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: NasaColors.sun,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sports_soccer, color: NasaColors.pitchDark, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'NASA SPORT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Malawi ward & youth football — live scores, scouting\nand transparent club finances, village by village.',
                style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 36),
              const Text(
                'Continue as',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    _RoleCard(
                      title: 'Viewer / Fan',
                      subtitle: 'Live scores, news, fixtures, league tables and sponsor a team.',
                      icon: Icons.groups_2_outlined,
                      onTap: () => AppState.instance.setRole(UserRole.viewer),
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      title: 'Scout',
                      subtitle: 'Discover players, watch highlight clips, build a watchlist and get alerts.',
                      icon: Icons.travel_explore,
                      onTap: () => AppState.instance.setRole(UserRole.scout),
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      title: 'Team / Coach',
                      subtitle: 'Manage your roster, log medical & attendance records, fixtures and finances.',
                      icon: Icons.shield_moon_outlined,
                      onTap: () => AppState.instance.setRole(UserRole.team),
                    ),
                  ],
                ),
              ),
              const Text(
                'Demo build — all data shown is illustrative.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: NasaColors.sun.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: NasaColors.sun),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
