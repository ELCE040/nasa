import 'package:flutter/foundation.dart';
import '../data/mock_data.dart';
import '../models/models.dart';

/// Single in-memory source of truth for the whole demo app.
///
/// This intentionally mimics what a real app would do against a backend:
/// every mutating method here (sendParentalConsent, addInjuryRecord,
/// fundEscrow, etc.) is the seam where a real HTTP/SMS-gateway/payment
/// call would go. For now they mutate local lists and notify listeners.
class AppState extends ChangeNotifier {
  AppState._internal() {
    final seed = SeedData.build();
    wards = seed.wards;
    teams = seed.teams;
    players = seed.players;
    matches = seed.matches;
    news = seed.news;
    events = seed.events;
    injuries = seed.injuries;
    attendance = seed.attendance;
    disciplinary = seed.disciplinary;
    referees = seed.referees;
    refereeRatings = seed.refereeRatings;
    videoClips = seed.videoClips;
    sponsorships = seed.sponsorships;
    ledger = seed.ledger;
    transfers = seed.transfers;
    consentLogs = seed.consentLogs;
  }

  static final AppState instance = AppState._internal();

  UserRole? currentRole = UserRole.viewer;

  // For the "Team" persona, this is the club the logged-in coach manages.
  String myTeamId = 't1';

  late List<Ward> wards;
  late List<Team> teams;
  late List<Player> players;
  late List<Match> matches;
  late List<NewsArticle> news;
  late List<EventItem> events;
  late List<InjuryRecord> injuries;
  late List<AttendanceRecord> attendance;
  late List<DisciplinaryRecord> disciplinary;
  late List<RefereeProfile> referees;
  late List<RefereeRating> refereeRatings;
  late List<VideoClip> videoClips;
  late List<Sponsorship> sponsorships;
  late List<LedgerEntry> ledger;
  late List<TransferEscrow> transfers;
  late List<ConsentRequestLog> consentLogs;

  final List<WatchlistItem> watchlist = [];
  final List<ScoutAlert> scoutAlerts = [
    ScoutAlert(
      id: 'sa1',
      playerId: 'p6',
      playerName: 'Blessings Mvula',
      type: 'Goal',
      message:
          'Blessings Mvula scored in the 9th minute vs Chilomoni Falcons FC.',
      date: DateTime.now().subtract(const Duration(hours: 6)),
      read: false,
    ),
    ScoutAlert(
      id: 'sa2',
      playerId: 'p1',
      playerName: 'Chikondi Banda',
      type: 'Man of the Match',
      message: 'Chikondi Banda was named Man of the Match last round.',
      date: DateTime.now().subtract(const Duration(days: 6)),
      read: true,
    ),
  ];

  int _idCounter = 1000;
  String _newId(String prefix) => '$prefix${_idCounter++}';

  // ---------------------------------------------------------------------
  // Role / session
  // ---------------------------------------------------------------------
  void setRole(UserRole role) {
    currentRole = role;
    notifyListeners();
  }

  void signOut() {
    currentRole = null;
    notifyListeners();
  }

  void setMyTeam(String teamId) {
    myTeamId = teamId;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------
  Team? teamById(String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Player> playersOfTeam(String teamId) =>
      players.where((p) => p.teamId == teamId).toList();

  List<Team> get standings {
    final sorted = [...teams];
    sorted.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      return b.goalDifference.compareTo(a.goalDifference);
    });
    return sorted;
  }

