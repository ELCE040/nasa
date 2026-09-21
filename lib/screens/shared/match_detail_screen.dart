import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../team/referee_rating_screen.dart';

// ─── Formation config (position-based inference) ─────────────────────────────

class _FormationConfig {
  final String label;
  final List<String> rowLabels;
  final List<int> rowCounts;
  final List<bool Function(String)> rowMatchers;
  const _FormationConfig({
    required this.label,
    required this.rowLabels,
    required this.rowCounts,
    required this.rowMatchers,
  });
}

final _formationConfigs = <String, _FormationConfig>{
  '4-4-2': _FormationConfig(
    label: '4-4-2',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [4, 4, 2],
    rowMatchers: [
      (p) =>
          p.contains('def') ||
          p.contains('cb') ||
          p.contains('lb') ||
          p.contains('rb') ||
          p.contains('back'),
      (p) =>
          p.contains('mid') ||
          p.contains('cm') ||
          p.contains('dm') ||
          p.contains('am') ||
          p.contains('wing') ||
          p.contains('rw') ||
          p.contains('lw'),
      (p) =>
          p.contains('strik') ||
          p.contains('fw') ||
          p.contains('att') ||
          p.contains('cf') ||
          p.contains('forward'),
    ],
  ),
  '4-3-3': _FormationConfig(
    label: '4-3-3',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [4, 3, 3],
    rowMatchers: [
      (p) =>
          p.contains('def') ||
          p.contains('cb') ||
          p.contains('lb') ||
          p.contains('rb') ||
          p.contains('back'),
      (p) =>
          p.contains('mid') ||
          p.contains('cm') ||
          p.contains('dm') ||
          p.contains('am'),
      (p) =>
          p.contains('strik') ||
          p.contains('fw') ||
          p.contains('att') ||
          p.contains('cf') ||
          p.contains('forward') ||
          p.contains('wing') ||
          p.contains('rw') ||
          p.contains('lw'),
    ],
  ),
  '4-2-3-1': _FormationConfig(
    label: '4-2-3-1',
    rowLabels: ['Defenders', 'Defensive Mids', 'Attacking Mids', 'Attackers'],
    rowCounts: [4, 2, 3, 1],
    rowMatchers: [
      (p) =>
          p.contains('def') ||
          p.contains('cb') ||
          p.contains('lb') ||
          p.contains('rb') ||
          p.contains('back'),
      (p) => p.contains('dm') || p.contains('cm'),
      (p) =>
          p.contains('am') ||
          p.contains('wing') ||
          p.contains('rw') ||
          p.contains('lw'),
      (p) =>
          p.contains('strik') ||
          p.contains('fw') ||
          p.contains('att') ||
          p.contains('cf') ||
          p.contains('forward'),
    ],
  ),
  '3-5-2': _FormationConfig(
    label: '3-5-2',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [3, 5, 2],
    rowMatchers: [
      (p) =>
          p.contains('def') ||
          p.contains('cb') ||
          p.contains('lb') ||
          p.contains('rb') ||
          p.contains('back'),
      (p) =>
          p.contains('mid') ||
          p.contains('cm') ||
          p.contains('dm') ||
          p.contains('am') ||
          p.contains('wing') ||
          p.contains('rw') ||
          p.contains('lw'),
      (p) =>
          p.contains('strik') ||
          p.contains('fw') ||
          p.contains('att') ||
          p.contains('cf') ||
          p.contains('forward'),
    ],
  ),
  '5-3-2': _FormationConfig(
    label: '5-3-2',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [5, 3, 2],
    rowMatchers: [
      (p) =>
          p.contains('def') ||
          p.contains('cb') ||
          p.contains('lb') ||
          p.contains('rb') ||
          p.contains('back'),
      (p) =>
          p.contains('mid') ||
          p.contains('cm') ||
          p.contains('dm') ||
          p.contains('am') ||
          p.contains('wing') ||
          p.contains('rw') ||
          p.contains('lw'),
      (p) =>
          p.contains('strik') ||
          p.contains('fw') ||
          p.contains('att') ||
          p.contains('cf') ||
          p.contains('forward'),
    ],
  ),
};

