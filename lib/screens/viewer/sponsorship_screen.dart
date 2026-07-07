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
        title: const Text('Sponsor a team'),
        actions: const [RoleSwitcherButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.volunteer_activism_outlined),
        label: const Text('Sponsor now'),
        onPressed: () => _showSponsorSheet(context),
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          final total =
              app.sponsorships.fold<double>(0, (s, x) => s + x.amountMwk);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NasaColors.pitch,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Raised across the league',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(formatMwk(total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(
                      'Adopt a team, fund a tournament prize pool, or sponsor kits — from Malawi or the diaspora.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Recent sponsors',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NasaColors.line),
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
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5))),
                                if (s.isDiaspora)
                                  const StatusChip(
                                      label: 'Diaspora', color: NasaColors.sun),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('$typeLabel · ${s.targetName}',
                                style: const TextStyle(
                                    fontSize: 11.5, color: NasaColors.slate)),
                            if (s.message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('"${s.message}"',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontStyle: FontStyle.italic,
                                        color: NasaColors.slate)),
                              ),
                          ],
                        ),
                      ),
                      Text(formatMwk(s.amountMwk),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: NasaColors.pitch)),
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

  void _showSponsorSheet(BuildContext context) {
    final app = AppState.instance;
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    SponsorshipType type = SponsorshipType.teamAdoption;
    String target = app.teams.first.name;
    bool isDiaspora = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sponsor a team or tournament',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 14),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Your name / organisation')),
                const SizedBox(height: 12),
                DropdownButtonFormField<SponsorshipType>(
                  initialValue: type,
                  decoration:
                      const InputDecoration(labelText: 'Sponsorship type'),
                  items: const [
                    DropdownMenuItem(
                        value: SponsorshipType.teamAdoption,
                        child: Text('Adopt a team')),
                    DropdownMenuItem(
                        value: SponsorshipType.tournamentPrizePool,
                        child: Text('Tournament prize pool')),
                    DropdownMenuItem(
                        value: SponsorshipType.kitSponsorship,
                        child: Text('Kit sponsorship')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration:
                      const InputDecoration(labelText: 'Team / tournament'),
                  items: app.teams
                      .map((t) =>
                          DropdownMenuItem(value: t.name, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setState(() => target = v ?? target),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Amount (MWK)', prefixText: 'MWK '),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: messageCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Message (optional)')),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isDiaspora,
                  title: const Text('Sending from the diaspora?'),
                  onChanged: (v) => setState(() => isDiaspora = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (nameCtrl.text.trim().isEmpty || amount <= 0) return;
                      app.addSponsorship(
                        sponsorName: nameCtrl.text.trim(),
                        isDiaspora: isDiaspora,
                        type: type,
                        targetName: target,
                        amountMwk: amount,
                        message: messageCtrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                      showNasaSnack(context,
                          'Thank you! Mobile money payment simulated and recorded on the public ledger.');
                    },
                    child: const Text('Confirm sponsorship'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
