import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'player_profile_screen.dart';

class TeamProfileScreen extends StatelessWidget {
  final String teamId;
  final UserRole viewAs;
  const TeamProfileScreen(
      {super.key, required this.teamId, required this.viewAs});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final team = app.teamById(teamId);
        if (team == null) {
          return const Scaffold(body: Center(child: Text('Team not found')));
        }
        final roster = app.playersOfTeam(teamId)
          ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
        final rank = app.standings.indexWhere((t) => t.id == teamId) + 1;

        return Scaffold(
          appBar: AppBar(
            title: Text(team.name),
            actions: const [RoleSwitcherButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Container(
                color: NasaColors.pitch,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Row(
                  children: [
                    InitialsAvatar(
                        text: team.name,
                        radius: 30,
                        background: Colors.white,
                        foreground: NasaColors.pitch),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(team.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('${team.wardName} · Founded ${team.foundedYear}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Text('Coach: ${team.coachName}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
                          if (team.sponsorName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Sponsor: ${team.sponsorName}',
                                  style: const TextStyle(
                                      color: NasaColors.sun,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NasaColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatPill(label: 'League Pos.', value: '$rank'),
                    StatPill(label: 'Points', value: '${team.points}'),
                    StatPill(
                        label: 'W-D-L',
                        value: '${team.won}-${team.drawn}-${team.lost}'),
                    StatPill(
                        label: 'GD',
                        value:
                            '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}'),
                  ],
                ),
              ),
              const SectionHeader(title: 'Squad'),
              ...roster.map((p) => ListTile(
                    leading: InitialsAvatar(text: p.name, radius: 18),
                    title: Text(p.name),
                    subtitle: Text(
                        '#${p.jerseyNumber} · ${p.position} · ${p.goals} goals'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerProfileScreen(playerId: p.id, viewAs: viewAs),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}
