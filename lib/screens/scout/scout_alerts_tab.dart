import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/player_profile_screen.dart';

class ScoutAlertsTab extends StatelessWidget {
  const ScoutAlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final alerts = [...app.scoutAlerts]..sort((a, b) => b.date.compareTo(a.date));
        if (alerts.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none,
            title: 'No alerts yet',
            message: 'Watchlisted players\' goals and Man of the Match awards will show up here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = alerts[i];
            final color = switch (a.type) {
              'Goal' => NasaColors.pitch,
              'Man of the Match' => NasaColors.sun,
              _ => NasaColors.slate,
            };
            return InkWell(
              onTap: () {
                app.markAlertRead(a.id);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayerProfileScreen(playerId: a.playerId, viewAs: UserRole.scout)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a.read ? Colors.white : NasaColors.sun.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NasaColors.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                        a.type == 'Goal' ? Icons.sports_soccer : Icons.star,
                        size: 18, color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              StatusChip(label: a.type, color: color),
                              if (!a.read) const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.circle, size: 7, color: NasaColors.earth),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(a.message, style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Text(formatShortDate(a.date), style: const TextStyle(fontSize: 10.5, color: NasaColors.slate)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