/// Guesses the best formation label for a group of 10 outfield starters.
String _inferFormationLabel(List<Player> outfield) {
  int defenders = 0, midfielders = 0, attackers = 0;
  for (final p in outfield) {
    final pos = p.position.toLowerCase();
    if (pos.contains('def') ||
        pos.contains('cb') ||
        pos.contains('back') ||
        pos.contains('lb') ||
        pos.contains('rb')) {
      defenders++;
    } else if (pos.contains('strik') ||
        pos.contains('forward') ||
        pos.contains('att') ||
        pos.contains('cf') ||
        pos.contains('fw')) {
      attackers++;
    } else {
      midfielders++;
    }
  }
  // Map common combos to formation labels
  final key = '$defenders-$midfielders-$attackers';
  const knownFormations = {
    '4-4-2': '4-4-2',
    '4-3-3': '4-3-3',
    '3-5-2': '3-5-2',
    '5-3-2': '5-3-2',
    '4-2-4': '4-3-3',
    '3-4-3': '4-3-3',
  };
  return knownFormations[key] ?? '4-4-2';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  final UserRole viewAs;
  const MatchDetailScreen(
      {super.key, required this.matchId, required this.viewAs});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _showHomeTeam = true;
  bool _loadingLineups = false;
  List<String> _homeLineupIds = [];
  List<String> _awayLineupIds = [];
  String _homeFormation = '4-4-2';
  String _awayFormation = '4-4-2';
  bool _lineupsFetched = false;
  String? _lineupError;

  @override
  void initState() {
    super.initState();
    _fetchLineups();
  }

  Future<void> _fetchLineups() async {
    if (_loadingLineups) return;
    print('[Lineup] ▶ _fetchLineups called for matchId=${widget.matchId}');
    setState(() {
      _loadingLineups = true;
      _lineupError = null;
    });
    try {
      print('[Lineup] Calling ApiService.fetchMatchLineups...');
      final data = await ApiService.fetchMatchLineups(widget.matchId);
      print(
          '[Lineup] ✅ Response: home=${data["home"]} (${data["homeFormation"]}) away=${data["away"]} (${data["awayFormation"]})');
      if (mounted) {
        setState(() {
          _homeLineupIds = List<String>.from(data['home'] ?? []);
          _awayLineupIds = List<String>.from(data['away'] ?? []);
          _homeFormation = (data['homeFormation'] ?? '4-4-2').toString();
          _awayFormation = (data['awayFormation'] ?? '4-4-2').toString();
          _lineupsFetched = true;
          _loadingLineups = false;
        });
        print(
            '[Lineup] State updated — homeIds=${_homeLineupIds.length} awayIds=${_awayLineupIds.length}');
      } else {
        print(
            '[Lineup] ⚠️ Widget unmounted before setState — lineups not applied');
      }
    } catch (e, st) {
      print('[Lineup] ❌ fetchMatchLineups FAILED: $e');
      print('[Lineup] Stacktrace: $st');
      if (mounted) {
        setState(() {
          _lineupError = 'Could not load lineups: $e';
          _loadingLineups = false;
          _lineupsFetched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        Match? match;
        for (final m in app.matches) {
          if (m.id == widget.matchId) match = m;
        }
        if (match == null) {
          print(
              '[Lineup] ❌ Match not found for id=${widget.matchId}. Total matches=${app.matches.length}');
          return const Scaffold(body: Center(child: Text('Match not found')));
        }
        // Keep a non-null reference for callbacks below; Dart does not retain
        // nullable-variable promotion inside closures.
        final currentMatch = match;
        print(
            '[Lineup] Build — match=${match.homeTeamName} vs ${match.awayTeamName}');
        print(
            '[Lineup]   homeTeamId=${match.homeTeamId}  awayTeamId=${match.awayTeamId}');
        print(
            '[Lineup]   _homeLineupIds=$_homeLineupIds  _awayLineupIds=$_awayLineupIds');
        print(
            '[Lineup]   _loadingLineups=$_loadingLineups  _lineupsFetched=$_lineupsFetched');

        final events = [...match.events]
          ..sort((a, b) => a.minute.compareTo(b.minute));
        // Shootout goals are deliberately separate from the normal match score.
        // They decide a tied knockout match but must never change 90/120-minute goals.
        final homeShootoutScore = events
            .where((event) =>
                event.type == 'Shootout Goal' &&
                event.teamName == currentMatch.homeTeamName)
            .length;
        final awayShootoutScore = events
            .where((event) =>
                event.type == 'Shootout Goal' &&
                event.teamName == currentMatch.awayTeamName)
            .length;
        final hasShootoutResult =
            homeShootoutScore > 0 || awayShootoutScore > 0;

        final homePlayers = app.playersOfTeam(match.homeTeamId)
          ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
        final awayPlayers = app.playersOfTeam(match.awayTeamId)
          ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
        print(
            '[Lineup]   homePlayers=${homePlayers.length}  awayPlayers=${awayPlayers.length}');
        if (homePlayers.isNotEmpty)
          print(
              '[Lineup]   homePlayer IDs sample: ${homePlayers.take(3).map((p) => p.id).toList()}');

        // For team role: merge their own lineup IDs if server hasn't returned any yet
        List<String> effectiveHomeIds = _homeLineupIds;
        List<String> effectiveAwayIds = _awayLineupIds;
        if (widget.viewAs == UserRole.team) {
          final myId = app.myTeamId;
          final myIds = app.lineupForMatch(match.id);
          print(
              '[Lineup]   viewAs=team myTeamId=$myId savedLineup=${myIds.length} ids');
          if (myId == match.homeTeamId && effectiveHomeIds.isEmpty)
            effectiveHomeIds = myIds;
          if (myId == match.awayTeamId && effectiveAwayIds.isEmpty)
            effectiveAwayIds = myIds;
        }

        final selectedLineupIds =
            _showHomeTeam ? effectiveHomeIds : effectiveAwayIds;
        final selectedPlayers = _showHomeTeam ? homePlayers : awayPlayers;
        final selectedTeamName =
            _showHomeTeam ? match.homeTeamName : match.awayTeamName;
        final selectedFormation =
            _showHomeTeam ? _homeFormation : _awayFormation;

        print(
            '[Lineup]   showHomeTeam=$_showHomeTeam  selectedLineupIds=$selectedLineupIds');
        List<Player> starters = selectedPlayers
            .where((p) => selectedLineupIds.contains(p.id))
            .toList();
        List<Player> subs = selectedPlayers
            .where((p) => !selectedLineupIds.contains(p.id))
            .toList();

        // Automatic fallback: If no custom lineup was saved yet, use top 11 registered players as starters
        if (starters.isEmpty && selectedPlayers.isNotEmpty) {
          starters = selectedPlayers.take(11).toList();
          subs = selectedPlayers.skip(11).toList();
        }
        if (widget.viewAs != UserRole.team && kDebugMode) {
          final photoCount = starters
              .where((player) =>
                  player.imageUrl != null &&
                  player.imageUrl!.trim().isNotEmpty &&
                  player.imageUrl != 'null')
              .length;
          debugPrint(
              '[FAN LINEUP IMAGE] $selectedTeamName: $photoCount/${starters.length} starter photo URL(s); roster=${selectedPlayers.length}.');
        }

        // Apply in-match substitutions to update the active on-pitch 11 and bench
        for (final ev in events) {
          if (ev.type == 'Substitution' && ev.teamName == selectedTeamName) {
            final parts =
                ev.playerName.split(RegExp(r'\s*(?:→|->|&rarr;|\?)\s*'));
            if (parts.length >= 2) {
              final outName = parts[0].trim().toLowerCase();
              final inName = parts[1].trim().toLowerCase();

              final outIdx = starters
                  .indexWhere((p) => p.name.trim().toLowerCase() == outName);
              final inIdx =
                  subs.indexWhere((p) => p.name.trim().toLowerCase() == inName);

              if (outIdx != -1 && inIdx != -1) {
                final subbedOutPlayer = starters[outIdx];
                final subbedInPlayer = subs[inIdx];
                starters[outIdx] = subbedInPlayer;
                subs[inIdx] = subbedOutPlayer;
              } else if (outIdx != -1) {
                final incomingPlayer = selectedPlayers.firstWhere(
                  (p) => p.name.trim().toLowerCase() == inName,
                  orElse: () => starters[outIdx],
                );
                if (incomingPlayer != starters[outIdx]) {
                  final subbedOutPlayer = starters[outIdx];
                  starters[outIdx] = incomingPlayer;
                  subs.removeWhere((p) => p.id == incomingPlayer.id);
                  if (!subs.any((p) => p.id == subbedOutPlayer.id)) {
                    subs.add(subbedOutPlayer);
                  }
                }
              }
            }
          }
        }
        print('[Lineup]   starters=${starters.length}  subs=${subs.length}');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Match details'),
            actions: const [RoleSwitcherButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ── Score header ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  decoration: BoxDecoration(
                    color: NasaColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NasaColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        match.displayCompetition,
                        style: const TextStyle(
                            color: NasaColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                              child: _TeamColumn(
                            name: match.homeTeamName,
                            logoUrl: app.teamById(match.homeTeamId)?.logoUrl,
                          )),
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
                                  child: Text(
                                      "${match.minute}' · ${match.phase}",
                                      style: const TextStyle(
                                          color: NasaColors.textMuted,
                                          fontSize: 12)),
                                ),
                              if (match.status == MatchStatus.fullTime)
                                const Text('Full time',
                                    style: TextStyle(
                                        color: NasaColors.textMuted,
                                        fontSize: 12)),
                              if (match.status == MatchStatus.postponed)
                                const Text('Postponed',
                                    style: TextStyle(
                                        color: NasaColors.crimson,
                                        fontSize: 12)),
                            ],
                          ),
                          Expanded(
                              child: _TeamColumn(
                            name: match.awayTeamName,
                            logoUrl: app.teamById(match.awayTeamId)?.logoUrl,
                          )),
                        ],
                      ),
                      if (match.status == MatchStatus.fullTime &&
                          match.playerOfMatchName != null &&
                          match.playerOfMatchName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: NasaColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      NasaColors.gold.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              '⭐ Player of the Match: ${match.playerOfMatchName}',
                              style: const TextStyle(
                                  color: NasaColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      if (hasShootoutResult)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: NasaColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      NasaColors.gold.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              'Penalties: $homeShootoutScore – $awayShootoutScore',
                              style: const TextStyle(
                                color: NasaColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Match info ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NasaColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NasaColors.border),
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

              // ── Match events ───────────────────────────────────────────────
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
                        'Goal' || 'Own Goal' => Icons.sports_soccer,
                        'Shootout Goal' => Icons.check_circle_outline,
                        'Shootout Miss' => Icons.cancel_outlined,
                        'Yellow Card' => Icons.square,
                        'Red Card' => Icons.square,
                        _ => Icons.swap_horiz,
                      };
                      final color = switch (e.type) {
                        // Regular goals are green; reserve red for own goals.
                        'Goal' => NasaColors.green,
                        'Own Goal' || 'Shootout Miss' => NasaColors.earth,
                        'Shootout Goal' => NasaColors.pitch,
                        'Yellow Card' => NasaColors.sun,
                        'Red Card' => NasaColors.earth,
                        _ => NasaColors.slate,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text("${e.minute}'",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      height: 1.4,
                                      color: NasaColors.textMain)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: e.type == 'Substitution'
                                  ? _buildSubstitutionEvent(e)
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: NasaColors.textMain),
                                            children: [
                                              TextSpan(
                                                  text: e.playerName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              if (e.type == 'Shootout Goal' ||
                                                  e.type == 'Shootout Miss')
                                                TextSpan(
                                                    text:
                                                        ' · Penalty shootout ${e.type == 'Shootout Goal' ? 'scored' : 'missed'}',
                                                    style: const TextStyle(
                                                        color: NasaColors.earth,
                                                        fontWeight:
                                                            FontWeight.w600))
                                              else if (e.isPenalty)
                                                const TextSpan(
                                                    text: ' (Pen)',
                                                    style: TextStyle(
                                                        color: NasaColors.earth,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              TextSpan(
                                                  text: ' · ${e.teamName}',
                                                  style: const TextStyle(
                                                      color: NasaColors.slate)),
                                            ],
                                          ),
                                        ),
                                        if (e.assistName != null &&
                                            e.assistName!.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                                'Assist: ${e.assistName}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: NasaColors.slate)),
                                          ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),

              // ── Lineups section ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Lineups',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        if (_loadingLineups) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ] else if (_lineupsFetched) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _fetchLineups,
                            child: const Icon(Icons.refresh,
                                size: 18, color: NasaColors.slate),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Team toggle ──────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: NasaColors.pitchDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TeamToggleBtn(
                              label: match.homeTeamName,
                              isSelected: _showHomeTeam,
                              onTap: () => setState(() => _showHomeTeam = true),
                              hasLineup: effectiveHomeIds.isNotEmpty,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _TeamToggleBtn(
                              label: match.awayTeamName,
                              isSelected: !_showHomeTeam,
                              onTap: () =>
                                  setState(() => _showHomeTeam = false),
                              hasLineup: effectiveAwayIds.isNotEmpty,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Lineup content for selected team ─────────────────────
                    if (_lineupError != null)
                      Center(
                        child: Text(_lineupError!,
                            style: const TextStyle(
                                color: NasaColors.slate, fontSize: 13)),
                      )
                    else if (starters.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: NasaColors.pitchDark.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.groups_outlined,
                                size: 40,
                                color: NasaColors.slate.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'No registered players or lineup available for $selectedTeamName.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: NasaColors.slate, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // ── Pitch formation view ─────────────────────────────
                      _PitchFormationView(
                        starters: starters,
                        teamName: selectedTeamName,
                        chosenFormation: selectedFormation,
                      ),
                      const SizedBox(height: 18),

                      // ── Subs bench ───────────────────────────────────────
                      Text('Substitutes (${subs.length})',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (subs.isEmpty)
                        const Text('No substitute data available.',
                            style: TextStyle(
                                color: NasaColors.slate, fontSize: 13))
                      else
                        ...subs.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  InitialsAvatar(
                                      text: p.name,
                                      radius: 16,
                                      imageUrl: p.imageUrl),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('#${p.jerseyNumber} ${p.name}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13)),
                                        Text(p.position,
                                            style: const TextStyle(
                                                color: NasaColors.slate,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ],
                ),
              ),

              // ── Referee rating (team only, full time) ──────────────────────
              if (widget.viewAs == UserRole.team &&
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

  Widget _buildSubstitutionEvent(MatchEvent e) {
    final raw = e.playerName.trim();
    String outPlayer = '';
    String inPlayer = '';

    // Split on various possible delimiters (Unicode arrow, ASCII arrow, question mark from latin1 encoding, or slash)
    if (raw.contains('→')) {
      final parts = raw.split('→');
      outPlayer = parts[0].trim();
      inPlayer = parts.length > 1 ? parts[1].trim() : '';
    } else if (raw.contains('->')) {
      final parts = raw.split('->');
      outPlayer = parts[0].trim();
      inPlayer = parts.length > 1 ? parts[1].trim() : '';
    } else if (raw.contains('?')) {
      final parts = raw.split('?');
      outPlayer = parts[0].trim();
      inPlayer = parts.length > 1 ? parts[1].trim() : '';
    } else if (raw.contains('/')) {
      final parts = raw.split('/');
      outPlayer = parts[0].trim();
      inPlayer = parts.length > 1 ? parts[1].trim() : '';
    } else {
      if (e.assistName != null && e.assistName!.isNotEmpty) {
        outPlayer = e.assistName!.trim();
        inPlayer = raw;
      } else {
        inPlayer = raw;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inPlayer.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.arrow_upward_rounded,
                  size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              const Text('IN: ',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A))),
              Flexible(
                child: Text(
                  inPlayer,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: NasaColors.textMain),
                ),
              ),
            ],
          ),
        if (outPlayer.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.arrow_downward_rounded,
                  size: 14, color: Color(0xFFDC2626)),
              const SizedBox(width: 4),
              const Text('OUT: ',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626))),
              Flexible(
                child: Text(
                  outPlayer,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: NasaColors.textMain),
                ),
              ),
              Text(' · ${e.teamName}',
                  style:
                      const TextStyle(fontSize: 11.5, color: NasaColors.slate)),
            ],
          ),
        ] else ...[
          Text(' · ${e.teamName}',
              style: const TextStyle(fontSize: 11.5, color: NasaColors.slate)),
        ],
      ],
    );
  }
}

