CREATE DATABASE IF NOT EXISTS nayshzoc_nasa_db;
USE nayshzoc_nasa_db;

-- ─── Teams ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS teams (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    wardId VARCHAR(50),
    wardName VARCHAR(255),
    leagueId VARCHAR(50),
    leagueName VARCHAR(255),
    foundedYear INT,
    coachName VARCHAR(255),
    sponsorName VARCHAR(255),
    dashboardOnly TINYINT(1) NOT NULL DEFAULT 0,
    isExternal TINYINT(1) NOT NULL DEFAULT 0,
    played INT DEFAULT 0,
    won INT DEFAULT 0,
    drawn INT DEFAULT 0,
    lost INT DEFAULT 0,
    goalsFor INT DEFAULT 0,
    goalsAgainst INT DEFAULT 0
);

-- ─── Players ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS players (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    age INT,
    position VARCHAR(50),
    teamId VARCHAR(50),
    teamName VARCHAR(255),
    wardName VARCHAR(255),
    jerseyNumber INT,
    preferredFoot VARCHAR(20),
    heightM FLOAT,
    bio TEXT,
    parentPhone VARCHAR(50),
    imageUrl TEXT DEFAULT NULL,
    goals INT DEFAULT 0,
    assists INT DEFAULT 0,
    appearances INT DEFAULT 0,
    cleanSheets INT DEFAULT 0,
    yellowCards INT DEFAULT 0,
    redCards INT DEFAULT 0,
    statsManualOverride TINYINT(1) NOT NULL DEFAULT 0,
    consentStatus VARCHAR(20) DEFAULT 'notSent'
);

-- ─── Matches ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS matches (
    id VARCHAR(50) PRIMARY KEY,
    homeTeamId VARCHAR(50),
    awayTeamId VARCHAR(50),
    homeTeamName VARCHAR(255),
    awayTeamName VARCHAR(255),
    venue VARCHAR(255),
    wardName VARCHAR(255),
    competition VARCHAR(255),
    leagueId VARCHAR(50),
    leagueName VARCHAR(255),
    kickoff DATETIME,
    status VARCHAR(20) DEFAULT 'upcoming',
    homeScore INT DEFAULT 0,
    awayScore INT DEFAULT 0,
    minute INT DEFAULT 0,
    travelDistanceKm FLOAT DEFAULT 0,
    isPrivate TINYINT(1) NOT NULL DEFAULT 0,
    playerOfMatchId VARCHAR(50) NULL,
    playerOfMatchName VARCHAR(255) NULL,
    liveStartedAt DATETIME NULL
);

-- ─── Leagues ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leagues (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    format VARCHAR(50) DEFAULT 'league',
    advancingTeams INT NOT NULL DEFAULT 2
);

-- ─── Match Events ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS match_events (
    id VARCHAR(50) PRIMARY KEY,
    matchId VARCHAR(50),
    minute INT,
    type VARCHAR(50),
    teamName VARCHAR(255),
    playerName VARCHAR(255)
);

-- A saved XI belongs to one team. matchId is NULL for the club's default XI.
CREATE TABLE IF NOT EXISTS team_lineups (
    id VARCHAR(120) PRIMARY KEY,
    teamId VARCHAR(50) NOT NULL,
    matchId VARCHAR(50) NULL,
    playerIds LONGTEXT NOT NULL,
    updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_team_fixture (teamId, matchId)
);

-- ─── Injuries ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS injuries (
    id VARCHAR(50) PRIMARY KEY,
    playerId VARCHAR(50),
    playerName VARCHAR(255),
    date DATETIME,
    injuryType VARCHAR(255),
    severity VARCHAR(20),
    recoveryDays INT,
    status VARCHAR(20) DEFAULT 'recovering',
    notes TEXT
);

-- ─── Attendance ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
    id VARCHAR(50) PRIMARY KEY,
    playerId VARCHAR(50),
    playerName VARCHAR(255),
    weekOf DATETIME,
    daysPresent INT,
    daysTotal INT,
    loggedBy VARCHAR(255)
);

