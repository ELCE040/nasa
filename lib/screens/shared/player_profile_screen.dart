import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design System Color Tokens (Dark Scouting Theme matching Reference UI)
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeColors {
  static const bgDark = NasaColors.navy;
  static const cardDark = NasaColors.bgCard;
  static const blueAccent = NasaColors.crimson;
  static const textPrimary = Colors.white;
  static const textSecondary = NasaColors.textMain;
  static const textMuted = NasaColors.textMuted;
  static const borderDark = NasaColors.border;
}

class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final UserRole viewAs;
  const PlayerProfileScreen({
    super.key,
    required this.playerId,
    required this.viewAs,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final app = AppState.instance;
  String? _lastStatsDebugSignature;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final player = app.playerById(widget.playerId);
        if (player == null) {
          return Scaffold(
            backgroundColor: _ThemeColors.bgDark,
            appBar: AppBar(
              backgroundColor: _ThemeColors.bgDark,
              foregroundColor: _ThemeColors.textPrimary,
              elevation: 0,
            ),
            body: const Center(
              child: Text(
                'Player not found',
                style: TextStyle(color: _ThemeColors.textSecondary),
              ),
            ),
          );
        }

        if (kDebugMode) {
          final breakdown = app.playerGoalBreakdown[player.id] ?? const [];
          final signature =
              '${player.id}:${player.goals}:${player.assists}:${player.appearances}:${breakdown.map((row) => '${row['competition']}=${row['goals']}').join('|')}';
          if (_lastStatsDebugSignature != signature) {
            _lastStatsDebugSignature = signature;
            debugPrint('[PLAYER PROFILE] id=${player.id} name=${player.name} '
                'goals=${player.goals} assists=${player.assists} '
                'appearances=${player.appearances} '
                'goalBreakdown=$breakdown');
          }
        }

        final scoutRatings = app.getPlayerScoutRatings(player.id);
        final foot = player.preferredFoot.trim().toLowerCase();
        final isLeft = foot.contains('left');
        final isBoth = foot.contains('both') || foot.contains('ambi');
        final isRight = !isLeft && !isBoth;
        final isGk = player.position.toLowerCase().contains('goal') ||
            player.position.toLowerCase().contains('gk');

        return Scaffold(
          backgroundColor: NasaColors.navy,
          appBar: AppBar(
            backgroundColor: NasaColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'Naysasport',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: const [AppRefreshButton(), RoleSwitcherButton()],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'PLAYER PROFILE',
                    style: TextStyle(
                      color: NasaColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                // 1. Profile Identity Header
                _PlayerIdentityHeader(
                  player: player,
                  isLeft: isLeft,
                  isBoth: isBoth,
                  isRight: isRight,
                ),
                const SizedBox(height: 24),

                // 2. 6-Axis Radar / Attribute Polygon Chart
                _RadarAttributeChart(ratings: scoutRatings),
                const SizedBox(height: 24),

                // 3. Strong Foot Toggle Row
                _StrongFootSection(
                  isLeft: isLeft,
                  isBoth: isBoth,
                  isRight: isRight,
                ),
                const SizedBox(height: 20),

                // 4. Stats Summary Row (Goals, Assists, Fan Rating)
                _StatsSummaryRow(
                  player: player,
                  fanRating: scoutRatings.fanRating,
                  isGk: isGk,
                  onGoalsTap:
                      isGk ? null : () => _showGoalBreakdown(context, player),
                ),
                const SizedBox(height: 28),

                // 5. "Rate This Player" Button
                _RatePlayerButton(
                  onTap: () => _showRatingModal(context, player, scoutRatings),
                ),
                const SizedBox(height: 12),

                // 6. Community ratings footnote
                Text(
                  'Based on ${scoutRatings.totalVotes} ${scoutRatings.totalVotes == 1 ? 'person' : 'people'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ThemeColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRatingModal(
    BuildContext context,
    Player player,
    PlayerScoutRatingData currentRatings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RatePlayerBottomSheet(
        player: player,
        ratings: currentRatings,
      ),
    );
  }

  void _showGoalBreakdown(BuildContext context, Player player) {
    final rows = app.playerGoalBreakdown[player.id] ?? const [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NasaColors.bgCard,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Goals by competition',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text('No goal events have been recorded yet.',
                    style: TextStyle(color: NasaColors.textMuted))
              else
                ...rows.map((row) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sports_soccer,
                          color: NasaColors.gold),
                      title: Text(row['competition']?.toString() ?? 'Other',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      trailing: Text('${row['goals'] ?? 0}',
                          style: const TextStyle(
                              color: NasaColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Header Card (Avatar + Jersey #, Name, Position Badge, Team/Age, Foot)
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerIdentityHeader extends StatelessWidget {
  final Player player;
  final bool isLeft;
  final bool isBoth;
  final bool isRight;

  const _PlayerIdentityHeader({
    required this.player,
    required this.isLeft,
    required this.isBoth,
    required this.isRight,
  });

  String _positionCode(String pos) {
    final p = pos.toUpperCase();
    if (p.contains('GOAL') || p.contains('GK')) return 'GK';
    if (p.contains('FORWARD') || p.contains('STRIKER') || p.contains('CF'))
      return 'FW';
    if (p.contains('WING') || p.contains('LW') || p.contains('RW')) return 'FW';
    if (p.contains('MID')) return 'MF';
    if (p.contains('DEF') || p.contains('CB') || p.contains('BACK'))
      return 'DF';
    return p.length > 3 ? p.substring(0, 2) : p;
  }

  @override
  Widget build(BuildContext context) {
    final footDisplay = isBoth
        ? 'Both (Dual)'
        : isLeft
            ? 'Left (Preferred)'
            : 'Right (Preferred)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NasaColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with gold border glow
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: NasaColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: NasaColors.gold,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NasaColors.gold.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _PlayerPhoto(player: player),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: NasaColors.crimson,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${player.jerseyNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Text Info Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: NasaColors.crimson.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: NasaColors.crimson.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        _positionCode(player.position),
                        style: const TextStyle(
                          color: NasaColors.crimson,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${player.teamName}  •  ${player.age}y',
                  style: const TextStyle(
                    color: NasaColors.textMuted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.sports_soccer_rounded,
                        size: 13, color: NasaColors.gold),
                    const SizedBox(width: 5),
                    Text(
                      footDisplay,
                      style: const TextStyle(
                        color: NasaColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  player.wardName,
                  style: const TextStyle(
                      color: NasaColors.textLight, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPhoto extends StatelessWidget {
  final Player player;

  const _PlayerPhoto({required this.player});

  @override
  Widget build(BuildContext context) {
    final imageUrl = player.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return const Center(
        child: Icon(Icons.person_rounded, size: 42, color: NasaColors.gold),
      );
    }

    return Image.network(
      ApiService.resolveUrl(imageUrl),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.person_rounded, size: 42, color: NasaColors.gold),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Radar Chart Widget with Polygon Painter
// ─────────────────────────────────────────────────────────────────────────────
class _RadarAttributeChart extends StatelessWidget {
  final PlayerScoutRatingData ratings;

  const _RadarAttributeChart({required this.ratings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 320,
        height: 290,
        child: CustomPaint(
          painter: _HexagonRadarPainter(
            stats: [
              ratings.pace,
              ratings.shooting,
              ratings.passing,
              ratings.dribbling,
              ratings.defending,
              ratings.physical,
            ],
            labels: const [
              'Pace',
              'Shooting',
              'Passing',
              'Dribbling',
              'Defending',
              'Physical',
            ],
          ),
        ),
      ),
    );
  }
}

class _HexagonRadarPainter extends CustomPainter {
  final List<double> stats; // 6 stats out of 100
  final List<String> labels;

  const _HexagonRadarPainter({required this.stats, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width / 2) - 44;
    const sides = 6;
    const angleOffset = -math.pi / 2; // Pace at the top

    // 1. Draw Concentric Web Hexagons
    final gridPaint = Paint()
      ..color = NasaColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int ring = 1; ring <= 4; ring++) {
      final radius = maxRadius * (ring / 4.0);
      final gridPath = Path();
      for (int i = 0; i < sides; i++) {
        final angle = angleOffset + (i * 2 * math.pi / sides);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        if (i == 0) {
          gridPath.moveTo(x, y);
        } else {
          gridPath.lineTo(x, y);
        }
      }
      gridPath.close();
      canvas.drawPath(gridPath, gridPaint);
    }

    // 2. Draw Web Axis Lines
    final axisPaint = Paint()
      ..color = NasaColors.border
      ..strokeWidth = 1.0;

    for (int i = 0; i < sides; i++) {
      final angle = angleOffset + (i * 2 * math.pi / sides);
      final x = center.dx + maxRadius * math.cos(angle);
      final y = center.dy + maxRadius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // 3. Draw Filled Player Polygon
    final polyPath = Path();
    final polyPoints = <Offset>[];

    for (int i = 0; i < sides; i++) {
      final angle = angleOffset + (i * 2 * math.pi / sides);
      final statFactor = (stats[i].clamp(15.0, 100.0) / 100.0);
      final radius = maxRadius * statFactor;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      final point = Offset(x, y);
      polyPoints.add(point);

      if (i == 0) {
        polyPath.moveTo(x, y);
      } else {
        polyPath.lineTo(x, y);
      }
    }
    polyPath.close();

    // Fill
    final fillPaint = Paint()
      ..color = NasaColors.gold.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(polyPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = NasaColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(polyPath, strokePaint);

    // Vertex points
    final dotPaint = Paint()
      ..color = NasaColors.crimson
      ..style = PaintingStyle.fill;
    final dotInner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final point in polyPoints) {
      canvas.drawCircle(point, 4.5, dotPaint);
      canvas.drawCircle(point, 2.0, dotInner);
    }

    // 4. Draw Attribute Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < sides; i++) {
      final angle = angleOffset + (i * 2 * math.pi / sides);
      final labelRadius = maxRadius + 22;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: _ThemeColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );
      textPainter.layout();

      // Align label appropriately around perimeter
      double offsetX = lx - (textPainter.width / 2);
      double offsetY = ly - (textPainter.height / 2);

      if (i == 0) {
        offsetY -= 4; // Top (Pace)
      } else if (i == 3) {
        offsetY += 4; // Bottom (Dribbling)
      }

      textPainter.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonRadarPainter oldDelegate) {
    return oldDelegate.stats != stats;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Strong Foot Section with Pill Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _StrongFootSection extends StatelessWidget {
  final bool isLeft;
  final bool isBoth;
  final bool isRight;

  const _StrongFootSection({
    required this.isLeft,
    required this.isBoth,
    required this.isRight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Strong Foot',
          style: TextStyle(
            color: _ThemeColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _ThemeColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _ThemeColors.borderDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FootPill(
                label: 'Left',
                isSelected: isLeft || isBoth,
              ),
              _FootPill(
                label: 'Right',
                isSelected: isRight || isBoth,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FootPill extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FootPill({
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? _ThemeColors.blueAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : _ThemeColors.textSecondary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Stats Summary Row (Goals, Assists, Fan Rating)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsSummaryRow extends StatelessWidget {
  final Player player;
  final double fanRating;
  final bool isGk;
  final VoidCallback? onGoalsTap;

  const _StatsSummaryRow({
    required this.player,
    required this.fanRating,
    required this.isGk,
    this.onGoalsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NasaColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onGoalsTap,
              child: _StatColumn(
                label: isGk ? 'Clean Sheets' : 'Goals',
                value: '${isGk ? player.cleanSheets : player.goals}',
                valueColor: NasaColors.gold,
              ),
            ),
          ),
          _divider(),
          Expanded(
            child: _StatColumn(
              label: 'Assists',
              value: '${player.assists}',
              valueColor: Colors.white,
            ),
          ),
          _divider(),
          Expanded(
            child: _StatColumn(
              label: 'Games',
              value: '${player.appearances}',
              valueColor: Colors.white,
            ),
          ),
          _divider(),
          Expanded(
            child: _StatColumn(
              label: 'Scout ⭐',
              value: fanRating.toStringAsFixed(1),
              valueColor: NasaColors.crimson,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 38,
        color: NasaColors.border,
      );
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _ThemeColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. "Rate This Player" Action Button
// ─────────────────────────────────────────────────────────────────────────────
class _RatePlayerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RatePlayerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.star_rounded, size: 20),
        label: const Text(
          'Rate This Player',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: NasaColors.crimson,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Rate Player Bottom Sheet (Interactive 6 Stats Sliders)
// ─────────────────────────────────────────────────────────────────────────────
class _RatePlayerBottomSheet extends StatefulWidget {
  final Player player;
  final PlayerScoutRatingData ratings;

  const _RatePlayerBottomSheet({
    required this.player,
    required this.ratings,
  });

  @override
  State<_RatePlayerBottomSheet> createState() => _RatePlayerBottomSheetState();
}

class _RatePlayerBottomSheetState extends State<_RatePlayerBottomSheet> {
  late double _pace;
  late double _shooting;
  late double _passing;
  late double _dribbling;
  late double _defending;
  late double _physical;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.ratings;
    _pace = (r.userPace ?? (r.totalVotes == 0 ? 50 : r.pace.round()))
        .clamp(1, 99)
        .toDouble();
    _shooting =
        (r.userShooting ?? (r.totalVotes == 0 ? 50 : r.shooting.round()))
            .clamp(1, 99)
            .toDouble();
    _passing = (r.userPassing ?? (r.totalVotes == 0 ? 50 : r.passing.round()))
        .clamp(1, 99)
        .toDouble();
    _dribbling =
        (r.userDribbling ?? (r.totalVotes == 0 ? 50 : r.dribbling.round()))
            .clamp(1, 99)
            .toDouble();
    _defending =
        (r.userDefending ?? (r.totalVotes == 0 ? 50 : r.defending.round()))
            .clamp(1, 99)
            .toDouble();
    _physical =
        (r.userPhysical ?? (r.totalVotes == 0 ? 50 : r.physical.round()))
            .clamp(1, 99)
            .toDouble();
  }

  Future<void> _submit() async {
    if (_saving || _submitted) return;
    setState(() => _saving = true);
    final saved = await AppState.instance.submitPlayerScoutRating(
      widget.player.id,
      pace: _pace.round(),
      shooting: _shooting.round(),
      passing: _passing.round(),
      dribbling: _dribbling.round(),
      defending: _defending.round(),
      physical: _physical.round(),
    );

    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not save the rating. Please check your connection and try again.')),
      );
      return;
    }
    setState(() {
      _saving = false;
      _submitted = true;
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NasaColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate Scout Attributes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Scout profile for ${widget.player.name}',
                    style: const TextStyle(
                      color: NasaColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              if (_submitted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NasaColors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Saved! ✓',
                    style: TextStyle(
                      color: NasaColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: NasaColors.border, height: 1),
          const SizedBox(height: 10),

          // 6 Attribute Sliders
          _AttributeSliderRow(
            label: 'Pace',
            value: _pace,
            onChanged: _submitted ? null : (v) => setState(() => _pace = v),
          ),
          _AttributeSliderRow(
            label: 'Shooting',
            value: _shooting,
            onChanged: _submitted ? null : (v) => setState(() => _shooting = v),
          ),
          _AttributeSliderRow(
            label: 'Passing',
            value: _passing,
            onChanged: _submitted ? null : (v) => setState(() => _passing = v),
          ),
          _AttributeSliderRow(
            label: 'Dribbling',
            value: _dribbling,
            onChanged:
                _submitted ? null : (v) => setState(() => _dribbling = v),
          ),
          _AttributeSliderRow(
            label: 'Defending',
            value: _defending,
            onChanged:
                _submitted ? null : (v) => setState(() => _defending = v),
          ),
          _AttributeSliderRow(
            label: 'Physical',
            value: _physical,
            onChanged: _submitted ? null : (v) => setState(() => _physical = v),
          ),
          const SizedBox(height: 18),

          // Submit Rating Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitted || _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: NasaColors.crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _submitted
                    ? '✓ Rating Submitted'
                    : (_saving ? 'Saving…' : 'Submit Rating'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;

  const _AttributeSliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: NasaColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: NasaColors.gold,
                inactiveTrackColor: NasaColors.border,
                thumbColor: NasaColors.crimson,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayColor: NasaColors.crimson.withValues(alpha: 0.12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: 1,
                max: 99,
                divisions: 98,
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            width: 36,
            alignment: Alignment.centerRight,
            child: Text(
              '${value.round()}',
              style: const TextStyle(
                color: NasaColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
