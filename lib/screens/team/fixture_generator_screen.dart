import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class FixtureGeneratorScreen extends StatefulWidget {
  const FixtureGeneratorScreen({super.key});
  @override
  State<FixtureGeneratorScreen> createState() => _FixtureGeneratorScreenState();
}

class _FixtureGeneratorScreenState extends State<FixtureGeneratorScreen> {
  final app = AppState.instance;
  late String _awayTeamId;
  final _venueCtrl = TextEditingController();
  final _competitionCtrl = TextEditingController(text: 'Ward Youth League');
  final _distanceCtrl = TextEditingController();
  DateTime _kickoff = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    final home = app.teamById(app.myTeamId)!;
    _venueCtrl.text = '${home.wardName.split(' ').first} Community Ground';
    final candidates = app.teams.where((t) => t.id != app.myTeamId).toList();
    _awayTeamId = candidates.first.id;
    _suggestDistance();
  }

  void _suggestDistance() {
    final home = app.teamById(app.myTeamId)!;
    final away = app.teamById(_awayTeamId)!;
    // Simple deterministic heuristic: same ward/district = short hop,
    // otherwise a pseudo-distance derived from ward id codes so the
    // "pitch scheduler" can factor travel cost into fixture planning.
    double distance;
    if (home.wardId == away.wardId) {
      distance = 1.5;
    } else if (_districtOf(home.wardId) == _districtOf(away.wardId)) {
      distance = 4.0 + (home.wardId.hashCode % away.wardId.hashCode).abs() % 6;
    } else {
      distance =
          140.0 + (home.wardId.hashCode ^ away.wardId.hashCode).abs() % 160;
    }
    _distanceCtrl.text = distance.toStringAsFixed(1);
  }

  String _districtOf(String wardId) {
    final ward = app.wards
        .firstWhere((w) => w.id == wardId, orElse: () => app.wards.first);
    return ward.district;
  }

  @override
  Widget build(BuildContext context) {
    final home = app.teamById(app.myTeamId)!;
    final candidates = app.teams.where((t) => t.id != app.myTeamId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule a fixture'),
        actions: const [RoleSwitcherButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Home club: ${home.name}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _awayTeamId,
            decoration: const InputDecoration(labelText: 'Opponent'),
            items: candidates
                .map((t) => DropdownMenuItem(
                    value: t.id, child: Text('${t.name} (${t.wardName})')))
                .toList(),
            onChanged: (v) => setState(() {
              _awayTeamId = v ?? _awayTeamId;
              _suggestDistance();
            }),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _venueCtrl,
              decoration: const InputDecoration(labelText: 'Venue / pitch')),
          const SizedBox(height: 12),
          TextField(
              controller: _competitionCtrl,
              decoration:
                  const InputDecoration(labelText: 'Competition / round')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kickoff'),
            subtitle:
                Text('${formatShortDate(_kickoff)} · ${formatTime(_kickoff)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _distanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Estimated travel distance (km)'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.auto_awesome, size: 20),
                tooltip: 'Auto-suggest from ward locations',
                onPressed: _suggestDistance,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The scheduler factors travel distance between wards so clubs aren\'t '
            'asked to make costly long trips back-to-back.',
            style:
                TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final away = app.teamById(_awayTeamId)!;
                app.generateFixture(
                  homeTeamId: home.id,
                  awayTeamId: away.id,
                  venue: _venueCtrl.text.trim().isEmpty
                      ? '${home.wardName} Ground'
                      : _venueCtrl.text.trim(),
                  kickoff: _kickoff,
                  competition: _competitionCtrl.text.trim().isEmpty
                      ? 'Friendly'
                      : _competitionCtrl.text.trim(),
                  travelDistanceKm: double.tryParse(_distanceCtrl.text) ?? 0,
                );
                Navigator.pop(context);
                showNasaSnack(context, 'Fixture scheduled vs ${away.name}');
              },
              child: const Text('Confirm fixture'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _kickoff,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_kickoff));
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      _kickoff =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}
