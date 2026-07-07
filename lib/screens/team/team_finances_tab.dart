import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../viewer/ledger_screen.dart';
import 'transfer_request_screen.dart';

class TeamFinancesTab extends StatelessWidget {
  const TeamFinancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final team = app.teamById(app.myTeamId)!;
        final mySponsorships = app.sponsorships.where((s) => s.targetName == team.name).toList();
        final myTransfers = app.transfers.where((t) => t.sellingTeam == team.name || t.buyingTeam == team.name).toList();
        final raised = mySponsorships.fold<double>(0, (s, x) => s + x.amountMwk);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: NasaColors.pitch, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sponsorship raised for your club', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(formatMwk(raised), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('View full public ledger'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen())),
            ),
            const SizedBox(height: 20),
            const Text('Sponsorships received', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            if (mySponsorships.isEmpty)
              const Text('No sponsorships recorded for this club yet.', style: TextStyle(color: NasaColors.slate, fontSize: 12.5))
            else
              ...mySponsorships.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: NasaColors.line)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.sponsorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text(formatShortDate(s.date), style: const TextStyle(fontSize: 11, color: NasaColors.slate)),
                            ],
                          ),
                        ),
                        Text(formatMwk(s.amountMwk), style: const TextStyle(fontWeight: FontWeight.w800, color: NasaColors.pitch)),
                      ],
                    ),
                  )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Player transfers (escrow)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferRequestScreen())),
                  child: const Text('Request transfer'),
                ),
              ],
            ),
            if (myTransfers.isEmpty)
              const Text('No transfers in progress.', style: TextStyle(color: NasaColors.slate, fontSize: 12.5))
            else
              ...myTransfers.map((t) => _EscrowCard(transfer: t)),
          ],
        );
      },
    );
  }
}

class _EscrowCard extends StatelessWidget {
  final TransferEscrow transfer;
  const _EscrowCard({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final statusLabel = switch (transfer.status) {
      EscrowStatus.awaitingPayment => 'Awaiting payment',
      EscrowStatus.fundsHeld => 'Funds held in escrow',
      EscrowStatus.clearanceReleased => 'Clearance released',
      EscrowStatus.completed => 'Completed',
    };
    final statusColor = switch (transfer.status) {
      EscrowStatus.awaitingPayment => NasaColors.slate,
      EscrowStatus.fundsHeld => NasaColors.sun,
      EscrowStatus.clearanceReleased => NasaColors.pitch,
      EscrowStatus.completed => NasaColors.pitchDark,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: NasaColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(transfer.playerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              StatusChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text('${transfer.sellingTeam} → ${transfer.buyingTeam}', style: const TextStyle(fontSize: 11.5, color: NasaColors.slate)),
          const SizedBox(height: 6),
          Text('Fee ${formatMwk(transfer.agreedFeeMwk)} · Commission ${formatMwk(transfer.commissionAmountMwk)} · Net ${formatMwk(transfer.netToSellingClubMwk)}',
              style: const TextStyle(fontSize: 11)),
          if (transfer.status != EscrowStatus.completed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => app.advanceEscrowStatus(transfer.id),
                child: Text(_nextActionLabel(transfer.status)),
              ),
            ),
        ],
      ),
    );
  }

  String _nextActionLabel(EscrowStatus s) {
    switch (s) {
      case EscrowStatus.awaitingPayment:
        return 'Mark funds received';
      case EscrowStatus.fundsHeld:
        return 'Release clearance';
      case EscrowStatus.clearanceReleased:
        return 'Mark completed';
      case EscrowStatus.completed:
        return '';
    }
  }
}
