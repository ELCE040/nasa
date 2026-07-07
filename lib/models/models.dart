// Core data models for Nasa Sport.
//
// These are plain Dart model classes used to back the demo/mock data
// layer (see lib/data/mock_data.dart) and the in-memory AppState
// (see lib/state/app_state.dart). When a real backend is wired in,
// these classes map naturally onto API/JSON payloads.

enum UserRole { viewer, scout, team }

enum MatchStatus { upcoming, live, fullTime, postponed }

enum ConsentStatus { notSent, sent, approved, declined }

enum InjurySeverity { minor, moderate, severe }

enum InjuryStatus { recovering, fit }

enum CardType { yellow, red }

enum EventType { tournament, trial, festival, coachingClinic }

enum SponsorshipType { teamAdoption, tournamentPrizePool, kitSponsorship }

enum LedgerType { income, expense }

enum EscrowStatus { awaitingPayment, fundsHeld, clearanceReleased, completed }

class Ward {
  final String id;
  final String name;
  final String district;
  const Ward({required this.id, required this.name, required this.district});
}

class Team {
  final String id;
  final String name;
  final String wardId;
  final String wardName;
  final int foundedYear;
  final String coachName;
  final String? sponsorName;
  int played;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;

  Team({
    required this.id,
    required this.name,
    required this.wardId,
    required this.wardName,
    required this.foundedYear,
    required this.coachName,
    this.sponsorName,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get points => won * 3 + drawn;
  int get goalDifference => goalsFor - goalsAgainst;
}

class Player {
  final String id;
  final String name;
  final int age;
  final String position;
  final String teamId;
  final String teamName;
  final String wardName;
  final int jerseyNumber;
  final String preferredFoot;
  final double heightM;
  final String bio;
  final String parentPhone;

  int goals;
  int assists;
  int appearances;
  int cleanSheets;
  int yellowCards;
  int redCards;
  ConsentStatus consentStatus;

  Player({
    required this.id,
    required this.name,
    required this.age,
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.wardName,
    required this.jerseyNumber,
    required this.preferredFoot,
    required this.heightM,
    required this.bio,
    required this.parentPhone,
    this.goals = 0,
    this.assists = 0,
    this.appearances = 0,
    this.cleanSheets = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.consentStatus = ConsentStatus.notSent,
  });

  bool get isMinor => age < 18;

  /// A simple, transparent algorithm-based market valuation in MWK.
  /// Real implementation would weigh league strength, scout endorsements,
  /// age curve, etc. This keeps the formula visible to the user.
  double get marketValueMwk {
    const base = 150000.0;
    final goalFactor = goals * 45000.0;
    final assistFactor = assists * 25000.0;
    final formFactor = appearances * 4000.0;
    final cleanSheetFactor = cleanSheets * 30000.0;
    final disciplinePenalty = (yellowCards * 5000.0) + (redCards * 20000.0);
    final ageCurve = age <= 16
        ? 1.15
        : age <= 19
            ? 1.3
            : 1.0;
    final value = (base +
            goalFactor +
            assistFactor +
            formFactor +
            cleanSheetFactor -
            disciplinePenalty) *
        ageCurve;
    return value < 50000 ? 50000 : value;
  }
}

class MatchEvent {
  final int minute;
  final String type; // Goal, Yellow Card, Red Card, Substitution
  final String teamName;
  final String playerName;
  const MatchEvent({
    required this.minute,
    required this.type,
    required this.teamName,
    required this.playerName,
  });
}

class Match {
  final String id;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final String venue;
  final String wardName;
  final String competition;
  final DateTime kickoff;
  MatchStatus status;
  int homeScore;
  int awayScore;
  int minute;
  final List<MatchEvent> events;
  final double travelDistanceKm;

  Match({
    required this.id,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.venue,
    required this.wardName,
    required this.competition,
    required this.kickoff,
    this.status = MatchStatus.upcoming,
    this.homeScore = 0,
    this.awayScore = 0,
    this.minute = 0,
    List<MatchEvent>? events,
    this.travelDistanceKm = 0,
  }) : events = events ?? [];
}

class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String body;
  final DateTime date;
  final String category;
  final String author;
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.date,
    required this.category,
    required this.author,
  });
}

class EventItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String venue;
  final String wardName;
  final EventType type;
  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.venue,
    required this.wardName,
    required this.type,
  });
}

class InjuryRecord {
  final String id;
  final String playerId;
  final String playerName;
  final DateTime date;
  final String injuryType;
  final InjurySeverity severity;
  final int recoveryDays;
  InjuryStatus status;
  final String notes;

