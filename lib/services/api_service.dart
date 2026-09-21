import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';

/// Central HTTP client for the NAYSA Node.js/MySQL backend.
///
/// ─── SWITCHING ENVIRONMENTS ───────────────────────────────────────────────
/// DEV  (local):  set baseUrl = 'http://localhost:3000/api'
///                Android emulator needs: 'http://10.0.2.2:3000/api'
/// PROD (server): set baseUrl = 'https://yourdomain.com/api'
///
/// Change the line below before building a production release.
/// ─────────────────────────────────────────────────────────────────────────
class ApiService {
  static String? _teamSessionToken;

  // Cache for ETag-based conditional requests (reduces data transfer)
  static String? _appDataETag;
  static Map<String, dynamic>? _cachedAppData;

  /// Makes the next app-data request a full download instead of an ETag 304.
  static void clearAppDataCache() {
    _appDataETag = null;
    _cachedAppData = null;
  }

  static void _loginDebug(String message) {
    if (kDebugMode) debugPrint('[TEAM LOGIN] $message');
  }

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _parseString(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    if (val is String) return val;
    return val.toString();
  }

  static DateTime _parseDateTime(dynamic val, [DateTime? fallback]) {
    final fallbackValue = fallback ?? DateTime.now();
    if (val == null) return fallbackValue;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? fallbackValue;
    return fallbackValue;
  }

  // ↓ Change this to your live server URL when deploying
  static const String _devUrl = 'http://localhost:3000/api';
  static const String _prodUrl = 'https://naysasport.com/backend/api';

  // Set to true when building the production APK / web build
  static const bool _isProduction = true;

  static String get baseUrl => _isProduction ? _prodUrl : _devUrl;

  static String resolveUrl(String url) {
    final value = url.trim();
    // Correct a URL accidentally saved as a Markdown link, for example
    // [photo](https://example.com/photo.jpg), before passing it to Image.network.
    final markdownMatch =
        RegExp(r'^\[[^\]]*\]\((https?://[^)]+)\)$').firstMatch(value);
    final normalized = markdownMatch?.group(1) ?? value;
    if (normalized.startsWith('http')) return normalized;
    final origin = baseUrl.replaceAll(RegExp(r'/backend/api$'), '');
    if (normalized.startsWith('/')) return '$origin$normalized';
    return '$origin/$normalized';
  }

