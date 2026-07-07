import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class RefereeRatingScreen extends StatefulWidget {
  final String matchLabel;
  const RefereeRatingScreen({super.key, required this.matchLabel});

  @override
  State<RefereeRatingScreen> createState() => _RefereeRatingScreenState();
}

class _RefereeRatingScreenState extends State<RefereeRatingScreen> {
  final app = AppState.instance;
  late String _refereeId;
  int _fairness = 4;
  int _communication = 4;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refereeId = app.referees.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final team = app.teamById(app.myTeamId)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate the referee'),
        actions: const [RoleSwitcherButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.matchLabel,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text('Submitted by ${team.name}',
              style: const TextStyle(fontSize: 11.5, color: NasaColors.slate)),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _refereeId,
            decoration: const InputDecoration(labelText: 'Match official'),
            items: app.referees
                .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                .toList(),
            onChanged: (v) => setState(() => _refereeId = v ?? _refereeId),
          ),
          const SizedBox(height: 20),
          _ScoreSlider(
              label: 'Fairness of decisions',
              value: _fairness,
              onChanged: (v) => setState(() => _fairness = v)),
          const SizedBox(height: 16),
          _ScoreSlider(
              label: 'Communication & control',
              value: _communication,
              onChanged: (v) => setState(() => _communication = v)),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Comments (optional)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                app.addRefereeRating(
                  refereeId: _refereeId,
                  matchLabel: widget.matchLabel,
                  ratedByTeam: team.name,
                  fairnessScore: _fairness,
                  communicationScore: _communication,
                  comment: _commentCtrl.text.trim(),
                );
                Navigator.pop(context);
                showNasaSnack(context, 'Referee rating submitted');
              },
              child: const Text('Submit rating'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _ScoreSlider(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('$value / 5',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: NasaColors.pitch)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: NasaColors.pitch,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
