import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
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

        // Upcoming fixtures (next 3 scheduled matches sorted by kickoff)
        final upcomingFixtures = [...app.upcomingMatches]
          ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
        final nextFixtures = upcomingFixtures.take(3).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _AdSlideshow(
              sponsorships: app.sponsorships,
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
                    imageUrl:
                        article.imageUrl != null && article.imageUrl!.isNotEmpty
                            ? ApiService.resolveUrl(article.imageUrl!)
                            : newsImageUrl(i),
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
            if (live.isNotEmpty) ...[
              const SectionHeader(title: 'Live events'),
              ...live.map((match) => _MatchShowcase(match: match)),
            ],
            SectionHeader(
              title: 'Latest results',
              actionLabel: 'Fixtures',
              onAction: onOpenFixtures,
            ),
            if (latestResults.isEmpty)
              const _InlineEmpty(message: 'No completed matches yet.')
            else
              ...latestResults.map((match) => _MatchShowcase(match: match)),
            // ── Upcoming fixtures ──────────────────────────────────────────
            SectionHeader(
              title: 'Upcoming fixtures',
              actionLabel: 'View all',
              onAction: onOpenFixtures,
            ),
            if (nextFixtures.isEmpty)
              const _InlineEmpty(message: 'No upcoming fixtures scheduled.')
            else
              ...nextFixtures.map((match) => _MatchShowcase(match: match)),
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
            const SectionHeader(title: 'Player leaderboards'),
            const _PlayerLeaderboardShowcase(),
          ],
        );
      },
    );
  }
}

class _AdSlideshow extends StatefulWidget {
  final List<Sponsorship> sponsorships;
  final VoidCallback onTap;
  const _AdSlideshow({required this.sponsorships, required this.onTap});

  @override
  State<_AdSlideshow> createState() => _AdSlideshowState();
}

