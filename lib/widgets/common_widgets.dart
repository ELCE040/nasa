import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// A round avatar showing initials — used everywhere a player/team/scout
/// photo would normally go, so the UI works fully offline with no media.
class InitialsAvatar extends StatelessWidget {
  final String text;
  final double radius;
  final Color? background;
  final Color? foreground;

  const InitialsAvatar({
    super.key,
    required this.text,
    this.radius = 22,
    this.background,
    this.foreground,
  });

  String get _initials {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? NasaColors.pitch.withValues(alpha: 0.12),
      child: Text(
        _initials,
        style: TextStyle(
          color: foreground ?? NasaColors.pitch,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.62,
        ),
      ),
    );
  }
}

/// Small pill labelling the ward / village a team or player represents —
/// the recurring "signature" tag used throughout the app.
class WardTag extends StatelessWidget {
  final String label;
  final IconData icon;
  const WardTag(
      {super.key, required this.label, this.icon = Icons.place_outlined});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NasaColors.chalk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NasaColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: NasaColors.slate),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NasaColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" badge for in-progress matches.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});
  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: NasaColors.earth,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String label;
  final String value;
  const StatPill({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: NasaColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: NasaColors.slate),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: NasaColors.slate),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NasaColors.slate),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class RoleSwitcherButton extends StatelessWidget {
  const RoleSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRole = AppState.instance.currentRole;
    return PopupMenuButton<UserRole>(
      tooltip: 'Switch role',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: AppState.instance.setRole,
      itemBuilder: (context) => [
        _roleItem(
          role: UserRole.viewer,
          currentRole: currentRole,
          icon: Icons.groups_2_outlined,
          label: 'Viewer / Fan',
        ),
        _roleItem(
          role: UserRole.scout,
          currentRole: currentRole,
          icon: Icons.travel_explore,
          label: 'Scout',
        ),
        _roleItem(
          role: UserRole.team,
          currentRole: currentRole,
          icon: Icons.shield_outlined,
          label: 'Team / Coach',
        ),
      ],
    );
  }

  PopupMenuItem<UserRole> _roleItem({
    required UserRole role,
    required UserRole? currentRole,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<UserRole>(
      value: role,
      child: Row(
        children: [
          Icon(
            currentRole == role ? Icons.check_circle : icon,
            size: 19,
            color: currentRole == role ? NasaColors.pitch : NasaColors.slate,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

/// Generic confirm-action helper: shows a snackbar, used to simulate
/// side-effects like "SMS sent", "video uploaded", "escrow funded" etc.
void showNasaSnack(BuildContext context, String message,
    {bool success = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success ? NasaColors.pitchDark : NasaColors.earth,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

String formatMwk(double amount) {
  final isNeg = amount < 0;
  final v = amount.abs().round();
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    buf.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  return '${isNeg ? '-' : ''}MWK $buf';
}

String formatShortDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ampm';
}

String newsImageUrl(int index) {
  const urls = [
    'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1517927033932-b3d18e61fb3a?auto=format&fit=crop&w=800&q=80',
  ];
  return urls[index % urls.length];
}
