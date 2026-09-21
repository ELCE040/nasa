import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LineupEditorScreen extends StatefulWidget {
  final Match? match;
  const LineupEditorScreen({super.key, this.match});

  @override
  State<LineupEditorScreen> createState() => _LineupEditorScreenState();
}

class FormationConfig {
  final String label;
  final List<String> rowLabels;
  final List<int> rowCounts;
  final List<bool Function(String)> rowMatchers;

  const FormationConfig({
    required this.label,
    required this.rowLabels,
    required this.rowCounts,
    required this.rowMatchers,
  });
}

final _formations = {
  '4-4-2': FormationConfig(
    label: '4-4-2',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [4, 4, 2],
    rowMatchers: [
      (position) => position.contains('def') || position.contains('cb') || position.contains('lb') || position.contains('rb'),
      (position) => position.contains('mid') || position.contains('cm') || position.contains('dm') || position.contains('am') || position.contains('wing') || position.contains('rw') || position.contains('lw'),
      (position) => position.contains('strik') || position.contains('fw') || position.contains('att') || position.contains('cf') || position.contains('forward'),
    ],
  ),
  '4-3-3': FormationConfig(
    label: '4-3-3',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [4, 3, 3],
    rowMatchers: [
      (position) => position.contains('def') || position.contains('cb') || position.contains('lb') || position.contains('rb'),
      (position) => position.contains('mid') || position.contains('cm') || position.contains('dm') || position.contains('am') || position.contains('wing') || position.contains('rw') || position.contains('lw'),
      (position) => position.contains('strik') || position.contains('fw') || position.contains('att') || position.contains('cf') || position.contains('forward'),
    ],
  ),
  '3-5-2': FormationConfig(
    label: '3-5-2',
    rowLabels: ['Defenders', 'Midfielders', 'Attackers'],
    rowCounts: [3, 5, 2],
    rowMatchers: [
      (position) => position.contains('def') || position.contains('cb') || position.contains('lb') || position.contains('rb'),
      (position) => position.contains('mid') || position.contains('cm') || position.contains('dm') || position.contains('am') || position.contains('wing') || position.contains('rw') || position.contains('lw'),
      (position) => position.contains('strik') || position.contains('fw') || position.contains('att') || position.contains('cf') || position.contains('forward'),
    ],
  ),
  '4-2-3-1': FormationConfig(
    label: '4-2-3-1',
    rowLabels: ['Defenders', 'Defensive mids', 'Attacking mids', 'Attackers'],
    rowCounts: [4, 2, 3, 1],
    rowMatchers: [
      (position) => position.contains('def') || position.contains('cb') || position.contains('lb') || position.contains('rb'),
      (position) => position.contains('dm') || position.contains('cm'),
      (position) => position.contains('am') || position.contains('wing') || position.contains('rw') || position.contains('lw'),
      (position) => position.contains('strik') || position.contains('fw') || position.contains('att') || position.contains('cf') || position.contains('forward'),
    ],
  ),
};

class _DraggedPlayer {
  final Player player;
  final String source;
  final int? row;
  final int? index;

  _DraggedPlayer({
    required this.player,
    required this.source,
    this.row,
    this.index,
  });
}

class _LineupEditorScreenState extends State<LineupEditorScreen> {
  late Set<String> _selected;
  bool _saving = false;
  String _selectedFormation = '4-4-2';
  Player? _gkSlot;
  late List<Player?> _outfieldSlots;

  @override
  void initState() {
    super.initState();
    final app = AppState.instance;
    _selected = app.lineupForMatch(widget.match?.id ?? '').toSet();
    final roster = app.playersOfTeam(app.myTeamId);
    _initializeSlots(roster);
  }

