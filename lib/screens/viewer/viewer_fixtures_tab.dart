import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/match_detail_screen.dart';

class ViewerFixturesTab extends StatefulWidget {
  const ViewerFixturesTab({super.key});
  @override
  State<ViewerFixturesTab> createState() => _ViewerFixturesTabState();
}

class _ViewerFixturesTabState extends State<ViewerFixturesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'Live'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Results')
            ],
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: app,
            builder: (context, _) {
              return TabBarView(
                controller: _tab,
                children: [
                  _MatchList(
                      matches: app.liveMatches,
                      emptyMessage: 'No matches live right now.'),
                  _MatchList(
                      matches: app.upcomingMatches,
                      emptyMessage: 'No upcoming fixtures scheduled.'),
                  _MatchList(
                      matches: app.pastMatches,
                      emptyMessage: 'No completed matches yet.'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<Match> matches;
  final String emptyMessage;
  const _MatchList({required this.matches, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return EmptyState(
          icon: Icons.sports_soccer,
          title: 'Nothing here yet',
          message: emptyMessage);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final m = matches[i];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    MatchDetailScreen(matchId: m.id, viewAs: UserRole.viewer)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NasaColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(m.competition,
                            style: const TextStyle(
                                fontSize: 11,
                                color: NasaColors.slate,
                                fontWeight: FontWeight.w700))),
                    if (m.status == MatchStatus.live) const LiveBadge(),
                    if (m.status == MatchStatus.postponed)
                      const StatusChip(
                          label: 'Postponed', color: NasaColors.earth),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: Text(m.homeTeamName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5))),
                    Text(
                      m.status == MatchStatus.upcoming ||
                              m.status == MatchStatus.postponed
                          ? 'vs'
                          : '${m.homeScore} - ${m.awayScore}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Expanded(
                        child: Text(m.awayTeamName,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 13, color: NasaColors.slate),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(m.venue,
                            style: const TextStyle(
                                fontSize: 11, color: NasaColors.slate))),
                    Text(
                      m.status == MatchStatus.upcoming
                          ? '${formatShortDate(m.kickoff)} · ${formatTime(m.kickoff)}'
                          : formatShortDate(m.kickoff),
                      style: const TextStyle(
                          fontSize: 11,
                          color: NasaColors.slate,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
