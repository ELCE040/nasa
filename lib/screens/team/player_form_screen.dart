import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class PlayerFormScreen extends StatefulWidget {
  const PlayerFormScreen({super.key});
  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _jerseyCtrl = TextEditingController();
  final _heightCtrl = TextEditingController(text: '1.65');
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+265 9');
  String _position = 'Striker';
  String _foot = 'Right';

  static const _positions = [
    'Goalkeeper',
    'Defender',
    'Midfielder',
    'Winger',
    'Striker'
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final team = app.teamById(app.myTeamId)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add player'),
        actions: const [RoleSwitcherButton()],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Registering to ${team.name} (${team.wardName})',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (v) =>
                        (int.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _jerseyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jersey #'),
                    validator: (v) =>
                        (int.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _position,
              decoration: const InputDecoration(labelText: 'Position'),
              items: _positions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _position = v ?? _position),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _foot,
                    decoration:
                        const InputDecoration(labelText: 'Preferred foot'),
                    items: const [
                      DropdownMenuItem(value: 'Right', child: Text('Right')),
                      DropdownMenuItem(value: 'Left', child: Text('Left')),
                    ],
                    onChanged: (v) => setState(() => _foot = v ?? _foot),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (m)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Emergency contact phone'),
              validator: (v) =>
                  (v == null || v.trim().length < 6) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Short bio'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  app.addPlayer(
                    name: _nameCtrl.text.trim(),
                    age: int.parse(_ageCtrl.text),
                    position: _position,
                    teamId: team.id,
                    jerseyNumber: int.parse(_jerseyCtrl.text),
                    preferredFoot: _foot,
                    heightM: double.tryParse(_heightCtrl.text) ?? 1.65,
                    bio: _bioCtrl.text.trim().isEmpty
                        ? 'New squad member.'
                        : _bioCtrl.text.trim(),
                    parentPhone: _phoneCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                  showNasaSnack(
                      context, '${_nameCtrl.text.trim()} added to the roster');
                },
                child: const Text('Register player'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
