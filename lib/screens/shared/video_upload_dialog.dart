import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

/// Shows a dialog to attach a short highlight clip's metadata to a player.
/// Field coordinators would attach the actual compressed video file in a
/// real implementation; this demo captures title/duration/match context.
void showVideoUploadDialog(BuildContext context, {String? presetPlayerId}) {
  final app = AppState.instance;
  final titleCtrl = TextEditingController();
  final durationCtrl = TextEditingController(text: '20');
  final matchCtrl = TextEditingController();
  String? selectedPlayerId = presetPlayerId ?? (app.players.isNotEmpty ? app.players.first.id : null);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Upload highlight clip'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (presetPlayerId == null)
                DropdownButtonFormField<String>(
                  initialValue: selectedPlayerId,
                  decoration: const InputDecoration(labelText: 'Player'),
                  items: app.players
                      .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} · ${p.teamName}')))
                      .toList(),
                  onChanged: (v) => setState(() => selectedPlayerId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Clip title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: matchCtrl,
                decoration: const InputDecoration(labelText: 'Match / session'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (seconds, max 30)',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Clips over 30 seconds will be compressed and trimmed automatically.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (selectedPlayerId == null || titleCtrl.text.trim().isEmpty) return;
              final duration = int.tryParse(durationCtrl.text) ?? 20;
              app.uploadVideoClip(
                playerId: selectedPlayerId!,
                title: titleCtrl.text.trim(),
                durationSeconds: duration > 30 ? 30 : duration,
                matchLabel: matchCtrl.text.trim().isEmpty ? 'Training session' : matchCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              showNasaSnack(context, 'Clip attached to player profile');
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    ),
  );
}
