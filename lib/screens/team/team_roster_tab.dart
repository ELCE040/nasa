import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/player_profile_screen.dart';
import 'player_form_screen.dart';

class TeamRosterTab extends StatelessWidget {
  const TeamRosterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final brandPrimary = Theme.of(context).colorScheme.primary;
        final roster = app.playersOfTeam(app.myTeamId)
          ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab_roster',
            backgroundColor: brandPrimary,
            foregroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.add, size: 28),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PlayerFormScreen())),
          ),
          body: roster.isEmpty
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No players yet',
                  message: 'Add your first player to get started.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: roster.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = roster[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: NasaColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: NasaColors.border),
                      ),
                      child: ListTile(
                        leading: InitialsAvatar(
                            text: p.name, radius: 20, imageUrl: p.imageUrl),
                        title: Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.white)),
                        subtitle: Text(
                            '#${p.jerseyNumber} · ${p.position} · Age ${p.age}',
                            style: const TextStyle(
                                fontSize: 12, color: NasaColors.textMuted)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit player',
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.white),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerFormScreen(player: p),
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: NasaColors.textMuted),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlayerProfileScreen(
                                  playerId: p.id, viewAs: UserRole.team)),
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
