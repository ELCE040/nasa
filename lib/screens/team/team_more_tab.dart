import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../viewer/events_screen.dart';
import 'disciplinary_log_screen.dart';
import '../viewer/sponsorship_screen.dart';

class TeamMoreTab extends StatelessWidget {
  const TeamMoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Club management',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.gavel_outlined,
          title: 'Disciplinary log',
          subtitle: 'Cards, suspensions and fines for your squad',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DisciplinaryLogScreen()),
          ),
        ),
        _MenuTile(
          icon: Icons.event_outlined,
          title: 'Events & tournaments',
          subtitle: 'Trials, festivals and cup fixtures',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventsScreen()),
          ),
        ),
        _MenuTile(
          icon: Icons.storefront_outlined,
          title: 'Sponsor a team',
          subtitle: 'Support local football and get business visibility',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SponsorshipScreen()),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.swap_horiz,
          title: 'Switch role',
          subtitle: 'Viewer - Scout - Team',
          onTap: () => app.signOut(),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Naysasport - Team & coach edition.',
            style:
                TextStyle(fontSize: 11, color: NasaColors.slate, height: 1.3),
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

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brandPrimary = Theme.of(context).colorScheme.primary;
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
            color: brandPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: brandPrimary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11.5, color: NasaColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right, color: NasaColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