-- ─── Disciplinary ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS disciplinary (
    id VARCHAR(50) PRIMARY KEY,
    playerId VARCHAR(50),
    playerName VARCHAR(255),
    teamName VARCHAR(255),
    matchLabel VARCHAR(255),
    cardType VARCHAR(10),
    reason TEXT,
    date DATETIME,
    suspensionMatches INT DEFAULT 0,
    fineAmount DECIMAL(12,2) DEFAULT 0,
    finePaid TINYINT(1) DEFAULT 0
);

-- ─── Referees ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referees (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255),
    matchesOfficiated INT DEFAULT 0,
    avgFairness FLOAT DEFAULT 0,
    avgCommunication FLOAT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS referee_ratings (
    id VARCHAR(50) PRIMARY KEY,
    refereeId VARCHAR(50),
    refereeName VARCHAR(255),
    matchLabel VARCHAR(255),
    ratedByTeam VARCHAR(255),
    fairnessScore INT,
    communicationScore INT,
    comment TEXT,
    date DATETIME
);

-- Individual scout submissions. The app reads the database averages per player.
CREATE TABLE IF NOT EXISTS player_scout_ratings (
    id VARCHAR(120) PRIMARY KEY,
    playerId VARCHAR(50) NOT NULL,
    pace INT NOT NULL,
    shooting INT NOT NULL,
    passing INT NOT NULL,
    dribbling INT NOT NULL,
    defending INT NOT NULL,
    physical INT NOT NULL,
    submittedAt DATETIME NOT NULL,
    INDEX idx_player_scout_ratings_player (playerId)
);

-- ─── Video Clips ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS video_clips (
    id VARCHAR(50) PRIMARY KEY,
    playerId VARCHAR(50),
    playerName VARCHAR(255),
    teamName VARCHAR(255),
    title VARCHAR(255),
    durationSeconds INT,
    uploadDate DATETIME,
    matchLabel VARCHAR(255)
);

-- ─── Sponsorships ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sponsorships (
    id VARCHAR(50) PRIMARY KEY,
    sponsorName VARCHAR(255),
    isDiaspora TINYINT(1) DEFAULT 0,
    type VARCHAR(50),
    targetName VARCHAR(255),
    amountMwk DECIMAL(14,2),
    message TEXT,
    date DATETIME,
    imageUrl TEXT,
    linkUrl TEXT
);

-- ─── Ledger ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ledger (
    id VARCHAR(50) PRIMARY KEY,
    date DATETIME,
    description TEXT,
    type VARCHAR(20),
    category VARCHAR(100),
    amountMwk DECIMAL(14,2)
);

-- ─── Transfers ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transfers (
    id VARCHAR(50) PRIMARY KEY,
    playerId VARCHAR(50),
    playerName VARCHAR(255),
    sellingTeam VARCHAR(255),
    buyingTeam VARCHAR(255),
    agreedFeeMwk DECIMAL(14,2),
    commissionPercent FLOAT DEFAULT 15,
    status VARCHAR(30) DEFAULT 'awaitingPayment',
    date DATETIME
);

-- ─── Consent Logs ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS consent_logs (
    id VARCHAR(50) PRIMARY KEY,
    playerId VARCHAR(50),
    playerName VARCHAR(255),
    parentPhone VARCHAR(50),
    sentDate DATETIME,
    status VARCHAR(20) DEFAULT 'sent'
);

-- ─── News ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS news (
    id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(500),
    summary TEXT,
    body LONGTEXT,
    date DATETIME,
    category VARCHAR(100),
    author VARCHAR(255),
    imageUrl TEXT
);

-- ─── Events ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
    id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(500),
    description TEXT,
    date DATETIME,
    venue VARCHAR(255),
    wardName VARCHAR(255),
    type VARCHAR(50)
);

