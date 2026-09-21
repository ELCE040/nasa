import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/match_detail_screen.dart';
import '../shared/player_profile_screen.dart';
import '../shared/team_profile_screen.dart';

class ViewerStandingsTab extends StatefulWidget {
  const ViewerStandingsTab({super.key});

  @override
  State<ViewerStandingsTab> createState() => _ViewerStandingsTabState();
}

class _ViewerStandingsTabState extends State<ViewerStandingsTab> {
  String _leagueFilter = 'all';
  int _hybridTab = 0; // 0: Groups, 1: Knockout Bracket
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final leagues = app.leagues
            .where((l) => l.name.toLowerCase() != 'unassigned')
            .toList();

        // Never merge unrelated competitions into one table. On first open,
        // prefer the active competition whose match was played most recently.
        final defaultLeagueId = _mostRecentActiveLeagueId(leagues, app);
        final validFilter = leagues.any((l) => l.id == _leagueFilter)
            ? _leagueFilter
            : defaultLeagueId;

        League? selectedLeague;
        for (final l in leagues) {
          if (l.id == validFilter) {
            selectedLeague = l;
            break;
          }
        }

        final format = selectedLeague?.format ?? 'league';
        final isLive = app.liveLeagueIds.contains(validFilter);

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // ─── DEBUG DIAGNOSTICS CARD ───
            if (_showDebug)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bug_report,
                            size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        const Text(
                          'DEBUG DIAGNOSTICS',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _showDebug = false),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Loading: ${app.isLoading} | Error: ${app.loadError ?? "None"}\n'
                      '• Leagues (${app.leagues.length}): ${app.leagues.map((l) => "${l.name} [${l.format}]").join(", ")}\n'
                      '• Teams in State: ${app.teams.length} | Standings Computed: ${app.standings.length}\n'
                      '• Matches in State: ${app.matches.length} | Players: ${app.players.length}\n'
                      '• Selected Filter: $validFilter | Format: $format',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => app.reload(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Reload API Data',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => app.refreshCurrentData(),
                          child: const Text('Refresh',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ─── LEAGUE SELECTOR ───
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: DropdownButtonFormField<String>(
                value: validFilter,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Competition / League'),
                items: [
                  ...leagues.map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.name} (${_formatLabel(l.format)})',
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _leagueFilter = value;
                    _hybridTab = 0;
                  });
                },
              ),
            ),

            if (isLive)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Row(
                  children: [
                    LiveBadge(),
                    SizedBox(width: 8),
                    Text('Scores & tables update live from match events',
                        style:
                            TextStyle(fontSize: 12, color: NasaColors.slate)),
                  ],
                ),
              ),

            // ─── TOURNAMENT FORMAT VIEW ───
            if (format == 'knockout' && selectedLeague != null) ...[
              _KnockoutBracketView(
                  leagueId: validFilter,
                  leagueName: selectedLeague?.name ?? 'Cup'),
            ] else if (format == 'group_knockout' &&
                selectedLeague != null) ...[
              _buildHybridSegmentedSwitch(),
              const SizedBox(height: 12),
              if (_hybridTab == 0)
                _GroupStandingsView(
                  leagueId: validFilter,
                  advancingTeams: selectedLeague?.advancingTeams ?? 2,
                )
              else
                _KnockoutBracketView(
                    leagueId: validFilter,
                    leagueName: selectedLeague?.name ?? 'Cup'),
            ] else ...[
              _StandardLeagueTableView(leagueId: selectedLeague?.id),
            ],

            const SizedBox(height: 24),
            const SectionHeader(title: 'Competition Leaders'),
            _LeaguePlayerStatsSection(
              leagueId: selectedLeague?.id,
            ),
          ],
        );
      },
    );
  }

  String _formatLabel(String format) {
    switch (format) {
      case 'knockout':
        return 'Cup Knockout';
      case 'group_knockout':
        return 'Group + KO';
      default:
        return 'League Table';
    }
  }

  String _mostRecentActiveLeagueId(List<League> leagues, AppState app) {
    if (leagues.isEmpty) return '';
    final activeLeagues =
        leagues.where((league) => league.status == 'active').toList();
    final candidates = activeLeagues.isNotEmpty ? activeLeagues : leagues;
    final candidateIds = candidates.map((league) => league.id).toSet();
    final matches = app.matches
        .where((match) => candidateIds.contains(match.leagueId))
        .toList()
      ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
    return matches.isNotEmpty ? matches.first.leagueId : candidates.first.id;
  }

  Widget _buildHybridSegmentedSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: NasaColors.pitchDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _hybridTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      _hybridTab == 0 ? NasaColors.pitch : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.table_chart_outlined,
                        size: 16,
                        color: _hybridTab == 0
                            ? Colors.white
                            : NasaColors.textMuted),
                    const SizedBox(width: 5),
                    Text('Group Standings',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: _hybridTab == 0
                                ? Colors.white
                                : NasaColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _hybridTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      _hybridTab == 1 ? NasaColors.pitch : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_tree_outlined,
                        size: 16,
                        color: _hybridTab == 1
                            ? Colors.white
                            : NasaColors.textMuted),
                    const SizedBox(width: 5),
                    Text('Knockout Bracket',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: _hybridTab == 1
                                ? Colors.white
                                : NasaColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STANDARD LEAGUE TABLE VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _StandardLeagueTableView extends StatelessWidget {
  final String? leagueId;
  const _StandardLeagueTableView({required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    List<Team> standings = leagueId != null
        ? app.standings.where((t) => t.leagueId == leagueId).toList()
        : <Team>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableHeaders(),
        if (standings.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No teams registered in this competition yet.',
                style: TextStyle(color: NasaColors.slate),
              ),
            ),
          )
        else
          ...standings.asMap().entries.map((entry) {
            final i = entry.key;
            final team = entry.value;
            return _TeamTableRow(index: i, team: team);
          }),
      ],
    );
  }

  Widget _buildTableHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            child: Text('#',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: NasaColors.slate)),
          ),
          const Expanded(
            child: Text('Team',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: NasaColors.slate)),
          ),
          const SizedBox(
            width: 28,
            child: Text('P',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: NasaColors.slate)),
          ),
          _tableHeader('W'),
          _tableHeader('D'),
          _tableHeader('L'),
          _tableHeader('GF'),
          _tableHeader('GA'),
          const SizedBox(
            width: 32,
            child: Text('GD',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: NasaColors.slate)),
          ),
          const SizedBox(
            width: 32,
            child: Text('Pts',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: NasaColors.slate)),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String label) => SizedBox(
        width: 22,
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: NasaColors.slate)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP STANDINGS VIEW (Group A, Group B, Group C...)
// ─────────────────────────────────────────────────────────────────────────────
class _GroupStandingsView extends StatelessWidget {
  final String? leagueId;
  final int advancingTeams;
  const _GroupStandingsView(
      {required this.leagueId, required this.advancingTeams});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    List<Team> allTeams = leagueId != null
        ? app.standings.where((t) => t.leagueId == leagueId).toList()
        : <Team>[];

