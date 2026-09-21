import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming events'),
        actions: const [RoleSwitcherButton()],
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          final events = [...app.events]
            ..sort((a, b) => a.date.compareTo(b.date));
          if (events.isEmpty) {
            return const EmptyState(
                icon: Icons.event_outlined,
                title: 'No events yet',
                message: 'Tournaments, trials and clinics will appear here.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = events[i];
              final typeLabel = switch (e.type) {
                EventType.tournament => 'Tournament',
                EventType.trial => 'Scouting Trial',
                EventType.festival => 'Festival',
                EventType.coachingClinic => 'Coaching Clinic',
              };
              final color = switch (e.type) {
                EventType.tournament => NasaColors.pitch,
                EventType.trial => NasaColors.earth,
                EventType.festival => NasaColors.sun,
                EventType.coachingClinic => NasaColors.slate,
              };
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NasaColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NasaColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(label: typeLabel, color: color),
                        const Spacer(),
                        Text(formatShortDate(e.date),
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: NasaColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(e.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(e.description,
                        style: const TextStyle(
                            color: NasaColors.textMuted,
                            fontSize: 12.5,
                            height: 1.35)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: NasaColors.crimson),
                        const SizedBox(width: 4),
                        Text(e.venue,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: NasaColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