class _AdSlideshowState extends State<_AdSlideshow> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sponsorships.isEmpty) return const SizedBox.shrink();

    final slides = widget.sponsorships.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          SizedBox(
            height: 156,
            child: PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) => _AdCard(
                sponsorship: slides[index],
                onTap: widget.onTap,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (slides.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < slides.length; i++)
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

class _AdCard extends StatelessWidget {
  final Sponsorship sponsorship;
  final VoidCallback onTap;

  const _AdCard({required this.sponsorship, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        sponsorship.imageUrl != null && sponsorship.imageUrl!.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (sponsorship.linkUrl != null && sponsorship.linkUrl!.isNotEmpty) {
          final uri = Uri.tryParse(sponsorship.linkUrl!);
          if (uri != null) {
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            } catch (_) {}
          }
        }
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              const Color(0xFFF8FAFC), // Clean white/light gray background card
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (hasImage)
                Positioned.fill(
                  child: Image.network(
                    ApiService.resolveUrl(sponsorship.imageUrl!),
                    // Fill the banner without leaving empty margins or cropping
                    // the sponsor artwork at its edges.
                    fit: BoxFit.fill,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasImage
                                  ? Colors.black.withValues(alpha: 0.62)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: hasImage
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sponsorship.sponsorName,
                            style: TextStyle(
                              color: hasImage
                                  ? Colors.white
                                  : const Color(0xFF0D1623),
                              shadows: hasImage
                                  ? const [
                                      Shadow(color: Colors.black, blurRadius: 4)
                                    ]
                                  : null,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sponsorship.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasImage
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              shadows: hasImage
                                  ? const [
                                      Shadow(color: Colors.black, blurRadius: 4)
                                    ]
                                  : null,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: NasaColors.crimson,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Visit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
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

  Widget _fallbackIcon() {
    return const Icon(
      Icons.campaign_outlined,
      color: NasaColors.crimson,
      size: 28,
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
      width: 240,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: NasaColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NasaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: SizedBox(
                  height: 108,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusChip(
                            label: article.category, color: NasaColors.gold),
                        const Text(
                          'Read More',
                          style: TextStyle(
                            color: NasaColors.crimson,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Colors.white,
                        height: 1.25,
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
      color: NasaColors.bgCardMuted,
      child: const Center(
        child: Icon(Icons.image_outlined, color: NasaColors.gold, size: 34),
      ),
    );
  }
}

class _MatchShowcase extends StatelessWidget {
  final Match match;
  const _MatchShowcase({required this.match});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final isUpcoming = match.status == MatchStatus.upcoming ||
        match.status == MatchStatus.postponed;
    final homeLogoUrl = app.teamById(match.homeTeamId)?.logoUrl;
    final awayLogoUrl = app.teamById(match.awayTeamId)?.logoUrl;
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
          color: NasaColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NasaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.displayCompetition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: NasaColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (match.status == MatchStatus.live) ...[
                  const LiveBadge(),
                  const SizedBox(width: 5),
                  Text('${match.minute}\'',
                      style: const TextStyle(
                          color: NasaColors.crimson,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ],
                if (match.status == MatchStatus.postponed)
                  const StatusChip(
                      label: 'Postponed', color: NasaColors.crimson),
                if (isUpcoming && match.status != MatchStatus.postponed)
                  Text(
                    formatTime(match.kickoff),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: NasaColors.gold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _FixtureTeamLogo(
                    name: match.homeTeamName, logoUrl: homeLogoUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.homeTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: NasaColors.navyDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NasaColors.border),
                  ),
                  child: Text(
                    isUpcoming
                        ? 'vs'
                        : '${match.homeScore} - ${match.awayScore}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: NasaColors.gold, // Gold scores
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.awayTeamName,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FixtureTeamLogo(
                    name: match.awayTeamName, logoUrl: awayLogoUrl),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: NasaColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    match.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: NasaColors.textMuted),
                  ),
                ),
                Text(
                  formatShortDate(match.kickoff),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: NasaColors.textMuted,
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

/// Uses the club's uploaded crest when available and a clear initial fallback
/// for teams that have not uploaded one yet.
class _FixtureTeamLogo extends StatelessWidget {
  final String name;
  final String? logoUrl;

  const _FixtureTeamLogo({required this.name, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final hasLogo =
        logoUrl != null && logoUrl!.trim().isNotEmpty && logoUrl != 'null';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: NasaColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(
              ApiService.resolveUrl(logoUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _TeamInitial(name: name),
            )
          : _TeamInitial(name: name),
    );
  }
}

class _TeamInitial extends StatelessWidget {
  final String name;
  const _TeamInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: NasaColors.crimson,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
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
        color: NasaColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NasaColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatShortDate(event.date)} at ${event.venue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NasaColors.textMuted, fontSize: 11.5),
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
      EventType.tournament => NasaColors.gold,
      EventType.trial => NasaColors.earth,
      EventType.festival => const Color(0xFF64B5F6),
      EventType.coachingClinic => NasaColors.green,
    };
  }
}

class _PlayerLeaderboardShowcase extends StatefulWidget {
  const _PlayerLeaderboardShowcase();

  @override
  State<_PlayerLeaderboardShowcase> createState() =>
      _PlayerLeaderboardShowcaseState();
}

class _PlayerLeaderboardShowcaseState
    extends State<_PlayerLeaderboardShowcase> {
  int _selectedTab = 0; // 0: Scorers, 1: Assists, 2: Goalkeepers
  String? _competitionId;
  String? _lastStatsDebugSignature;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final competitions = app.leagues
        .where((league) => league.name.toLowerCase() != 'unassigned')
        .toList();
    final competitionIdsWithPlayers = app.playerStatsByCompetition.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toSet();
    String? newestCompetitionWithPlayers;
    for (final match in app.matches) {
      if (competitionIdsWithPlayers.contains(match.leagueId)) {
        newestCompetitionWithPlayers = match.leagueId;
        break;
      }
    }
    String? firstCompetitionWithPlayers;
    for (final competition in competitions) {
      if (competitionIdsWithPlayers.contains(competition.id)) {
        firstCompetitionWithPlayers = competition.id;
        break;
      }
    }
    final selectedCompetitionId =
        competitions.any((league) => league.id == _competitionId)
            ? _competitionId
            : newestCompetitionWithPlayers ??
                firstCompetitionWithPlayers ??
                (competitions.isNotEmpty ? competitions.first.id : null);
    final competitionPlayers = selectedCompetitionId == null
        ? <Player>[]
        : (app.playerStatsByCompetition[selectedCompetitionId] ?? <Player>[]);
    final topScorers = competitionPlayers
        .where((player) => player.goals > 0)
        .toList()
      ..sort((a, b) => b.goals.compareTo(a.goals));
    final topAssisters = competitionPlayers
        .where((player) => player.assists > 0)
        .toList()
      ..sort((a, b) => b.assists.compareTo(a.assists));
    final topGoalkeepers = competitionPlayers.where((player) {
      final position = player.position.toLowerCase();
      return position.contains('goal') ||
          position.contains('gk') ||
          player.cleanSheets > 0;
    }).toList()
      ..sort((a, b) {
        if (b.cleanSheets != a.cleanSheets) {
          return b.cleanSheets.compareTo(a.cleanSheets);
        }
        return b.appearances.compareTo(a.appearances);
      });

    if (kDebugMode) {
      final signature =
          '${selectedCompetitionId ?? 'none'}:${_selectedTab}:${competitionPlayers.length}:${competitionPlayers.map((p) => '${p.id}=${p.goals}/${p.assists}/${p.appearances}').join(',')}';
      if (_lastStatsDebugSignature != signature) {
        _lastStatsDebugSignature = signature;
        debugPrint('[HOME LEADERBOARD] competition=$selectedCompetitionId '
            'tab=$_selectedTab players=${competitionPlayers.length} '
            'top=${competitionPlayers.take(10).map((p) => '${p.name}:${p.goals}g/${p.assists}a/${p.appearances}apps').join(', ')}');
      }
    }

    List<Player> displayPlayers;
    String statSuffix;
    int Function(Player) statValue;

    switch (_selectedTab) {
      case 1:
        displayPlayers = topAssisters;
        statSuffix = 'assists';
        statValue = (p) => p.assists;
        break;
      case 2:
        displayPlayers = topGoalkeepers;
        statSuffix = 'clean sheets';
        statValue = (p) => p.cleanSheets;
        break;
      default:
        displayPlayers = topScorers;
        statSuffix = 'goals';
        statValue = (p) => p.goals;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (competitions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: DropdownButtonFormField<String>(
              value: selectedCompetitionId,
              isExpanded: true,
              dropdownColor: NasaColors.bgNavy,
              decoration: const InputDecoration(
                labelText: 'League / Cup',
                isDense: true,
              ),
              items: competitions
                  .map((league) => DropdownMenuItem(
                        value: league.id,
                        child:
                            Text(league.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) => setState(() => _competitionId = id),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: NasaColors.bgNavy,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NasaColors.border),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildTab(0, 'Goals', Icons.sports_soccer),
                _buildTab(1, 'Assists', Icons.assistant_outlined),
                _buildTab(2, 'Clean Sheets', Icons.cleaning_services_outlined),
              ],
            ),
          ),
        ),
        if (competitions.isEmpty)
          const _InlineEmpty(message: 'No leagues or cups are available yet.')
        else if (displayPlayers.isEmpty)
          const _InlineEmpty(
              message:
                  'No players recorded for this category in this competition yet.')
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: NasaColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NasaColors.border),
            ),
            child: Column(
              children: displayPlayers.asMap().entries.map((entry) {
                final index = entry.key;
                final player = entry.value;
                final count = statValue(player);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InitialsAvatar(
                    text: player.name,
                    radius: 16,
                    imageUrl: player.imageUrl,
                    background: NasaColors.bgNavy,
                    foreground: NasaColors.gold,
                  ),
                  title: Text(
                    '${index + 1}. ${player.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${player.teamName} · ${player.position}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: NasaColors.textMuted,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: NasaColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: NasaColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$count $statSuffix',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        color: NasaColors.gold,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerProfileScreen(
                        playerId: player.id,
                        viewAs: UserRole.viewer,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? NasaColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected
                      ? const Color(0xFF070D18)
                      : NasaColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: isSelected
                              ? const Color(0xFF070D18)
                              : NasaColors.textMuted))),
            ],
          ),
        ),
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