  InjuryRecord({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.date,
    required this.injuryType,
    required this.severity,
    required this.recoveryDays,
    this.status = InjuryStatus.recovering,
    this.notes = '',
  });
}

class AttendanceRecord {
  final String id;
  final String playerId;
  final String playerName;
  final DateTime weekOf;
  final int daysPresent;
  final int daysTotal;
  final String loggedBy;

  const AttendanceRecord({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.weekOf,
    required this.daysPresent,
    required this.daysTotal,
    required this.loggedBy,
  });

  double get rate => daysTotal == 0 ? 0 : daysPresent / daysTotal;
}

class DisciplinaryRecord {
  final String id;
  final String playerId;
  final String playerName;
  final String teamName;
  final String matchLabel;
  final CardType cardType;
  final String reason;
  final DateTime date;
  final int suspensionMatches;
  final double fineAmount;
  bool finePaid;

  DisciplinaryRecord({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.matchLabel,
    required this.cardType,
    required this.reason,
    required this.date,
    this.suspensionMatches = 0,
    this.fineAmount = 0,
    this.finePaid = false,
  });
}

class RefereeProfile {
  final String id;
  final String name;
  int matchesOfficiated;
  double avgFairness;
  double avgCommunication;
  RefereeProfile({
    required this.id,
    required this.name,
    this.matchesOfficiated = 0,
    this.avgFairness = 0,
    this.avgCommunication = 0,
  });
}

class RefereeRating {
  final String id;
  final String refereeId;
  final String refereeName;
  final String matchLabel;
  final String ratedByTeam;
  final int fairnessScore;
  final int communicationScore;
  final String comment;
  final DateTime date;
  const RefereeRating({
    required this.id,
    required this.refereeId,
    required this.refereeName,
    required this.matchLabel,
    required this.ratedByTeam,
    required this.fairnessScore,
    required this.communicationScore,
    required this.comment,
    required this.date,
  });
}

class VideoClip {
  final String id;
  final String playerId;
  final String playerName;
  final String teamName;
  final String title;
  final int durationSeconds;
  final DateTime uploadDate;
  final String matchLabel;
  const VideoClip({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.title,
    required this.durationSeconds,
    required this.uploadDate,
    required this.matchLabel,
  });
}

class WatchlistItem {
  final String id;
  final String playerId;
  final String playerName;
  final String teamName;
  final DateTime addedDate;
  bool alertsEnabled;
  WatchlistItem({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.addedDate,
    this.alertsEnabled = true,
  });
}

class ScoutAlert {
  final String id;
  final String playerId;
  final String playerName;
  final String type; // Goal, Man of the Match, Card, Milestone
  final String message;
  final DateTime date;
  bool read;
  ScoutAlert({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.type,
    required this.message,
    required this.date,
    this.read = false,
  });
}

class Sponsorship {
  final String id;
  final String sponsorName;
  final bool isDiaspora;
  final SponsorshipType type;
  final String targetName;
  final double amountMwk;
  final String message;
  final DateTime date;
  const Sponsorship({
    required this.id,
    required this.sponsorName,
    required this.isDiaspora,
    required this.type,
    required this.targetName,
    required this.amountMwk,
    required this.message,
    required this.date,
  });
}

class LedgerEntry {
  final String id;
  final DateTime date;
  final String description;
  final LedgerType type;
  final String category;
  final double amountMwk;

  const LedgerEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    required this.category,
    required this.amountMwk,
  });
}

class TransferEscrow {
  final String id;
  final String playerId;
  final String playerName;
  final String sellingTeam;
  final String buyingTeam;
  final double agreedFeeMwk;
  final double commissionPercent;
  EscrowStatus status;
  final DateTime date;

  TransferEscrow({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.sellingTeam,
    required this.buyingTeam,
    required this.agreedFeeMwk,
    this.commissionPercent = 15,
    this.status = EscrowStatus.awaitingPayment,
    required this.date,
  });

  double get commissionAmountMwk => agreedFeeMwk * commissionPercent / 100;
  double get netToSellingClubMwk => agreedFeeMwk - commissionAmountMwk;
}

class ConsentRequestLog {
  final String id;
  final String playerId;
  final String playerName;
  final String parentPhone;
  final DateTime sentDate;
  ConsentStatus status;
  ConsentRequestLog({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.parentPhone,
    required this.sentDate,
    this.status = ConsentStatus.sent,
  });
}