-- ─── Seed Data ────────────────────────────────────────────────────────────────
INSERT IGNORE INTO teams (id, name, wardId, wardName, foundedYear, coachName, sponsorName, played, won, drawn, lost, goalsFor, goalsAgainst) VALUES
('t1', 'Mtandire Eagles FC', 'w1', 'Mtandire Ward', 2018, 'Coach Felix Banda', NULL, 8, 5, 2, 1, 17, 6),
('t2', 'Area 25 Comets FC', 'w2', 'Area 25 Ward', 2019, 'Coach Grace Mvula', 'Lilongwe Hardware Ltd', 8, 4, 3, 1, 14, 8),
('t3', 'Ndirande Tigers FC', 'w3', 'Ndirande Ward', 2015, 'Coach Dalitso Phiri', NULL, 8, 6, 1, 1, 20, 5),
('t4', 'Chilomoni Falcons FC', 'w4', 'Chilomoni Ward', 2020, 'Coach Joseph Kalulu', NULL, 8, 3, 2, 3, 11, 12),
('t5', 'Katoto Stars FC', 'w5', 'Katoto Ward', 2017, 'Coach Esther Nyirenda', 'Mzuzu Diaspora Friends', 8, 5, 1, 2, 16, 9),
('t6', 'Chigumula Warriors FC', 'w6', 'Chigumula Ward', 2016, 'Coach Patrick Gondwe', NULL, 8, 2, 2, 4, 9, 15),
('t7', 'Mtandire South United FC', 'w7', 'Mtandire South Ward', 2021, 'Coach Memory Chirwa', NULL, 8, 1, 3, 4, 7, 14),
('t8', 'Naperi United FC', 'w8', 'Naperi Ward', 2014, 'Coach Andrew Mbewe', 'Zomba Grain Traders', 8, 4, 2, 2, 13, 10);

INSERT IGNORE INTO players (id, name, age, position, teamId, teamName, wardName, jerseyNumber, preferredFoot, heightM, bio, parentPhone, goals, assists, appearances, cleanSheets, yellowCards, redCards, consentStatus) VALUES
('p1', 'Chikondi Banda', 16, 'Striker', 't1', 'Mtandire Eagles FC', 'Mtandire Ward', 9, 'Right', 1.68, 'Sharp-shooting forward known for pace in behind defences.', '+265 991 22 33 44', 11, 3, 8, 0, 1, 0, 'approved'),
('p2', 'Limbani Phiri', 17, 'Midfielder', 't1', 'Mtandire Eagles FC', 'Mtandire Ward', 8, 'Left', 1.71, 'Box-to-box engine, sets the tempo for the Eagles.', '+265 991 22 33 45', 4, 7, 8, 0, 2, 0, 'approved'),
('p3', 'Yamikani Kachali', 15, 'Goalkeeper', 't1', 'Mtandire Eagles FC', 'Mtandire Ward', 1, 'Right', 1.74, 'Commanding shot-stopper, youngest keeper in the league.', '+265 991 22 33 46', 0, 0, 8, 4, 0, 0, 'sent'),
('p4', 'Tadala Nyirenda', 18, 'Defender', 't2', 'Area 25 Comets FC', 'Area 25 Ward', 4, 'Right', 1.79, 'Composed centre-back, strong in the air.', '+265 998 11 22 33', 1, 0, 8, 0, 3, 0, 'approved'),
('p5', 'Chisomo Gondwe', 16, 'Winger', 't2', 'Area 25 Comets FC', 'Area 25 Ward', 11, 'Left', 1.66, 'Quick feet, end product still developing.', '+265 998 11 22 34', 6, 5, 7, 0, 0, 0, 'notSent'),
('p6', 'Blessings Mvula', 17, 'Striker', 't3', 'Ndirande Tigers FC', 'Ndirande Ward', 10, 'Right', 1.73, 'League''s leading scorer two seasons running.', '+265 993 44 55 66', 14, 4, 8, 0, 1, 0, 'approved'),
('p7', 'Mphatso Chirwa', 17, 'Midfielder', 't3', 'Ndirande Tigers FC', 'Ndirande Ward', 6, 'Right', 1.70, 'Reads the game well beyond his years.', '+265 993 44 55 67', 3, 6, 8, 0, 0, 0, 'approved'),
('p8', 'Thandiwe Banda', 14, 'Defender', 't3', 'Ndirande Tigers FC', 'Ndirande Ward', 5, 'Left', 1.60, 'Promising young left-back, school prefect too.', '+265 993 44 55 68', 0, 0, 6, 0, 0, 0, 'declined'),
('p9', 'Dalitso Kalulu', 18, 'Striker', 't4', 'Chilomoni Falcons FC', 'Chilomoni Ward', 7, 'Right', 1.77, 'Physical presence, holds the ball up well.', '+265 995 66 77 88', 5, 2, 8, 0, 0, 1, 'approved'),
('p10', 'Esther Phiri', 16, 'Midfielder', 't4', 'Chilomoni Falcons FC', 'Chilomoni Ward', 14, 'Right', 1.64, 'Tireless runner, covers every blade of grass.', '+265 995 66 77 89', 2, 3, 7, 0, 0, 0, 'sent'),
('p11', 'Patrick Mbewe', 17, 'Defender', 't5', 'Katoto Stars FC', 'Katoto Ward', 3, 'Left', 1.75, 'Reliable left-back with an eye for an overlap.', '+265 996 33 44 55', 1, 4, 8, 0, 0, 0, 'approved'),
('p12', 'Memory Kachepa', 15, 'Striker', 't5', 'Katoto Stars FC', 'Katoto Ward', 9, 'Right', 1.69, 'Explosive pace, one to watch from the north.', '+265 996 33 44 56', 9, 2, 8, 0, 0, 0, 'notSent'),
('p13', 'Andrew Nyasulu', 17, 'Goalkeeper', 't6', 'Chigumula Warriors FC', 'Chigumula Ward', 1, 'Right', 1.80, 'Tall keeper, excellent shot-stopper under pressure.', '+265 997 55 66 77', 0, 0, 8, 2, 0, 0, 'approved'),
('p14', 'Joseph Banda', 18, 'Winger', 't7', 'Mtandire South United FC', 'Mtandire South Ward', 7, 'Left', 1.71, 'Direct dribbler, loves to cut inside.', '+265 992 88 99 00', 3, 2, 8, 0, 0, 0, 'sent'),
('p15', 'Grace Chikuse', 16, 'Defender', 't8', 'Naperi United FC', 'Naperi Ward', 2, 'Right', 1.67, 'Calm under pressure, rarely loses a duel.', '+265 994 11 33 55', 0, 0, 8, 0, 1, 0, 'approved');