// ─── Team toggle button ───────────────────────────────────────────────────────

class _TeamToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool hasLineup;
  final VoidCallback onTap;
  const _TeamToggleBtn({
    required this.label,
    required this.isSelected,
    required this.hasLineup,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? NasaColors.pitch : NasaColors.bgCardMuted,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? NasaColors.pitch : NasaColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isSelected ? Colors.white : NasaColors.textMain,
                ),
              ),
            ),
            if (!hasLineup) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline,
                  size: 13,
                  color: isSelected ? Colors.white70 : NasaColors.slate),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Pitch formation view (read-only) ─────────────────────────────────────────

class _PitchFormationView extends StatelessWidget {
  final List<Player> starters;
  final String teamName;
  final String? chosenFormation;

  const _PitchFormationView({
    required this.starters,
    required this.teamName,
    this.chosenFormation,
  });

  List<Player?> _buildSlots(
      _FormationConfig formation, Player? gk, List<Player> outfield) {
    final rows = List.generate(formation.rowCounts.length, (_) => <Player>[]);
    final leftovers = <Player>[];

    for (final player in outfield) {
      final pos = player.position.toLowerCase();
      var matched = false;
      for (var row = 0; row < formation.rowMatchers.length; row++) {
        if (formation.rowMatchers[row](pos)) {
          if (rows[row].length < formation.rowCounts[row]) {
            rows[row].add(player);
            matched = true;
            break;
          }
        }
      }
      if (!matched) leftovers.add(player);
    }

    for (final player in leftovers) {
      for (var row = 0; row < rows.length; row++) {
        if (rows[row].length < formation.rowCounts[row]) {
          rows[row].add(player);
          break;
        }
      }
    }

    final slots = <Player?>[];
    for (var row = 0; row < formation.rowCounts.length; row++) {
      for (var i = 0; i < formation.rowCounts[row]; i++) {
        slots.add(i < rows[row].length ? rows[row][i] : null);
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final gkList = starters
        .where((p) => p.position.toLowerCase().contains('goal'))
        .toList();
    final gk = gkList.isNotEmpty
        ? gkList.first
        : (starters.isNotEmpty ? starters.first : null);
    final outfield = starters.where((p) => p.id != gk?.id).toList();

    final formationLabel = (chosenFormation != null &&
            _formationConfigs.containsKey(chosenFormation))
        ? chosenFormation!
        : _inferFormationLabel(outfield);
    final formation =
        _formationConfigs[formationLabel] ?? _formationConfigs['4-4-2']!;
    final outfieldSlots = _buildSlots(formation, gk, outfield);

    // Build row-level slot groups
    final rowSlots = <List<Player?>>[];
    var idx = 0;
    for (final count in formation.rowCounts) {
      rowSlots.add(outfieldSlots.sublist(idx, idx + count));
      idx += count;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Formation label
        Row(
          children: [
            const Icon(Icons.grid_view_rounded,
                size: 15, color: NasaColors.slate),
            const SizedBox(width: 6),
            Text('Formation: $formationLabel',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NasaColors.pitchDark)),
          ],
        ),
        const SizedBox(height: 10),
        // Green pitch
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2d7a3a), Color(0xFF1e5a28)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              // Attacker rows → GK at bottom (reading as pitch from attack to defense)
              for (var row = rowSlots.length - 1; row >= 0; row--) ...[
                _PitchRow(
                  label: formation.rowLabels[row],
                  players: rowSlots[row],
                ),
                const SizedBox(height: 12),
              ],
              // GK
              _PitchRow(label: 'Goalkeeper', players: [gk]),
            ],
          ),
        ),
      ],
    );
  }
}

