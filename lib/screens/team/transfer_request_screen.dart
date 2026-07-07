import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class TransferRequestScreen extends StatefulWidget {
  const TransferRequestScreen({super.key});
  @override
  State<TransferRequestScreen> createState() => _TransferRequestScreenState();
}

class _TransferRequestScreenState extends State<TransferRequestScreen> {
  final app = AppState.instance;
  late String _playerId;
  final _buyingTeamCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final roster = app.playersOfTeam(app.myTeamId);
    _playerId = roster.isNotEmpty ? roster.first.id : '';
  }

  @override
  Widget build(BuildContext context) {
    final roster = app.playersOfTeam(app.myTeamId);
    final fee = double.tryParse(_feeCtrl.text) ?? 0;
    final commission = fee * 0.15;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a transfer'),
        actions: const [RoleSwitcherButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Funds are held in escrow until clearance is released to the selling club, '
            'less a 15% platform commission.',
            style:
                TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 16),
          if (roster.isEmpty)
            const Text(
                'Add players to your roster before requesting a transfer.')
          else
            DropdownButtonFormField<String>(
              initialValue: _playerId,
              decoration: const InputDecoration(labelText: 'Player'),
              items: roster
                  .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _playerId = v ?? _playerId),
            ),
          const SizedBox(height: 12),
          TextField(
              controller: _buyingTeamCtrl,
              decoration: const InputDecoration(labelText: 'Buying club')),
          const SizedBox(height: 12),
          TextField(
            controller: _feeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Agreed fee (MWK)', prefixText: 'MWK '),
            onChanged: (_) => setState(() {}),
          ),
          if (fee > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EC),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform commission (15%): ${formatMwk(commission)}',
                      style: const TextStyle(fontSize: 12.5)),
                  Text('Net to your club: ${formatMwk(fee - commission)}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: roster.isEmpty
                  ? null
                  : () {
                      if (_buyingTeamCtrl.text.trim().isEmpty || fee <= 0) {
                        return;
                      }
                      app.requestTransfer(
                        playerId: _playerId,
                        buyingTeam: _buyingTeamCtrl.text.trim(),
                        agreedFeeMwk: fee,
                      );
                      Navigator.pop(context);
                      showNasaSnack(context,
                          'Transfer request created — escrow awaiting payment');
                    },
              child: const Text('Create transfer & open escrow'),
            ),
          ),
        ],
      ),
    );
  }
}
