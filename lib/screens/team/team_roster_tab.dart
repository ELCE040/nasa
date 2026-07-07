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
        final roster = app.playersOfTeam(app.myTeamId)
          ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.person_add_alt),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NasaColors.line)),
                      child: ListTile(
                        leading: InitialsAvatar(text: p.name, radius: 20),
                        title: Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: Text(
                            '#${p.jerseyNumber} · ${p.position} · Age ${p.age}',
                            style: const TextStyle(fontSize: 11.5)),
                        trailing: const Icon(Icons.chevron_right),
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
