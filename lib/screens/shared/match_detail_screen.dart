import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../team/referee_rating_screen.dart';

class MatchDetailScreen extends StatelessWidget {
  final String matchId;
  final UserRole viewAs;
  const MatchDetailScreen(
      {super.key, required this.matchId, required this.viewAs});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        Match? match;
        for (final m in app.matches) {
          if (m.id == matchId) match = m;
        }
        if (match == null) {
          return const Scaffold(body: Center(child: Text('Match not found')));
        }
        final events = [...match.events]
          ..sort((a, b) => a.minute.compareTo(b.minute));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Match details'),
            actions: const [RoleSwitcherButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Container(
                color: NasaColors.pitch,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  children: [
                    Text(
                      match.competition,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: _TeamColumn(name: match.homeTeamName)),
                        Column(
                          children: [
                            Text(
                              match.status == MatchStatus.upcoming
                                  ? formatTime(match.kickoff)
                                  : '${match.homeScore} - ${match.awayScore}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            if (match.status == MatchStatus.live)
                              const LiveBadge(),
                            if (match.status == MatchStatus.live)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text("${match.minute}'",
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ),
                            if (match.status == MatchStatus.fullTime)
                              const Text('Full time',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            if (match.status == MatchStatus.postponed)
                              const Text('Postponed',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Expanded(child: _TeamColumn(name: match.awayTeamName)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NasaColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(icon: Icons.place_outlined, label: match.venue),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label:
                              '${formatShortDate(match.kickoff)} · ${formatTime(match.kickoff)}'),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.directions_bus_outlined,
                          label:
                              '${match.travelDistanceKm.toStringAsFixed(0)} km between villages'),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'Match events'),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No events yet.',
                      style: TextStyle(color: NasaColors.slate)),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: events.map((e) {
                      final icon = switch (e.type) {
                        'Goal' => Icons.sports_soccer,
                        'Yellow Card' => Icons.square,
                        'Red Card' => Icons.square,
                        _ => Icons.swap_horiz,
                      };
                      final color = switch (e.type) {
                        'Goal' => NasaColors.pitch,
                        'Yellow Card' => NasaColors.sun,
                        'Red Card' => NasaColors.earth,
                        _ => NasaColors.slate,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text("${e.minute}'",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                            Icon(icon, size: 16, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${e.playerName} · ${e.teamName}',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (viewAs == UserRole.team &&
                  match.status == MatchStatus.fullTime)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Rate the referee for this match'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RefereeRatingScreen(
                          matchLabel:
                              '${match!.homeTeamName} vs ${match.awayTeamName}',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  const _TeamColumn({required this.name});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InitialsAvatar(
            text: name,
            radius: 22,
            background: Colors.white,
            foreground: NasaColors.pitch),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: NasaColors.slate),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