INSERT IGNORE INTO referees (id, name, matchesOfficiated, avgFairness, avgCommunication) VALUES
('r1', 'Ref. Charles Mhango', 21, 4.4, 4.1),
('r2', 'Ref. Linda Sumani', 17, 4.7, 4.6),
('r3', 'Ref. Peter Kanyenda', 13, 3.6, 3.4);

INSERT IGNORE INTO news (id, title, summary, body, date, category, author) VALUES
('n1', 'Chikondi Banda nets brace as Eagles soar past Comets', 'Mtandire Eagles FC striker continues record-breaking season with two more goals.', 'Chikondi Banda struck twice as Mtandire Eagles FC moved top of the Lilongwe Ward Youth League table on goal difference.', NOW() - INTERVAL 2 HOUR, 'Match Report', 'Nasa Sport Desk'),
('n2', 'Ndirande Tigers extend unbeaten run to seven matches', 'Blessings Mvula early strike secures another win for the Blantyre side.', 'Ndirande Tigers FC remain the form team of the Blantyre Ward Youth League after a hard-fought win over Chilomoni Falcons FC.', NOW() - INTERVAL 6 HOUR, 'Match Report', 'Nasa Sport Desk'),
('n3', 'Diaspora sponsors step up for Katoto Stars', 'Mzuzu Diaspora Friends group funds travel costs for Saturday''s long trip south.', 'A group of Mzuzu-born Malawians living abroad has contributed travel funds to Katoto Stars FC ahead of a demanding 187km trip.', NOW() - INTERVAL 1 DAY, 'Community', 'Nasa Sport Desk');

INSERT IGNORE INTO events (id, title, description, date, venue, wardName, type) VALUES
('e1', 'Inter-Region Cup — Quarter Finals', 'Knockout fixtures between ward champions from Lilongwe, Blantyre, Mzuzu and Zomba regions.', NOW() + INTERVAL 1 DAY, 'Mtandire South Pitch', 'Mtandire South Ward', 'tournament'),
('e2', 'Open Scouting Trials — Under-17', 'Open trial day for unregistered players aged 14-17 from surrounding wards.', NOW() + INTERVAL 4 DAY, 'Ndirande Youth Pitch', 'Ndirande Ward', 'trial'),
('e3', 'Ward Football Festival', 'Community festival with mini-tournaments for under-12, under-15 and under-17 age groups.', NOW() + INTERVAL 9 DAY, 'Area 25 Community Ground', 'Area 25 Ward', 'festival');