  static Future<dynamic> _get(String path) async {
    try {
      print('[API] GET $baseUrl$path');
      final res = await http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return json.decode(res.body);
      print(
          '[API] GET $path failed with status ${res.statusCode}: ${res.body}');
      throw Exception('GET $path failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      print('[API] GET $path error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> loginTeam(
      String username, String password) async {
    _loginDebug(
        'POST $baseUrl/login (username supplied: ${username.isNotEmpty})');
    final res = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    _loginDebug(
        'Login response: HTTP ${res.statusCode}; ${res.body.length} bytes');
    if (res.statusCode == 401) {
      _loginDebug('Rejected by server: invalid credentials.');
      throw Exception('Invalid username or password');
    }
    if (res.statusCode != 200) {
      _loginDebug('Login service failure: HTTP ${res.statusCode}.');
      throw Exception('Login service is unavailable (${res.statusCode})');
    }
    final data = Map<String, dynamic>.from(json.decode(res.body) as Map);
    _loginDebug(
        'Login response fields: ${data.keys.where((key) => key != 'token').join(', ')}; token returned: ${data['token'] is String}');
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      _loginDebug(
          'Server is running an older login API: no session token returned.');
      throw Exception(
          'Server login is outdated. Please contact the administrator.');
    }
    _teamSessionToken = token;
    return data;
  }

  static Future<Map<String, dynamic>> fetchTeamWorkspace() async {
    final token = _teamSessionToken;
    if (token == null) throw Exception('Team session is missing');
    final res = await http.get(
      Uri.parse('$baseUrl/team-workspace'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    _loginDebug(
        'Team workspace response: HTTP ${res.statusCode}; ${res.body.length} bytes');
    if (res.statusCode != 200) {
      throw Exception('Unable to load team data: ${res.statusCode}');
    }
    return Map<String, dynamic>.from(json.decode(res.body) as Map);
  }

  static void clearTeamSession() => _teamSessionToken = null;

  /// Sends a lightweight heartbeat ping to track active users.
  static Future<void> pingHeartbeat({
    required String deviceId,
    required String role,
    String platform = 'mobile',
    String appVersion = '1.0.0',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ping'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'deviceId': deviceId,
              'role': role,
              'platform': platform,
              'appVersion': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[API] Heartbeat rejected: HTTP ${response.statusCode}');
      }
    } catch (_) {
      debugPrint('[API] Heartbeat request failed');
    }
  }

  static Future<void> saveTeamLineup(
      {String? matchId,
      required List<String> playerIds,
      String formation = '4-4-2'}) async {
    final token = _teamSessionToken;
    if (token == null) throw Exception('Team session is missing');
    final scope = matchId ?? 'default';
    final res = await http
        .put(
          Uri.parse('$baseUrl/team-lineups/$scope'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode({'playerIds': playerIds, 'formation': formation}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200)
      throw Exception('Unable to save lineup (${res.statusCode})');
  }

  /// Fetches both home and away team lineup player IDs & formations for a given match.
  /// Returns `{'home': [...ids], 'homeFormation': '4-4-2', 'away': [...ids], 'awayFormation': '4-4-2'}`.
  static Future<Map<String, dynamic>> fetchMatchLineups(String matchId) async {
    final url = '$baseUrl/match-lineups/$matchId';
    print('[ApiService.fetchMatchLineups] ▶ GET $url');
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      print(
          '[ApiService.fetchMatchLineups] HTTP ${res.statusCode}  body=${res.body.length} chars');
      print(
          '[ApiService.fetchMatchLineups] body preview: ${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
      if (res.statusCode == 404) {
        print('[ApiService.fetchMatchLineups] 404 — returning empty lineups');
        return {
          'home': <String>[],
          'homeFormation': '4-4-2',
          'away': <String>[],
          'awayFormation': '4-4-2'
        };
      }
      if (res.statusCode != 200) {
        throw Exception(
            'Unable to fetch lineups (${res.statusCode}): ${res.body}');
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final home = List<String>.from(
          (data['home'] as List? ?? []).map((e) => e.toString()));
      final away = List<String>.from(
          (data['away'] as List? ?? []).map((e) => e.toString()));
      final homeFormation = (data['homeFormation'] ?? '4-4-2').toString();
      final awayFormation = (data['awayFormation'] ?? '4-4-2').toString();
      print(
          '[ApiService.fetchMatchLineups] ✅ parsed home=${home.length} ($homeFormation)  away=${away.length} ($awayFormation)');
      return {
        'home': home,
        'homeFormation': homeFormation,
        'away': away,
        'awayFormation': awayFormation,
      };
    } catch (e, st) {
      print('[ApiService.fetchMatchLineups] ❌ ERROR: $e');
      print('[ApiService.fetchMatchLineups] Stack: $st');
      rethrow;
    }
  }

  // Decoders used by the authenticated, server-filtered team workspace.
  static Team decodeTeam(Map json) => _teamFromJson(json);
  static Player decodePlayer(Map json) => _playerFromJson(json);
  static Match decodeMatch(Map json) => _matchFromJson(json);
  static InjuryRecord decodeInjury(Map json) => _injuryFromJson(json);
  static AttendanceRecord decodeAttendance(Map json) =>
      _attendanceFromJson(json);
  static DisciplinaryRecord decodeDisciplinary(Map json) =>
      _disciplinaryFromJson(json);
  static VideoClip decodeVideo(Map j) => VideoClip(
      id: j['id'],
      playerId: j['playerId'],
      playerName: j['playerName'],
      teamName: j['teamName'],
      title: j['title'],
      durationSeconds: j['durationSeconds'],
      uploadDate: DateTime.parse(j['uploadDate']),
      matchLabel: j['matchLabel']);
  static Sponsorship decodeSponsorship(Map j) => Sponsorship(
      id: j['id'],
      sponsorName: j['sponsorName'],
      isDiaspora: j['isDiaspora'] == 1,
      type: SponsorshipType.values.firstWhere((e) => e.name == j['type'],
          orElse: () => SponsorshipType.teamAdoption),
      targetName: j['targetName'],
      amountMwk: _parseDouble(j['amountMwk']),
      message: j['message'] ?? '',
      date: DateTime.parse(j['date']),
      imageUrl: j['imageUrl'],
      linkUrl: j['linkUrl']);
  static TransferEscrow decodeTransfer(Map j) => TransferEscrow(
      id: j['id'],
      playerId: j['playerId'],
      playerName: j['playerName'],
      sellingTeam: j['sellingTeam'],
      buyingTeam: j['buyingTeam'],
      agreedFeeMwk: _parseDouble(j['agreedFeeMwk']),
      commissionPercent: _parseDouble(j['commissionPercent'], 15),
      status: EscrowStatus.values.firstWhere((e) => e.name == j['status'],
          orElse: () => EscrowStatus.awaitingPayment),
      date: DateTime.parse(j['date']));
  static ConsentRequestLog decodeConsent(Map j) => ConsentRequestLog(
      id: j['id'],
      playerId: j['playerId'],
      playerName: j['playerName'],
      parentPhone: j['parentPhone'],
      sentDate: DateTime.parse(j['sentDate']),
      status: ConsentStatus.values.firstWhere((e) => e.name == j['status'],
          orElse: () => ConsentStatus.sent));

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (res.statusCode == 200 || res.statusCode == 201)
      return json.decode(res.body);
    throw Exception('POST $path failed: ${res.statusCode} ${res.body}');
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (res.statusCode == 200) return json.decode(res.body);
    throw Exception('PUT $path failed: ${res.statusCode} ${res.body}');
  }

  // ─── Health ────────────────────────────────────────────────────────────────
  static Future<bool> isOnline() async {
    try {
      print('[API] Checking health: $baseUrl/health');
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 15));
      print('[API] Health check response: ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      print('[API] ❌ HEALTH CHECK FAILED: $e');
      print('[API] ❌ BaseUrl: $baseUrl');
      print('[API] ❌ Exception type: ${e.runtimeType}');
      // Fallback: test with leagues endpoint instead
      try {
        print('[API] Trying fallback endpoint: $baseUrl/leagues');
        final fallbackRes = await http
            .get(Uri.parse('$baseUrl/leagues'))
            .timeout(const Duration(seconds: 15));
        print('[API] Fallback response: ${fallbackRes.statusCode}');
        return fallbackRes.statusCode == 200;
      } catch (fallbackE) {
        print('[API] ❌ FALLBACK ALSO FAILED: $fallbackE');
        return false;
      }
    }
  }

  /// OPTIMIZED: Fetch all app data in a single request with ETag caching.
  /// This replaces 18+ individual API calls with 1 request (or 304 if unchanged).
  /// First request: ~2-3 seconds. Subsequent requests: ~100ms (304 Not Modified).
  static Future<Map<String, dynamic>> fetchAppData(
      {bool forceRefresh = false}) async {
    try {
      if (forceRefresh) clearAppDataCache();
      final startTime = DateTime.now();
      print('[API] 🚀 Fetching all app data (ETag: $_appDataETag)...');

      final headers = {'Content-Type': 'application/json'};
      if (_appDataETag != null) {
        headers['If-None-Match'] = _appDataETag!;
      }

      // A 520 is generated by Cloudflare when the origin is briefly
      // unavailable. Retrying a couple of times prevents a short-lived
      // upstream restart from taking the whole app offline.
      const maxAttempts = 3;
      late http.Response res;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        res = await http
            .get(
              Uri.parse('$baseUrl/app-data'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20));

        final isTransientServerError = res.statusCode == 520 ||
            res.statusCode == 522 ||
            res.statusCode == 524 ||
            (res.statusCode >= 500 && res.statusCode < 600);
        if (!isTransientServerError || attempt == maxAttempts) break;

        final retryDelay = Duration(seconds: attempt);
        print('[API] ⚠️  HTTP ${res.statusCode}; retrying app-data request '
            '($attempt/$maxAttempts) in ${retryDelay.inSeconds}s');
        await Future<void>.delayed(retryDelay);
      }

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (res.statusCode == 304) {
        // Not Modified — use cached data
        print('[API] ✅ 304 Not Modified (${elapsed}ms) — using cached data');
        return _cachedAppData ?? {};
      }

      if (res.statusCode == 200) {
        // New data available
        _appDataETag = res.headers['etag'];
        final data = Map<String, dynamic>.from(json.decode(res.body) as Map);
        _cachedAppData = data;
        print('[API] ✅ 200 OK (${elapsed}ms) — fetched complete app data');
        print('[API]    Teams: ${(data['teams'] as List?)?.length ?? 0}');
        print('[API]    Players: ${(data['players'] as List?)?.length ?? 0}');
        print('[API]    Matches: ${(data['matches'] as List?)?.length ?? 0}');
        return data;
      }

      print('[API] ❌ Unexpected status: ${res.statusCode}; '
          'response: ${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
      throw Exception('Failed to fetch app data: ${res.statusCode}');
    } catch (e) {
      print('[API] ❌ Error fetching app data: $e');
      // Return cached data as fallback if available
      if (_cachedAppData != null) {
        print('[API] ⚠️  Using stale cached data due to error');
        return _cachedAppData!;
      }
      rethrow;
    }
  }

  // ─── Teams ─────────────────────────────────────────────────────────────────
  static Future<List<Team>> fetchTeams() async {
    final data = await _get('/teams') as List;
    return data.map((j) => _teamFromJson(j)).toList();
  }

  /// Calculated competition data. Player statistics are returned separately for
  /// every league/cup and must not be combined across competitions.
  static Future<
      ({
        List<Team> standings,
        List<Player> playerStats,
        Map<String, List<Player>> playerStatsByCompetition,
        Map<String, List<Map<String, dynamic>>> playerGoalBreakdown,
        Set<String> liveLeagueIds
      })> fetchLeagueLiveData() async {
    final data =
        Map<String, dynamic>.from(await _get('/league-live-data') as Map);
    final standings = (data['standings'] as List? ?? const [])
        .map((row) => _teamFromJson(row as Map))
        .toList();
    final playerStats = (data['playerStats'] as List? ?? const [])
        .map((row) => _playerFromJson(row as Map))
        .toList();
    final playerStatsByCompetition = <String, List<Player>>{};
    final playerGoalBreakdown = <String, List<Map<String, dynamic>>>{};
    final rawCompetitionStats =
        data['playerStatsByCompetition'] as Map? ?? const {};
    rawCompetitionStats.forEach((competitionId, rows) {
      playerStatsByCompetition[competitionId.toString()] =
          (rows as List? ?? const [])
              .map((row) => _playerFromJson(row as Map))
              .toList();
    });
    final rawGoalBreakdown = data['playerGoalBreakdown'] as Map? ?? const {};
    rawGoalBreakdown.forEach((playerId, rows) {
      playerGoalBreakdown[playerId.toString()] = (rows as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    });
    final liveLeagueIds = (data['liveLeagueIds'] as List? ?? const [])
        .map((id) => id.toString())
        .toSet();
    return (
      standings: standings,
      playerStats: playerStats,
      playerStatsByCompetition: playerStatsByCompetition,
      playerGoalBreakdown: playerGoalBreakdown,
      liveLeagueIds: liveLeagueIds,
    );
  }

  /// Retrieves published player photo URLs when an older team-workspace API
  /// does not include its imageUrl field yet.
  static Future<Map<String, String>> fetchPublishedPlayerImageUrls() async {
    final data =
        Map<String, dynamic>.from(await _get('/league-live-data') as Map);
    final imageUrls = <String, String>{};
    final rows = data['playerStats'] as List? ?? const [];
    for (final row in rows) {
      if (row is! Map) continue;
      final id = _parseString(row['id']).trim();
      final imageUrl = _parseString(row['imageUrl']).trim();
      if (id.isNotEmpty && imageUrl.isNotEmpty && imageUrl != 'null') {
        imageUrls[id] = imageUrl;
      }
    }
    if (kDebugMode) {
      debugPrint(
          '[IMAGE DATA] Public photo lookup returned ${imageUrls.length} player image URL(s).');
    }
    return imageUrls;
  }

  static Future<void> saveTeam(Team t) => _post('/teams', _teamToJson(t));

  static Future<void> updateTeam(Team t) =>
      _put('/teams/${t.id}', _teamToJson(t));

  static Future<void> updateTeamLogo(String logoUrl) async {
    final token = _teamSessionToken;
    if (token == null) throw Exception('Team session is missing');
    final res = await http
        .put(
          Uri.parse('$baseUrl/team-profile/logo'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({'logoUrl': logoUrl}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      String detail = '';
      try {
        detail = (json.decode(res.body) as Map)['error']?.toString() ?? '';
      } catch (_) {}
      if (res.statusCode == 404) {
        throw Exception(
            'The live server has not been updated for team logos yet. Please deploy the latest backend.');
      }
      throw Exception(
          'Unable to save the team logo (${res.statusCode})${detail.isEmpty ? '' : ': $detail'}');
    }
  }

  // ─── Players ───────────────────────────────────────────────────────────────
  static Future<List<Player>> fetchPlayers({String? teamId}) async {
    final path = teamId != null ? '/players?teamId=$teamId' : '/players';
    final data = await _get(path) as List;
    return data.map((j) => _playerFromJson(j)).toList();
  }

  static Future<void> savePlayer(Player p) async {
    final token = _teamSessionToken;
    if (token == null) throw Exception('Team session is missing');
    final res = await http
        .post(
          Uri.parse('$baseUrl/team-players'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode(_playerToJson(p)),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 201) {
      String detail = '';
      try {
        detail = (json.decode(res.body) as Map)['error']?.toString() ?? '';
      } catch (_) {}
      throw Exception(
          'Unable to add player (${res.statusCode})${detail.isEmpty ? '' : ': $detail'}');
    }
  }

  static Future<void> updateTeamPlayer(Player p) async {
    final token = _teamSessionToken;
    if (token == null) throw Exception('Team session is missing');
    final res = await http
        .put(
          Uri.parse('$baseUrl/team-players/${p.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode(_playerToJson(p)),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      String detail = '';
      try {
        detail = (json.decode(res.body) as Map)['error']?.toString() ?? '';
      } catch (_) {}
      throw Exception(
          'Unable to update player (${res.statusCode})${detail.isEmpty ? '' : ': $detail'}');
    }
  }

  /// Uploads a player photo and returns its public URL. Uses bytes rather than
  /// a filesystem path, so the same implementation works on Flutter Web too.
  static Future<String> uploadPlayerImage(XFile file) async {
    final token = _teamSessionToken;
    if (token == null)
      throw Exception('Please sign in as a team before uploading a photo.');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty)
      throw Exception('The selected image is empty. Choose another photo.');
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Image is too large. Choose a photo smaller than 5 MB.');
    }
    final mediaType = _imageMediaType(file);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: file.name,
        contentType: mediaType,
      ));
    debugPrint(
        '[IMAGE UPLOAD] Sending ${file.name} (${bytes.length} bytes, $mediaType) to $baseUrl/upload');
    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 45));
      final body = await streamed.stream.bytesToString();
      debugPrint('[IMAGE UPLOAD] HTTP ${streamed.statusCode}: $body');
      Map<String, dynamic> data = {};
      try {
        data = Map<String, dynamic>.from(json.decode(body) as Map);
      } catch (_) {}
      if (streamed.statusCode != 200) {
        throw Exception(data['error']?.toString() ??
            'Photo upload failed (HTTP ${streamed.statusCode}).');
      }
      final url = data['url']?.toString();
      if (url == null || !url.startsWith('https://')) {
        throw Exception('The server returned an invalid photo URL.');
      }
      return url;
    } catch (error) {
      debugPrint('[IMAGE UPLOAD] Failed: $error');
      rethrow;
    }
  }

  static MediaType _imageMediaType(XFile file) {
    final reportedType = file.mimeType;
    if (reportedType != null && reportedType.startsWith('image/')) {
      try {
        return MediaType.parse(reportedType);
      } catch (_) {
        // Fall back to a reliable extension mapping below.
      }
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  static Future<void> updatePlayerStats(Player p) => _put('/players/${p.id}', {
        'goals': p.goals,
        'assists': p.assists,
        'appearances': p.appearances,
        'cleanSheets': p.cleanSheets,
        'yellowCards': p.yellowCards,
        'redCards': p.redCards,
        'consentStatus': p.consentStatus.name,
      });

  // ─── Matches ───────────────────────────────────────────────────────────────
  static Future<List<Match>> fetchMatches() async {
    final data = await _get('/matches') as List;
    return data.map((j) => _matchFromJson(j)).toList();
  }

  static Future<void> saveMatch(Match m) => _post('/matches', _matchToJson(m));

  static Future<void> updateMatchScore(Match m) => _put('/matches/${m.id}', {
        'status': m.status.name,
        'homeScore': m.homeScore,
        'awayScore': m.awayScore,
        'minute': m.minute,
      });

  static Future<void> addMatchEvent(String matchId, MatchEvent e, String eid) =>
      _post('/matches/$matchId/events', {
        'id': eid,
        'minute': e.minute,
        'type': e.type,
        'teamName': e.teamName,
        'playerName': e.playerName,
        'assistName': e.assistName,
        'isPenalty': e.isPenalty,
      });

  // ─── Injuries ──────────────────────────────────────────────────────────────
  static Future<List<InjuryRecord>> fetchInjuries({String? playerId}) async {
    final path =
        playerId != null ? '/injuries?playerId=$playerId' : '/injuries';
    final data = await _get(path) as List;
    return data.map((j) => _injuryFromJson(j)).toList();
  }

  static Future<void> saveInjury(InjuryRecord r, String id) =>
      _post('/injuries', {
        'id': id,
        'playerId': r.playerId,
        'playerName': r.playerName,
        'date': r.date.toIso8601String(),
        'injuryType': r.injuryType,
        'severity': r.severity.name,
        'recoveryDays': r.recoveryDays,
        'notes': r.notes,
      });

  static Future<void> updateInjuryStatus(
          String injuryId, InjuryStatus status) =>
      _put('/injuries/$injuryId/status', {'status': status.name});

  // ─── Attendance ────────────────────────────────────────────────────────────
  static Future<List<AttendanceRecord>> fetchAttendance(
      {String? playerId}) async {
    final path =
        playerId != null ? '/attendance?playerId=$playerId' : '/attendance';
    final data = await _get(path) as List;
    return data.map((j) => _attendanceFromJson(j)).toList();
  }

  static Future<void> saveAttendance(AttendanceRecord r, String id) =>
      _post('/attendance', {
        'id': id,
        'playerId': r.playerId,
        'playerName': r.playerName,
        'weekOf': r.weekOf.toIso8601String(),
        'daysPresent': r.daysPresent,
        'daysTotal': r.daysTotal,
        'loggedBy': r.loggedBy,
      });

  // ─── Disciplinary ──────────────────────────────────────────────────────────
  static Future<List<DisciplinaryRecord>> fetchDisciplinary() async {
    final data = await _get('/disciplinary') as List;
    return data.map((j) => _disciplinaryFromJson(j)).toList();
  }

  static Future<void> saveDisciplinary(DisciplinaryRecord r, String id) =>
      _post('/disciplinary', {
        'id': id,
        'playerId': r.playerId,
        'playerName': r.playerName,
        'teamName': r.teamName,
        'matchLabel': r.matchLabel,
        'cardType': r.cardType.name,
        'reason': r.reason,
        'date': r.date.toIso8601String(),
        'suspensionMatches': r.suspensionMatches,
        'fineAmount': r.fineAmount,
      });

  static Future<void> markFinePaid(String id) =>
      _put('/disciplinary/$id/pay', {});

  // ─── Referees ──────────────────────────────────────────────────────────────
  static Future<List<RefereeProfile>> fetchReferees() async {
    final data = await _get('/referees') as List;
    return data
        .map((j) => RefereeProfile(
              id: j['id'],
              name: j['name'],
              matchesOfficiated: j['matchesOfficiated'] ?? 0,
              avgFairness: _parseDouble(j['avgFairness'], 0.0),
              avgCommunication: _parseDouble(j['avgCommunication'], 0.0),
            ))
        .toList();
  }

  static Future<List<RefereeRating>> fetchRefereeRatings() async {
    final data = await _get('/referee-ratings') as List;
    return data
        .map((j) => RefereeRating(
              id: j['id'],
              refereeId: j['refereeId'],
              refereeName: j['refereeName'],
              matchLabel: j['matchLabel'],
              ratedByTeam: j['ratedByTeam'],
              fairnessScore: j['fairnessScore'],
              communicationScore: j['communicationScore'],
              comment: j['comment'] ?? '',
              date: DateTime.parse(j['date']),
            ))
        .toList();
  }

  static Future<void> saveRefereeRating(RefereeRating r, String id) =>
      _post('/referee-ratings', {
        'id': id,
        'refereeId': r.refereeId,
        'refereeName': r.refereeName,
        'matchLabel': r.matchLabel,
        'ratedByTeam': r.ratedByTeam,
        'fairnessScore': r.fairnessScore,
        'communicationScore': r.communicationScore,
        'comment': r.comment,
        'date': r.date.toIso8601String(),
      });

  static Future<void> savePlayerScoutRating({
    required String id,
    required String playerId,
    required int pace,
    required int shooting,
    required int passing,
    required int dribbling,
    required int defending,
    required int physical,
  }) =>
      _post('/player-scout-ratings', {
        'id': id,
        'playerId': playerId,
        'pace': pace,
        'shooting': shooting,
        'passing': passing,
        'dribbling': dribbling,
        'defending': defending,
        'physical': physical,
      });

  static Future<List<Map<String, dynamic>>> fetchPlayerScoutRatings() async {
    final data = await _get('/player-scout-ratings') as List;
    return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  // ─── Video Clips ───────────────────────────────────────────────────────────
  static Future<List<VideoClip>> fetchVideos({String? playerId}) async {
    final path = playerId != null ? '/videos?playerId=$playerId' : '/videos';
    final data = await _get(path) as List;
    return data
        .map((j) => VideoClip(
              id: j['id'],
              playerId: j['playerId'],
              playerName: j['playerName'],
              teamName: j['teamName'],
              title: j['title'],
              durationSeconds: j['durationSeconds'],
              uploadDate: DateTime.parse(j['uploadDate']),
              matchLabel: j['matchLabel'],
            ))
        .toList();
  }

  static Future<void> saveVideo(VideoClip v, String id) => _post('/videos', {
        'id': id,
        'playerId': v.playerId,
        'playerName': v.playerName,
        'teamName': v.teamName,
        'title': v.title,
        'durationSeconds': v.durationSeconds,
        'matchLabel': v.matchLabel,
      });

  // ─── Sponsorships ──────────────────────────────────────────────────────────
  static Future<List<Sponsorship>> fetchSponsorships() async {
    final data = await _get('/sponsorships') as List;
    return data
        .map((j) => Sponsorship(
              id: j['id'],
              sponsorName: j['sponsorName'],
              isDiaspora: j['isDiaspora'] == 1,
              type: SponsorshipType.values.firstWhere(
                  (e) => e.name == j['type'],
                  orElse: () => SponsorshipType.teamAdoption),
              targetName: j['targetName'],
              amountMwk: _parseDouble(j['amountMwk'], 0.0),
              message: j['message'] ?? '',
              date: DateTime.parse(j['date']),
              imageUrl: j['imageUrl'],
              linkUrl: j['linkUrl'],
            ))
        .toList();
  }

  static Future<void> saveSponsorship(Sponsorship s, String id) =>
      _post('/sponsorships', {
        'id': id,
        'sponsorName': s.sponsorName,
        'isDiaspora': s.isDiaspora,
        'type': s.type.name,
        'targetName': s.targetName,
        'amountMwk': s.amountMwk,
        'message': s.message,
        'date': s.date.toIso8601String(),
        'imageUrl': s.imageUrl,
        'linkUrl': s.linkUrl,
      });

  // ─── Ledger ────────────────────────────────────────────────────────────────
  static Future<List<LedgerEntry>> fetchLedger() async {
    final data = await _get('/ledger') as List;
    return data
        .map((j) => LedgerEntry(
              id: j['id'],
              date: DateTime.parse(j['date']),
              description: j['description'],
              type: j['type'] == 'income'
                  ? LedgerType.income
                  : LedgerType.expense,
              category: j['category'],
              amountMwk: _parseDouble(j['amountMwk'], 0.0),
            ))
        .toList();
  }

  static Future<void> saveLedgerEntry(LedgerEntry e, String id) =>
      _post('/ledger', {
        'id': id,
        'date': e.date.toIso8601String(),
        'description': e.description,
        'type': e.type.name,
        'category': e.category,
        'amountMwk': e.amountMwk,
      });

  // ─── Transfers ─────────────────────────────────────────────────────────────
  static Future<List<TransferEscrow>> fetchTransfers() async {
    final data = await _get('/transfers') as List;
    return data
        .map((j) => TransferEscrow(
              id: j['id'],
              playerId: j['playerId'],
              playerName: j['playerName'],
              sellingTeam: j['sellingTeam'],
              buyingTeam: j['buyingTeam'],
              agreedFeeMwk: _parseDouble(j['agreedFeeMwk'], 0.0),
              commissionPercent: _parseDouble(j['commissionPercent'], 15),
              status: EscrowStatus.values.firstWhere(
                  (e) => e.name == j['status'],
                  orElse: () => EscrowStatus.awaitingPayment),
              date: DateTime.parse(j['date']),
            ))
        .toList();
  }

  static Future<void> saveTransfer(TransferEscrow t, String id) =>
      _post('/transfers', {
        'id': id,
        'playerId': t.playerId,
        'playerName': t.playerName,
        'sellingTeam': t.sellingTeam,
        'buyingTeam': t.buyingTeam,
        'agreedFeeMwk': t.agreedFeeMwk,
        'commissionPercent': t.commissionPercent,
        'date': t.date.toIso8601String(),
      });

  static Future<void> advanceTransfer(String id) =>
      _put('/transfers/$id/advance', {});

  // ─── Consent ───────────────────────────────────────────────────────────────
  static Future<List<ConsentRequestLog>> fetchConsent() async {
    final data = await _get('/consent') as List;
    return data
        .map((j) => ConsentRequestLog(
              id: j['id'],
              playerId: j['playerId'],
              playerName: j['playerName'],
              parentPhone: j['parentPhone'],
              sentDate: DateTime.parse(j['sentDate']),
              status: ConsentStatus.values.firstWhere(
                  (e) => e.name == j['status'],
                  orElse: () => ConsentStatus.sent),
            ))
        .toList();
  }

  static Future<void> sendConsent(ConsentRequestLog c, String id) =>
      _post('/consent', {
        'id': id,
        'playerId': c.playerId,
        'playerName': c.playerName,
        'parentPhone': c.parentPhone,
        'sentDate': c.sentDate.toIso8601String(),
      });

  static Future<void> approveConsent(String playerId) =>
      _put('/consent/$playerId/approve', {});

  // ─── News ──────────────────────────────────────────────────────────────────
  static Future<List<NewsArticle>> fetchNews() async {
    final data = await _get('/news') as List;
    return data
        .map((j) => NewsArticle(
              id: j['id'],
              title: j['title'],
              summary: j['summary'] ?? '',
              body: j['body'] ?? '',
              date: DateTime.parse(j['date']),
              category: j['category'] ?? '',
              author: j['author'] ?? '',
              imageUrl: j['imageUrl'],
            ))
        .toList();
  }

  // ─── Events ────────────────────────────────────────────────────────────────
  static Future<List<EventItem>> fetchEvents() async {
    final data = await _get('/events') as List;
    return data
        .map((j) => EventItem(
              id: j['id'],
              title: j['title'],
              description: j['description'] ?? '',
              date: DateTime.parse(j['date']),
              venue: j['venue'],
              wardName: j['wardName'],
              type: EventType.values.firstWhere((e) => e.name == j['type'],
                  orElse: () => EventType.tournament),
            ))
        .toList();
  }

  // ─── JSON converters ───────────────────────────────────────────────────────
  static Team _teamFromJson(Map j) => Team(
        id: j['id'],
        name: j['name'],
        wardId: j['wardId'] ?? '',
        wardName: j['wardName'] ?? '',
        leagueId: j['leagueId'] ?? '',
        leagueName: j['leagueName'] ?? '',
        foundedYear: j['foundedYear'] ?? 2020,
        coachName: j['coachName'] ?? '',
        sponsorName: j['sponsorName'],
        groupName: j['groupName']?.toString(),
        logoUrl: j['logoUrl']?.toString(),
        dashboardOnly: _parseInt(j['dashboardOnly'], 0) == 1,
        played: j['played'] ?? 0,
        won: j['won'] ?? 0,
        drawn: j['drawn'] ?? 0,
        lost: j['lost'] ?? 0,
        goalsFor: j['goalsFor'] ?? 0,
        goalsAgainst: j['goalsAgainst'] ?? 0,
      );

  static Map<String, dynamic> _teamToJson(Team t) => {
        'id': t.id,
        'name': t.name,
        'wardId': t.wardId,
        'wardName': t.wardName,
        'leagueId': t.leagueId,
        'leagueName': t.leagueName,
        'foundedYear': t.foundedYear,
        'coachName': t.coachName,
        'sponsorName': t.sponsorName,
        'groupName': t.groupName,
        'logoUrl': t.logoUrl,
        'dashboardOnly': t.dashboardOnly ? 1 : 0,
        'played': t.played,
        'won': t.won,
        'drawn': t.drawn,
        'lost': t.lost,
        'goalsFor': t.goalsFor,
        'goalsAgainst': t.goalsAgainst,
      };

  static Player _playerFromJson(Map j) => Player(
        id: _parseString(j['id']),
        name: _parseString(j['name']),
        age: _parseInt(j['age'], 16),
        position: _parseString(j['position'], 'Midfielder'),
        teamId: _parseString(j['teamId']),
        teamName: _parseString(j['teamName']),
        wardName: _parseString(j['wardName']),
        jerseyNumber: _parseInt(j['jerseyNumber'], 0),
        preferredFoot: _parseString(j['preferredFoot'], 'Right'),
        heightM: _parseDouble(j['heightM'], 1.70),
        bio: _parseString(j['bio']),
        parentPhone: _parseString(j['parentPhone']),
        imageUrl: j['imageUrl']?.toString(),
        goals: _parseInt(j['goals'], 0),
        assists: _parseInt(j['assists'], 0),
        appearances: _parseInt(j['appearances'], 0),
        cleanSheets: _parseInt(j['cleanSheets'], 0),
        yellowCards: _parseInt(j['yellowCards'], 0),
        redCards: _parseInt(j['redCards'], 0),
        consentStatus: ConsentStatus.values.firstWhere(
            (e) => e.name == (j['consentStatus'] ?? 'notSent'),
            orElse: () => ConsentStatus.notSent),
      );

  static Map<String, dynamic> _playerToJson(Player p) => {
        'id': p.id,
        'name': p.name,
        'age': p.age,
        'position': p.position,
        'teamId': p.teamId,
        'teamName': p.teamName,
        'wardName': p.wardName,
        'jerseyNumber': p.jerseyNumber,
        'preferredFoot': p.preferredFoot,
        'heightM': p.heightM,
        'bio': p.bio,
        'parentPhone': p.parentPhone,
        'imageUrl': p.imageUrl,
      };

  static Match _matchFromJson(Map j) {
    try {
      final evList = (j['events'] as List? ?? []);
      return Match(
        id: _parseString(j['id']),
        homeTeamId: _parseString(j['homeTeamId']),
        awayTeamId: _parseString(j['awayTeamId']),
        homeTeamName: _parseString(j['homeTeamName']),
        awayTeamName: _parseString(j['awayTeamName']),
        venue: _parseString(j['venue']),
        wardName: _parseString(j['wardName']),
        competition: _parseString(j['competition']),
        leagueId: _parseString(j['leagueId']),
        leagueName: _parseString(j['leagueName']),
        kickoff: _parseDateTime(j['kickoff'], DateTime.now()),
        stage: _parseString(j['stage'], 'League Match'),
        groupName: j['groupName'] != null ? _parseString(j['groupName']) : null,
        playerOfMatchId: j['playerOfMatchId'] != null
            ? _parseString(j['playerOfMatchId'])
            : null,
        playerOfMatchName: j['playerOfMatchName'] != null
            ? _parseString(j['playerOfMatchName'])
            : null,
        status: MatchStatus.values.firstWhere(
            (e) => e.name == _parseString(j['status'], 'upcoming'),
            orElse: () => MatchStatus.upcoming),
        homeScore: _parseInt(j['homeScore'], 0),
        awayScore: _parseInt(j['awayScore'], 0),
        minute: _parseInt(j['minute'], 0),
        phase: _parseString(j['phase'], 'First Half'),
        travelDistanceKm: _parseDouble(j['travelDistanceKm'], 0.0),
        events: evList.map((e) {
          final eventMap = e is Map ? e : <String, dynamic>{};
          return MatchEvent(
            minute: _parseInt(eventMap['minute'], 0),
            type: _parseString(eventMap['type']),
            teamName: _parseString(eventMap['teamName']),
            playerName: _parseString(eventMap['playerName']),
            assistName: _parseString(eventMap['assistName'], ''),
            isPenalty:
                (eventMap['isPenalty'] == 1 || eventMap['isPenalty'] == true),
          );
        }).toList(),
      );
    } catch (e, st) {
      debugPrint('[MATCH PARSE ERROR] $e');
      debugPrint('Raw match JSON: $j');
      debugPrint('$st');
      rethrow;
    }
  }

  static Map<String, dynamic> _matchToJson(Match m) => {
        'id': m.id,
        'homeTeamId': m.homeTeamId,
        'awayTeamId': m.awayTeamId,
        'homeTeamName': m.homeTeamName,
        'awayTeamName': m.awayTeamName,
        'venue': m.venue,
        'wardName': m.wardName,
        'competition': m.competition,
        'leagueId': m.leagueId,
        'leagueName': m.leagueName,
        'kickoff': m.kickoff.toIso8601String(),
        'stage': m.stage,
        'groupName': m.groupName,
        'playerOfMatchId': m.playerOfMatchId,
        'playerOfMatchName': m.playerOfMatchName,
        'travelDistanceKm': m.travelDistanceKm,
      };

  static Future<List<League>> fetchLeagues() async {
    final data = await _get('/leagues') as List;
    return data
        .map((j) => League(
              id: j['id'],
              name: j['name'],
              description: j['description'] ?? '',
              format: j['format'] ?? 'league',
              advancingTeams: _parseInt(j['advancingTeams'], 2),
              status: j['status'] ?? 'active',
            ))
        .toList();
  }

  static InjuryRecord _injuryFromJson(Map j) => InjuryRecord(
        id: j['id'],
        playerId: j['playerId'],
        playerName: j['playerName'],
        date: DateTime.parse(j['date']),
        injuryType: j['injuryType'] ?? '',
        severity: InjurySeverity.values.firstWhere(
            (e) => e.name == (j['severity'] ?? 'minor'),
            orElse: () => InjurySeverity.minor),
        recoveryDays: j['recoveryDays'] ?? 0,
        status: InjuryStatus.values.firstWhere(
            (e) => e.name == (j['status'] ?? 'recovering'),
            orElse: () => InjuryStatus.recovering),
        notes: j['notes'] ?? '',
      );

  static AttendanceRecord _attendanceFromJson(Map j) => AttendanceRecord(
        id: j['id'],
        playerId: j['playerId'],
        playerName: j['playerName'],
        weekOf: DateTime.parse(j['weekOf']),
        daysPresent: j['daysPresent'] ?? 0,
        daysTotal: j['daysTotal'] ?? 5,
        loggedBy: j['loggedBy'] ?? '',
      );

  static DisciplinaryRecord _disciplinaryFromJson(Map j) => DisciplinaryRecord(
        id: j['id'],
        playerId: j['playerId'],
        playerName: j['playerName'],
        teamName: j['teamName'] ?? '',
        matchLabel: j['matchLabel'] ?? '',
        cardType: j['cardType'] == 'red' ? CardType.red : CardType.yellow,
        reason: j['reason'] ?? '',
        date: DateTime.parse(j['date']),
        suspensionMatches: j['suspensionMatches'] ?? 0,
        fineAmount: _parseDouble(j['fineAmount'], 0.0),
        finePaid: j['finePaid'] == 1,
      );
}
