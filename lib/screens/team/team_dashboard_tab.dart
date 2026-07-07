import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/video_upload_dialog.dart';
import 'fixture_generator_screen.dart';
import 'player_form_screen.dart';

class TeamDashboardTab extends StatelessWidget {
  const TeamDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final team = app.teamById(app.myTeamId)!;
        final roster = app.playersOfTeam(team.id);
        final unpaidFines = app.disciplinary
            .where((d) => roster.any((p) => p.id == d.playerId) && !d.finePaid)
            .toList();
        final rank = app.standings.indexWhere((t) => t.id == team.id) + 1;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: NasaColors.pitch,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(team.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17)),
                      ),
                      _TeamSwitcher(currentId: team.id),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${team.wardName} · Coach ${team.coachName}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StatPill(label: 'League Pos.', value: '$rank'),
                      StatPill(label: 'Points', value: '${team.points}'),
                      StatPill(label: 'Squad', value: '${roster.length}'),
                      StatPill(
                          label: 'GD',
                          value:
                              '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}'),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Quick actions'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ActionChip(
                      icon: Icons.person_add_alt,
                      label: 'Add player',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlayerFormScreen()))),
                  _ActionChip(
                      icon: Icons.event_outlined,
                      label: 'Schedule fixture',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FixtureGeneratorScreen()))),
                  _ActionChip(
                      icon: Icons.videocam_outlined,
                      label: 'Upload clip',
                      onTap: () => showVideoUploadDialog(context)),
                ],
              ),
            ),
            if (unpaidFines.isNotEmpty) ...[
              const SectionHeader(title: 'Unpaid disciplinary fines'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: unpaidFines
                      .map((d) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NasaColors.line)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.playerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      Text(d.reason,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: NasaColors.slate)),
                                    ],
                                  ),
                                ),
                                Text(formatMwk(d.fineAmount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: NasaColors.earth)),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    app.markFinePaid(d.id);
                                    showNasaSnack(
                                        context, 'Fine marked as paid');
                                  },
                                  child: const Text('Mark paid'),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TeamSwitcher extends StatelessWidget {
  final String currentId;
  const _TeamSwitcher({required this.currentId});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
      tooltip: 'Switch managed club',
      onSelected: (id) => app.setMyTeam(id),
      itemBuilder: (context) => app.teams
          .map((t) => PopupMenuItem(value: t.id, child: Text(t.name)))
          .toList(),
    );
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NasaColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: NasaColors.pitch),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
