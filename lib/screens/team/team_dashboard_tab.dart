import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/match_detail_screen.dart';
import 'player_form_screen.dart';

class TeamDashboardTab extends StatefulWidget {
  const TeamDashboardTab({super.key});
  @override
  State<TeamDashboardTab> createState() => _TeamDashboardTabState();
}

class _TeamDashboardTabState extends State<TeamDashboardTab> {
  bool _savingLogo = false;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final team = app.currentTeam ?? app.teamById(app.myTeamId);
        if (team == null)
          return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Team not found',
              message: 'Sign in again to load your club.');
        final roster = app.playersOfTeam(team.id);
        final matches = app.matches
            .where((m) => m.homeTeamId == team.id || m.awayTeamId == team.id)
            .toList();
        final upcoming = matches
            .where((m) => m.status == MatchStatus.upcoming)
            .toList()
          ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
        final results = matches
            .where((m) => m.status == MatchStatus.fullTime)
            .toList()
          ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _ClubHeader(
                team: team,
                rosterSize: roster.length,
                saving: _savingLogo,
                onEdit: () => _changeLogo(team)),
            const SizedBox(height: 18),
            _CompetitionCard(team: team, app: app),
            if (team.leagueId.isNotEmpty) ...[
              const SectionHeader(title: 'League position'),
              _CompactStandings(team: team, app: app),
            ],
            if (upcoming.isNotEmpty) ...[
              const SectionHeader(title: 'Next fixture'),
              _MatchTile(
                  match: upcoming.first,
                  isResult: false,
                  onTap: () => _openMatch(upcoming.first)),
              _FixturesLink(
                  onTap: () => _openFixtures(team.id),
                  label: 'View all fixtures'),
            ],
            if (results.isNotEmpty) ...[
              const SectionHeader(title: 'Latest results'),
              ...results.take(3).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MatchTile(
                      match: m, isResult: true, onTap: () => _openMatch(m)))),
              _FixturesLink(
                  onTap: () => _openFixtures(team.id),
                  label: 'All fixtures & results'),
            ],
            const SectionHeader(title: 'Quick actions'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _ActionChip(
                  icon: Icons.person_add_alt,
                  label: 'Add player',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PlayerFormScreen()))),
              _ActionChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'Edit team logo',
                  onTap: _savingLogo ? () {} : () => _changeLogo(team)),
            ]),
          ],
        );
      },
    );
  }

  Future<void> _changeLogo(Team team) async {
    if (_savingLogo) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
          child: Wrap(children: [
        ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
        ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery)),
      ])),
    );
    if (source == null || !mounted) return;
    try {
      final file = await ImagePicker().pickImage(
          source: source, imageQuality: 90, maxWidth: 1600, maxHeight: 1600);
      if (file == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop team logo',
              toolbarColor: NasaColors.pitch,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true)
        ],
      );
      if (cropped == null || !mounted) return;
      setState(() => _savingLogo = true);
      final url = await ApiService.uploadPlayerImage(XFile(cropped.path));
      await ApiService.updateTeamLogo(url);
      await AppState.instance.loadTeamWorkspace();
      if (mounted) showNasaSnack(context, '${team.name} logo updated.');
    } catch (error) {
      debugPrint('[TEAM LOGO] $error');
      if (mounted)
        showNasaSnack(context, 'Could not update team logo: $error',
            success: false);
    } finally {
      if (mounted) setState(() => _savingLogo = false);
    }
  }

  void _openMatch(Match match) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MatchDetailScreen(matchId: match.id, viewAs: UserRole.team)));
  void _openFixtures(String teamId) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => _AllFixturesScreen(teamId: teamId)));
}

class _ClubHeader extends StatelessWidget {
  final Team team;
  final int rosterSize;
  final bool saving;
  final VoidCallback onEdit;
  const _ClubHeader(
      {required this.team,
      required this.rosterSize,
      required this.saving,
      required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final brandSecondary = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NasaColors.border),
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          InitialsAvatar(
              text: team.name,
              radius: 36,
              background: const Color(0xFF1E3A8A).withValues(alpha: 0.5),
              foreground: const Color(0xFF60A5FA),
              imageUrl: team.logoUrl),
          Positioned(
              right: -4,
              bottom: -4,
              child: Material(
                  color: brandSecondary,
                  shape: const CircleBorder(),
                  child: InkWell(
                      onTap: saving ? null : onEdit,
                      customBorder: const CircleBorder(),
                      child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.edit,
                                  size: 14, color: Colors.black))))),
        ]),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(team.name,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('${team.wardName} · Coach ${team.coachName}',
              style:
                  const TextStyle(color: NasaColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: NasaColors.navyDark,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: NasaColors.border),
            ),
            child: Text('$rosterSize registered players',
                style: TextStyle(
                    color: brandSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5)),
          ),
        ])),
      ]),
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  final Team team;
  final AppState app;
  const _CompetitionCard({required this.team, required this.app});
  @override
  Widget build(BuildContext context) {
    final isOut = app.teamEliminated;
    final brandPrimary = Theme.of(context).colorScheme.primary;
    final brandSecondary = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOut ? const Color(0xFF3B121A) : NasaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOut ? brandPrimary : NasaColors.border),
      ),
      child: Row(children: [
        Icon(isOut ? Icons.cancel_outlined : Icons.emoji_events_outlined,
            color: isOut ? brandPrimary : brandSecondary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              team.leagueName.isNotEmpty
                  ? team.leagueName
                  : 'No competition assigned',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 14)),
          const SizedBox(height: 3),
          Text(app.teamCompetitionStatus ?? 'Competition status is loading.',
              style: TextStyle(
                  fontSize: 12,
                  color:
                      isOut ? const Color(0xFFFCA5A5) : NasaColors.textMuted)),
        ])),
      ]),
    );
  }
}

