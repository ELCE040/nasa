import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class DisciplinaryLogScreen extends StatelessWidget {
  const DisciplinaryLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final roster = app.playersOfTeam(app.myTeamId);
        final records = app.disciplinary
            .where((d) => roster.any((p) => p.id == d.playerId))
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Disciplinary log'),
            actions: const [RoleSwitcherButton()],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab_disciplinary',
            child: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, roster),
          ),
          body: records.isEmpty
              ? const EmptyState(
                  icon: Icons.gavel_outlined,
                  title: 'Clean sheet',
                  message: 'No cards or fines recorded for your squad.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = records[i];
                    final color = d.cardType == CardType.red
                        ? NasaColors.earth
                        : NasaColors.sun;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: NasaColors.line)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 14,
                              height: 18,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${d.playerName} · ${d.reason}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text(d.matchLabel,
                                    style: const TextStyle(
                                        fontSize: 11, color: NasaColors.slate)),
                                Text(formatShortDate(d.date),
                                    style: const TextStyle(
                                        fontSize: 11, color: NasaColors.slate)),
                                if (d.suspensionMatches > 0)
                                  Text(
                                      '${d.suspensionMatches} match suspension',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: NasaColors.earth,
                                          fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          if (d.fineAmount > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatMwk(d.fineAmount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                                if (!d.finePaid)
                                  TextButton(
                                    onPressed: () => app.markFinePaid(d.id),
                                    child: const Text('Mark paid',
                                        style: TextStyle(fontSize: 11)),
                                  )
                                else
                                  const StatusChip(
                                      label: 'Paid', color: NasaColors.pitch),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, List<Player> roster) {
    if (roster.isEmpty) {
      showNasaSnack(context, 'Add players to your roster first',
          success: false);
      return;
    }
    final app = AppState.instance;
    String playerId = roster.first.id;
    CardType cardType = CardType.yellow;
    final reasonCtrl = TextEditingController();
    final matchCtrl = TextEditingController();
    final suspensionCtrl = TextEditingController(text: '0');
    final fineCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add disciplinary record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: playerId,
                  decoration: const InputDecoration(labelText: 'Player'),
                  items: roster
                      .map((p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setState(() => playerId = v ?? playerId),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CardType>(
                  initialValue: cardType,
                  decoration: const InputDecoration(labelText: 'Card'),
                  items: const [
                    DropdownMenuItem(
                        value: CardType.yellow, child: Text('Yellow card')),
                    DropdownMenuItem(
                        value: CardType.red, child: Text('Red card')),
                  ],
                  onChanged: (v) => setState(() => cardType = v ?? cardType),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Reason')),
                const SizedBox(height: 12),
                TextField(
                    controller: matchCtrl,
                    decoration: const InputDecoration(labelText: 'Match')),
                const SizedBox(height: 12),
                TextField(
                    controller: suspensionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Suspension (matches)')),
                const SizedBox(height: 12),
                TextField(
                    controller: fineCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fine (MWK)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                app.addDisciplinaryRecord(
                  playerId: playerId,
                  matchLabel: matchCtrl.text.trim().isEmpty
                      ? 'Unspecified match'
                      : matchCtrl.text.trim(),
                  cardType: cardType,
                  reason: reasonCtrl.text.trim(),
                  suspensionMatches: int.tryParse(suspensionCtrl.text) ?? 0,
                  fineAmount: double.tryParse(fineCtrl.text) ?? 0,
                );
                Navigator.pop(ctx);
                showNasaSnack(context, 'Disciplinary record added');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