    // Group teams by groupName
    final Map<String, List<Team>> groups = {};
    for (final team in allTeams) {
      final g = team.groupName;
      final groupKey =
          (g != null && g.trim().isNotEmpty) ? g.trim() : 'Group A';
      groups.putIfAbsent(groupKey, () => []).add(team);
    }

    // Sort group keys alphabetically
    final sortedGroupKeys = groups.keys.toList()..sort();

    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text('No group teams registered in this competition yet.',
              style: TextStyle(color: NasaColors.slate)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedGroupKeys.map((groupName) {
        final teamsInGroup = groups[groupName] ?? <Team>[];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: NasaColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NasaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: NasaColors.bgNavy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  border: Border(bottom: BorderSide(color: NasaColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: NasaColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: NasaColors.pitch.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Top $advancingTeams Advance',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF86EFAC),
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 22,
                        child: Text('#',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: NasaColors.slate))),
                    const Expanded(
                        child: Text('Team',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: NasaColors.slate))),
                    const SizedBox(
                        width: 26,
                        child: Text('P',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: NasaColors.slate))),
                    _miniHeader('W'),
                    _miniHeader('D'),
                    _miniHeader('L'),
                    _miniHeader('GF'),
                    _miniHeader('GA'),
                    const SizedBox(
                        width: 30,
                        child: Text('GD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: NasaColors.slate))),
                    const SizedBox(
                        width: 30,
                        child: Text('Pts',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: NasaColors.slate))),
                  ],
                ),
              ),
              ...teamsInGroup.asMap().entries.map((entry) {
                final i = entry.key;
                final team = entry.value;
                final isAdvancing = i < advancingTeams;
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamProfileScreen(
                          teamId: team.id, viewAs: UserRole.viewer),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAdvancing
                          ? const Color(0xFF166534).withValues(alpha: 0.26)
                          : NasaColors.bgCard,
                      border: const Border(
                          top: BorderSide(color: NasaColors.line, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isAdvancing
                                  ? const Color(0xFF86EFAC)
                                  : NasaColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  team.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: isAdvancing
                                        ? Colors.white
                                        : NasaColors.textMain,
                                  ),
                                ),
                              ),
                              if (isAdvancing) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle,
                                    size: 12, color: NasaColors.pitch),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(
                            width: 26,
                            child: Text('${team.played}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white))),
                        _miniValue(team.won),
                        _miniValue(team.drawn),
                        _miniValue(team.lost),
                        _miniValue(team.goalsFor),
                        _miniValue(team.goalsAgainst),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${team.points}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: NasaColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _miniHeader(String label) => SizedBox(
        width: 20,
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                color: NasaColors.slate)),
      );

  Widget _miniValue(int val) => SizedBox(
        width: 20,
        child: Text('$val',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// KNOCKOUT BRACKET & PROGRESS VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _KnockoutBracketView extends StatefulWidget {
  final String? leagueId;
  final String leagueName;
  const _KnockoutBracketView(
      {required this.leagueId, required this.leagueName});

  @override
  State<_KnockoutBracketView> createState() => _KnockoutBracketViewState();
}

class _KnockoutBracketViewState extends State<_KnockoutBracketView> {
  String _selectedStage = 'All Stages';

  static const List<String> _stageOrder = [
    'Round of 32',
    'Round of 16',
    'Quarter-Final',
    'Semi-Final',
    'Third Place',
    'Final',
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final allLeagueMatches = widget.leagueId != null
        ? app.matches.where((m) => m.leagueId == widget.leagueId).toList()
        : <Match>[];

    // Filter matches that are knockout stages (or all matches if pure knockout)
    final knockoutMatches = allLeagueMatches.where((m) {
      if (m.stage != 'League Match' && m.stage != 'Group Stage') return true;
      return false;
    }).toList();

    // If none are specifically tagged with knockout stage, check if all matches are knockout
    final displayMatches =
        knockoutMatches.isNotEmpty ? knockoutMatches : allLeagueMatches;

    // Group matches by stage
    final Map<String, List<Match>> matchesByStage = {};
    for (final m in displayMatches) {
      final stg = m.stage.isNotEmpty ? m.stage : 'Knockout Round';
      matchesByStage.putIfAbsent(stg, () => []).add(m);
    }

    // Sort stages according to tournament hierarchy
    final sortedStages = matchesByStage.keys.toList()
      ..sort((a, b) {
        final ia =
            _stageOrder.indexWhere((s) => s.toLowerCase() == a.toLowerCase());
        final ib =
            _stageOrder.indexWhere((s) => s.toLowerCase() == b.toLowerCase());
        if (ia != -1 && ib != -1) return ia.compareTo(ib);
        if (ia != -1) return -1;
        if (ib != -1) return 1;
        return a.compareTo(b);
      });

    // Check if Final is completed to showcase the Champion
    final finalMatches =
        displayMatches.where((m) => m.stage.toLowerCase() == 'final').toList();
    Match? completedFinal;
    String? championName;
    String? runnerUpName;
    String? championTeamId;
    if (finalMatches.isNotEmpty) {
      final f = finalMatches.first;
      if (f.status == MatchStatus.fullTime) {
        completedFinal = f;
        if (f.homeScore > f.awayScore) {
          championName = f.homeTeamName;
          runnerUpName = f.awayTeamName;
          championTeamId = f.homeTeamId;
        } else if (f.awayScore > f.homeScore) {
          championName = f.awayTeamName;
          runnerUpName = f.homeTeamName;
          championTeamId = f.awayTeamId;
        }
      }
    }

    final availableStageFilters = ['All Stages', ...sortedStages];
    final activeFilter = availableStageFilters.contains(_selectedStage)
        ? _selectedStage
        : 'All Stages';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── GRAND TOURNAMENT WINNER / CHAMPION SECTION ───
        if (championName != null && completedFinal != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0B132B)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD2B059), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD2B059).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFDF79), Color(0xFFD2B059)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFD2B059).withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events,
                          size: 34, color: Color(0xFF5A3A00)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD2B059)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFD2B059)
                                          .withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  'TOURNAMENT WINNER',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFD2B059),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            championName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Final: ${completedFinal.homeTeamName} ${completedFinal.homeScore} – ${completedFinal.awayScore} ${completedFinal.awayTeamName}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8)),
                          ),
                          if (runnerUpName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '🥈 Runner-Up: $runnerUpName',
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (championTeamId != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFF334155)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamProfileScreen(
                              teamId: championTeamId!, viewAs: UserRole.viewer),
                        ),
                      ),
                      icon: const Icon(Icons.shield_outlined,
                          size: 16, color: Color(0xFFD2B059)),
                      label: const Text('View Champion Club Profile →',
                          style: TextStyle(
                              color: Color(0xFFD2B059),
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        backgroundColor:
                            const Color(0xFFD2B059).withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Tournament Stage Progression Steps Header
        if (sortedStages.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                ...availableStageFilters.map((stage) {
                  final isSelected = activeFilter == stage;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(stage),
                      selectedColor: NasaColors.pitch,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : NasaColors.textMain,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      checkmarkColor: Colors.white,
                      onSelected: (_) => setState(() => _selectedStage = stage),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (displayMatches.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: NasaColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NasaColors.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 36, color: NasaColors.gold),
                  SizedBox(height: 8),
                  Text(
                    'No knockout matches scheduled for this competition yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NasaColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Render stages - all fixtures of each round grouped in ONE card
          ...sortedStages
              .where(
                  (stg) => activeFilter == 'All Stages' || activeFilter == stg)
              .map((stg) {
            final matches = matchesByStage[stg] ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: NasaColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NasaColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stage Header (One single header for all fixtures in this stage)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: NasaColors.pitchDark.withValues(alpha: 0.04),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(13)),
                      border: const Border(
                          bottom: BorderSide(color: NasaColors.line)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.military_tech_outlined,
                            size: 18, color: NasaColors.pitch),
                        const SizedBox(width: 8),
                        Text(
                          stg.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: NasaColors.textMain,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: NasaColors.pitch.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${matches.length} fixture${matches.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: NasaColors.pitch,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List all fixtures in this round
                  ...matches.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final match = entry.value;
                    final isLast = idx == matches.length - 1;
                    return Column(
                      children: [
                        _KnockoutFixtureRow(
                          match: match,
                          fixtureIndex: idx + 1,
                          totalInRound: matches.length,
                        ),
                        if (!isLast)
                          const Divider(height: 1, color: NasaColors.line),
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KNOCKOUT FIXTURE ROW (within unified round card)
// ─────────────────────────────────────────────────────────────────────────────
class _KnockoutFixtureRow extends StatelessWidget {
  final Match match;
  final int fixtureIndex;
  final int totalInRound;
  const _KnockoutFixtureRow({
    required this.match,
    required this.fixtureIndex,
    required this.totalInRound,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live;
    final isFT = match.status == MatchStatus.fullTime;
    final isFinal = match.stage.toLowerCase() == 'final';
    final homeShootoutScore = match.events
        .where((event) =>
            event.type == 'Shootout Goal' &&
            event.teamName == match.homeTeamName)
        .length;
    final awayShootoutScore = match.events
        .where((event) =>
            event.type == 'Shootout Goal' &&
            event.teamName == match.awayTeamName)
        .length;
    final hasShootout = homeShootoutScore > 0 || awayShootoutScore > 0;
    final homeWon = isFT &&
        (match.homeScore > match.awayScore ||
            (match.homeScore == match.awayScore &&
                homeShootoutScore > awayShootoutScore));
    final awayWon = isFT &&
        (match.awayScore > match.homeScore ||
            (match.homeScore == match.awayScore &&
                awayShootoutScore > homeShootoutScore));
    final group = match.groupName;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatchDetailScreen(matchId: match.id, viewAs: UserRole.viewer),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Micro Header (Fixture #, venue/kickoff/live)
            Row(
              children: [
                if (totalInRound > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: NasaColors.pitchDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Fixture #$fixtureIndex',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: NasaColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (group != null && group.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      group,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (match.venue.isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      match.venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          color: NasaColors.slate,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (isLive) ...[
                  const LiveBadge(),
                  const SizedBox(width: 5),
                  Text('${match.minute}\'',
                      style: const TextStyle(
                          color: NasaColors.crimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ] else if (isFT)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isFinal
                          ? const Color(0xFFD2B059).withValues(alpha: 0.2)
                          : NasaColors.pitchDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isFinal ? 'FINAL COMPLETED' : 'FULL TIME',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isFinal ? NasaColors.gold : NasaColors.textMuted,
                      ),
                    ),
                  )
                else
                  Text(
                    formatShortDate(match.kickoff),
                    style: const TextStyle(
                        fontSize: 11,
                        color: NasaColors.slate,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Home Team Row
            _teamRow(
              name: match.homeTeamName,
              score: match.homeScore,
              isWinner: homeWon,
              isLoser: isFT && awayWon,
              isFinal: isFinal,
              stage: match.stage,
              isLiveOrFT: isLive || isFT,
            ),
            const SizedBox(height: 6),
            // Away Team Row
            _teamRow(
              name: match.awayTeamName,
              score: match.awayScore,
              isWinner: awayWon,
              isLoser: isFT && homeWon,
              isFinal: isFinal,
              stage: match.stage,
              isLiveOrFT: isLive || isFT,
            ),
            if (hasShootout)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: NasaColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: NasaColors.gold.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'Penalties: $homeShootoutScore – $awayShootoutScore',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: NasaColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamRow({
    required String name,
    required int score,
    required bool isWinner,
    required bool isLoser,
    required bool isFinal,
    required String stage,
    required bool isLiveOrFT,
  }) {
    final isTbd = name.startsWith('TBD') || name == 'tbd';

    String badgeText = '';
    Color badgeBg = const Color(0xFFD2B059).withValues(alpha: 0.15);
    Color badgeFg = const Color(0xFFB45309);

    if (!isTbd && isWinner) {
      if (isFinal) {
        badgeText = 'WINNER';
        badgeBg = const Color(0xFFD2B059).withValues(alpha: 0.25);
        badgeFg = const Color(0xFF92400E);
      } else if (stage.toLowerCase() == 'semi-final') {
        badgeText = 'TO FINAL →';
        badgeBg = const Color(0xFF16A34A).withValues(alpha: 0.15);
        badgeFg = const Color(0xFF166534);
      } else {
        badgeText = 'ADVANCES';
        badgeBg = const Color(0xFFD2B059).withValues(alpha: 0.15);
        badgeFg = const Color(0xFFB45309);
      }
    } else if (!isTbd && isLoser && isFinal) {
      badgeText = 'RUNNER-UP';
      badgeBg = const Color(0xFF94A3B8).withValues(alpha: 0.2);
      badgeFg = const Color(0xFF475569);
    }

    return Row(
      children: [
        if (!isTbd && isWinner)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              isFinal ? Icons.emoji_events : Icons.arrow_right,
              size: 18,
              color: const Color(0xFFD2B059),
            ),
          )
        else
          const SizedBox(width: 4),
        Expanded(
          child: Text(
            isTbd ? 'TBD — Awaiting Opponent' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isWinner && !isTbd
                  ? FontWeight.w900
                  : (isLiveOrFT && !isTbd ? FontWeight.w600 : FontWeight.w700),
              fontSize: isTbd ? 12 : 13.5,
              fontStyle: isTbd ? FontStyle.italic : FontStyle.normal,
              color: isTbd
                  ? NasaColors.slate
                  : (isWinner ? NasaColors.gold : NasaColors.textMain),
            ),
          ),
        ),
        if (badgeText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(badgeText,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w900, color: badgeFg)),
          ),
        if (isTbd)
          const Text('—',
              style: TextStyle(color: NasaColors.slate, fontSize: 13))
        else if (isLiveOrFT)
          Container(
            constraints: const BoxConstraints(minWidth: 26),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner
                  ? const Color(0xFFD2B059).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$score',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
                fontSize: 15,
                color: isWinner ? NasaColors.gold : NasaColors.textMain,
              ),
            ),
          )
        else
          const Text('—', style: TextStyle(color: NasaColors.slate)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM TABLE ROW (for Standard Table)
// ─────────────────────────────────────────────────────────────────────────────
class _TeamTableRow extends StatelessWidget {
  final int index;
  final Team team;
  const _TeamTableRow({required this.index, required this.team});

  @override
  Widget build(BuildContext context) {
    final isLeader = index == 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TeamProfileScreen(teamId: team.id, viewAs: UserRole.viewer),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isLeader
              ? NasaColors.gold.withValues(alpha: 0.1)
              : NasaColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLeader ? NasaColors.gold : NasaColors.border,
            width: isLeader ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isLeader ? NasaColors.gold : Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          team.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isLeader ? NasaColors.gold : Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLeader) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.emoji_events,
                            size: 13, color: NasaColors.gold),
                      ],
                    ],
                  ),
                  Text(
                    team.wardName,
                    style: const TextStyle(
                        fontSize: 10.5, color: NasaColors.slate),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              child: Text('${team.played}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
            ),
            _tableValue(team.won),
            _tableValue(team.drawn),
            _tableValue(team.lost),
            _tableValue(team.goalsFor),
            _tableValue(team.goalsAgainst),
            SizedBox(
              width: 32,
              child: Text(
                '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${team.points}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isLeader ? NasaColors.gold : Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableValue(int value) => SizedBox(
        width: 22,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _LeaguePlayerStatsSection extends StatefulWidget {
  final String? leagueId;
  const _LeaguePlayerStatsSection({this.leagueId});

  @override
  State<_LeaguePlayerStatsSection> createState() =>
      _LeaguePlayerStatsSectionState();
}

class _LeaguePlayerStatsSectionState extends State<_LeaguePlayerStatsSection> {
  int _selectedTab = 0; // 0: Goals, 1: Assists, 2: Clean Sheets
  String? _lastStatsDebugSignature;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final leaguePlayers = widget.leagueId == null
        ? <Player>[]
        : (app.playerStatsByCompetition[widget.leagueId] ?? <Player>[]);

    List<Player> players;
    String statSuffix;
    int Function(Player) statValue;

    switch (_selectedTab) {
      case 1:
        players = [...leaguePlayers]
          ..sort((a, b) => b.assists.compareTo(a.assists));
        players = players.where((p) => p.assists > 0).take(5).toList();
        statSuffix = 'assists';
        statValue = (p) => p.assists;
        break;
      case 2:
        players = [...leaguePlayers]..sort((a, b) {
            if (b.cleanSheets != a.cleanSheets)
              return b.cleanSheets.compareTo(a.cleanSheets);
            return b.appearances.compareTo(a.appearances);
          });
        players = players
            .where((p) {
              final pos = p.position.toLowerCase();
              return pos.contains('goal') ||
                  pos.contains('gk') ||
                  p.cleanSheets > 0;
            })
            .take(5)
            .toList();
        statSuffix = 'clean sheets';
        statValue = (p) => p.cleanSheets;
        break;
      default:
        players = [...leaguePlayers]
          ..sort((a, b) => b.goals.compareTo(a.goals));
        players = players.where((p) => p.goals > 0).take(5).toList();
        statSuffix = 'goals';
        statValue = (p) => p.goals;
        break;
    }

    if (kDebugMode) {
      final signature =
          '${widget.leagueId ?? 'none'}:$_selectedTab:${leaguePlayers.map((p) => '${p.id}=${p.goals}/${p.assists}/${p.appearances}').join(',')}';
      if (_lastStatsDebugSignature != signature) {
        _lastStatsDebugSignature = signature;
        debugPrint('[STANDINGS LEADERBOARD] competition=${widget.leagueId} '
            'tab=$_selectedTab players=${leaguePlayers.length} '
            'display=${players.map((p) => '${p.name}:${statValue(p)} $statSuffix').join(', ')}');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: NasaColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NasaColors.border),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTab(0, 'Top Scorers', Icons.sports_soccer),
              _buildTab(1, 'Top Assists', Icons.assistant_outlined),
              _buildTab(2, 'Clean Sheets', Icons.cleaning_services_outlined),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (widget.leagueId == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('Choose a league or cup to view its leaders.',
                  style: TextStyle(color: NasaColors.slate, fontSize: 13)),
            ),
          )
        else if (players.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                  'No recorded player stats for this category in this competition yet.',
                  style: TextStyle(color: NasaColors.slate, fontSize: 13)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: NasaColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NasaColors.border),
            ),
            child: Column(
              children: players.asMap().entries.map((entry) {
                final index = entry.key;
                final player = entry.value;
                final count = statValue(player);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InitialsAvatar(
                    text: player.name,
                    radius: 18,
                    imageUrl: player.imageUrl,
                  ),
                  title: Text(
                    '${index + 1}. ${player.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Colors.white),
                  ),
                  subtitle: Text(
                    '${player.teamName} · ${player.position}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: NasaColors.slate),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NasaColors.crimson.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: NasaColors.crimson.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$count $statSuffix',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: NasaColors.crimson,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerProfileScreen(
                        playerId: player.id,
                        viewAs: UserRole.viewer,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? NasaColors.crimson : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? Colors.white : NasaColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color:
                              active ? Colors.white : NasaColors.textMuted))),
            ],
          ),
        ),
      ),
    );
  }
}
