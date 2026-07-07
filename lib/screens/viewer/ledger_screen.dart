import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public ledger'),
        actions: const [RoleSwitcherButton()],
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          final income = app.ledger
              .where((e) => e.type == LedgerType.income)
              .fold<double>(0, (s, e) => s + e.amountMwk);
          final expense = app.ledger
              .where((e) => e.type == LedgerType.expense)
              .fold<double>(0, (s, e) => s + e.amountMwk);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Every kwacha raised from registration fees and sponsors, and how it is spent on prizes, balls and equipment — open for the community to see.',
                style: TextStyle(
                    color: NasaColors.slate, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _Totals(
                          label: 'Total income',
                          value: income,
                          color: NasaColors.pitch)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Totals(
                          label: 'Total spent',
                          value: expense,
                          color: NasaColors.earth)),
                ],
              ),
              const SizedBox(height: 10),
              _Totals(
                  label: 'Net balance',
                  value: app.totalLedgerBalance,
                  color: NasaColors.ink,
                  full: true),
              const SizedBox(height: 18),
              const Text('Transaction history',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              ...app.ledger.map((e) {
                final isIncome = e.type == LedgerType.income;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NasaColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:
                              (isIncome ? NasaColors.pitch : NasaColors.earth)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 17,
                          color: isIncome ? NasaColors.pitch : NasaColors.earth,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.description,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('${e.category} · ${formatShortDate(e.date)}',
                                style: const TextStyle(
                                    fontSize: 11, color: NasaColors.slate)),
                          ],
                        ),
                      ),
                      Text(
                        '${isIncome ? '+' : '-'}${formatMwk(e.amountMwk)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                isIncome ? NasaColors.pitch : NasaColors.earth,
                            fontSize: 12.5),
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
}

class _Totals extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool full;
  const _Totals(
      {required this.label,
      required this.value,
      required this.color,
      this.full = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NasaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: NasaColors.slate,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(formatMwk(value),
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        ],
      ),
    );
  }
}