  List<Player> get topScorers {
    final sorted = [...players];
    sorted.sort((a, b) => b.goals.compareTo(a.goals));
    return sorted.where((p) => p.goals > 0).toList();
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

  void addPlayer({
    required String name,
    required int age,
    required String position,
    required String teamId,
    required int jerseyNumber,
    required String preferredFoot,
    required double heightM,
    required String bio,
    required String parentPhone,
  }) {
    final team = teamById(teamId);
    if (team == null) return;
    players.add(
      Player(
        id: _newId('p'),
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
      ),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Player Identity & Welfare
  // ---------------------------------------------------------------------
  void sendParentalConsent(Player player) {
    player.consentStatus = ConsentStatus.sent;
    consentLogs.insert(
      0,
      ConsentRequestLog(
        id: _newId('c'),
        playerId: player.id,
        playerName: player.name,
        parentPhone: player.parentPhone,
        sentDate: DateTime.now(),
        status: ConsentStatus.sent,
      ),
    );
    notifyListeners();
  }

  void markConsentApproved(String playerId) {
    final p = playerById(playerId);
    if (p != null) p.consentStatus = ConsentStatus.approved;
    for (final c in consentLogs) {
      if (c.playerId == playerId) c.status = ConsentStatus.approved;
    }
    notifyListeners();
  }

  void addInjuryRecord({
    required String playerId,
    required String injuryType,
    required InjurySeverity severity,
    required int recoveryDays,
    required String notes,
  }) {
    final p = playerById(playerId);
    if (p == null) return;
    injuries.insert(
      0,
      InjuryRecord(
        id: _newId('inj'),
        playerId: playerId,
        playerName: p.name,
        date: DateTime.now(),
        injuryType: injuryType,
        severity: severity,
        recoveryDays: recoveryDays,
        notes: notes,
      ),
    );
    notifyListeners();
  }

  void setInjuryStatus(String injuryId, InjuryStatus status) {
    for (final i in injuries) {
      if (i.id == injuryId) i.status = status;
    }
    notifyListeners();
  }

  void logAttendance({
    required String playerId,
    required int daysPresent,
    required int daysTotal,
    required String loggedBy,
  }) {
    final p = playerById(playerId);
    if (p == null) return;
    attendance.insert(
      0,
      AttendanceRecord(
        id: _newId('att'),
        playerId: playerId,
        playerName: p.name,
        weekOf: DateTime.now(),
        daysPresent: daysPresent,
        daysTotal: daysTotal,
        loggedBy: loggedBy,
      ),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Tournament & Match Management
  // ---------------------------------------------------------------------
  void generateFixture({
    required String homeTeamId,
    required String awayTeamId,
    required String venue,
    required DateTime kickoff,
    required String competition,
    required double travelDistanceKm,
  }) {
    final home = teamById(homeTeamId);
    final away = teamById(awayTeamId);
    if (home == null || away == null) return;
    matches.add(
      Match(
        id: _newId('m'),
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        homeTeamName: home.name,
        awayTeamName: away.name,
        venue: venue,
        wardName: home.wardName,
        competition: competition,
        kickoff: kickoff,
        travelDistanceKm: travelDistanceKm,
      ),
    );
    notifyListeners();
  }

  void addRefereeRating({
    required String refereeId,
    required String matchLabel,
    required String ratedByTeam,
    required int fairnessScore,
    required int communicationScore,
    required String comment,
  }) {
    final ref = referees.firstWhere(
      (r) => r.id == refereeId,
      orElse: () => referees.first,
    );
    refereeRatings.insert(
      0,
      RefereeRating(
        id: _newId('rr'),
        refereeId: ref.id,
        refereeName: ref.name,
        matchLabel: matchLabel,
        ratedByTeam: ratedByTeam,
        fairnessScore: fairnessScore,
        communicationScore: communicationScore,
        comment: comment,
        date: DateTime.now(),
      ),
    );
    final allForRef =
        refereeRatings.where((r) => r.refereeId == ref.id).toList();
    ref.avgFairness =
        allForRef.map((r) => r.fairnessScore).reduce((a, b) => a + b) /
            allForRef.length;
    ref.avgCommunication =
        allForRef.map((r) => r.communicationScore).reduce((a, b) => a + b) /
            allForRef.length;
    notifyListeners();
  }

  void addDisciplinaryRecord({
    required String playerId,
    required String matchLabel,
    required CardType cardType,
    required String reason,
    int suspensionMatches = 0,
    double fineAmount = 0,
  }) {
    final p = playerById(playerId);
    if (p == null) return;
    disciplinary.insert(
      0,
      DisciplinaryRecord(
        id: _newId('d'),
        playerId: playerId,
        playerName: p.name,
        teamName: p.teamName,
        matchLabel: matchLabel,
        cardType: cardType,
        reason: reason,
        date: DateTime.now(),
        suspensionMatches: suspensionMatches,
        fineAmount: fineAmount,
      ),
    );
    if (cardType == CardType.yellow) {
      p.yellowCards += 1;
    } else {
      p.redCards += 1;
    }
    notifyListeners();
  }

  void markFinePaid(String disciplinaryId) {
    for (final d in disciplinary) {
      if (d.id == disciplinaryId) d.finePaid = true;
    }
    notifyListeners();
  }

  /// Simulated live-score progression so the Viewer experience feels alive.
  void simulateLiveTick() {
    for (final m in matches) {
      if (m.status == MatchStatus.live && m.minute < 90) {
        m.minute = (m.minute + 1).clamp(0, 90);
      }
    }
    notifyListeners();
  }

  void addGoalEvent(String matchId,
      {required bool isHome, required String playerName}) {
    final m =
        matches.firstWhere((m) => m.id == matchId, orElse: () => matches.first);
    if (isHome) {
      m.homeScore += 1;
    } else {
      m.awayScore += 1;
    }
    m.events.add(MatchEvent(
      minute: m.minute,
      type: 'Goal',
      teamName: isHome ? m.homeTeamName : m.awayTeamName,
      playerName: playerName,
    ));
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Data & Scout Monetization
  // ---------------------------------------------------------------------
  void uploadVideoClip({
    required String playerId,
    required String title,
    required int durationSeconds,
    required String matchLabel,
  }) {
    final p = playerById(playerId);
    if (p == null) return;
    videoClips.insert(
      0,
      VideoClip(
        id: _newId('v'),
        playerId: playerId,
        playerName: p.name,
        teamName: p.teamName,
        title: title,
        durationSeconds: durationSeconds,
        uploadDate: DateTime.now(),
        matchLabel: matchLabel,
      ),
    );
    notifyListeners();
  }

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

  // ---------------------------------------------------------------------
  // Financial Transparency
  // ---------------------------------------------------------------------
  void addSponsorship({
    required String sponsorName,
    required bool isDiaspora,
    required SponsorshipType type,
    required String targetName,
    required double amountMwk,
    required String message,
  }) {
    sponsorships.insert(
      0,
      Sponsorship(
        id: _newId('s'),
        sponsorName: sponsorName,
        isDiaspora: isDiaspora,
        type: type,
        targetName: targetName,
        amountMwk: amountMwk,
        message: message,
        date: DateTime.now(),
      ),
    );
    ledger.insert(
      0,
      LedgerEntry(
        id: _newId('l'),
        date: DateTime.now(),
        description: 'Sponsorship — $sponsorName for $targetName',
        type: LedgerType.income,
        category: 'Sponsorship',
        amountMwk: amountMwk,
      ),
    );
    notifyListeners();
  }

  void addLedgerExpense({
    required String description,
    required String category,
    required double amountMwk,
  }) {
    ledger.insert(
      0,
      LedgerEntry(
        id: _newId('l'),
        date: DateTime.now(),
        description: description,
        type: LedgerType.expense,
        category: category,
        amountMwk: amountMwk,
      ),
    );
    notifyListeners();
  }

  void requestTransfer({
    required String playerId,
    required String buyingTeam,
    required double agreedFeeMwk,
  }) {
    final p = playerById(playerId);
    if (p == null) return;
    transfers.insert(
      0,
      TransferEscrow(
        id: _newId('tr'),
        playerId: playerId,
        playerName: p.name,
        sellingTeam: p.teamName,
        buyingTeam: buyingTeam,
        agreedFeeMwk: agreedFeeMwk,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void advanceEscrowStatus(String transferId) {
    for (final t in transfers) {
      if (t.id == transferId) {
        switch (t.status) {
          case EscrowStatus.awaitingPayment:
            t.status = EscrowStatus.fundsHeld;
            break;
          case EscrowStatus.fundsHeld:
            t.status = EscrowStatus.clearanceReleased;
            ledger.insert(
              0,
              LedgerEntry(
                id: _newId('l'),
                date: DateTime.now(),
                description: 'Transfer commission (15%) — ${t.playerName}',
                type: LedgerType.income,
                category: 'Transfer Commission',
                amountMwk: t.commissionAmountMwk,
              ),
            );
            break;
          case EscrowStatus.clearanceReleased:
            t.status = EscrowStatus.completed;
            break;
          case EscrowStatus.completed:
            break;
        }
      }
    }
    notifyListeners();
  }
}
