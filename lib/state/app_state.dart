import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Single source of truth for the whole app.
///
/// On first construction it tries to load all core data from the
/// Node.js/MySQL backend. If the backend is unreachable it falls
/// Node.js/MySQL backend. If the backend is unreachable it shows an error.
class AppState extends ChangeNotifier {
  AppState._internal() {
    _boot();
  }

  static final AppState instance = AppState._internal();

  UserRole? currentRole = UserRole.viewer;
  String myTeamId = 't1';

  // Heartbeat tracking
  late final String deviceId;
  Timer? _heartbeatTimer;

  static const _deviceIdKey = 'nasa_device_id';

  static String _generateDeviceId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = (now ^ 0x5DEECE66D).abs().toRadixString(36);
    return 'dev_$r';
  }

  // Loading state
  bool isLoading = true;
  bool isOnline = false;
  String? loadError;
  DateTime? lastUpdated;

  Timer? _pollTimer;
  bool _isRefreshing = false;

  List<Ward> wards = [];
  List<Team> teams = [];
  List<League> leagues = [];
  Set<String> liveLeagueIds = {};
  List<Player> players = [];

  /// Match-derived player totals, isolated by league or cup id.
  final Map<String, List<Player>> playerStatsByCompetition = {};
  final Map<String, List<Map<String, dynamic>>> playerGoalBreakdown = {};
  // Team sign-in replaces `players` with its restricted workspace response.
  // Preserve public photo URLs separately so that response can be repaired.
  final Map<String, String> _publishedPlayerImageUrls = {};
  bool _attemptedPublishedPhotoLookup = false;
  List<Match> matches = [];
  List<NewsArticle> news = [];
  List<EventItem> events = [];
  List<InjuryRecord> injuries = [];
  List<AttendanceRecord> attendance = [];
  List<DisciplinaryRecord> disciplinary = [];
  List<RefereeProfile> referees = [];
  List<RefereeRating> refereeRatings = [];
  final Map<String, PlayerScoutRatingData> _playerScoutRatings = {};
  List<VideoClip> videoClips = [];
  List<Sponsorship> sponsorships = [];
  List<LedgerEntry> ledger = [];
  List<TransferEscrow> transfers = [];
  List<ConsentRequestLog> consentLogs = [];
  List<String> defaultLineup = [];
  final Map<String, List<String>> fixtureLineups = {};

  final List<WatchlistItem> watchlist = [];
  final List<ScoutAlert> scoutAlerts = [];

  Team? currentTeam;
  Color teamBrandPrimary = NasaColors.crimson;
  Color teamBrandSecondary = NasaColors.gold;
  List<Team> teamLeagueStandings = [];
  String? teamCompetitionStatus;
  int? teamLeaguePosition;
  int? teamLeagueSize;
  bool teamEliminated = false;

  int _idCounter = 1000;
  String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  // ─── Boot: try backend, fall back to mock ─────────────────────────────────
  Future<void> _boot() async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    deviceId = preferences.getString(_deviceIdKey) ?? _generateDeviceId();
    await preferences.setString(_deviceIdKey, deviceId);

    print('[AppState] Booting — fetching live app data bundle...');
    await _loadFromBackend();

    isOnline = (loadError == null);
    isLoading = false;
    print('[AppState] Boot complete. isOnline=$isOnline, loadError=$loadError');
    notifyListeners();

    // Start periodic polling — refresh live data
    if (isOnline) {
      _startPolling();
      _startHeartbeat();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    final roleName = currentRole == UserRole.scout
        ? 'scout'
        : (currentRole == UserRole.team ? 'team' : 'viewer');
    final platformStr = kIsWeb ? 'web' : (defaultTargetPlatform.name);
    ApiService.pingHeartbeat(
      deviceId: deviceId,
      role: roleName,
      platform: platformStr,
      appVersion: '1.0.0',
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Adaptive polling: faster during live matches, slower otherwise
    // This balances real-time updates with server load
    final interval = liveLeagueIds.isNotEmpty
        ? const Duration(seconds: 8) // During live matches: 8 seconds
        : const Duration(seconds: 15); // Normal: 15 seconds (was 5!)
    _pollTimer = Timer.periodic(interval, (_) async {
      await _refreshLive();
    });
    print(
        '[AppState] Polling started — refreshing every ${interval.inSeconds}s');
  }

  /// Lightweight refresh: only fetches data that changes frequently during a match
  Future<void> _refreshLive() async {
    if (!isOnline || _isRefreshing) return;
    _isRefreshing = true;
    try {
      print('[AppState] ⚡ Live refresh...');
      if (currentRole == UserRole.team) {
        await loadTeamWorkspace();
        return;
      }

      // Use optimized single-request endpoint instead of 5 separate requests
      final appData = await ApiService.fetchAppData();

      // Match events are embedded inside each Match by the backend.
      matches = (appData['matches'] as List? ?? [])
          .map((j) => ApiService.decodeMatch(j as Map))
          .toList();

      final rawNews = appData['news'] as List? ?? [];
      news = rawNews.map((j) {
        final m = j as Map;
        return NewsArticle(
          id: m['id']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          summary: m['summary']?.toString() ?? '',
          body: m['body']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          category: m['category']?.toString() ?? '',
          author: m['author']?.toString() ?? '',
          imageUrl: m['imageUrl']?.toString(),
        );
      }).toList();

      teams = (appData['standings'] as List? ?? [])
          .map((j) => ApiService.decodeTeam(j as Map))
          .toList();

      players = (appData['players'] as List? ?? [])
          .map((j) => ApiService.decodePlayer(j as Map))
          .toList();
      _cachePublishedPlayerImageUrls(players);
      _applyPlayerScoutRatings(
          appData['playerScoutRatings'] as List? ?? const []);

      playerStatsByCompetition.clear();
      playerGoalBreakdown
        ..clear()
        ..addAll(_decodeGoalBreakdown(appData['playerGoalBreakdown']));
      final statsMap = appData['playerStatsByCompetition'] as Map? ?? {};
      statsMap.forEach((competitionId, rows) {
        playerStatsByCompetition[competitionId.toString()] =
            (rows as List? ?? [])
                .map((j) => ApiService.decodePlayer(j as Map))
                .toList();
      });
      _debugPlayerCompetitionStats();

      liveLeagueIds = Set<String>.from(
        (appData['liveLeagueIds'] as List? ?? []).map((id) => id.toString()),
      );

      final rawSponsorships = appData['sponsorships'] as List? ?? [];
      sponsorships = rawSponsorships.map((j) {
        final m = j as Map;
        return Sponsorship(
          id: m['id']?.toString() ?? '',
          sponsorName: m['sponsorName']?.toString() ?? '',
          isDiaspora: m['isDiaspora'] == 1 || m['isDiaspora'] == true,
          type: SponsorshipType.values.firstWhere(
            (e) => e.name == (m['type']?.toString() ?? ''),
            orElse: () => SponsorshipType.teamAdoption,
          ),
          targetName: m['targetName']?.toString() ?? '',
          amountMwk: double.tryParse(m['amountMwk']?.toString() ?? '0') ?? 0.0,
          message: m['message']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          imageUrl: m['imageUrl']?.toString(),
          linkUrl: m['linkUrl']?.toString(),
        );
      }).toList();

      lastUpdated = DateTime.now();
      print('[AppState] ✅ Live refresh done at $lastUpdated');
      notifyListeners();
    } catch (e) {
      print('[AppState] Live refresh error: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> reload() async {
    _pollTimer?.cancel();
    ApiService.clearAppDataCache();
    await _boot();
  }

  /// Refreshes only the data the active role is allowed to access.
  Future<void> refreshCurrentData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      // A user-initiated refresh must reload fresh data, not reuse a 304 cache.
      ApiService.clearAppDataCache();
      if (currentRole == UserRole.team) {
        await loadTeamWorkspace();
      } else {
        await _loadFromBackend();
      }
      lastUpdated = DateTime.now();
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadFromBackend() async {
    print('[AppState] ⚡ Loading all data with optimized endpoint...');
    try {
      final startTime = DateTime.now();

      // Single API call returns everything (with ETag caching!)
      final appData = await ApiService.fetchAppData();

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      print('[AppState] ✅ Complete data loaded in ${elapsed}ms');

      // Parse teams (standings = ranked team list from league-live-data)
      teams = (appData['standings'] as List? ?? [])
          .map((j) => ApiService.decodeTeam(j as Map))
          .toList();
      print('[AppState] Teams loaded: ${teams.length}');

      // Parse players
      players = (appData['players'] as List? ?? [])
          .map((j) => ApiService.decodePlayer(j as Map))
          .toList();
      _cachePublishedPlayerImageUrls(players);
      _logPlayerImageCoverage('public player feed');
      print('[AppState] Players loaded: ${players.length}');
      _applyPlayerScoutRatings(
          appData['playerScoutRatings'] as List? ?? const []);

      // Parse player stats by competition
      playerStatsByCompetition.clear();
      playerGoalBreakdown
        ..clear()
        ..addAll(_decodeGoalBreakdown(appData['playerGoalBreakdown']));
      final statsMap = appData['playerStatsByCompetition'] as Map? ?? {};
      statsMap.forEach((competitionId, rows) {
        playerStatsByCompetition[competitionId.toString()] =
            (rows as List? ?? [])
                .map((j) => ApiService.decodePlayer(j as Map))
                .toList();
      });
      _debugPlayerCompetitionStats();

      // Live league IDs
      liveLeagueIds = Set<String>.from(
        (appData['liveLeagueIds'] as List? ?? []).map((id) => id.toString()),
      );

      // Parse matches (events are embedded inside each match by the backend)
      matches = (appData['matches'] as List? ?? [])
          .map((j) => ApiService.decodeMatch(j as Map))
          .toList();
      print('[AppState] Matches loaded: ${matches.length}');

      // Parse news
      final rawNews = appData['news'] as List? ?? [];
      news = rawNews.map((j) {
        final m = j as Map;
        return NewsArticle(
          id: m['id']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          summary: m['summary']?.toString() ?? '',
          body: m['body']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          category: m['category']?.toString() ?? '',
          author: m['author']?.toString() ?? '',
          imageUrl: m['imageUrl']?.toString(),
        );
      }).toList();
      print('[AppState] News loaded: ${news.length}');

      // Parse leagues
      final rawLeagues = appData['leagues'] as List? ?? [];
      leagues = rawLeagues.map((j) {
        final m = j as Map;
        return League(
          id: m['id']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          description: m['description']?.toString() ?? '',
          format: m['format']?.toString() ?? 'league',
          advancingTeams:
              int.tryParse(m['advancingTeams']?.toString() ?? '') ?? 2,
          status: m['status']?.toString() ?? 'active',
        );
      }).toList();
      print('[AppState] Leagues loaded: ${leagues.length}');

      // Calendar events (/api/events — EventItem, not match events)
      // NOTE: match events are embedded inside each Match object above.
      final rawEvents = appData['calendarEvents'] as List? ?? [];
      events = rawEvents.map((j) {
        final m = j as Map;
        return EventItem(
          id: m['id']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          description: m['description']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          venue: m['venue']?.toString() ?? '',
          wardName: m['wardName']?.toString() ?? '',
          type: EventType.values.firstWhere(
            (e) => e.name == (m['type']?.toString() ?? ''),
            orElse: () => EventType.tournament,
          ),
        );
      }).toList();
      print('[AppState] Calendar events loaded: ${events.length}');

      // Parse injuries
      final rawInjuries = appData['injuries'] as List? ?? [];
      injuries =
          rawInjuries.map((j) => ApiService.decodeInjury(j as Map)).toList();
      print('[AppState] Injuries loaded: ${injuries.length}');

      // Parse attendance
      final rawAttendance = appData['attendance'] as List? ?? [];
      attendance = rawAttendance.map((j) {
        final m = j as Map;
        return AttendanceRecord(
          id: m['id']?.toString() ?? '',
          playerId: m['playerId']?.toString() ?? '',
          playerName: m['playerName']?.toString() ?? '',
          weekOf: DateTime.tryParse(m['weekOf']?.toString() ?? '') ??
              DateTime.now(),
          daysPresent: (m['daysPresent'] as num?)?.toInt() ?? 0,
          daysTotal: (m['daysTotal'] as num?)?.toInt() ?? 5,
          loggedBy: m['loggedBy']?.toString() ?? '',
        );
      }).toList();
      print('[AppState] Attendance loaded: ${attendance.length}');

      // Parse disciplinary
      final rawDisciplinary = appData['disciplinary'] as List? ?? [];
      disciplinary = rawDisciplinary.map((j) {
        final m = j as Map;
        return DisciplinaryRecord(
          id: m['id']?.toString() ?? '',
          playerId: m['playerId']?.toString() ?? '',
          playerName: m['playerName']?.toString() ?? '',
          teamName: m['teamName']?.toString() ?? '',
          matchLabel: m['matchLabel']?.toString() ?? '',
          cardType: m['cardType'] == 'red' ? CardType.red : CardType.yellow,
          reason: m['reason']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          suspensionMatches: (m['suspensionMatches'] as num?)?.toInt() ?? 0,
          fineAmount:
              double.tryParse(m['fineAmount']?.toString() ?? '0') ?? 0.0,
          finePaid: m['finePaid'] == 1 || m['finePaid'] == true,
        );
      }).toList();
      print('[AppState] Disciplinary loaded: ${disciplinary.length}');

      // Parse referees
      final rawReferees = appData['referees'] as List? ?? [];
      referees = rawReferees.map((j) {
        final m = j as Map;
        return RefereeProfile(
          id: m['id']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          matchesOfficiated: (m['matchesOfficiated'] as num?)?.toInt() ?? 0,
          avgFairness:
              double.tryParse(m['avgFairness']?.toString() ?? '0') ?? 0.0,
          avgCommunication:
              double.tryParse(m['avgCommunication']?.toString() ?? '0') ?? 0.0,
        );
      }).toList();
      print('[AppState] Referees loaded: ${referees.length}');

      // Parse referee ratings
      final rawRatings = appData['refereeRatings'] as List? ?? [];
      refereeRatings = rawRatings.map((j) {
        final m = j as Map;
        return RefereeRating(
          id: m['id']?.toString() ?? '',
          refereeId: m['refereeId']?.toString() ?? '',
          refereeName: m['refereeName']?.toString() ?? '',
          matchLabel: m['matchLabel']?.toString() ?? '',
          ratedByTeam: m['ratedByTeam']?.toString() ?? '',
          fairnessScore: (m['fairnessScore'] as num?)?.toInt() ?? 0,
          communicationScore: (m['communicationScore'] as num?)?.toInt() ?? 0,
          comment: m['comment']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
      print('[AppState] Referee ratings loaded: ${refereeRatings.length}');

      // Parse video clips
      final rawVideos = appData['videos'] as List? ?? [];
      videoClips = rawVideos.map((j) {
        final m = j as Map;
        return VideoClip(
          id: m['id']?.toString() ?? '',
          playerId: m['playerId']?.toString() ?? '',
          playerName: m['playerName']?.toString() ?? '',
          teamName: m['teamName']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
          uploadDate: DateTime.tryParse(m['uploadDate']?.toString() ?? '') ??
              DateTime.now(),
          matchLabel: m['matchLabel']?.toString() ?? '',
        );
      }).toList();
      print('[AppState] Videos loaded: ${videoClips.length}');

      // Parse sponsorships
      final rawSponsorships = appData['sponsorships'] as List? ?? [];
      sponsorships = rawSponsorships.map((j) {
        final m = j as Map;
        return Sponsorship(
          id: m['id']?.toString() ?? '',
          sponsorName: m['sponsorName']?.toString() ?? '',
          isDiaspora: m['isDiaspora'] == 1 || m['isDiaspora'] == true,
          type: SponsorshipType.values.firstWhere(
            (e) => e.name == (m['type']?.toString() ?? ''),
            orElse: () => SponsorshipType.teamAdoption,
          ),
          targetName: m['targetName']?.toString() ?? '',
          amountMwk: double.tryParse(m['amountMwk']?.toString() ?? '0') ?? 0.0,
          message: m['message']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          imageUrl: m['imageUrl']?.toString(),
          linkUrl: m['linkUrl']?.toString(),
        );
      }).toList();
      print('[AppState] Sponsorships loaded: ${sponsorships.length}');

      // Parse ledger
      final rawLedger = appData['ledger'] as List? ?? [];
      ledger = rawLedger.map((j) {
        final m = j as Map;
        return LedgerEntry(
          id: m['id']?.toString() ?? '',
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
          description: m['description']?.toString() ?? '',
          type: m['type'] == 'income' ? LedgerType.income : LedgerType.expense,
          category: m['category']?.toString() ?? '',
          amountMwk: double.tryParse(m['amountMwk']?.toString() ?? '0') ?? 0.0,
        );
      }).toList();
      print('[AppState] Ledger loaded: ${ledger.length}');

      // Parse transfers
      final rawTransfers = appData['transfers'] as List? ?? [];
      transfers = rawTransfers.map((j) {
        final m = j as Map;
        return TransferEscrow(
          id: m['id']?.toString() ?? '',
          playerId: m['playerId']?.toString() ?? '',
          playerName: m['playerName']?.toString() ?? '',
          sellingTeam: m['sellingTeam']?.toString() ?? '',
          buyingTeam: m['buyingTeam']?.toString() ?? '',
          agreedFeeMwk:
              double.tryParse(m['agreedFeeMwk']?.toString() ?? '0') ?? 0.0,
          commissionPercent:
              double.tryParse(m['commissionPercent']?.toString() ?? '15') ??
                  15.0,
          status: EscrowStatus.values.firstWhere(
            (e) => e.name == (m['status']?.toString() ?? ''),
            orElse: () => EscrowStatus.awaitingPayment,
          ),
          date:
              DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
      print('[AppState] Transfers loaded: ${transfers.length}');

      // Parse consent logs
      final rawConsent = appData['consentLogs'] as List? ?? [];
      consentLogs = rawConsent.map((j) {
        final m = j as Map;
        return ConsentRequestLog(
          id: m['id']?.toString() ?? '',
          playerId: m['playerId']?.toString() ?? '',
          playerName: m['playerName']?.toString() ?? '',
          parentPhone: m['parentPhone']?.toString() ?? '',
          sentDate: DateTime.tryParse(m['sentDate']?.toString() ?? '') ??
              DateTime.now(),
          status: ConsentStatus.values.firstWhere(
            (e) => e.name == (m['status']?.toString() ?? ''),
            orElse: () => ConsentStatus.sent,
          ),
        );
      }).toList();
      print('[AppState] Consent logs loaded: ${consentLogs.length}');

      wards = [
        Ward(id: 'w1', name: 'Nancholi', district: 'Blantyre'),
        Ward(id: 'w2', name: 'Chilomoni', district: 'Blantyre'),
        Ward(id: 'w3', name: 'Zingwangwa', district: 'Blantyre'),
        Ward(id: 'w4', name: 'Ndirande', district: 'Blantyre'),
      ];
      print('[AppState] All data loaded successfully!');
    } catch (e, stack) {
      print('[AppState] LOAD ERROR: $e');
      print('[AppState] STACK TRACE: $stack');
      loadError = _loadErrorMessage(e);
    }
  }

  String _loadErrorMessage(Object error) {
    final detail = error.toString().replaceFirst('Exception: ', '').trim();
    if (detail.contains('TimeoutException') || detail.contains('timed out')) {
      return 'The server took too long to respond. Please try again.';
    }
    if (detail.contains('SocketException') ||
        detail.contains('Failed host lookup')) {
      return 'Unable to reach the server. Check your internet connection and try again.';
    }
    if (detail.isNotEmpty) {
      return 'Unable to load app data: ${detail.length > 160 ? '${detail.substring(0, 160)}…' : detail}';
    }
    return 'Unable to load app data. Please try again.';
  }

  // ─── Role / session ────────────────────────────────────────────────────────
  void setRole(UserRole role, [Team? team]) {
    currentRole = role;
    currentTeam = team;
    if (role == UserRole.team && team != null) {
      myTeamId = team.id;
    }
    // A signed-in coach sees a restricted roster. Before opening the fan or
    // scout experience, restore the public roster so opponent lineups can
    // resolve player names and published photos as well.
    if (role != UserRole.team && isOnline) {
      unawaited(_restorePublicMatchData());
    }
    if (isOnline) {
      _sendHeartbeat();
    }
    notifyListeners();
  }

  Future<void> _restorePublicMatchData() async {
    try {
      if (kDebugMode) {
        debugPrint(
            '[FAN DATA] Restoring public players and fixtures after role switch.');
      }
      final results = await Future.wait<dynamic>([
        ApiService.fetchLeagueLiveData(),
        ApiService.fetchMatches(),
      ]);
      final leagueData = results[0] as ({
        List<Team> standings,
        List<Player> playerStats,
        Map<String, List<Player>> playerStatsByCompetition,
        Map<String, List<Map<String, dynamic>>> playerGoalBreakdown,
        Set<String> liveLeagueIds
      });
      teams = leagueData.standings;
      teamLeagueStandings = [];
      players = leagueData.playerStats;
      _cachePublishedPlayerImageUrls(players);
      playerStatsByCompetition
        ..clear()
        ..addAll(leagueData.playerStatsByCompetition);
      playerGoalBreakdown
        ..clear()
        ..addAll(leagueData.playerGoalBreakdown);
      liveLeagueIds = leagueData.liveLeagueIds;
      matches = results[1] as List<Match>;
      _logPlayerImageCoverage('fan roster after role switch');
      notifyListeners();
    } catch (error) {
      if (kDebugMode)
        debugPrint('[FAN DATA] Could not restore public roster: $error');
    }
  }

  /// Replace the shared/public cache with the server-authorized team workspace.
  /// This prevents a team session from retaining data loaded before sign-in.
  Future<void> loadTeamWorkspace() async {
    final data = await ApiService.fetchTeamWorkspace();
    final team = ApiService.decodeTeam(data['team'] as Map);
    await _loadTeamBranding(team.logoUrl);
    final competitionStatus = data['competitionStatus'] as Map?;
    teamCompetitionStatus = competitionStatus?['status']?.toString();
    teamLeaguePosition = competitionStatus?['position'] as int?;
    teamLeagueSize = competitionStatus?['totalTeams'] as int?;
    teamEliminated = competitionStatus?['eliminated'] == true;
    // The public competition feed can contain published player photos even
    // when an older team-workspace deployment omits imageUrl. Fetch those
    // URLs once and keep them separately from the restricted player list.
    _cachePublishedPlayerImageUrls(players);
    final workspacePlayers = (data['players'] as List)
        .map((j) => ApiService.decodePlayer(j as Map))
        .toList();
    final needsPhotoFallback = workspacePlayers.any((player) =>
        player.imageUrl == null ||
        player.imageUrl!.trim().isEmpty ||
        player.imageUrl == 'null');
    if (needsPhotoFallback && !_attemptedPublishedPhotoLookup) {
      _attemptedPublishedPhotoLookup = true;
      try {
        _publishedPlayerImageUrls.addAll(
          await ApiService.fetchPublishedPlayerImageUrls(),
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[IMAGE DATA] Public photo fallback failed: $error');
        }
      }
    }
    teams = [team];
    currentTeam = team;
    myTeamId = team.id;
    teamLeagueStandings = (data['competitionStandings'] as List? ?? [])
        .map((j) => ApiService.decodeTeam(j as Map))
        .toList();
    players = workspacePlayers.map((player) {
      final publishedImageUrl = _publishedPlayerImageUrls[player.id];
      if (player.imageUrl != null || publishedImageUrl == null) return player;
      return Player(
        id: player.id,
        name: player.name,
        age: player.age,
        position: player.position,
        teamId: player.teamId,
        teamName: player.teamName,
        wardName: player.wardName,
        jerseyNumber: player.jerseyNumber,
        preferredFoot: player.preferredFoot,
        heightM: player.heightM,
        bio: player.bio,
        parentPhone: player.parentPhone,
        imageUrl: publishedImageUrl,
        goals: player.goals,
        assists: player.assists,
        appearances: player.appearances,
        cleanSheets: player.cleanSheets,
        yellowCards: player.yellowCards,
        redCards: player.redCards,
        consentStatus: player.consentStatus,
      );
    }).toList();
    if (kDebugMode) {
      debugPrint(
          '[TEAM WORKSPACE] team=${team.name} (${team.id}), players=${players.length}');
      debugPrint(
          '[TEAM WORKSPACE] Restored ${players.where((player) => player.imageUrl != null && _publishedPlayerImageUrls.containsKey(player.id)).length} published player photo URL(s).');
    }
    _logPlayerImageCoverage('team workspace');
    matches = (data['matches'] as List)
        .map((j) => ApiService.decodeMatch(j as Map))
        .toList();
    injuries = (data['injuries'] as List)
        .map((j) => ApiService.decodeInjury(j as Map))
        .toList();
    attendance = (data['attendance'] as List)
        .map((j) => ApiService.decodeAttendance(j as Map))
        .toList();
    disciplinary = (data['disciplinary'] as List)
        .map((j) => ApiService.decodeDisciplinary(j as Map))
        .toList();
    videoClips = (data['videos'] as List)
        .map((j) => ApiService.decodeVideo(j as Map))
        .toList();
    sponsorships = (data['sponsorships'] as List)
        .map((j) => ApiService.decodeSponsorship(j as Map))
        .toList();
    transfers = (data['transfers'] as List)
        .map((j) => ApiService.decodeTransfer(j as Map))
        .toList();
    consentLogs = (data['consentLogs'] as List)
        .map((j) => ApiService.decodeConsent(j as Map))
        .toList();
    defaultLineup = [];
    fixtureLineups.clear();
    for (final raw in (data['lineups'] as List? ?? const [])) {
      final row = raw as Map;
      final value = row['playerIds'];
      final ids = value is String
          ? List<String>.from(jsonDecode(value) as List)
          : List<String>.from(value as List);
      final matchId = row['matchId'] as String?;
      if (matchId == null) {
        defaultLineup = ids;
      } else {
        fixtureLineups[matchId] = ids;
      }
    }
    ledger = [];
    notifyListeners();
  }

  Future<void> _loadTeamBranding(String? logoUrl) async {
    if (logoUrl == null || logoUrl.trim().isEmpty) {
      teamBrandPrimary = NasaColors.crimson;
      teamBrandSecondary = NasaColors.gold;
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(logoUrl),
        maximumColorCount: 24,
      );
      final primary = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          NasaColors.crimson;
      final secondary = palette.lightVibrantColor?.color ??
          palette.lightMutedColor?.color ??
          (ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
              ? Colors.white
              : Colors.black);
      teamBrandPrimary = primary;
      teamBrandSecondary = secondary;
    } catch (error) {
      if (kDebugMode)
        debugPrint('[TEAM BRANDING] Could not extract logo colors: $error');
      teamBrandPrimary = NasaColors.crimson;
      teamBrandSecondary = NasaColors.gold;
    }
  }

  void signOut() {
    currentRole = null;
    currentTeam = null;
    ApiService.clearTeamSession();
    notifyListeners();
  }

  void setMyTeam(String teamId) {
    // A team account has exactly one server-authorized club.
    if (currentRole == UserRole.team && teamId != currentTeam?.id) return;
    myTeamId = teamId;
    notifyListeners();
  }

  List<String> lineupForMatch(String matchId) =>
      fixtureLineups[matchId] ?? defaultLineup;

  Future<void> saveLineup(List<String> playerIds,
      {String? matchId, String formation = '4-4-2'}) async {
    final rosterIds =
        playersOfTeam(myTeamId).map((player) => player.id).toSet();
    if (playerIds.length != 11 ||
        playerIds.toSet().length != 11 ||
        !playerIds.every(rosterIds.contains)) {
      throw ArgumentError('Choose 11 different players from your roster.');
    }
    await ApiService.saveTeamLineup(
        matchId: matchId, playerIds: playerIds, formation: formation);
    if (matchId == null) {
      defaultLineup = List.of(playerIds);
    } else {
      fixtureLineups[matchId] = List.of(playerIds);
    }
    notifyListeners();
  }

  // ─── Lookups ───────────────────────────────────────────────────────────────
  Team? teamById(String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) {
        return p;
      }
    }
    // Check if player exists in any competition stats list
    for (final compList in playerStatsByCompetition.values) {
      for (final p in compList) {
        if (p.id == id) {
          return p;
        }
      }
    }
    return null;
  }

  Map<String, List<Map<String, dynamic>>> _decodeGoalBreakdown(Object? raw) {
    final result = <String, List<Map<String, dynamic>>>{};
    if (raw is! Map) return result;
    raw.forEach((playerId, rows) {
      result[playerId.toString()] = (rows is List ? rows : const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
    return result;
  }

  void _debugPlayerCompetitionStats() {
    if (!kDebugMode) return;
    final summary = playerStatsByCompetition.entries.map((entry) {
      final top = [...entry.value]..sort((a, b) => b.goals.compareTo(a.goals));
      final topRows = top
          .take(3)
          .map((p) => '${p.name}:${p.goals}g/${p.appearances}apps')
          .join(', ');
      return '${entry.key}[${entry.value.length}] {$topRows}';
    }).join(' | ');
    debugPrint('[COMPETITION STATS SNAPSHOT] buckets=$summary');
    debugPrint('[GENERAL PLAYER STATS] players=${players.length} '
        'sample=${players.take(5).map((p) => '${p.name}:${p.goals}g/${p.assists}a/${p.appearances}apps').join(', ')}');
  }

  void _syncPlayerAggregatedStats() {
    for (final player in players) {
      _syncSinglePlayerStats(player);
    }
  }

  void _syncSinglePlayerStats(Player player) {
    int totalGoals = player.goals;
    int totalAssists = player.assists;
    int totalAppearances = player.appearances;
    int totalCleanSheets = player.cleanSheets;
    int totalYellowCards = player.yellowCards;
    int totalRedCards = player.redCards;

    final pNameLower = player.name.trim().toLowerCase();
    final isGk = player.position.toLowerCase().contains('goal') ||
        player.position.toLowerCase().contains('gk');

    // 1. Check all competitions in playerStatsByCompetition
    int compGoals = 0;
    int compAssists = 0;
    int compAppearances = 0;
    int compCleanSheets = 0;
    int compYellow = 0;
    int compRed = 0;
    bool foundInComp = false;

    for (final compList in playerStatsByCompetition.values) {
      for (final cp in compList) {
        if (cp.id == player.id ||
            (cp.name.trim().toLowerCase() == pNameLower &&
                cp.teamId == player.teamId)) {
          foundInComp = true;
          if (cp.goals > compGoals) compGoals = cp.goals;
          if (cp.assists > compAssists) compAssists = cp.assists;
          if (cp.appearances > compAppearances)
            compAppearances = cp.appearances;
          if (cp.cleanSheets > compCleanSheets)
            compCleanSheets = cp.cleanSheets;
          if (cp.yellowCards > compYellow) compYellow = cp.yellowCards;
          if (cp.redCards > compRed) compRed = cp.redCards;
        }
      }
    }

    if (foundInComp) {
      if (compGoals > totalGoals) totalGoals = compGoals;
      if (compAssists > totalAssists) totalAssists = compAssists;
      if (compAppearances > totalAppearances)
        totalAppearances = compAppearances;
      if (compCleanSheets > totalCleanSheets)
        totalCleanSheets = compCleanSheets;
      if (compYellow > totalYellowCards) totalYellowCards = compYellow;
      if (compRed > totalRedCards) totalRedCards = compRed;
    }

    // 2. Cross-check with matches & match events
    int matchGoals = 0;
    int matchAssists = 0;
    int matchAppearances = 0;
    int matchYellow = 0;
    int matchRed = 0;
    int matchCleanSheets = 0;

    for (final match in matches) {
      final isHome = match.homeTeamId == player.teamId;
      final isAway = match.awayTeamId == player.teamId;
      final teamPlayed = isHome || isAway;
      if (!teamPlayed) continue;

      bool playerInMatch = false;

      // Check if in lineup
      if (fixtureLineups[match.id]?.contains(player.id) == true ||
          fixtureLineups['${player.teamId}:${match.id}']?.contains(player.id) ==
              true) {
        playerInMatch = true;
      }

      // Check match events
      for (final event in match.events) {
        final isHomeEvent = event.teamName == match.homeTeamName;
        final isAwayEvent = event.teamName == match.awayTeamName;
        final isEventForMyTeam = (isHome && isHomeEvent) ||
            (isAway && isAwayEvent) ||
            (!isHomeEvent && !isAwayEvent);
        if (!isEventForMyTeam) continue;

        final evPlayerLower = event.playerName.trim().toLowerCase();
        final evAssistLower = event.assistName?.trim().toLowerCase();
        final typeStr = event.type.toString().toLowerCase();

        if (typeStr.contains('sub')) {
          // Check substitution in/out
          String outName = '';
          String inName = '';
          if (evPlayerLower.contains('→')) {
            final parts = evPlayerLower.split('→');
            outName = parts[0].trim();
            inName = parts.length > 1 ? parts[1].trim() : '';
          } else if (evPlayerLower.contains('->')) {
            final parts = evPlayerLower.split('->');
            outName = parts[0].trim();
            inName = parts.length > 1 ? parts[1].trim() : '';
          } else if (evPlayerLower.contains('?')) {
            final parts = evPlayerLower.split('?');
            outName = parts[0].trim();
            inName = parts.length > 1 ? parts[1].trim() : '';
          } else if (evPlayerLower.contains('/')) {
            final parts = evPlayerLower.split('/');
            outName = parts[0].trim();
            inName = parts.length > 1 ? parts[1].trim() : '';
          } else {
            inName = evPlayerLower;
          }

          if (outName == pNameLower ||
              inName == pNameLower ||
              evPlayerLower == pNameLower) {
            playerInMatch = true;
          }
        } else {
          if (evPlayerLower == pNameLower) {
            playerInMatch = true;
            if (typeStr == 'goal') {
              matchGoals++;
            } else if (typeStr.contains('yellow')) {
              matchYellow++;
            } else if (typeStr.contains('red')) {
              matchRed++;
            }
          }
          if (evAssistLower != null && evAssistLower == pNameLower) {
            playerInMatch = true;
            matchAssists++;
          }
        }
      }

      if (playerInMatch) {
        matchAppearances++;
        if (isGk && match.status == MatchStatus.fullTime) {
          final conceded = isHome ? match.awayScore : match.homeScore;
          if (conceded == 0) {
            matchCleanSheets++;
          }
        }
      }
    }

    if (matchGoals > totalGoals) totalGoals = matchGoals;
    if (matchAssists > totalAssists) totalAssists = matchAssists;
    if (matchAppearances > totalAppearances)
      totalAppearances = matchAppearances;
    if (matchYellow > totalYellowCards) totalYellowCards = matchYellow;
    if (matchRed > totalRedCards) totalRedCards = matchRed;
    if (matchCleanSheets > totalCleanSheets)
      totalCleanSheets = matchCleanSheets;

    // If a player has recorded stats (goals/assists/cards/clean sheets) but 0 recorded appearances,
    // they must have appeared in at least 1 match.
    if (totalAppearances == 0 &&
        (totalGoals > 0 ||
            totalAssists > 0 ||
            totalYellowCards > 0 ||
            totalCleanSheets > 0)) {
      totalAppearances = matchAppearances > 0 ? matchAppearances : 1;
    }

    player.goals = totalGoals;
    player.assists = totalAssists;
    player.appearances = totalAppearances;
    player.cleanSheets = totalCleanSheets;
    player.yellowCards = totalYellowCards;
    player.redCards = totalRedCards;
  }

  void _logPlayerImageCoverage(String source) {
    if (!kDebugMode) return;
    final playersWithImages = players.where((player) {
      final imageUrl = player.imageUrl;
      return imageUrl != null &&
          imageUrl.trim().isNotEmpty &&
          imageUrl != 'null';
    }).toList();
    debugPrint(
        '[IMAGE DATA] $source: ${playersWithImages.length}/${players.length} player image URLs received.');
    if (playersWithImages.isNotEmpty) {
      debugPrint(
          '[IMAGE DATA] Sample: ${playersWithImages.first.name} → ${ApiService.resolveUrl(playersWithImages.first.imageUrl!)}');
    }
  }

  void _cachePublishedPlayerImageUrls(Iterable<Player> source) {
    for (final player in source) {
      final imageUrl = player.imageUrl?.trim();
      if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null') {
        _publishedPlayerImageUrls[player.id] = imageUrl;
      }
    }
  }

  List<Player> playersOfTeam(String teamId) =>
      players.where((p) => p.teamId == teamId).toList();

  List<Team> get standings {
    final sorted = [...teams];
    sorted.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference)
        return b.goalDifference.compareTo(a.goalDifference);
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  List<Player> get topScorers {
    final sorted = [...players];
    sorted.sort((a, b) => b.goals.compareTo(a.goals));
    return sorted.where((p) => p.goals > 0).toList();
  }

  List<Player> get topAssisters {
    final sorted = [...players];
    sorted.sort((a, b) => b.assists.compareTo(a.assists));
    return sorted.where((p) => p.assists > 0).toList();
  }

  List<Player> get topGoalkeepers {
    final sorted = [...players];
    sorted.sort((a, b) {
      if (b.cleanSheets != a.cleanSheets)
        return b.cleanSheets.compareTo(a.cleanSheets);
      return b.appearances.compareTo(a.appearances);
    });
    return sorted
        .where((p) =>
            p.position.toLowerCase().contains('goal') ||
            p.position.toLowerCase().contains('gk') ||
            p.cleanSheets > 0)
        .toList();
  }

  List<Match> get liveMatches =>
      matches.where((m) => m.status == MatchStatus.live).toList();

  List<Match> get upcomingMatches {
    final list =
        matches.where((m) => m.status == MatchStatus.upcoming).toList();
    list.sort((a, b) => a.kickoff.compareTo(b.kickoff));
    return list;
  }

  List<Match> get pastMatches {
    final list =
        matches.where((m) => m.status == MatchStatus.fullTime).toList();
    list.sort((a, b) => b.kickoff.compareTo(a.kickoff));
    return list;
  }

  bool isWatchlisted(String playerId) =>
      watchlist.any((w) => w.playerId == playerId);

  List<InjuryRecord> injuriesForPlayer(String playerId) =>
      injuries.where((i) => i.playerId == playerId).toList();

  List<AttendanceRecord> attendanceForPlayer(String playerId) =>
      attendance.where((a) => a.playerId == playerId).toList();

  List<DisciplinaryRecord> disciplinaryForPlayer(String playerId) =>
      disciplinary.where((d) => d.playerId == playerId).toList();

  List<VideoClip> videoClipsForPlayer(String playerId) =>
      videoClips.where((v) => v.playerId == playerId).toList();

  double get totalLedgerBalance {
    double bal = 0;
    for (final e in ledger) {
      bal += e.type == LedgerType.income ? e.amountMwk : -e.amountMwk;
    }
    return bal;
  }

  // ─── Player management ─────────────────────────────────────────────────────
  Future<void> addPlayer({
    required String name,
    required int age,
    required String position,
    required String teamId,
    required int jerseyNumber,
    required String preferredFoot,
    required double heightM,
    required String bio,
    required String parentPhone,
    String? imageUrl,
  }) async {
    if (currentRole == UserRole.team && teamId != currentTeam?.id) {
      throw ArgumentError('You can only add players to your own team.');
    }
    final team = teamById(teamId);
    if (team == null) throw ArgumentError('Your team could not be found.');
    final id = _newId('p');
    final p = Player(
      id: id,
      name: name,
      age: age,
      position: position,
      teamId: teamId,
      teamName: team.name,
      wardName: team.wardName,
      jerseyNumber: jerseyNumber,
      preferredFoot: preferredFoot,
      heightM: heightM,
      bio: bio,
      parentPhone: parentPhone,
      imageUrl: imageUrl,
    );
    if (isOnline) await ApiService.savePlayer(p);
    players.add(p);
    notifyListeners();
  }

  Future<void> updatePlayerProfile({
    required Player existing,
    required String name,
    required int age,
    required String position,
    required int jerseyNumber,
    required String preferredFoot,
    required double heightM,
    required String bio,
    required String parentPhone,
    String? imageUrl,
  }) async {
    if (currentRole != UserRole.team || existing.teamId != currentTeam?.id) {
      throw ArgumentError('You can only edit players in your own team.');
    }
    final updated = Player(
      id: existing.id,
      name: name,
      age: age,
      position: position,
      teamId: existing.teamId,
      teamName: existing.teamName,
      wardName: existing.wardName,
      jerseyNumber: jerseyNumber,
      preferredFoot: preferredFoot,
      heightM: heightM,
      bio: bio,
      parentPhone: parentPhone,
      imageUrl: imageUrl,
      goals: existing.goals,
      assists: existing.assists,
      appearances: existing.appearances,
      cleanSheets: existing.cleanSheets,
      yellowCards: existing.yellowCards,
      redCards: existing.redCards,
      consentStatus: existing.consentStatus,
    );
    if (isOnline) await ApiService.updateTeamPlayer(updated);
    final index = players.indexWhere((player) => player.id == existing.id);
    if (index == -1) throw ArgumentError('Player could not be found.');
    players[index] = updated;
    notifyListeners();
  }

  // ─── Consent ───────────────────────────────────────────────────────────────
  Future<void> sendParentalConsent(Player player) async {
    player.consentStatus = ConsentStatus.sent;
    final id = _newId('c');
    final log = ConsentRequestLog(
      id: id,
      playerId: player.id,
      playerName: player.name,
      parentPhone: player.parentPhone,
      sentDate: DateTime.now(),
      status: ConsentStatus.sent,
    );
    consentLogs.insert(0, log);
    if (isOnline) ApiService.sendConsent(log, id).catchError((_) {});
    notifyListeners();
  }

  Future<void> markConsentApproved(String playerId) async {
    final p = playerById(playerId);
    if (p != null) p.consentStatus = ConsentStatus.approved;
    for (final c in consentLogs) {
      if (c.playerId == playerId) c.status = ConsentStatus.approved;
    }
    if (isOnline) ApiService.approveConsent(playerId).catchError((_) {});
    notifyListeners();
  }

  // ─── Injuries ──────────────────────────────────────────────────────────────
  Future<void> addInjuryRecord({
    required String playerId,
    required String injuryType,
    required InjurySeverity severity,
    required int recoveryDays,
    required String notes,
  }) async {
    final p = playerById(playerId);
    if (p == null) return;
    final id = _newId('inj');
    final r = InjuryRecord(
      id: id,
      playerId: playerId,
      playerName: p.name,
      date: DateTime.now(),
      injuryType: injuryType,
      severity: severity,
      recoveryDays: recoveryDays,
      notes: notes,
    );
    injuries.insert(0, r);
    if (isOnline) ApiService.saveInjury(r, id).catchError((_) {});
    notifyListeners();
  }

  Future<void> setInjuryStatus(String injuryId, InjuryStatus status) async {
    for (final i in injuries) {
      if (i.id == injuryId) i.status = status;
    }
    if (isOnline)
      ApiService.updateInjuryStatus(injuryId, status).catchError((_) {});
    notifyListeners();
  }

  // ─── Attendance ────────────────────────────────────────────────────────────
  Future<void> logAttendance({
    required String playerId,
    required int daysPresent,
    required int daysTotal,
    required String loggedBy,
  }) async {
    final p = playerById(playerId);
    if (p == null) return;
    final id = _newId('att');
    final r = AttendanceRecord(
      id: id,
      playerId: playerId,
      playerName: p.name,
      weekOf: DateTime.now(),
      daysPresent: daysPresent,
      daysTotal: daysTotal,
      loggedBy: loggedBy,
    );
    attendance.insert(0, r);
    if (isOnline) ApiService.saveAttendance(r, id).catchError((_) {});
    notifyListeners();
  }

  // ─── Fixtures ──────────────────────────────────────────────────────────────
  Future<void> generateFixture({
    required String homeTeamId,
    required String awayTeamId,
    required String venue,
    required DateTime kickoff,
    required String competition,
    required double travelDistanceKm,
  }) async {
    final home = teamById(homeTeamId);
    final away = teamById(awayTeamId);
    if (home == null || away == null) return;
    final id = _newId('m');
    final m = Match(
      id: id,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      homeTeamName: home.name,
      awayTeamName: away.name,
      venue: venue,
      wardName: home.wardName,
      competition: competition,
      leagueId: home.leagueId,
      leagueName: home.leagueName,
      kickoff: kickoff,
      travelDistanceKm: travelDistanceKm,
    );
    matches.add(m);
    if (isOnline) ApiService.saveMatch(m).catchError((_) {});
    notifyListeners();
  }

  void simulateLiveTick() {
    for (final m in matches) {
      if (m.status == MatchStatus.live && m.minute < 90) {
        m.minute = (m.minute + 1).clamp(0, 90);
      }
    }
    notifyListeners();
  }

  Future<void> addGoalEvent(String matchId,
      {required bool isHome, required String playerName}) async {
    final m =
        matches.firstWhere((m) => m.id == matchId, orElse: () => matches.first);
    if (isHome) {
      m.homeScore += 1;
    } else {
      m.awayScore += 1;
    }
    final ev = MatchEvent(
      minute: m.minute,
      type: 'Goal',
      teamName: isHome ? m.homeTeamName : m.awayTeamName,
      playerName: playerName,
    );
    m.events.add(ev);
    if (isOnline) {
      ApiService.updateMatchScore(m).catchError((_) {});
      ApiService.addMatchEvent(matchId, ev, _newId('me')).catchError((_) {});
    }
    notifyListeners();
  }

  // ─── Referee ratings ───────────────────────────────────────────────────────
  Future<void> addRefereeRating({
    required String refereeId,
    required String matchLabel,
    required String ratedByTeam,
    required int fairnessScore,
    required int communicationScore,
    required String comment,
  }) async {
    final ref = referees.firstWhere(
      (r) => r.id == refereeId,
      orElse: () => referees.first,
    );
    final id = _newId('rr');
    final rating = RefereeRating(
      id: id,
      refereeId: ref.id,
      refereeName: ref.name,
      matchLabel: matchLabel,
      ratedByTeam: ratedByTeam,
      fairnessScore: fairnessScore,
      communicationScore: communicationScore,
      comment: comment,
      date: DateTime.now(),
    );
    refereeRatings.insert(0, rating);
    final allForRef =
        refereeRatings.where((r) => r.refereeId == ref.id).toList();
    ref.avgFairness =
        allForRef.map((r) => r.fairnessScore).reduce((a, b) => a + b) /
            allForRef.length;
    ref.avgCommunication =
        allForRef.map((r) => r.communicationScore).reduce((a, b) => a + b) /
            allForRef.length;
    if (isOnline) ApiService.saveRefereeRating(rating, id).catchError((_) {});
    notifyListeners();
  }

  // ─── Player Fan Ratings & Live Aggregator ─────────────────────────────
  final Map<String, List<Map<String, int>>> _playerFanVotes = {};
  final Map<String, Map<String, int>> _userSubmittedPlayerVotes = {};

  PlayerFanRatingData getPlayerFanRating(String playerId) {
    final player = playerById(playerId);
    final userVote = _userSubmittedPlayerVotes[playerId];

    // Seed realistic baseline community votes based on player performance profile
    double seedForm = 3.8;
    double seedImpact = 3.6;
    double seedWorkRate = 4.0;
    int seedVotes = 24;

    if (player != null) {
      final goalRate =
          player.appearances > 0 ? player.goals / player.appearances : 0.0;
      seedForm =
          (3.5 + (goalRate * 1.5) + (player.assists * 0.2)).clamp(3.0, 4.9);
      seedImpact = (3.2 +
              (player.goals * 0.3) +
              (player.assists * 0.25) +
              (player.cleanSheets * 0.3))
          .clamp(3.0, 5.0);
      seedWorkRate = (4.0 +
              (player.appearances * 0.1) -
              (player.yellowCards * 0.2) -
              (player.redCards * 0.5))
          .clamp(3.0, 5.0);
      seedVotes = 18 + (player.goals * 4) + (player.appearances * 2);
    }

    final localVotes = _playerFanVotes[playerId] ?? [];
    double totalForm = seedForm * seedVotes;
    double totalImpact = seedImpact * seedVotes;
    double totalWorkRate = seedWorkRate * seedVotes;
    int totalCount = seedVotes;

    for (final v in localVotes) {
      totalForm += (v['form'] ?? 3);
      totalImpact += (v['impact'] ?? 3);
      totalWorkRate += (v['workRate'] ?? 3);
      totalCount++;
    }

    final formAvg = totalForm / totalCount;
    final impactAvg = totalImpact / totalCount;
    final workRateAvg = totalWorkRate / totalCount;
    final overallAvg = (formAvg + impactAvg + workRateAvg) / 3.0;

    return PlayerFanRatingData(
      formAvg: formAvg,
      impactAvg: impactAvg,
      workRateAvg: workRateAvg,
      overallAvg: overallAvg,
      totalVotes: totalCount,
      userForm: userVote?['form'],
      userImpact: userVote?['impact'],
      userWorkRate: userVote?['workRate'],
    );
  }

  void submitPlayerFanRating(
      String playerId, int form, int impact, int workRate) {
    final prevVote = _userSubmittedPlayerVotes[playerId];
    _userSubmittedPlayerVotes[playerId] = {
      'form': form,
      'impact': impact,
      'workRate': workRate,
    };

    if (prevVote == null) {
      _playerFanVotes.putIfAbsent(playerId, () => []).add({
        'form': form,
        'impact': impact,
        'workRate': workRate,
      });
    } else {
      final list = _playerFanVotes[playerId];
      if (list != null && list.isNotEmpty) {
        list.last = {
          'form': form,
          'impact': impact,
          'workRate': workRate,
        };
      }
    }

    notifyListeners();
  }

  // ─── Player Scout Attribute Ratings (Radar Chart) ──────────────────────────
  // Ratings are aggregate values returned from MySQL, never generated locally.
  final Map<String, Map<String, int>> _userScoutVotes = {};

  void _applyPlayerScoutRatings(List rawRatings) {
    _playerScoutRatings.clear();
    for (final raw in rawRatings) {
      if (raw is! Map) continue;
      final playerId = raw['playerId']?.toString() ?? '';
      if (playerId.isEmpty) continue;
      final userVote = _userScoutVotes[playerId];
      _playerScoutRatings[playerId] = PlayerScoutRatingData(
        pace: _asDouble(raw['pace']),
        shooting: _asDouble(raw['shooting']),
        passing: _asDouble(raw['passing']),
        dribbling: _asDouble(raw['dribbling']),
        defending: _asDouble(raw['defending']),
        physical: _asDouble(raw['physical']),
        totalVotes: _asInt(raw['totalVotes']),
        userPace: userVote?['pace'],
        userShooting: userVote?['shooting'],
        userPassing: userVote?['passing'],
        userDribbling: userVote?['dribbling'],
        userDefending: userVote?['defending'],
        userPhysical: userVote?['physical'],
      );
    }
  }

  double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  /// Returns the real, database-aggregated scout ratings for the radar chart.
  PlayerScoutRatingData getPlayerScoutRatings(String playerId) {
    final saved = _playerScoutRatings[playerId];
    final userVote = _userScoutVotes[playerId];
    return PlayerScoutRatingData(
      pace: saved?.pace ?? 0,
      shooting: saved?.shooting ?? 0,
      passing: saved?.passing ?? 0,
      dribbling: saved?.dribbling ?? 0,
      defending: saved?.defending ?? 0,
      physical: saved?.physical ?? 0,
      totalVotes: saved?.totalVotes ?? 0,
      userPace: userVote?['pace'],
      userShooting: userVote?['shooting'],
      userPassing: userVote?['passing'],
      userDribbling: userVote?['dribbling'],
      userDefending: userVote?['defending'],
      userPhysical: userVote?['physical'],
    );
  }

  Future<bool> submitPlayerScoutRating(
    String playerId, {
    required int pace,
    required int shooting,
    required int passing,
    required int dribbling,
    required int defending,
    required int physical,
  }) async {
    if (!isOnline) return false;
    try {
      await ApiService.savePlayerScoutRating(
        id: _newId('psr'),
        playerId: playerId,
        pace: pace,
        shooting: shooting,
        passing: passing,
        dribbling: dribbling,
        defending: defending,
        physical: physical,
      );
      _userScoutVotes[playerId] = {
        'pace': pace,
        'shooting': shooting,
        'passing': passing,
        'dribbling': dribbling,
        'defending': defending,
        'physical': physical,
      };
      _applyPlayerScoutRatings(await ApiService.fetchPlayerScoutRatings());
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('[PLAYER RATING] Unable to save rating: $error');
      return false;
    }
  }

  // ─── Disciplinary ──────────────────────────────────────────────────────────
  Future<void> addDisciplinaryRecord({
    required String playerId,
    required String matchLabel,
    required CardType cardType,
    required String reason,
    int suspensionMatches = 0,
    double fineAmount = 0,
  }) async {
    final p = playerById(playerId);
    if (p == null) return;
    final id = _newId('d');
    final r = DisciplinaryRecord(
      id: id,
      playerId: playerId,
      playerName: p.name,
      teamName: p.teamName,
      matchLabel: matchLabel,
      cardType: cardType,
      reason: reason,
      date: DateTime.now(),
      suspensionMatches: suspensionMatches,
      fineAmount: fineAmount,
    );
    disciplinary.insert(0, r);
    if (cardType == CardType.yellow) {
      p.yellowCards += 1;
    } else {
      p.redCards += 1;
    }
    if (isOnline) ApiService.saveDisciplinary(r, id).catchError((_) {});
    notifyListeners();
  }

  Future<void> markFinePaid(String disciplinaryId) async {
    for (final d in disciplinary) {
      if (d.id == disciplinaryId) d.finePaid = true;
    }
    if (isOnline) ApiService.markFinePaid(disciplinaryId).catchError((_) {});
    notifyListeners();
  }

  // ─── Video clips ───────────────────────────────────────────────────────────
  Future<void> uploadVideoClip({
    required String playerId,
    required String title,
    required int durationSeconds,
    required String matchLabel,
  }) async {
    final p = playerById(playerId);
    if (p == null) return;
    final id = _newId('v');
    final v = VideoClip(
      id: id,
      playerId: playerId,
      playerName: p.name,
      teamName: p.teamName,
      title: title,
      durationSeconds: durationSeconds,
      uploadDate: DateTime.now(),
      matchLabel: matchLabel,
    );
    videoClips.insert(0, v);
    if (isOnline) ApiService.saveVideo(v, id).catchError((_) {});
    notifyListeners();
  }

  // ─── Watchlist ─────────────────────────────────────────────────────────────
  void toggleWatchlist(Player player) {
    final existingIndex = watchlist.indexWhere((w) => w.playerId == player.id);
    if (existingIndex >= 0) {
      watchlist.removeAt(existingIndex);
    } else {
      watchlist.insert(
        0,
        WatchlistItem(
          id: _newId('wl'),
          playerId: player.id,
          playerName: player.name,
          teamName: player.teamName,
          addedDate: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void toggleWatchlistAlerts(String playerId) {
    for (final w in watchlist) {
      if (w.playerId == playerId) w.alertsEnabled = !w.alertsEnabled;
    }
    notifyListeners();
  }

  void markAlertRead(String alertId) {
    for (final a in scoutAlerts) {
      if (a.id == alertId) a.read = true;
    }
    notifyListeners();
  }

  // ─── Sponsorships ──────────────────────────────────────────────────────────
  Future<void> addSponsorship({
    required String sponsorName,
    required bool isDiaspora,
    required SponsorshipType type,
    required String targetName,
    required double amountMwk,
    required String message,
  }) async {
    final id = _newId('s');
    final s = Sponsorship(
      id: id,
      sponsorName: sponsorName,
      isDiaspora: isDiaspora,
      type: type,
      targetName: targetName,
      amountMwk: amountMwk,
      message: message,
      date: DateTime.now(),
    );
    sponsorships.insert(0, s);
    final lid = _newId('l');
    final entry = LedgerEntry(
      id: lid,
      date: DateTime.now(),
      description: 'Sponsorship — $sponsorName for $targetName',
      type: LedgerType.income,
      category: 'Sponsorship',
      amountMwk: amountMwk,
    );
    ledger.insert(0, entry);
    if (isOnline) {
      ApiService.saveSponsorship(s, id).catchError((_) {});
      ApiService.saveLedgerEntry(entry, lid).catchError((_) {});
    }
    notifyListeners();
  }

  Future<void> addLedgerExpense({
    required String description,
    required String category,
    required double amountMwk,
  }) async {
    final id = _newId('l');
    final entry = LedgerEntry(
      id: id,
      date: DateTime.now(),
      description: description,
      type: LedgerType.expense,
      category: category,
      amountMwk: amountMwk,
    );
    ledger.insert(0, entry);
    if (isOnline) ApiService.saveLedgerEntry(entry, id).catchError((_) {});
    notifyListeners();
  }

  // ─── Transfers ─────────────────────────────────────────────────────────────
  Future<void> requestTransfer({
    required String playerId,
    required String buyingTeam,
    required double agreedFeeMwk,
  }) async {
    final p = playerById(playerId);
    if (p == null) return;
    final id = _newId('tr');
    final t = TransferEscrow(
      id: id,
      playerId: playerId,
      playerName: p.name,
      sellingTeam: p.teamName,
      buyingTeam: buyingTeam,
      agreedFeeMwk: agreedFeeMwk,
      date: DateTime.now(),
    );
    transfers.insert(0, t);
    if (isOnline) ApiService.saveTransfer(t, id).catchError((_) {});
    notifyListeners();
  }

  Future<void> advanceEscrowStatus(String transferId) async {
    for (final t in transfers) {
      if (t.id == transferId) {
        switch (t.status) {
          case EscrowStatus.awaitingPayment:
            t.status = EscrowStatus.fundsHeld;
            break;
          case EscrowStatus.fundsHeld:
            t.status = EscrowStatus.clearanceReleased;
            final lid = _newId('l');
            final entry = LedgerEntry(
              id: lid,
              date: DateTime.now(),
              description: 'Transfer commission (15%) — ${t.playerName}',
              type: LedgerType.income,
              category: 'Transfer Commission',
              amountMwk: t.commissionAmountMwk,
            );
            ledger.insert(0, entry);
            if (isOnline)
              ApiService.saveLedgerEntry(entry, lid).catchError((_) {});
            break;
          case EscrowStatus.clearanceReleased:
            t.status = EscrowStatus.completed;
            break;
          case EscrowStatus.completed:
            break;
        }
        if (isOnline) ApiService.advanceTransfer(transferId).catchError((_) {});
      }
    }
    notifyListeners();
  }
}
