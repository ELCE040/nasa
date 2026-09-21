import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/player_profile_screen.dart';

class ScoutWatchlistTab extends StatelessWidget {
  const ScoutWatchlistTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        if (app.watchlist.isEmpty) {
          return const EmptyState(
            icon: Icons.bookmark_outline,
            title: 'Your watchlist is empty',
            message: 'Follow players from Discover to get SMS/email alerts on goals and Man of the Match awards.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: app.watchlist.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final w = app.watchlist[i];
            final player = app.playerById(w.playerId);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NasaColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NasaColors.border),
              ),
              child: Row(
                children: [
                  InitialsAvatar(
                    text: w.playerName,
                    radius: 20,
                    imageUrl: player?.imageUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.playerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                        Text(w.teamName, style: const TextStyle(fontSize: 12, color: NasaColors.textMuted)),
                        const SizedBox(height: 4),
                        Text('Added ${formatShortDate(w.addedDate)}', style: const TextStyle(fontSize: 11, color: NasaColors.textLight)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(w.alertsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined, size: 20),
                        color: w.alertsEnabled ? NasaColors.crimson : NasaColors.textMuted,
                        onPressed: () => app.toggleWatchlistAlerts(w.playerId),
                        tooltip: 'Toggle alerts',
                      ),
                      if (player != null)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PlayerProfileScreen(playerId: player.id, viewAs: UserRole.scout)),
                          ),
                          child: const Text('View', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
