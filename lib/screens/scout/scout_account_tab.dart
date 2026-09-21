import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class ScoutAccountTab extends StatelessWidget {
  const ScoutAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedBuilder(
          animation: app,
          builder: (context, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NasaColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NasaColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: NasaColors.crimson.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.travel_explore, color: NasaColors.crimson, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Scout Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Watching ${app.watchlist.length} players', style: const TextStyle(color: NasaColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('About this premium portal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        const Text(
          'Nasa Sport\'s scouting layer gives professional scouts due-diligence data: '
          'algorithmic market valuations, injury history, disciplinary records and short '
          'highlight clips — plus automated alerts the moment a watchlisted player scores '
          'or wins Man of the Match.',
          style: TextStyle(color: NasaColors.textMuted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: NasaColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NasaColors.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.swap_horiz, color: NasaColors.crimson),
            title: const Text('Switch role', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
            subtitle: const Text('Viewer · Scout · Team', style: TextStyle(fontSize: 12, color: NasaColors.textMuted)),
            trailing: const Icon(Icons.chevron_right, color: NasaColors.textMuted),
            onTap: () => app.signOut(),
          ),
        ),
      ],
    );
  }
}