  Future<void> _save() async {
    if (_selected.length != 11) {
      showNasaSnack(context, 'Select exactly 11 starting players.');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppState.instance.saveLineup(_selected.toList(), matchId: widget.match?.id, formation: _selectedFormation);
      if (mounted) {
        showNasaSnack(context, widget.match == null ? 'Default starting XI saved' : 'Fixture lineup saved');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showNasaSnack(context, 'Could not save lineup. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _positionOrder(String position) {
    switch (position) {
      case 'Goalkeeper':
        return 0;
      case 'Defender':
        return 1;
      case 'Midfielder':
        return 2;
      case 'Winger':
        return 3;
      case 'Striker':
        return 4;
      default:
        return 5;
    }
  }

  void _initializeSlots(List<Player> roster) {
    final formation = _formations[_selectedFormation]!;
    final selectedPlayers = roster.where((p) => _selected.contains(p.id)).toList();

    final gkPlayers = selectedPlayers.where((p) => p.position.toLowerCase().contains('goal')).toList();
    _gkSlot = gkPlayers.isNotEmpty ? gkPlayers.first : null;

    final outfieldPlayers = selectedPlayers.where((p) => p.id != _gkSlot?.id).toList();
    _outfieldSlots = _assignOutfieldSlots(outfieldPlayers, formation);
  }

  void _refreshSelectedFromSlots() {
    final ids = <String>{};
    if (_gkSlot != null) ids.add(_gkSlot!.id);
    for (final player in _outfieldSlots) {
      if (player != null) ids.add(player.id);
    }
    _selected = ids;
  }

  void _toggleSelection(Player player) {
    setState(() {
      if (_selected.contains(player.id)) {
        if (_gkSlot?.id == player.id) {
          _gkSlot = null;
        }
        for (var i = 0; i < _outfieldSlots.length; i++) {
          if (_outfieldSlots[i]?.id == player.id) {
            _outfieldSlots[i] = null;
          }
        }
      } else {
        if (_gkSlot == null) {
          _gkSlot = player;
        } else {
          final emptyIndex = _outfieldSlots.indexWhere((slot) => slot == null);
          if (emptyIndex == -1) {
            showNasaSnack(context, 'Remove one starter before adding another.');
            return;
          }
          _outfieldSlots[emptyIndex] = player;
        }
      }
      _refreshSelectedFromSlots();
    });
  }

  List<Player?> _assignOutfieldSlots(List<Player> players, FormationConfig formation) {
    final rows = List.generate(formation.rowCounts.length, (_) => <Player>[]);
    final leftovers = <Player>[];

    for (final player in players) {
      final normalized = player.position.toLowerCase();
      var matched = false;
      for (var row = 0; row < formation.rowMatchers.length; row++) {
        if (formation.rowMatchers[row](normalized)) {
          if (rows[row].length < formation.rowCounts[row]) {
            rows[row].add(player);
          } else {
            leftovers.add(player);
          }
          matched = true;
          break;
        }
      }
      if (!matched) {
        leftovers.add(player);
      }
    }

    for (final player in leftovers) {
      for (var row = 0; row < rows.length; row++) {
        if (rows[row].length < formation.rowCounts[row]) {
          rows[row].add(player);
          break;
        }
      }
    }

    final slots = <Player?>[];
    for (var row = 0; row < formation.rowCounts.length; row++) {
      final rowPlayers = rows[row];
      for (var i = 0; i < formation.rowCounts[row]; i++) {
        slots.add(i < rowPlayers.length ? rowPlayers[i] : null);
      }
    }
    return slots;
  }

  void _handleDrop(_DraggedPlayer drag, String dest, int? destRow, int destIndex) {
    setState(() {
      final droppedPlayer = drag.player;
      final fromSub = drag.source == 'sub';
      final fromGk = drag.source == 'gk';
      final fromOutfield = drag.source == 'slot';

      if (dest == 'gk') {
        final oldGk = _gkSlot;
        _gkSlot = droppedPlayer;
        if (fromOutfield && drag.index != null) {
          _outfieldSlots[drag.index!] = oldGk;
        }
        if (fromSub && oldGk != null) {
          final emptyIndex = _outfieldSlots.indexWhere((slot) => slot == null);
          if (emptyIndex >= 0) {
            _outfieldSlots[emptyIndex] = oldGk;
          }
        }
      } else if (dest == 'sub') {
        if (fromGk) {
          _gkSlot = null;
        }
        if (fromOutfield && drag.index != null) {
          _outfieldSlots[drag.index!] = null;
        }
      } else {
        final oldSlotPlayer = _outfieldSlots[destIndex];
        if (fromGk) {
          _gkSlot = oldSlotPlayer;
          _outfieldSlots[destIndex] = droppedPlayer;
        } else if (fromSub) {
          _outfieldSlots[destIndex] = droppedPlayer;
        } else if (fromOutfield && drag.index != null) {
          _outfieldSlots[drag.index!] = oldSlotPlayer;
          _outfieldSlots[destIndex] = droppedPlayer;
        }
      }

      _refreshSelectedFromSlots();
    });
  }

  Widget _buildPitchSlot({
    Player? player,
    required String label,
    required VoidCallback onTap,
    required String dest,
    int? destRow,
    required int destIndex,
  }) {
    Widget slotBody() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player != null)
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: NasaColors.gold, width: 2), // Starting 11 Gold glow
                      boxShadow: [
                        BoxShadow(
                          color: NasaColors.gold.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: InitialsAvatar(
                      text: player.name,
                      radius: 17,
                      imageUrl: player.imageUrl,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: NasaColors.navyDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${player.jerseyNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        color: NasaColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    player.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.2,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white60, size: 18),
              ),
          ],
        ),
      );
    }

