import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class SponsorshipScreen extends StatelessWidget {
  const SponsorshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsors'),
        actions: const [RoleSwitcherButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_sponsorship',
        icon: const Icon(Icons.volunteer_activism_outlined),
        label: const Text('Become a sponsor'),
        onPressed: () => _showContactDialog(context),
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              const Text('Our Sponsors',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 16),
              if (app.sponsorships.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sponsors yet. Be the first!', style: TextStyle(color: NasaColors.textMuted)),
                ),
              ...app.sponsorships.map((s) {
                final typeLabel = switch (s.type) {
                  SponsorshipType.teamAdoption => 'Team adoption',
                  SponsorshipType.tournamentPrizePool => 'Prize pool',
                  SponsorshipType.kitSponsorship => 'Kit sponsorship',
                };
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NasaColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NasaColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(s.sponsorName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15, color: Colors.white))),
                                if (s.isDiaspora)
                                  const StatusChip(
                                      label: 'Diaspora', color: NasaColors.gold),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('$typeLabel · ${s.targetName}',
                                style: const TextStyle(
                                    fontSize: 12.5, color: NasaColors.textMuted)),
                            if (s.message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('"${s.message}"',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontStyle: FontStyle.italic,
                                        color: NasaColors.textMain)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Become a sponsor'),
        content: const Text(
            'If you would like to sponsor a team or the league, please contact us at:\n\n'
            'Email: contact@naysasport.com\n'
            'Phone: +265 99 123 4567\n\n'
            'We appreciate your support!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