class _PitchRow extends StatelessWidget {
  final String label;
  final List<Player?> players;
  const _PitchRow({required this.label, required this.players});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: players.map((p) => _PlayerToken(player: p)).toList(),
        ),
      ],
    );
  }
}

class _PlayerToken extends StatelessWidget {
  final Player? player;
  const _PlayerToken({this.player});

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return const SizedBox(
        width: 60,
        child: Column(children: [
          CircleAvatar(radius: 20, backgroundColor: Colors.white12),
          SizedBox(height: 4),
          Text('—', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      );
    }
    final p = player!;
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              InitialsAvatar(
                text: p.name,
                radius: 20,
                background: Colors.white,
                foreground: NasaColors.pitch,
                imageUrl: p.imageUrl,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: NasaColors.sun,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${p.jerseyNumber}',
                  style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _shortName(p.name),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.2),
          ),
        ],
      ),
    );
  }

  static String _shortName(String full) {
    final parts = full.trim().split(' ');
    if (parts.length == 1) return full;
    return '${parts.first[0]}. ${parts.last}';
  }
}

// ─── Re-used small widgets ────────────────────────────────────────────────────

class _TeamColumn extends StatelessWidget {
  final String name;
  final String? logoUrl;
  const _TeamColumn({required this.name, this.logoUrl});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InitialsAvatar(
          text: name,
          radius: 22,
          background: Colors.white,
          foreground: NasaColors.pitch,
          imageUrl: logoUrl,
        ),
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
