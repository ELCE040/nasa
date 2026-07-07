// Demo data for Nasa Sport.
//
// All data here is fictional/illustrative — it exists so every screen in
// the app can be explored end-to-end without a live backend. Swap
// `SeedData.build()` for real API calls when wiring up a backend.

import '../models/models.dart';

class SeedData {
  final List<Ward> wards;
  final List<Team> teams;
  final List<Player> players;
  final List<Match> matches;
  final List<NewsArticle> news;
  final List<EventItem> events;
  final List<InjuryRecord> injuries;
  final List<AttendanceRecord> attendance;
  final List<DisciplinaryRecord> disciplinary;
  final List<RefereeProfile> referees;
  final List<RefereeRating> refereeRatings;
  final List<VideoClip> videoClips;
  final List<Sponsorship> sponsorships;
  final List<LedgerEntry> ledger;
  final List<TransferEscrow> transfers;
  final List<ConsentRequestLog> consentLogs;

  SeedData({
    required this.wards,
    required this.teams,
    required this.players,
    required this.matches,
    required this.news,
    required this.events,
    required this.injuries,
    required this.attendance,
    required this.disciplinary,
    required this.referees,
    required this.refereeRatings,
    required this.videoClips,
    required this.sponsorships,
    required this.ledger,
    required this.transfers,
    required this.consentLogs,
  });

