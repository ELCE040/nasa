import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'sponsorship_screen.dart';
import 'events_screen.dart';

class ViewerMoreTab extends StatelessWidget {
  const ViewerMoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Community',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.storefront_outlined,
          title: 'Sponsor a team',
          subtitle: 'Support local football and get business visibility',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SponsorshipScreen())),
        ),

        _MenuTile(
          icon: Icons.event_outlined,
          title: 'Events & tournaments',
          subtitle: 'Trials, festivals and cup fixtures',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const EventsScreen())),
        ),
        const SizedBox(height: 20),
        const Text('Account',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.swap_horiz,
          title: 'Switch role',
          subtitle: 'Viewer · Team',
          onTap: () => AppState.instance.signOut(),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Naysasport — Malawi ward & youth football, viewer edition.',
            style: TextStyle(fontSize: 11, color: NasaColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NasaColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: NasaColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: NasaColors.gold, size: 20),
        ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: NasaColors.textMuted)),
        trailing: const Icon(Icons.chevron_right, color: NasaColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
