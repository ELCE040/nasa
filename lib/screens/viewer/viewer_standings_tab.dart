import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../shared/team_profile_screen.dart';

class ViewerStandingsTab extends StatefulWidget {
  const ViewerStandingsTab({super.key});

  @override
  State<ViewerStandingsTab> createState() => _ViewerStandingsTabState();
}

class _ViewerStandingsTabState extends State<ViewerStandingsTab> {
  String _leagueId = 'default';

  static const _leagues = [
    _LeagueOption(id: 'default', label: 'Default League'),
    _LeagueOption(id: 'lilongwe', label: 'Lilongwe Ward League'),
    _LeagueOption(id: 'blantyre', label: 'Blantyre Ward League'),
    _LeagueOption(id: 'northern', label: 'Northern League'),
    _LeagueOption(id: 'zomba', label: 'Zomba League'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final standings = _standingsFor(app, _leagueId);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: DropdownButtonFormField<String>(
                initialValue: _leagueId,
                decoration: const InputDecoration(labelText: 'League'),
                items: _leagues
                    .map((league) => DropdownMenuItem(
                          value: league.id,
                          child: Text(league.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _leagueId = value);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: NasaColors.slate),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Team',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: NasaColors.slate),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      'P',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: NasaColors.slate),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      'GD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: NasaColors.slate),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      'Pts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: NasaColors.slate),
                    ),
                  ),
                ],
              ),
            ),
            if (standings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No teams in this league yet.',
                  style: TextStyle(color: NasaColors.slate),
                ),
              )
            else
              ...standings.asMap().entries.map((entry) {
                final i = entry.key;
                final team = entry.value;
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamProfileScreen(
                          teamId: team.id, viewAs: UserRole.viewer),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NasaColors.line),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
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
                              textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${team.points}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  List<Team> _standingsFor(AppState app, String leagueId) {
    final teams = app.standings.where((team) {
      return switch (leagueId) {
        'lilongwe' => {'w1', 'w2', 'w7'}.contains(team.wardId),
        'blantyre' => {'w3', 'w4', 'w6'}.contains(team.wardId),
        'northern' => team.wardId == 'w5',
        'zomba' => team.wardId == 'w8',
        _ => true,
      };
    }).toList();
    return teams;
  }
}

class _LeagueOption {
  final String id;
  final String label;

  const _LeagueOption({required this.id, required this.label});
}
