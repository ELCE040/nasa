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
  String _leagueFilter = 'all';

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
          color: NasaColors.bgNav,
          child: TabBar(
            controller: _tab,
            indicatorColor: NasaColors.gold,
            labelColor: NasaColors.gold,
            unselectedLabelColor: NasaColors.textMuted,
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
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<String>(
                      value: _leagueFilter,
                      dropdownColor: NasaColors.bgNavy,
                      decoration:
                          const InputDecoration(labelText: 'League (All)'),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('All Leagues')),
                        ...app.leagues.map((l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.name)))
                      ],
                      onChanged: (v) =>
                          setState(() => _leagueFilter = v ?? 'all'),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _MatchList(
                            matches:
                                _filterByLeague(app.liveMatches, _leagueFilter),
                            emptyMessage: 'No matches live right now.'),
                        _MatchList(
                            matches: _filterByLeague(
                                app.upcomingMatches, _leagueFilter),
                            emptyMessage: 'No upcoming fixtures scheduled.'),
                        _MatchList(
                            matches:
                                _filterByLeague(app.pastMatches, _leagueFilter),
                            emptyMessage: 'No completed matches yet.'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Match> _filterByLeague(List<Match> source, String leagueId) {
    if (leagueId == 'all') return source;
    return source.where((m) => m.leagueId == leagueId).toList();
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
        final app = AppState.instance;
        final homeLogoUrl = app.teamById(m.homeTeamId)?.logoUrl;
        final awayLogoUrl = app.teamById(m.awayTeamId)?.logoUrl;

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
              color: NasaColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NasaColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.displayCompetition,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: NasaColors.textMuted,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (m.stage.isNotEmpty &&
                              m.stage != 'League Match') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: NasaColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.stage,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: NasaColors.gold),
                              ),
                            ),
                          ],
                          if (m.groupName != null &&
                              m.groupName!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.groupName!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFA78BFA)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (m.status == MatchStatus.live) ...[
                      const LiveBadge(),
                      const SizedBox(width: 5),
                      Text('${m.minute}\'',
                          style: const TextStyle(
                              color: NasaColors.crimson,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ],
                    if (m.status == MatchStatus.postponed)
                      const StatusChip(
                          label: 'Postponed', color: NasaColors.crimson),
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
                      foreground: NasaColors.crimson,
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
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: NasaColors.navyDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NasaColors.border),
                      ),
                      child: Text(
                        m.status == MatchStatus.upcoming ||
                                m.status == MatchStatus.postponed
                            ? 'vs'
                            : '${m.homeScore} - ${m.awayScore}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: NasaColors.gold),
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
                      foreground: NasaColors.crimson,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 13, color: NasaColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(m.venue,
                            style: const TextStyle(
                                fontSize: 11, color: NasaColors.textMuted))),
                    Text(
                      m.status == MatchStatus.upcoming
                          ? '${formatShortDate(m.kickoff)} · ${formatTime(m.kickoff)}'
                          : formatShortDate(m.kickoff),
                      style: const TextStyle(
                          fontSize: 11,
                          color: NasaColors.textMuted,
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
