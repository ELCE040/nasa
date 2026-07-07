import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/match_detail_screen.dart';
import 'fixture_generator_screen.dart';

class TeamFixturesTab extends StatelessWidget {
  const TeamFixturesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final myMatches = app.matches.where((m) => m.homeTeamId == app.myTeamId || m.awayTeamId == app.myTeamId).toList()
          ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Schedule'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixtureGeneratorScreen())),
          ),
          body: myMatches.isEmpty
              ? const EmptyState(icon: Icons.event_busy_outlined, title: 'No fixtures yet', message: 'Schedule your club\'s next match.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: myMatches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = myMatches[i];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: m.id, viewAs: UserRole.team)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: NasaColors.line)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(m.competition, style: const TextStyle(fontSize: 11, color: NasaColors.slate, fontWeight: FontWeight.w700))),
                                if (m.status == MatchStatus.live) const LiveBadge(),
                                if (m.status == MatchStatus.postponed) const StatusChip(label: 'Postponed', color: NasaColors.earth),
                                if (m.status == MatchStatus.fullTime) const StatusChip(label: 'Full time', color: NasaColors.slate),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text(m.homeTeamName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                                Text(
                                  m.status == MatchStatus.upcoming || m.status == MatchStatus.postponed ? 'vs' : '${m.homeScore} - ${m.awayScore}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                Expanded(child: Text(m.awayTeamName, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('${m.venue} · ${m.travelDistanceKm.toStringAsFixed(0)} km travel', style: const TextStyle(fontSize: 11, color: NasaColors.slate)),
                            Text(
                              m.status == MatchStatus.upcoming ? '${formatShortDate(m.kickoff)} · ${formatTime(m.kickoff)}' : formatShortDate(m.kickoff),
                              style: const TextStyle(fontSize: 11, color: NasaColors.slate),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