    return DragTarget<_DraggedPlayer>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _handleDrop(details.data, dest, destRow, destIndex),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? NasaColors.crimson.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: player != null
              ? LongPressDraggable<_DraggedPlayer>(
                  data: _DraggedPlayer(player: player, source: dest, row: destRow, index: destIndex),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: NasaColors.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: NasaColors.gold),
                      ),
                      child: slotBody(),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: GestureDetector(onTap: onTap, child: slotBody())),
                  child: GestureDetector(onTap: onTap, child: slotBody()),
                )
              : GestureDetector(onTap: onTap, child: slotBody()),
        );
      },
    );
  }

  Widget _buildPitchRow(String title, List<Player?> slots, int rowIndex, int rowStart, {MainAxisAlignment alignment = MainAxisAlignment.center}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = math.min(76.0, (constraints.maxWidth - (slots.length - 1) * 8) / slots.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: alignment,
              children: [
                for (var i = 0; i < slots.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: slotWidth,
                      child: _buildPitchSlot(
                        player: slots[i],
                        label: slots[i] == null ? 'Tap to assign' : slots[i]!.position,
                        onTap: slots[i] == null ? () {} : () => _toggleSelection(slots[i]!),
                        dest: 'slot',
                        destRow: rowIndex,
                        destIndex: rowStart + i,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _benchPlayerCard(Player player) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSelection(player),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: NasaColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NasaColors.border),
          ),
          child: Row(
            children: [
              InitialsAvatar(text: player.name, radius: 18, imageUrl: player.imageUrl),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('#${player.jerseyNumber} · ${player.position}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: NasaColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, color: NasaColors.crimson, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final roster = app.playersOfTeam(app.myTeamId)
      ..sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    final isFixture = widget.match != null;
    final selectedPlayers = roster.where((player) => _selected.contains(player.id)).toList()
      ..sort((a, b) {
        final order = _positionOrder(a.position).compareTo(_positionOrder(b.position));
        return order != 0 ? order : a.jerseyNumber.compareTo(b.jerseyNumber);
      });
    final substitutePlayers = roster.where((player) => !_selected.contains(player.id)).toList();

    final formation = _formations[_selectedFormation]!;
    final gkSlots = [_gkSlot];
    final rowSlots = <List<Player?>>[];
    final rowStarts = <int>[];
    var index = 0;
    for (var rowCount in formation.rowCounts) {
      rowStarts.add(index);
      rowSlots.add(_outfieldSlots.sublist(index, index + rowCount));
      index += rowCount;
    }

    return Scaffold(
      backgroundColor: NasaColors.navy,
      appBar: AppBar(
        backgroundColor: NasaColors.navy,
        title: Text(isFixture ? 'Fixture Lineup' : 'Default Lineup'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NasaColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NasaColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFixture ? '${widget.match!.homeTeamName} vs ${widget.match!.awayTeamName}' : 'Tactical Starting 11',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: selectedPlayers.length == 11
                            ? NasaColors.green.withValues(alpha: 0.2)
                            : NasaColors.crimson.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${selectedPlayers.length} / 11 Starters Selected',
                        style: TextStyle(
                          color: selectedPlayers.length == 11 ? NasaColors.green : NasaColors.crimson,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Tap a starter on the pitch to remove them, tap a substitute to add.',
                    style: TextStyle(color: NasaColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          Expanded(
            child: roster.isEmpty
                ? const EmptyState(icon: Icons.groups_outlined, title: 'No squad available', message: 'Add at least 11 players before setting a lineup.')
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          const Text('Formation:', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              items: _formations.keys
                                  .map((formation) => DropdownMenuItem(value: formation, child: Text(formation, style: const TextStyle(fontWeight: FontWeight.w700))))
                                  .toList(),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              initialValue: _selectedFormation,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedFormation = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ─── STYLIZED DEEP NAVY FOOTBALL PITCH ───
                      Container(
                        decoration: BoxDecoration(
                          color: NasaColors.navy, // Deep Navy Grass (#0d1623)
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: CustomPaint(
                            painter: const _TacticalPitchPainter(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var row = formation.rowLabels.length - 1; row >= 0; row--) ...[
                                    _buildPitchRow(formation.rowLabels[row], rowSlots[row], row + 1, rowStarts[row], alignment: MainAxisAlignment.spaceEvenly),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildPitchRow('Goalkeeper', gkSlots, 0, 0, alignment: MainAxisAlignment.center),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DragTarget<_DraggedPlayer>(
                        onWillAcceptWithDetails: (_) => true,
                        onAcceptWithDetails: (details) => _handleDrop(details.data, 'sub', null, 0),
                        builder: (context, candidateData, rejectedData) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Bench Substitutes (${substitutePlayers.length})',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                              if (candidateData.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, bottom: 8),
                                  child: Text('Drop here to move to bench', style: TextStyle(color: NasaColors.crimson, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 190,
                                child: GridView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: substitutePlayers.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    // Horizontal grids use the main axis for card width.
                                    // A fixed extent prevents narrow cards and text overflow.
                                    mainAxisExtent: 180,
                                  ),
                                  itemBuilder: (context, index) {
                                    final player = substitutePlayers[index];
                                    final card = _benchPlayerCard(player);
                                    return LongPressDraggable<_DraggedPlayer>(
                                      data: _DraggedPlayer(player: player, source: 'sub'),
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: SizedBox(width: 180, height: 82, child: _benchPlayerCard(player)),
                                      ),
                                      childWhenDragging: Opacity(opacity: 0.3, child: card),
                                      child: card,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving || roster.length < 11 ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save lineup'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticalPitchPainter extends CustomPainter {
  const _TacticalPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Pitch Outer Inset Boundary
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, w - 16, h - 16),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, linePaint);

    // Halfway Line
    canvas.drawLine(Offset(8, h / 2), Offset(w - 8, h / 2), linePaint);

    // Center Circle & Center Spot
    canvas.drawCircle(Offset(w / 2, h / 2), 34, linePaint);
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, fillPaint);

    // Top Penalty Area (Opponent)
    final topPenaltyRect = Rect.fromLTWH(w * 0.22, 8, w * 0.56, h * 0.16);
    canvas.drawRect(topPenaltyRect, linePaint);
    final topGoalAreaRect = Rect.fromLTWH(w * 0.35, 8, w * 0.30, h * 0.07);
    canvas.drawRect(topGoalAreaRect, linePaint);

    // Bottom Penalty Area (Defending / GK)
    final botPenaltyRect = Rect.fromLTWH(w * 0.22, h - 8 - (h * 0.16), w * 0.56, h * 0.16);
    canvas.drawRect(botPenaltyRect, linePaint);
    final botGoalAreaRect = Rect.fromLTWH(w * 0.35, h - 8 - (h * 0.07), w * 0.30, h * 0.07);
    canvas.drawRect(botGoalAreaRect, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