class _CompactStandings extends StatelessWidget {
  final Team team;
  final AppState app;

  const _CompactStandings({required this.team, required this.app});

  @override
  Widget build(BuildContext context) {
    final standings = app.teamLeagueStandings
        .where((standing) => standing.leagueId == team.leagueId)
        .toList();
    final teamIndex =
        standings.indexWhere((standing) => standing.id == team.id);

    if (standings.isEmpty || teamIndex == -1) {
      return const SizedBox.shrink();
    }

    final start = standings.length <= 3
        ? 0
        : teamIndex == 0
            ? 0
            : teamIndex >= standings.length - 1
                ? standings.length - 3
                : teamIndex - 1;
    final visibleTeams = standings.skip(start).take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NasaColors.border),
      ),
      child: Column(
        children: [
          const _CompactStandingsHeader(),
          ...visibleTeams.asMap().entries.map((entry) {
            final standing = entry.value;
            final position = start + entry.key + 1;
            return _CompactStandingsRow(
              position: position,
              team: standing,
              isCurrentTeam: standing.id == team.id,
            );
          }),
        ],
      ),
    );
  }
}

class _CompactStandingsHeader extends StatelessWidget {
  const _CompactStandingsHeader();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 7),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('#', style: _compactHeaderStyle)),
            Expanded(child: Text('Team', style: _compactHeaderStyle)),
            SizedBox(
                width: 30,
                child: Text('P',
                    textAlign: TextAlign.center, style: _compactHeaderStyle)),
            SizedBox(
                width: 38,
                child: Text('GD',
                    textAlign: TextAlign.center, style: _compactHeaderStyle)),
            SizedBox(
                width: 38,
                child: Text('Pts',
                    textAlign: TextAlign.right, style: _compactHeaderStyle)),
          ],
        ),
      );
}

class _CompactStandingsRow extends StatelessWidget {
  final int position;
  final Team team;
  final bool isCurrentTeam;

  const _CompactStandingsRow({
    required this.position,
    required this.team,
    required this.isCurrentTeam,
  });

  @override
  Widget build(BuildContext context) {
    final brandSecondary = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentTeam
            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14)
            : Colors.transparent,
        border: Border(
          top: BorderSide(color: NasaColors.border.withValues(alpha: 0.65)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$position',
              style: TextStyle(
                color: isCurrentTeam ? brandSecondary : NasaColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrentTeam ? Colors.white : NasaColors.textMuted,
                fontWeight: isCurrentTeam ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text('${team.played}',
                textAlign: TextAlign.center, style: _compactValueStyle),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}',
              textAlign: TextAlign.center,
              style: _compactValueStyle,
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${team.points}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isCurrentTeam ? brandSecondary : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _compactHeaderStyle = TextStyle(
  color: NasaColors.slate,
  fontSize: 10,
  fontWeight: FontWeight.w800,
);

const _compactValueStyle = TextStyle(
  color: NasaColors.textMuted,
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

class _MatchTile extends StatelessWidget {
  final Match match;
  final bool isResult;
  final VoidCallback onTap;
  const _MatchTile(
      {required this.match, required this.isResult, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NasaColors.bgCard,
            border: Border.all(color: NasaColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${match.displayCompetition} · ${match.stage}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NasaColors.textMuted)),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                  child: Text(match.homeTeamName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NasaColors.navyDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: NasaColors.border),
                ),
                child: Text(
                    isResult ? '${match.homeScore} - ${match.awayScore}' : 'vs',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.secondary)),
              ),
              Expanded(
                  child: Text(match.awayTeamName,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13.5))),
            ]),
            const SizedBox(height: 8),
            Text(
                isResult
                    ? 'Full time · ${formatShortDate(match.kickoff)}'
                    : '${formatShortDate(match.kickoff)} · ${formatTime(match.kickoff)} · ${match.venue}',
                style: const TextStyle(
                    fontSize: 11.5, color: NasaColors.textMuted)),
          ]),
        ),
      );
}

class _FixturesLink extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _FixturesLink({required this.onTap, required this.label});
  @override
  Widget build(BuildContext context) {
    final brandPrimary = Theme.of(context).colorScheme.primary;
    return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(Icons.calendar_month_outlined, color: brandPrimary),
            label: Text(label,
                style: TextStyle(
                    color: brandPrimary, fontWeight: FontWeight.w800))));
  }
}

class _AllFixturesScreen extends StatelessWidget {
  final String teamId;
  const _AllFixturesScreen({required this.teamId});
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
        appBar: AppBar(title: const Text('Fixtures & results')),
        body: AnimatedBuilder(
            animation: app,
            builder: (_, __) {
              final matches = app.matches
                  .where(
                      (m) => m.homeTeamId == teamId || m.awayTeamId == teamId)
                  .toList()
                ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
              if (matches.isEmpty)
                return const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No fixtures yet',
                    message: 'Fixtures will appear here when scheduled.');
              return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _MatchTile(
                      match: matches[i],
                      isResult: matches[i].status == MatchStatus.fullTime,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MatchDetailScreen(
                                  matchId: matches[i].id,
                                  viewAs: UserRole.team)))));
            }));
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final brandPrimary = Theme.of(context).colorScheme.primary;
    return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: NasaColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NasaColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: brandPrimary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Colors.white))
            ])));
  }
}