INSERT IGNORE INTO sponsorships (id, sponsorName, isDiaspora, type, targetName, amountMwk, message, date, imageUrl, linkUrl) VALUES
('s1', 'Mzuzu Diaspora Friends', 1, 'teamAdoption', 'Katoto Stars FC', 280000, 'For our boys — travel safe and play well!', NOW() - INTERVAL 1 DAY, NULL, NULL),
('s2', 'Lilongwe Hardware Ltd', 0, 'kitSponsorship', 'Area 25 Comets FC', 150000, 'Proud to back local talent.', NOW() - INTERVAL 10 DAY, NULL, NULL);

INSERT IGNORE INTO ledger (id, date, description, type, category, amountMwk) VALUES
('l1', NOW() - INTERVAL 1 DAY, 'Sponsorship — Mzuzu Diaspora Friends', 'income', 'Sponsorship', 280000),
('l2', NOW() - INTERVAL 2 DAY, 'Match balls — 12 units', 'expense', 'Equipment', 96000),
('l3', NOW() - INTERVAL 4 DAY, 'Referee fees — Round 9 fixtures', 'expense', 'Referee Fees', 45000),
('l4', NOW() - INTERVAL 6 DAY, 'Player registration fees — 38 players', 'income', 'Registration Fees', 190000),
('l5', NOW() - INTERVAL 10 DAY, 'Kit sponsorship — Lilongwe Hardware Ltd', 'income', 'Sponsorship', 150000);

INSERT IGNORE INTO injuries (id, playerId, playerName, date, injuryType, severity, recoveryDays, status, notes) VALUES
('inj1', 'p9', 'Dalitso Kalulu', NOW() - INTERVAL 14 DAY, 'Ankle sprain', 'moderate', 21, 'recovering', 'Twisted ankle in training.'),
('inj2', 'p4', 'Tadala Nyirenda', NOW() - INTERVAL 60 DAY, 'Hamstring strain', 'minor', 10, 'fit', 'Returned to full training after rehab.'),
('inj3', 'p12', 'Memory Kachepa', NOW() - INTERVAL 3 DAY, 'Knee knock', 'minor', 5, 'recovering', 'Knock from a tackle.');

INSERT IGNORE INTO attendance (id, playerId, playerName, weekOf, daysPresent, daysTotal, loggedBy) VALUES
('att1', 'p1', 'Chikondi Banda', NOW() - INTERVAL 7 DAY, 5, 5, 'Coach Felix Banda'),
('att2', 'p2', 'Limbani Phiri', NOW() - INTERVAL 7 DAY, 4, 5, 'Coach Felix Banda'),
('att3', 'p6', 'Blessings Mvula', NOW() - INTERVAL 7 DAY, 5, 5, 'Coach Dalitso Phiri');

INSERT IGNORE INTO disciplinary (id, playerId, playerName, teamName, matchLabel, cardType, reason, date, suspensionMatches, fineAmount, finePaid) VALUES
('d1', 'p9', 'Dalitso Kalulu', 'Chilomoni Falcons FC', 'Chilomoni Falcons FC vs Ndirande Tigers FC', 'red', 'Serious foul play', NOW() - INTERVAL 5 DAY, 2, 5000, 0),
('d2', 'p4', 'Tadala Nyirenda', 'Area 25 Comets FC', 'Mtandire Eagles FC vs Area 25 Comets FC', 'yellow', 'Tactical foul', NOW() - INTERVAL 1 DAY, 0, 1000, 1);

