import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/match_detail_screen.dart';
import 'lineup_editor_screen.dart';

class TeamFixturesTab extends StatelessWidget {
  const TeamFixturesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final brandPrimary = Theme.of(context).colorScheme.primary;
        final brandSecondary = Theme.of(context).colorScheme.secondary;
        final myMatches = app.matches
            .where((m) =>
                m.homeTeamId == app.myTeamId || m.awayTeamId == app.myTeamId)
            .toList()
          ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
        return Scaffold(
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'fab_default_lineup',
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Default XI'),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LineupEditorScreen())),
              ),
            ],
          ),
          body: myMatches.isEmpty
              ? const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No fixtures yet',
                  message: 'Wait for the league to schedule your next match.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: myMatches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = myMatches[i];
                    final homeLogoUrl = app.teamById(m.homeTeamId)?.logoUrl;
                    final awayLogoUrl = app.teamById(m.awayTeamId)?.logoUrl;

                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MatchDetailScreen(
                                matchId: m.id, viewAs: UserRole.team)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: NasaColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: NasaColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(m.displayCompetition,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: NasaColors.textMuted,
                                            fontWeight: FontWeight.w700))),
                                if (m.status == MatchStatus.live) ...[
                                  const LiveBadge(),
                                  const SizedBox(width: 5),
                                  Text('${m.minute}\'',
                                      style: TextStyle(
                                          color: brandPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900)),
                                ],
                                if (m.status == MatchStatus.postponed)
                                  StatusChip(
                                      label: 'Postponed', color: brandPrimary),
                                if (m.status == MatchStatus.fullTime)
                                  const StatusChip(
                                      label: 'Full time',
                                      color: NasaColors.textMuted),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                InitialsAvatar(
                                  text: m.homeTeamName,
                                  radius: 14,
                                  imageUrl: homeLogoUrl,
                                  background: Colors.white,
                                  foreground: brandPrimary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(m.homeTeamName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: Colors.white))),
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: NasaColors.navyDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: NasaColors.border),
                                  ),
                                  child: Text(
                                    m.status == MatchStatus.upcoming ||
                                            m.status == MatchStatus.postponed
                                        ? 'vs'
                                        : '${m.homeScore} - ${m.awayScore}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: brandSecondary),
                                  ),
                                ),
                                Expanded(
                                    child: Text(m.awayTeamName,
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: Colors.white))),
                                const SizedBox(width: 8),
                                InitialsAvatar(
                                  text: m.awayTeamName,
                                  radius: 14,
                                  imageUrl: awayLogoUrl,
                                  background: Colors.white,
                                  foreground: brandPrimary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                                '${m.venue} · ${m.travelDistanceKm.toStringAsFixed(0)} km travel',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: NasaColors.textMuted)),
                            Text(
                              m.status == MatchStatus.upcoming
                                  ? '${formatShortDate(m.kickoff)} · ${formatTime(m.kickoff)}'
                                  : formatShortDate(m.kickoff),
                              style: const TextStyle(
                                  fontSize: 11.5, color: NasaColors.textMuted),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: Icon(Icons.groups_outlined,
                                    size: 17, color: brandPrimary),
                                label: Text(
                                  app.fixtureLineups.containsKey(m.id)
                                      ? 'Edit fixture XI'
                                      : 'Set fixture XI',
                                  style: TextStyle(
                                      color: brandPrimary,
                                      fontWeight: FontWeight.w800),
                                ),
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            LineupEditorScreen(match: m))),
                              ),
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
