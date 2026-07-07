import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../shared/match_detail_screen.dart';
import '../shared/news_detail_screen.dart';
import '../shared/player_profile_screen.dart';
import 'events_screen.dart';
import 'sponsorship_screen.dart';

class ViewerHomeTab extends StatelessWidget {
  final VoidCallback onOpenFixtures;
  const ViewerHomeTab({super.key, required this.onOpenFixtures});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final latestNews = app.news.take(4).toList();
        final latestResults = app.pastMatches.take(2).toList();
        final upcomingEvents = [...app.events]
          ..sort((a, b) => a.date.compareTo(b.date));
        final live = app.liveMatches;
        final topScorers = app.topScorers.take(5).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _AdSlideshow(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SponsorshipScreen()),
              ),
            ),
            const SectionHeader(title: 'News highlights'),
            SizedBox(
              height: 214,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: latestNews.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final article = latestNews[i];
                  return _NewsHighlightCard(
                    article: article,
                    imageUrl: newsImageUrl(i),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewsDetailScreen(article: article),
                      ),
                    ),
                  );
                },
              ),
            ),
            SectionHeader(
              title: 'Latest results',
              actionLabel: 'Fixtures',
              onAction: onOpenFixtures,
            ),
            if (latestResults.isEmpty)
              const _InlineEmpty(message: 'No completed matches yet.')
            else
              ...latestResults.map((match) => _MatchShowcase(match: match)),
            if (live.isNotEmpty) ...[
              const SectionHeader(title: 'Live events'),
              ...live.map((match) => _MatchShowcase(match: match)),
            ] else ...[
              const SectionHeader(title: 'Live events'),
              const _InlineEmpty(message: 'No live matches right now.'),
            ],
            SectionHeader(
              title: 'Upcoming events',
              actionLabel: 'View all',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventsScreen()),
              ),
            ),
            if (upcomingEvents.isEmpty)
              const _InlineEmpty(message: 'No events scheduled right now.')
            else
              ...upcomingEvents
                  .take(3)
                  .map((event) => _EventShowcase(event: event)),
            const SectionHeader(title: 'Top scorers'),
            _TopScorersShowcase(players: topScorers),
          ],
        );
      },
    );
  }
}

class _AdSlideshow extends StatefulWidget {
  final VoidCallback onTap;
  const _AdSlideshow({required this.onTap});

  @override
  State<_AdSlideshow> createState() => _AdSlideshowState();
}

class _AdSlideshowState extends State<_AdSlideshow> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    _AdSlide(
      title: 'Match day sponsor',
      message: 'Put your business in front of local fans every weekend.',
      icon: Icons.campaign_outlined,
    ),
    _AdSlide(
      title: 'Kit partnership',
      message: 'Support youth teams with shirts, boots, and training gear.',
      icon: Icons.checkroom_outlined,
    ),
    _AdSlide(
      title: 'Tournament banner',
      message: 'Promote festivals, trials, and community cup fixtures.',
      icon: Icons.emoji_events_outlined,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          SizedBox(
            height: 126,
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) => _AdCard(
                slide: _slides[index],
                onTap: widget.onTap,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _index == i ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _index == i ? NasaColors.pitch : NasaColors.line,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdSlide {
  final String title;
  final String message;
  final IconData icon;

  const _AdSlide({
    required this.title,
    required this.message,
    required this.icon,
  });
}

class _AdCard extends StatelessWidget {
  final _AdSlide slide;
  final VoidCallback onTap;

  const _AdCard({required this.slide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NasaColors.pitch,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    slide.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(slide.icon, color: NasaColors.pitch, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsHighlightCard extends StatelessWidget {
  final NewsArticle article;
  final String imageUrl;
  final VoidCallback onTap;

  const _NewsHighlightCard({
    required this.article,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 238,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NasaColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImageFallback(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                        label: article.category, color: NasaColors.pitch),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NasaColors.pitch.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(Icons.image_outlined, color: NasaColors.pitch, size: 34),
      ),
    );
  }
}

class _MatchShowcase extends StatelessWidget {
  final Match match;
  const _MatchShowcase({required this.match});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = match.status == MatchStatus.upcoming ||
        match.status == MatchStatus.postponed;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatchDetailScreen(matchId: match.id, viewAs: UserRole.viewer),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NasaColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.competition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: NasaColors.slate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (match.status == MatchStatus.live) const LiveBadge(),
                if (match.status == MatchStatus.postponed)
                  const StatusChip(label: 'Postponed', color: NasaColors.earth),
                if (isUpcoming && match.status != MatchStatus.postponed)
                  Text(
                    formatTime(match.kickoff),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: NasaColors.pitch,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.homeTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: NasaColors.chalk,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUpcoming
                        ? 'vs'
                        : '${match.homeScore} - ${match.awayScore}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.awayTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: NasaColors.slate),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    match.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: NasaColors.slate),
                  ),
                ),
                Text(
                  formatShortDate(match.kickoff),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: NasaColors.slate,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventShowcase extends StatelessWidget {
  final EventItem event;
  const _EventShowcase({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NasaColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_eventIcon(event.type), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventTypeLabel(event.type),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatShortDate(event.date)} at ${event.venue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: NasaColors.slate, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _eventTypeLabel(EventType type) {
    return switch (type) {
      EventType.tournament => 'Tournament',
      EventType.trial => 'Scouting trial',
      EventType.festival => 'Festival',
      EventType.coachingClinic => 'Coaching clinic',
    };
  }

  IconData _eventIcon(EventType type) {
    return switch (type) {
      EventType.tournament => Icons.emoji_events_outlined,
      EventType.trial => Icons.visibility_outlined,
      EventType.festival => Icons.celebration_outlined,
      EventType.coachingClinic => Icons.medical_services_outlined,
    };
  }

  Color _eventColor(EventType type) {
    return switch (type) {
      EventType.tournament => NasaColors.pitch,
      EventType.trial => NasaColors.earth,
      EventType.festival => NasaColors.pitchDark,
      EventType.coachingClinic => NasaColors.slate,
    };
  }
}

class _TopScorersShowcase extends StatelessWidget {
  final List<Player> players;
  const _TopScorersShowcase({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const _InlineEmpty(message: 'No scorers recorded yet.');
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NasaColors.line),
      ),
      child: Column(
        children: players.asMap().entries.map((entry) {
          final index = entry.key;
          final player = entry.value;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: NasaColors.chalk,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: NasaColors.pitch,
                ),
              ),
            ),
            title: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
            subtitle: Text(
              player.teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
            trailing: Text(
              '${player.goals} goals',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: NasaColors.pitch),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfileScreen(
                    playerId: player.id, viewAs: UserRole.viewer),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String message;
  const _InlineEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(message, style: const TextStyle(color: NasaColors.slate)),
    );
  }
}