INSERT IGNORE INTO video_clips (id, playerId, playerName, teamName, title, durationSeconds, uploadDate, matchLabel) VALUES
('v1', 'p1', 'Chikondi Banda', 'Mtandire Eagles FC', 'Brace vs Area 25 Comets FC', 24, NOW() - INTERVAL 1 HOUR, 'Mtandire Eagles FC vs Area 25 Comets FC'),
('v2', 'p6', 'Blessings Mvula', 'Ndirande Tigers FC', 'Curling opener vs Chilomoni Falcons FC', 18, NOW() - INTERVAL 5 HOUR, 'Ndirande Tigers FC vs Chilomoni Falcons FC');

INSERT IGNORE INTO transfers (id, playerId, playerName, sellingTeam, buyingTeam, agreedFeeMwk, commissionPercent, status, date) VALUES
('tr1', 'p6', 'Blessings Mvula', 'Ndirande Tigers FC', 'Blantyre City Academy', 1200000, 15, 'fundsHeld', NOW() - INTERVAL 2 DAY),
('tr2', 'p1', 'Chikondi Banda', 'Mtandire Eagles FC', 'Lilongwe Premier Youth', 900000, 15, 'awaitingPayment', NOW() - INTERVAL 10 HOUR);

INSERT IGNORE INTO consent_logs (id, playerId, playerName, parentPhone, sentDate, status) VALUES
('c1', 'p3', 'Yamikani Kachali', '+265 991 22 33 46', NOW() - INTERVAL 2 DAY, 'sent'),
('c2', 'p10', 'Esther Phiri', '+265 995 66 77 89', NOW() - INTERVAL 1 DAY, 'sent');

INSERT IGNORE INTO matches (id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, kickoff, status, homeScore, awayScore, minute, travelDistanceKm) VALUES
('m1', 't1', 't2', 'Mtandire Eagles FC', 'Area 25 Comets FC', 'Mtandire Community Ground', 'Mtandire Ward', 'Lilongwe Ward Youth League — Round 9', NOW() - INTERVAL 58 MINUTE, 'live', 2, 1, 58, 3.2),
('m2', 't3', 't4', 'Ndirande Tigers FC', 'Chilomoni Falcons FC', 'Ndirande Youth Pitch', 'Ndirande Ward', 'Blantyre Ward Youth League — Round 9', NOW() - INTERVAL 22 MINUTE, 'live', 1, 0, 22, 4.6),
('m3', 't5', 't6', 'Katoto Stars FC', 'Chigumula Warriors FC', 'Katoto Sports Ground', 'Katoto Ward', 'Northern Cross-District Friendly', NOW() + INTERVAL 3 HOUR, 'upcoming', 0, 0, 0, 187.0),
('m4', 't7', 't8', 'Mtandire South United FC', 'Naperi United FC', 'Mtandire South Pitch', 'Mtandire South Ward', 'Inter-Region Cup — Quarter Final', NOW() + INTERVAL 1 DAY, 'upcoming', 0, 0, 0, 261.0),
('m5', 't2', 't1', 'Area 25 Comets FC', 'Mtandire Eagles FC', 'Area 25 Community Ground', 'Area 25 Ward', 'Lilongwe Ward Youth League — Round 8', NOW() - INTERVAL 6 DAY, 'fullTime', 1, 3, 90, 3.2);

INSERT IGNORE INTO match_events (id, matchId, minute, type, teamName, playerName) VALUES
('me1', 'm1', 12, 'Goal', 'Mtandire Eagles FC', 'Chikondi Banda'),
('me2', 'm1', 34, 'Yellow Card', 'Area 25 Comets FC', 'Tadala Nyirenda'),
('me3', 'm1', 41, 'Goal', 'Area 25 Comets FC', 'Chisomo Gondwe'),
('me4', 'm1', 52, 'Goal', 'Mtandire Eagles FC', 'Chikondi Banda'),
('me5', 'm2', 9, 'Goal', 'Ndirande Tigers FC', 'Blessings Mvula'),
('me6', 'm5', 18, 'Goal', 'Mtandire Eagles FC', 'Chikondi Banda'),
('me7', 'm5', 29, 'Goal', 'Area 25 Comets FC', 'Chisomo Gondwe'),
('me8', 'm5', 60, 'Goal', 'Mtandire Eagles FC', 'Limbani Phiri'),
('me9', 'm5', 77, 'Goal', 'Mtandire Eagles FC', 'Chikondi Banda');