  static SeedData build() {
    final now = DateTime.now();

    final wards = <Ward>[
      const Ward(id: 'w1', name: 'Mtandire Ward', district: 'Lilongwe'),
      const Ward(id: 'w2', name: 'Area 25 Ward', district: 'Lilongwe'),
      const Ward(id: 'w3', name: 'Ndirande Ward', district: 'Blantyre'),
      const Ward(id: 'w4', name: 'Chilomoni Ward', district: 'Blantyre'),
      const Ward(id: 'w5', name: 'Katoto Ward', district: 'Mzuzu'),
      const Ward(id: 'w6', name: 'Chigumula Ward', district: 'Blantyre'),
      const Ward(id: 'w7', name: 'Mtandire South Ward', district: 'Lilongwe'),
      const Ward(id: 'w8', name: 'Naperi Ward', district: 'Zomba'),
    ];

    final teams = <Team>[
      Team(id: 't1', name: 'Mtandire Eagles FC', wardId: 'w1', wardName: 'Mtandire Ward', foundedYear: 2018, coachName: 'Coach Felix Banda', sponsorName: null, played: 8, won: 5, drawn: 2, lost: 1, goalsFor: 17, goalsAgainst: 6),
      Team(id: 't2', name: 'Area 25 Comets FC', wardId: 'w2', wardName: 'Area 25 Ward', foundedYear: 2019, coachName: 'Coach Grace Mvula', sponsorName: 'Lilongwe Hardware Ltd', played: 8, won: 4, drawn: 3, lost: 1, goalsFor: 14, goalsAgainst: 8),
      Team(id: 't3', name: 'Ndirande Tigers FC', wardId: 'w3', wardName: 'Ndirande Ward', foundedYear: 2015, coachName: 'Coach Dalitso Phiri', sponsorName: null, played: 8, won: 6, drawn: 1, lost: 1, goalsFor: 20, goalsAgainst: 5),
      Team(id: 't4', name: 'Chilomoni Falcons FC', wardId: 'w4', wardName: 'Chilomoni Ward', foundedYear: 2020, coachName: 'Coach Joseph Kalulu', sponsorName: null, played: 8, won: 3, drawn: 2, lost: 3, goalsFor: 11, goalsAgainst: 12),
      Team(id: 't5', name: 'Katoto Stars FC', wardId: 'w5', wardName: 'Katoto Ward', foundedYear: 2017, coachName: 'Coach Esther Nyirenda', sponsorName: 'Mzuzu Diaspora Friends', played: 8, won: 5, drawn: 1, lost: 2, goalsFor: 16, goalsAgainst: 9),
      Team(id: 't6', name: 'Chigumula Warriors FC', wardId: 'w6', wardName: 'Chigumula Ward', foundedYear: 2016, coachName: 'Coach Patrick Gondwe', sponsorName: null, played: 8, won: 2, drawn: 2, lost: 4, goalsFor: 9, goalsAgainst: 15),
      Team(id: 't7', name: 'Mtandire South United FC', wardId: 'w7', wardName: 'Mtandire South Ward', foundedYear: 2021, coachName: 'Coach Memory Chirwa', sponsorName: null, played: 8, won: 1, drawn: 3, lost: 4, goalsFor: 7, goalsAgainst: 14),
      Team(id: 't8', name: 'Naperi United FC', wardId: 'w8', wardName: 'Naperi Ward', foundedYear: 2014, coachName: 'Coach Andrew Mbewe', sponsorName: 'Zomba Grain Traders', played: 8, won: 4, drawn: 2, lost: 2, goalsFor: 13, goalsAgainst: 10),
    ];

    final players = <Player>[
      Player(id: 'p1', name: 'Chikondi Banda', age: 16, position: 'Striker', teamId: 't1', teamName: 'Mtandire Eagles FC', wardName: 'Mtandire Ward', jerseyNumber: 9, preferredFoot: 'Right', heightM: 1.68, bio: 'Sharp-shooting forward known for pace in behind defences.', parentPhone: '+265 991 22 33 44', goals: 11, assists: 3, appearances: 8, yellowCards: 1, consentStatus: ConsentStatus.approved),
      Player(id: 'p2', name: 'Limbani Phiri', age: 17, position: 'Midfielder', teamId: 't1', teamName: 'Mtandire Eagles FC', wardName: 'Mtandire Ward', jerseyNumber: 8, preferredFoot: 'Left', heightM: 1.71, bio: 'Box-to-box engine, sets the tempo for the Eagles.', parentPhone: '+265 991 22 33 45', goals: 4, assists: 7, appearances: 8, yellowCards: 2, consentStatus: ConsentStatus.approved),
      Player(id: 'p3', name: 'Yamikani Kachali', age: 15, position: 'Goalkeeper', teamId: 't1', teamName: 'Mtandire Eagles FC', wardName: 'Mtandire Ward', jerseyNumber: 1, preferredFoot: 'Right', heightM: 1.74, bio: 'Commanding shot-stopper, youngest keeper in the league.', parentPhone: '+265 991 22 33 46', cleanSheets: 4, appearances: 8, consentStatus: ConsentStatus.sent),
      Player(id: 'p4', name: 'Tadala Nyirenda', age: 18, position: 'Defender', teamId: 't2', teamName: 'Area 25 Comets FC', wardName: 'Area 25 Ward', jerseyNumber: 4, preferredFoot: 'Right', heightM: 1.79, bio: 'Composed centre-back, strong in the air.', parentPhone: '+265 998 11 22 33', goals: 1, appearances: 8, yellowCards: 3, consentStatus: ConsentStatus.approved),
      Player(id: 'p5', name: 'Chisomo Gondwe', age: 16, position: 'Winger', teamId: 't2', teamName: 'Area 25 Comets FC', wardName: 'Area 25 Ward', jerseyNumber: 11, preferredFoot: 'Left', heightM: 1.66, bio: 'Quick feet, end product still developing.', parentPhone: '+265 998 11 22 34', goals: 6, assists: 5, appearances: 7, consentStatus: ConsentStatus.notSent),
      Player(id: 'p6', name: 'Blessings Mvula', age: 17, position: 'Striker', teamId: 't3', teamName: 'Ndirande Tigers FC', wardName: 'Ndirande Ward', jerseyNumber: 10, preferredFoot: 'Right', heightM: 1.73, bio: 'League\'s leading scorer two seasons running.', parentPhone: '+265 993 44 55 66', goals: 14, assists: 4, appearances: 8, yellowCards: 1, consentStatus: ConsentStatus.approved),
      Player(id: 'p7', name: 'Mphatso Chirwa', age: 17, position: 'Midfielder', teamId: 't3', teamName: 'Ndirande Tigers FC', wardName: 'Ndirande Ward', jerseyNumber: 6, preferredFoot: 'Right', heightM: 1.70, bio: 'Reads the game well beyond his years.', parentPhone: '+265 993 44 55 67', goals: 3, assists: 6, appearances: 8, consentStatus: ConsentStatus.approved),
      Player(id: 'p8', name: 'Thandiwe Banda', age: 14, position: 'Defender', teamId: 't3', teamName: 'Ndirande Tigers FC', wardName: 'Ndirande Ward', jerseyNumber: 5, preferredFoot: 'Left', heightM: 1.60, bio: 'Promising young left-back, school prefect too.', parentPhone: '+265 993 44 55 68', appearances: 6, consentStatus: ConsentStatus.declined),
      Player(id: 'p9', name: 'Dalitso Kalulu', age: 18, position: 'Striker', teamId: 't4', teamName: 'Chilomoni Falcons FC', wardName: 'Chilomoni Ward', jerseyNumber: 7, preferredFoot: 'Right', heightM: 1.77, bio: 'Physical presence, holds the ball up well.', parentPhone: '+265 995 66 77 88', goals: 5, assists: 2, appearances: 8, redCards: 1, consentStatus: ConsentStatus.approved),
      Player(id: 'p10', name: 'Esther Phiri', age: 16, position: 'Midfielder', teamId: 't4', teamName: 'Chilomoni Falcons FC', wardName: 'Chilomoni Ward', jerseyNumber: 14, preferredFoot: 'Right', heightM: 1.64, bio: 'Tireless runner, covers every blade of grass.', parentPhone: '+265 995 66 77 89', goals: 2, assists: 3, appearances: 7, consentStatus: ConsentStatus.sent),
      Player(id: 'p11', name: 'Patrick Mbewe', age: 17, position: 'Defender', teamId: 't5', teamName: 'Katoto Stars FC', wardName: 'Katoto Ward', jerseyNumber: 3, preferredFoot: 'Left', heightM: 1.75, bio: 'Reliable left-back with an eye for an overlap.', parentPhone: '+265 996 33 44 55', goals: 1, assists: 4, appearances: 8, consentStatus: ConsentStatus.approved),
      Player(id: 'p12', name: 'Memory Kachepa', age: 15, position: 'Striker', teamId: 't5', teamName: 'Katoto Stars FC', wardName: 'Katoto Ward', jerseyNumber: 9, preferredFoot: 'Right', heightM: 1.69, bio: 'Explosive pace, one to watch from the north.', parentPhone: '+265 996 33 44 56', goals: 9, assists: 2, appearances: 8, consentStatus: ConsentStatus.notSent),
      Player(id: 'p13', name: 'Andrew Nyasulu', age: 17, position: 'Goalkeeper', teamId: 't6', teamName: 'Chigumula Warriors FC', wardName: 'Chigumula Ward', jerseyNumber: 1, preferredFoot: 'Right', heightM: 1.80, bio: 'Tall keeper, excellent shot-stopper under pressure.', parentPhone: '+265 997 55 66 77', cleanSheets: 2, appearances: 8, consentStatus: ConsentStatus.approved),
      Player(id: 'p14', name: 'Joseph Banda', age: 18, position: 'Winger', teamId: 't7', teamName: 'Mtandire South United FC', wardName: 'Mtandire South Ward', jerseyNumber: 7, preferredFoot: 'Left', heightM: 1.71, bio: 'Direct dribbler, loves to cut inside.', parentPhone: '+265 992 88 99 00', goals: 3, assists: 2, appearances: 8, consentStatus: ConsentStatus.sent),
      Player(id: 'p15', name: 'Grace Chikuse', age: 16, position: 'Defender', teamId: 't8', teamName: 'Naperi United FC', wardName: 'Naperi Ward', jerseyNumber: 2, preferredFoot: 'Right', heightM: 1.67, bio: 'Calm under pressure, rarely loses a duel.', parentPhone: '+265 994 11 33 55', appearances: 8, yellowCards: 1, consentStatus: ConsentStatus.approved),
    ];

    final matches = <Match>[
      Match(
        id: 'm1', homeTeamId: 't1', awayTeamId: 't2',
        homeTeamName: 'Mtandire Eagles FC', awayTeamName: 'Area 25 Comets FC',
        venue: 'Mtandire Community Ground', wardName: 'Mtandire Ward',
        competition: 'Lilongwe Ward Youth League — Round 9',
        kickoff: now.subtract(const Duration(minutes: 58)),
        status: MatchStatus.live, homeScore: 2, awayScore: 1, minute: 58,
        events: [
          const MatchEvent(minute: 12, type: 'Goal', teamName: 'Mtandire Eagles FC', playerName: 'Chikondi Banda'),
          const MatchEvent(minute: 34, type: 'Yellow Card', teamName: 'Area 25 Comets FC', playerName: 'Tadala Nyirenda'),
          const MatchEvent(minute: 41, type: 'Goal', teamName: 'Area 25 Comets FC', playerName: 'Chisomo Gondwe'),
          const MatchEvent(minute: 52, type: 'Goal', teamName: 'Mtandire Eagles FC', playerName: 'Chikondi Banda'),
        ],
        travelDistanceKm: 3.2,
      ),
      Match(
        id: 'm2', homeTeamId: 't3', awayTeamId: 't4',
        homeTeamName: 'Ndirande Tigers FC', awayTeamName: 'Chilomoni Falcons FC',
        venue: 'Ndirande Youth Pitch', wardName: 'Ndirande Ward',
        competition: 'Blantyre Ward Youth League — Round 9',
        kickoff: now.subtract(const Duration(minutes: 22)),
        status: MatchStatus.live, homeScore: 1, awayScore: 0, minute: 22,
        events: [
          const MatchEvent(minute: 9, type: 'Goal', teamName: 'Ndirande Tigers FC', playerName: 'Blessings Mvula'),
        ],
        travelDistanceKm: 4.6,
      ),
      Match(
        id: 'm3', homeTeamId: 't5', awayTeamId: 't6',
        homeTeamName: 'Katoto Stars FC', awayTeamName: 'Chigumula Warriors FC',
        venue: 'Katoto Sports Ground', wardName: 'Katoto Ward',
        competition: 'Northern Cross-District Friendly',
        kickoff: now.add(const Duration(hours: 3)),
        status: MatchStatus.upcoming,
        travelDistanceKm: 187.0,
      ),
      Match(
        id: 'm4', homeTeamId: 't7', awayTeamId: 't8',
        homeTeamName: 'Mtandire South United FC', awayTeamName: 'Naperi United FC',
        venue: 'Mtandire South Pitch', wardName: 'Mtandire South Ward',
        competition: 'Inter-Region Cup — Quarter Final',
        kickoff: now.add(const Duration(days: 1, hours: 2)),
        status: MatchStatus.upcoming,
        travelDistanceKm: 261.0,
      ),
      Match(
        id: 'm5', homeTeamId: 't2', awayTeamId: 't1',
        homeTeamName: 'Area 25 Comets FC', awayTeamName: 'Mtandire Eagles FC',
        venue: 'Area 25 Community Ground', wardName: 'Area 25 Ward',
        competition: 'Lilongwe Ward Youth League — Round 8',
        kickoff: now.subtract(const Duration(days: 6)),
        status: MatchStatus.fullTime, homeScore: 1, awayScore: 3,
        events: [
          const MatchEvent(minute: 18, type: 'Goal', teamName: 'Mtandire Eagles FC', playerName: 'Chikondi Banda'),
          const MatchEvent(minute: 29, type: 'Goal', teamName: 'Area 25 Comets FC', playerName: 'Chisomo Gondwe'),
          const MatchEvent(minute: 60, type: 'Goal', teamName: 'Mtandire Eagles FC', playerName: 'Limbani Phiri'),
          const MatchEvent(minute: 77, type: 'Goal', teamName: 'Mtandire Eagles FC', playerName: 'Chikondi Banda'),
        ],
        travelDistanceKm: 3.2,
      ),
      Match(
        id: 'm6', homeTeamId: 't4', awayTeamId: 't3',
        homeTeamName: 'Chilomoni Falcons FC', awayTeamName: 'Ndirande Tigers FC',
        venue: 'Chilomoni Open Ground', wardName: 'Chilomoni Ward',
        competition: 'Blantyre Ward Youth League — Round 8',
        kickoff: now.subtract(const Duration(days: 5)),
        status: MatchStatus.fullTime, homeScore: 0, awayScore: 2,
        travelDistanceKm: 4.6,
      ),
      Match(
        id: 'm7', homeTeamId: 't6', awayTeamId: 't5',
        homeTeamName: 'Chigumula Warriors FC', awayTeamName: 'Katoto Stars FC',
        venue: 'Chigumula Ground', wardName: 'Chigumula Ward',
        competition: 'Northern Cross-District Friendly',
        kickoff: now.add(const Duration(days: 3)),
        status: MatchStatus.postponed,
        travelDistanceKm: 187.0,
      ),
    ];

    final news = <NewsArticle>[
      NewsArticle(
        id: 'n1',
        title: 'Chikondi Banda nets brace as Eagles soar past Comets',
        summary: 'Mtandire Eagles FC striker continues record-breaking season with two more goals.',
        body: 'Chikondi Banda struck twice as Mtandire Eagles FC moved top of the Lilongwe Ward Youth League table on goal difference. The 16-year-old has now scored 11 goals in 8 appearances this season, drawing attention from regional scouting networks. Coach Felix Banda praised the squad\'s discipline and the support of the Mtandire community in keeping training sessions consistent despite transport costs to away fixtures.',
        date: now.subtract(const Duration(hours: 2)),
        category: 'Match Report',
        author: 'Nasa Sport Desk',
      ),
      NewsArticle(
        id: 'n2',
        title: 'Ndirande Tigers extend unbeaten run to seven matches',
        summary: 'Blessings Mvula\'s early strike secures another win for the Blantyre side.',
        body: 'Ndirande Tigers FC remain the form team of the Blantyre Ward Youth League after a hard-fought win over Chilomoni Falcons FC. Blessings Mvula\'s ninth-minute goal proved decisive, taking his season tally to 14. The Tigers have now gone seven matches without defeat, a club record under Coach Dalitso Phiri.',
        date: now.subtract(const Duration(hours: 6)),
        category: 'Match Report',
        author: 'Nasa Sport Desk',
      ),
      NewsArticle(
        id: 'n3',
        title: 'Diaspora sponsors step up for Katoto Stars ahead of cross-district friendly',
        summary: 'Mzuzu Diaspora Friends group funds travel costs for Saturday\'s long trip south.',
        body: 'A group of Mzuzu-born Malawians living abroad has contributed travel funds to Katoto Stars FC ahead of a demanding 187km trip for a cross-district friendly. The sponsorship, arranged through Nasa Sport\'s adoption portal, will cover transport and meals for the full 18-player travelling squad.',
        date: now.subtract(const Duration(days: 1)),
        category: 'Community',
        author: 'Nasa Sport Desk',
      ),
      NewsArticle(
        id: 'n4',
        title: 'New disciplinary rules tighten registration checks across the league',
        summary: 'Unregistered players will be barred from taking the field under updated rules.',
        body: 'League organisers have confirmed that all clubs must clear outstanding disciplinary fines and registration paperwork before players are eligible to start matches. The change follows several disputes last season over players featuring while serving suspensions.',
        date: now.subtract(const Duration(days: 2)),
        category: 'League News',
        author: 'Nasa Sport Desk',
      ),
      NewsArticle(
        id: 'n5',
        title: 'School attendance now a factor in coach evaluations',
        summary: 'Clubs prioritising education are seeing more interest from corporate sponsors.',
        body: 'Several ward clubs have reported new sponsorship interest after publishing player school attendance records through the Nasa Sport platform. Sponsors say the data gives confidence that football development is not coming at the cost of education.',
        date: now.subtract(const Duration(days: 3)),
        category: 'Community',
        author: 'Nasa Sport Desk',
      ),
    ];

    final events = <EventItem>[
      EventItem(
        id: 'e1',
        title: 'Inter-Region Cup — Quarter Finals',
        description: 'Knockout fixtures between ward champions from Lilongwe, Blantyre, Mzuzu and Zomba regions.',
        date: now.add(const Duration(days: 1, hours: 2)),
        venue: 'Mtandire South Pitch',
        wardName: 'Mtandire South Ward',
        type: EventType.tournament,
      ),
      EventItem(
        id: 'e2',
        title: 'Open Scouting Trials — Under-17',
        description: 'Open trial day for unregistered players aged 14-17 from surrounding wards.',
        date: now.add(const Duration(days: 4)),
        venue: 'Ndirande Youth Pitch',
        wardName: 'Ndirande Ward',
        type: EventType.trial,
      ),
      EventItem(
        id: 'e3',
        title: 'Ward Football Festival',
        description: 'Community festival with mini-tournaments for under-12, under-15 and under-17 age groups.',
        date: now.add(const Duration(days: 9)),
        venue: 'Area 25 Community Ground',
        wardName: 'Area 25 Ward',
        type: EventType.festival,
      ),
      EventItem(
        id: 'e4',
        title: 'Coaching Clinic: Injury Prevention & First Aid',
        description: 'Free clinic for ward coaches covering injury prevention, basic first aid and the medical registry tool.',
        date: now.add(const Duration(days: 12)),
        venue: 'Katoto Sports Ground',
        wardName: 'Katoto Ward',
        type: EventType.coachingClinic,
      ),
    ];

    final injuries = <InjuryRecord>[
      InjuryRecord(id: 'inj1', playerId: 'p9', playerName: 'Dalitso Kalulu', date: now.subtract(const Duration(days: 14)), injuryType: 'Ankle sprain', severity: InjurySeverity.moderate, recoveryDays: 21, status: InjuryStatus.recovering, notes: 'Twisted ankle in training; physio recommended rest until swelling subsides.'),
      InjuryRecord(id: 'inj2', playerId: 'p4', playerName: 'Tadala Nyirenda', date: now.subtract(const Duration(days: 60)), injuryType: 'Hamstring strain', severity: InjurySeverity.minor, recoveryDays: 10, status: InjuryStatus.fit, notes: 'Returned to full training after rehab programme.'),
      InjuryRecord(id: 'inj3', playerId: 'p12', playerName: 'Memory Kachepa', date: now.subtract(const Duration(days: 3)), injuryType: 'Knee knock', severity: InjurySeverity.minor, recoveryDays: 5, status: InjuryStatus.recovering, notes: 'Knock from a tackle, monitored by club first-aider.'),
    ];

    final attendance = <AttendanceRecord>[
      AttendanceRecord(id: 'att1', playerId: 'p1', playerName: 'Chikondi Banda', weekOf: now.subtract(const Duration(days: 7)), daysPresent: 5, daysTotal: 5, loggedBy: 'Coach Felix Banda'),
      AttendanceRecord(id: 'att2', playerId: 'p2', playerName: 'Limbani Phiri', weekOf: now.subtract(const Duration(days: 7)), daysPresent: 4, daysTotal: 5, loggedBy: 'Coach Felix Banda'),
      AttendanceRecord(id: 'att3', playerId: 'p8', playerName: 'Thandiwe Banda', weekOf: now.subtract(const Duration(days: 7)), daysPresent: 3, daysTotal: 5, loggedBy: 'Coach Dalitso Phiri'),
      AttendanceRecord(id: 'att4', playerId: 'p6', playerName: 'Blessings Mvula', weekOf: now.subtract(const Duration(days: 7)), daysPresent: 5, daysTotal: 5, loggedBy: 'Coach Dalitso Phiri'),
    ];

    final disciplinary = <DisciplinaryRecord>[
      DisciplinaryRecord(id: 'd1', playerId: 'p9', playerName: 'Dalitso Kalulu', teamName: 'Chilomoni Falcons FC', matchLabel: 'Chilomoni Falcons FC vs Ndirande Tigers FC', cardType: CardType.red, reason: 'Serious foul play', date: now.subtract(const Duration(days: 5)), suspensionMatches: 2, fineAmount: 5000, finePaid: false),
      DisciplinaryRecord(id: 'd2', playerId: 'p4', playerName: 'Tadala Nyirenda', teamName: 'Area 25 Comets FC', matchLabel: 'Mtandire Eagles FC vs Area 25 Comets FC', cardType: CardType.yellow, reason: 'Tactical foul', date: now.subtract(const Duration(minutes: 24)), fineAmount: 1000, finePaid: true),
      DisciplinaryRecord(id: 'd3', playerId: 'p15', playerName: 'Grace Chikuse', teamName: 'Naperi United FC', matchLabel: 'Naperi United FC vs Katoto Stars FC', cardType: CardType.yellow, reason: 'Dissent', date: now.subtract(const Duration(days: 9)), fineAmount: 1000, finePaid: false),
    ];

    final referees = <RefereeProfile>[
      RefereeProfile(id: 'r1', name: 'Ref. Charles Mhango', matchesOfficiated: 21, avgFairness: 4.4, avgCommunication: 4.1),
      RefereeProfile(id: 'r2', name: 'Ref. Linda Sumani', matchesOfficiated: 17, avgFairness: 4.7, avgCommunication: 4.6),
      RefereeProfile(id: 'r3', name: 'Ref. Peter Kanyenda', matchesOfficiated: 13, avgFairness: 3.6, avgCommunication: 3.4),
    ];

    final refereeRatings = <RefereeRating>[
      RefereeRating(id: 'rr1', refereeId: 'r1', refereeName: 'Ref. Charles Mhango', matchLabel: 'Area 25 Comets FC vs Mtandire Eagles FC', ratedByTeam: 'Mtandire Eagles FC', fairnessScore: 4, communicationScore: 4, comment: 'Fair on both sides, communicated decisions clearly.', date: now.subtract(const Duration(days: 6))),
      RefereeRating(id: 'rr2', refereeId: 'r3', refereeName: 'Ref. Peter Kanyenda', matchLabel: 'Chilomoni Falcons FC vs Ndirande Tigers FC', ratedByTeam: 'Chilomoni Falcons FC', fairnessScore: 3, communicationScore: 3, comment: 'Missed a clear handball but stayed in control of the match.', date: now.subtract(const Duration(days: 5))),
    ];

    final videoClips = <VideoClip>[
      VideoClip(id: 'v1', playerId: 'p1', playerName: 'Chikondi Banda', teamName: 'Mtandire Eagles FC', title: 'Brace vs Area 25 Comets FC', durationSeconds: 24, uploadDate: now.subtract(const Duration(hours: 1)), matchLabel: 'Mtandire Eagles FC vs Area 25 Comets FC'),
      VideoClip(id: 'v2', playerId: 'p6', playerName: 'Blessings Mvula', teamName: 'Ndirande Tigers FC', title: 'Curling opener vs Chilomoni Falcons FC', durationSeconds: 18, uploadDate: now.subtract(const Duration(hours: 5)), matchLabel: 'Ndirande Tigers FC vs Chilomoni Falcons FC'),
      VideoClip(id: 'v3', playerId: 'p12', playerName: 'Memory Kachepa', teamName: 'Katoto Stars FC', title: 'Solo run and finish — training highlight', durationSeconds: 29, uploadDate: now.subtract(const Duration(days: 2)), matchLabel: 'Training session'),
      VideoClip(id: 'v4', playerId: 'p2', playerName: 'Limbani Phiri', teamName: 'Mtandire Eagles FC', title: 'Assist + Man of the Match display', durationSeconds: 27, uploadDate: now.subtract(const Duration(days: 6)), matchLabel: 'Area 25 Comets FC vs Mtandire Eagles FC'),
    ];

    final sponsorships = <Sponsorship>[
      Sponsorship(id: 's1', sponsorName: 'Mzuzu Diaspora Friends', isDiaspora: true, type: SponsorshipType.teamAdoption, targetName: 'Katoto Stars FC', amountMwk: 280000, message: 'For our boys — travel safe and play well!', date: now.subtract(const Duration(days: 1))),
      Sponsorship(id: 's2', sponsorName: 'Lilongwe Hardware Ltd', isDiaspora: false, type: SponsorshipType.kitSponsorship, targetName: 'Area 25 Comets FC', amountMwk: 150000, message: 'Proud to back local talent.', date: now.subtract(const Duration(days: 10))),
      Sponsorship(id: 's3', sponsorName: 'Anonymous Well-wisher (UK)', isDiaspora: true, type: SponsorshipType.tournamentPrizePool, targetName: 'Inter-Region Cup', amountMwk: 400000, message: 'Keep grassroots football growing.', date: now.subtract(const Duration(days: 15))),
      Sponsorship(id: 's4', sponsorName: 'Zomba Grain Traders', isDiaspora: false, type: SponsorshipType.teamAdoption, targetName: 'Naperi United FC', amountMwk: 180000, message: 'Investing in our community\'s youth.', date: now.subtract(const Duration(days: 20))),
    ];

    final ledger = <LedgerEntry>[
      LedgerEntry(id: 'l1', date: now.subtract(const Duration(days: 1)), description: 'Sponsorship — Mzuzu Diaspora Friends', type: LedgerType.income, category: 'Sponsorship', amountMwk: 280000),
      LedgerEntry(id: 'l2', date: now.subtract(const Duration(days: 2)), description: 'Match balls — 12 units', type: LedgerType.expense, category: 'Equipment', amountMwk: 96000),
      LedgerEntry(id: 'l3', date: now.subtract(const Duration(days: 4)), description: 'Referee fees — Round 9 fixtures', type: LedgerType.expense, category: 'Referee Fees', amountMwk: 45000),
      LedgerEntry(id: 'l4', date: now.subtract(const Duration(days: 6)), description: 'Player registration fees — 38 players', type: LedgerType.income, category: 'Registration Fees', amountMwk: 190000),
      LedgerEntry(id: 'l5', date: now.subtract(const Duration(days: 9)), description: 'Transport — Katoto away fixture', type: LedgerType.expense, category: 'Transport', amountMwk: 62000),
      LedgerEntry(id: 'l6', date: now.subtract(const Duration(days: 10)), description: 'Kit sponsorship — Lilongwe Hardware Ltd', type: LedgerType.income, category: 'Sponsorship', amountMwk: 150000),
      LedgerEntry(id: 'l7', date: now.subtract(const Duration(days: 15)), description: 'Inter-Region Cup prize pool contribution', type: LedgerType.income, category: 'Sponsorship', amountMwk: 400000),
      LedgerEntry(id: 'l8', date: now.subtract(const Duration(days: 18)), description: 'Tournament trophies and medals', type: LedgerType.expense, category: 'Prizes', amountMwk: 120000),
    ];

    final transfers = <TransferEscrow>[
      TransferEscrow(id: 'tr1', playerId: 'p6', playerName: 'Blessings Mvula', sellingTeam: 'Ndirande Tigers FC', buyingTeam: 'Blantyre City Academy', agreedFeeMwk: 1200000, status: EscrowStatus.fundsHeld, date: now.subtract(const Duration(days: 2))),
      TransferEscrow(id: 'tr2', playerId: 'p1', playerName: 'Chikondi Banda', sellingTeam: 'Mtandire Eagles FC', buyingTeam: 'Lilongwe Premier Youth', agreedFeeMwk: 900000, status: EscrowStatus.awaitingPayment, date: now.subtract(const Duration(hours: 10))),
    ];

    final consentLogs = <ConsentRequestLog>[
      ConsentRequestLog(id: 'c1', playerId: 'p3', playerName: 'Yamikani Kachali', parentPhone: '+265 991 22 33 46', sentDate: now.subtract(const Duration(days: 2)), status: ConsentStatus.sent),
      ConsentRequestLog(id: 'c2', playerId: 'p10', playerName: 'Esther Phiri', parentPhone: '+265 995 66 77 89', sentDate: now.subtract(const Duration(days: 1)), status: ConsentStatus.sent),
      ConsentRequestLog(id: 'c3', playerId: 'p8', playerName: 'Thandiwe Banda', parentPhone: '+265 993 44 55 68', sentDate: now.subtract(const Duration(days: 12)), status: ConsentStatus.declined),
      ConsentRequestLog(id: 'c4', playerId: 'p14', playerName: 'Joseph Banda', parentPhone: '+265 992 88 99 00', sentDate: now.subtract(const Duration(days: 3)), status: ConsentStatus.sent),
    ];

    return SeedData(
      wards: wards,
      teams: teams,
      players: players,
      matches: matches,
      news: news,
      events: events,
      injuries: injuries,
      attendance: attendance,
      disciplinary: disciplinary,
      referees: referees,
      refereeRatings: refereeRatings,
      videoClips: videoClips,
      sponsorships: sponsorships,
      ledger: ledger,
      transfers: transfers,
      consentLogs: consentLogs,
    );
  }
}
