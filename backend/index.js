const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
require('dotenv').config();

const app = express();

// Allow requests from the Flutter web/mobile app and local dev
const allowedOrigins = [
  process.env.APP_URL || 'https://naysasport.com',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://localhost:8081',
  'http://10.0.2.2:3000', // Android emulator → host loopback
];
app.use(cors({
  origin: (origin, cb) => {
    // Allow server-to-server (no origin) and whitelisted origins
    if (!origin || allowedOrigins.some(o => origin.startsWith(o))) {
      cb(null, true);
    } else {
      cb(new Error(`CORS blocked: ${origin}`));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

// Serve uploads statically
app.use('/backend/uploads', express.static(path.join(__dirname, 'uploads')));

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const r2Configured = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET_NAME', 'R2_PUBLIC_URL']
  .every((name) => Boolean(process.env[name]));

// Configure S3Client for Cloudflare R2
const s3Client = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

// Configure Multer for safe in-memory image uploads before they are sent to R2.
// Keeping the limit modest protects the Node process on mobile-data networks.
const supportedImageTypes = new Map([
  ['image/jpeg', '.jpg'],
  ['image/png', '.png'],
  ['image/webp', '.webp'],
]);
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
  fileFilter: (req, file, callback) => {
    if (!supportedImageTypes.has(file.mimetype)) {
      return callback(new multer.MulterError('LIMIT_UNEXPECTED_FILE', 'image'));
    }
    callback(null, true);
  },
});

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'naysa_db',
  // Match kick-off times are local, wall-clock times.  Returning MySQL DATETIME
  // fields as strings prevents Node from applying the server timezone before
  // they are sent to the Flutter app.
  dateStrings: true,
  waitForConnections: true,
  connectionLimit: 50,
  queueLimit: 0
});

pool.query(`CREATE TABLE IF NOT EXISTS team_competitions (
  id VARCHAR(100) PRIMARY KEY,
  teamId VARCHAR(50) NOT NULL,
  leagueId VARCHAR(50) NOT NULL,
  competitionRole VARCHAR(50) DEFAULT 'participant',
  enrolledAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_team_league (teamId, leagueId),
  INDEX idx_tc_league (leagueId),
  INDEX idx_tc_team (teamId)
)`).catch(error => console.error('Unable to prepare team_competitions table:', error.message));

pool.query(`CREATE TABLE IF NOT EXISTS team_squad_members (
  id VARCHAR(100) PRIMARY KEY,
  teamId VARCHAR(50) NOT NULL,
  playerId VARCHAR(50) NOT NULL,
  jerseyNumber INT NULL,
  isNationalTeam TINYINT(1) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'active',
  callupDate DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_team_player (teamId, playerId),
  INDEX idx_tsm_team (teamId),
  INDEX idx_tsm_player (playerId)
)`).catch(error => console.error('Unable to prepare team_squad_members table:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "teamType"').then(([rows]) => {
  if (!rows.length) return pool.query("ALTER TABLE teams ADD COLUMN teamType VARCHAR(30) NOT NULL DEFAULT 'club'");
}).catch(() => {});

pool.query('SHOW COLUMNS FROM players LIKE "clubStatus"').then(([rows]) => {
  if (!rows.length) return pool.query("ALTER TABLE players ADD COLUMN clubStatus VARCHAR(30) NOT NULL DEFAULT 'club'");
}).catch(() => {});

pool.query(`CREATE TABLE IF NOT EXISTS team_lineups (
  id VARCHAR(120) PRIMARY KEY, teamId VARCHAR(50) NOT NULL,
  matchId VARCHAR(50) NULL, playerIds LONGTEXT NOT NULL,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_team_fixture (teamId, matchId)
)`).catch(error => console.error('Unable to prepare team_lineups table:', error.message));

pool.query('SHOW COLUMNS FROM team_lineups LIKE "formation"').then(([rows]) => {
  if (!rows.length) {
    return pool.query('ALTER TABLE team_lineups ADD COLUMN formation VARCHAR(20) DEFAULT "4-4-2"');
  }
}).catch(error => console.error('Unable to add formation column to team_lineups:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "leagueId"').then(([rows]) => {
  if (!rows.length) {
    return pool.query('ALTER TABLE teams ADD COLUMN leagueId VARCHAR(50)');
  }
}).catch(error => console.error('Unable to add teams.leagueId:', error.message));

// A profile-stat correction is deliberately kept after it has been saved. It
// overrides the calculated total for that player until the administrator
// clears/updates it, rather than being lost on the next app refresh.
pool.query('SHOW COLUMNS FROM players LIKE "statsManualOverride"').then(([rows]) => {
  if (!rows.length) {
    return pool.query('ALTER TABLE players ADD COLUMN statsManualOverride TINYINT(1) NOT NULL DEFAULT 0');
  }
}).catch(error => console.error('Unable to add players.statsManualOverride:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "leagueName"').then(([rows]) => {
  if (!rows.length) {
    return pool.query('ALTER TABLE teams ADD COLUMN leagueName VARCHAR(255)');
  }
}).catch(error => console.error('Unable to add teams.leagueName:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "groupName"').then(([rows]) => {
  if (!rows.length) {
    return pool.query('ALTER TABLE teams ADD COLUMN groupName VARCHAR(50) DEFAULT NULL');
  }
}).catch(error => console.error('Unable to add teams.groupName:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "dashboardOnly"').then(([rows]) => {
  if (!rows.length) return pool.query('ALTER TABLE teams ADD COLUMN dashboardOnly TINYINT(1) NOT NULL DEFAULT 0');
}).catch(error => console.error('Unable to add teams.dashboardOnly:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "isExternal"').then(([rows]) => {
  if (!rows.length) return pool.query('ALTER TABLE teams ADD COLUMN isExternal TINYINT(1) NOT NULL DEFAULT 0');
}).catch(error => console.error('Unable to add teams.isExternal:', error.message));

pool.query('SHOW COLUMNS FROM teams LIKE "logoUrl"').then(([rows]) => {
  if (!rows.length) return pool.query('ALTER TABLE teams ADD COLUMN logoUrl TEXT NULL');
}).catch(error => console.error('Unable to add teams.logoUrl:', error.message));

pool.query(`CREATE TABLE IF NOT EXISTS leagues (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  format VARCHAR(50) DEFAULT 'league'
)`).catch(error => console.error('Unable to create leagues table:', error.message));

pool.query('SHOW COLUMNS FROM leagues LIKE "format"').then(([rows]) => {
  if (!rows.length) {
    return pool.query("ALTER TABLE leagues ADD COLUMN format VARCHAR(50) DEFAULT 'league'");
  }
}).catch(error => console.error('Unable to add leagues.format:', error.message));

pool.query('SHOW COLUMNS FROM leagues LIKE "advancingTeams"').then(([rows]) => {
  if (!rows.length) {
    return pool.query('ALTER TABLE leagues ADD COLUMN advancingTeams INT NOT NULL DEFAULT 2');
  }
}).catch(error => console.error('Unable to add leagues.advancingTeams:', error.message));

pool.query('SHOW COLUMNS FROM leagues LIKE "status"').then(([rows]) => {
  if (!rows.length) {
    return pool.query("ALTER TABLE leagues ADD COLUMN status VARCHAR(50) DEFAULT 'active'");
  }
}).catch(error => console.error('Unable to add leagues.status:', error.message));

// Sync matches competition name with leagueName if generic
pool.query("UPDATE matches SET competition = leagueName WHERE leagueName IS NOT NULL AND leagueName != '' AND (competition = 'NAYSA League' OR competition = '' OR competition IS NULL)").catch(err => console.error('Unable to sync match competition names:', err.message));

pool.query('SHOW COLUMNS FROM matches LIKE "stage"').then(([rows]) => {
  if (!rows.length) {
    return pool.query("ALTER TABLE matches ADD COLUMN stage VARCHAR(50) DEFAULT 'League Match'");
  }
}).catch(error => console.error('Unable to add matches.stage:', error.message));

pool.query('SHOW COLUMNS FROM matches LIKE "groupName"').then(([rows]) => {
  if (!rows.length) {
    return pool.query("ALTER TABLE matches ADD COLUMN groupName VARCHAR(50) DEFAULT NULL");
  }
}).catch(error => console.error('Unable to add matches.groupName:', error.message));

pool.query('SHOW COLUMNS FROM matches LIKE "isPrivate"').then(([rows]) => {
  if (!rows.length) {
    return pool.query("ALTER TABLE matches ADD COLUMN isPrivate TINYINT(1) NOT NULL DEFAULT 0");
  }
}).catch(error => console.error('Unable to add matches.isPrivate:', error.message));

pool.query('SHOW COLUMNS FROM matches LIKE "playerOfMatchId"').then(([rows]) => {
  if (!rows.length) return pool.query('ALTER TABLE matches ADD COLUMN playerOfMatchId VARCHAR(50) NULL');
}).catch(error => console.error('Unable to add matches.playerOfMatchId:', error.message));

pool.query('SHOW COLUMNS FROM matches LIKE "playerOfMatchName"').then(([rows]) => {
  if (!rows.length) return pool.query('ALTER TABLE matches ADD COLUMN playerOfMatchName VARCHAR(255) NULL');
}).catch(error => console.error('Unable to add matches.playerOfMatchName:', error.message));

pool.query('SHOW COLUMNS FROM matches LIKE "liveStartedAt"').then(([rows]) => {
  if (!rows.length) return pool.query('ALTER TABLE matches ADD COLUMN liveStartedAt DATETIME NULL');
}).catch(error => console.error('Unable to add matches.liveStartedAt:', error.message));

async function syncLiveMatchMinutes(pool) {
  try {
    // Preserve a minute already recorded before server-authoritative timing
    // was introduced: minute 50 means the clock began 50 minutes ago.
    await pool.query("UPDATE matches SET liveStartedAt=DATE_SUB(NOW(), INTERVAL minute MINUTE) WHERE status='live' AND liveStartedAt IS NULL");
    await pool.query(`UPDATE matches
      SET minute = LEAST(120, GREATEST(0, TIMESTAMPDIFF(MINUTE, liveStartedAt, NOW())))
      WHERE status='live' AND liveStartedAt IS NOT NULL`);
  } catch (error) {
    console.error('Unable to synchronize live match minutes:', error.message);
  }
}

pool.query(`CREATE TABLE IF NOT EXISTS match_events (
  id VARCHAR(120) PRIMARY KEY,
  matchId VARCHAR(50) NOT NULL,
  minute INT DEFAULT 0,
  type VARCHAR(50) NOT NULL,
  teamName VARCHAR(255),
  playerName VARCHAR(255),
  assistName VARCHAR(255),
  isPenalty TINYINT(1) DEFAULT 0,
  INDEX idx_matchId (matchId)
)`).catch(error => console.error('Unable to create match_events table:', error.message));

pool.query(`CREATE TABLE IF NOT EXISTS player_scout_ratings (
  id VARCHAR(120) PRIMARY KEY,
  playerId VARCHAR(50) NOT NULL,
  pace INT NOT NULL, shooting INT NOT NULL, passing INT NOT NULL,
  dribbling INT NOT NULL, defending INT NOT NULL, physical INT NOT NULL,
  submittedAt DATETIME NOT NULL,
  INDEX idx_player_scout_ratings_player (playerId)
)`).catch(error => console.error('Unable to create player_scout_ratings table:', error.message));

pool.query(`CREATE TABLE IF NOT EXISTS app_active_sessions (
  deviceId VARCHAR(100) PRIMARY KEY,
  role VARCHAR(50) DEFAULT 'viewer',
  platform VARCHAR(50) DEFAULT 'mobile',
  appVersion VARCHAR(50) DEFAULT '1.0.0',
  firstSeen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  lastPing DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_lastPing (lastPing)
)`).catch(error => console.error('Unable to create app_active_sessions table:', error.message));


// League tables and player leaderboards are calculated from the match record.
// This prevents a live score, a correction, or a full-time update from ever
// leaving a separately-stored aggregate out of sync.
async function calculateLeagueLiveData() {
  const [[teams], [players], [matches], [events], [lineups], [leagues], [teamComps], [squadMembers]] = await Promise.all([
    pool.query('SELECT * FROM teams'),
    pool.query('SELECT * FROM players'),
    pool.query("SELECT * FROM matches WHERE status IN ('live', 'fullTime')"),
    pool.query('SELECT * FROM match_events'),
    pool.query('SELECT teamId, matchId, playerIds FROM team_lineups'),
    pool.query('SELECT * FROM leagues'),
    pool.query('SELECT * FROM team_competitions').catch(() => [[]]),
    pool.query('SELECT * FROM team_squad_members').catch(() => [[]]),
  ]);

  const leagueFormatMap = new Map((leagues || []).map(l => [l.id, l.format || 'league']));

  const publicTeamIds = new Set(teams.filter(team => Number(team.dashboardOnly) !== 1 && Number(team.isExternal) !== 1).map(team => team.id));
  const relevantMatches = matches.filter(match => match.homeTeamId && match.awayTeamId && Number(match.isPrivate) !== 1 && publicTeamIds.has(match.homeTeamId) && publicTeamIds.has(match.awayTeamId));
  const matchById = new Map(relevantMatches.map(match => [match.id, match]));
  const eventsByMatch = new Map();
  for (const event of events) {
    if (!matchById.has(event.matchId)) continue;
    const list = eventsByMatch.get(event.matchId) || [];
    list.push(event);
    eventsByMatch.set(event.matchId, list);
  }

  const teamsById = new Map(teams.map(team => [team.id, team]));
  const enrolledTeamsByComp = new Set();
  for (const tc of (teamComps || [])) {
    if (tc.leagueId && tc.teamId) enrolledTeamsByComp.add(`${tc.leagueId}:${tc.teamId}`);
  }
  for (const team of teams) {
    if (team.leagueId) enrolledTeamsByComp.add(`${team.leagueId}:${team.id}`);
  }
  for (const match of relevantMatches) {
    if (match.leagueId) {
      if (match.homeTeamId) enrolledTeamsByComp.add(`${match.leagueId}:${match.homeTeamId}`);
      if (match.awayTeamId) enrolledTeamsByComp.add(`${match.leagueId}:${match.awayTeamId}`);
    }
  }

  const tableByCompAndTeam = new Map();
  for (const compKey of enrolledTeamsByComp) {
    const [leagueId, teamId] = compKey.split(':');
    const team = teamsById.get(teamId);
    if (!team) continue;
    if (Number(team.dashboardOnly) === 1 || Number(team.isExternal) === 1) continue;
    const { username, password, ...publicTeam } = team;
    tableByCompAndTeam.set(compKey, {
      ...publicTeam,
      leagueId,
      played: 0, won: 0, drawn: 0, lost: 0, goalsFor: 0, goalsAgainst: 0,
    });
  }

  const applyResult = (leagueId, teamId, goalsFor, goalsAgainst) => {
    const key = `${leagueId}:${teamId}`;
    let team = tableByCompAndTeam.get(key);
    if (!team) {
      const baseTeam = teamsById.get(teamId);
      if (!baseTeam || Number(baseTeam.dashboardOnly) === 1 || Number(baseTeam.isExternal) === 1) return;
      const { username, password, ...publicTeam } = baseTeam;
      team = { ...publicTeam, leagueId, played: 0, won: 0, drawn: 0, lost: 0, goalsFor: 0, goalsAgainst: 0 };
      tableByCompAndTeam.set(key, team);
    }
    team.played += 1;
    team.goalsFor += Number(goalsFor) || 0;
    team.goalsAgainst += Number(goalsAgainst) || 0;
    if (goalsFor > goalsAgainst) team.won += 1;
    else if (goalsFor === goalsAgainst) team.drawn += 1;
    else team.lost += 1;
  };

  for (const match of relevantMatches) {
    const format = leagueFormatMap.get(match.leagueId) || 'league';
    if (format === 'knockout') continue;
    const isKnockoutStage = match.stage && [
      'Round of 32', 'Round of 16', 'Quarter-Final', 'Semi-Final', 'Third Place', 'Final'
    ].includes(match.stage);
    if (format === 'group_knockout' && isKnockoutStage) continue;

    applyResult(match.leagueId, match.homeTeamId, match.homeScore, match.awayScore);
    applyResult(match.leagueId, match.awayTeamId, match.awayScore, match.homeScore);
  }

  // Multi-squad player lookup and dual (general + per-competition) stats tracking
  const playersByTeamAndName = new Map();
  const playersById = new Map();
  const playersByNameOnly = new Map();
  for (const player of players) {
    playersById.set(player.id, player);
    if (player.teamId) {
      playersByTeamAndName.set(`${player.teamId}:${String(player.name).trim().toLowerCase()}`, player);
    }
    const nameKey = String(player.name).trim().toLowerCase();
    playersByNameOnly.set(nameKey, playersByNameOnly.has(nameKey) ? null : player);
  }
  for (const sm of (squadMembers || [])) {
    const p = playersById.get(sm.playerId);
    if (p) {
      playersByTeamAndName.set(`${sm.teamId}:${String(p.name).trim().toLowerCase()}`, p);
    }
  }

  const findPlayer = (teamId, name) => {
    const clean = String(name || '').trim().toLowerCase();
    return playersByTeamAndName.get(`${teamId}:${clean}`) || playersByNameOnly.get(clean) || null;
  };

  const generalPlayerStats = new Map();
  const statForGeneral = (player) => {
    if (!player) return null;
    let s = generalPlayerStats.get(player.id);
    if (!s) {
      s = {
        ...player, goals: 0, assists: 0, appearances: 0,
        cleanSheets: 0, yellowCards: 0, redCards: 0,
      };
      generalPlayerStats.set(player.id, s);
    }
    return s;
  };

  const playerStatsByCompetition = new Map();
  const playerGoalBreakdown = new Map();
  const addGoalBreakdown = (player, match) => {
    if (!player) return;
    const competitionName = match.leagueId
      ? (leagues.find(league => league.id === match.leagueId)?.name || match.leagueName || 'Competition')
      : (match.competition || 'Friendly');
    const key = `${player.id}:${competitionName}`;
    const rows = playerGoalBreakdown.get(player.id) || new Map();
    rows.set(key, { competition: competitionName, goals: (rows.get(key)?.goals || 0) + 1 });
    playerGoalBreakdown.set(player.id, rows);
  };
  const statFor = (competitionId, player) => {
    if (!competitionId || !player) return null;
    let competitionStats = playerStatsByCompetition.get(competitionId);
    if (!competitionStats) {
      competitionStats = new Map();
      playerStatsByCompetition.set(competitionId, competitionStats);
    }
    let stat = competitionStats.get(player.id);
    if (!stat) {
      stat = {
        ...player, goals: 0, assists: 0, appearances: 0,
        cleanSheets: 0, yellowCards: 0, redCards: 0,
      };
      competitionStats.set(player.id, stat);
    }
    return stat;
  };

  const lineupByScope = new Map();
  for (const lineup of lineups) {
    try {
      lineupByScope.set(`${lineup.teamId}:${lineup.matchId || 'default'}`, JSON.parse(lineup.playerIds));
    } catch (_) {}
  }

  const creditedPlayers = new Map();
  const creditAppearance = (competitionId, matchId, playerId) => {
    const key = `${competitionId}:${matchId}:${playerId}`;
    if (creditedPlayers.has(key)) return;
    const player = playersById.get(playerId);
    const stat = statFor(competitionId, player);
    if (stat) stat.appearances += 1;
    const gen = statForGeneral(player);
    if (gen) gen.appearances += 1;
    creditedPlayers.set(key, stat);
  };

  for (const match of relevantMatches) {
    const competitionId = match.leagueId || null;
    for (const teamId of [match.homeTeamId, match.awayTeamId]) {
      const ids = lineupByScope.get(`${teamId}:${match.id}`) || lineupByScope.get(`${teamId}:default`) || [];
      ids.forEach(playerId => creditAppearance(competitionId, match.id, playerId));
    }
    for (const event of eventsByMatch.get(match.id) || []) {
      const teamId = event.teamName === match.homeTeamName ? match.homeTeamId :
        event.teamName === match.awayTeamName ? match.awayTeamId : null;
      if (!teamId) continue;
      if (event.type === 'Goal') {
        const pScorer = findPlayer(teamId, event.playerName);
        const scorer = statFor(competitionId, pScorer);
        if (scorer) scorer.goals += 1;
        const genScorer = statForGeneral(pScorer);
        if (genScorer) genScorer.goals += 1;
        addGoalBreakdown(pScorer, match);

        const pAssister = findPlayer(teamId, event.assistName);
        const assister = statFor(competitionId, pAssister);
        if (assister) assister.assists += 1;
        const genAssister = statForGeneral(pAssister);
        if (genAssister) genAssister.assists += 1;
      } else if (event.type === 'Yellow Card') {
        const pCard = findPlayer(teamId, event.playerName);
        const player = statFor(competitionId, pCard);
        if (player) player.yellowCards += 1;
        const gen = statForGeneral(pCard);
        if (gen) gen.yellowCards += 1;
      } else if (event.type === 'Red Card') {
        const pCard = findPlayer(teamId, event.playerName);
        const player = statFor(competitionId, pCard);
        if (player) player.redCards += 1;
        const gen = statForGeneral(pCard);
        if (gen) gen.redCards += 1;
      } else if (event.type === 'Substitution') {
        const incomingName = String(event.playerName || '').split(/(?:→|->|&rarr;|\?)/).pop().trim();
        const incoming = findPlayer(teamId, incomingName);
        if (incoming) creditAppearance(competitionId, match.id, incoming.id);
      }
    }

    if (match.status === 'fullTime') {
      for (const [teamId, conceded] of [[match.homeTeamId, match.awayScore], [match.awayTeamId, match.homeScore]]) {
        if (Number(conceded) !== 0) continue;
        for (const [key, player] of creditedPlayers) {
          if (!key.startsWith(`${competitionId}:${match.id}:`)) continue;
          if (player && /goalkeeper|\bgk\b/i.test(player.position || '')) {
            player.cleanSheets += 1;
            const gen = statForGeneral(player);
            if (gen) gen.cleanSheets += 1;
          }
        }
      }
    }
  }

  const standings = [...tableByCompAndTeam.values()].sort((a, b) => {
    const pointsA = a.won * 3 + a.drawn;
    const pointsB = b.won * 3 + b.drawn;
    if (pointsB !== pointsA) return pointsB - pointsA;
    const gdA = a.goalsFor - a.goalsAgainst;
    const gdB = b.goalsFor - b.goalsAgainst;
    if (gdB !== gdA) return gdB - gdA;
    if (b.goalsFor !== a.goalsFor) return b.goalsFor - a.goalsFor;
    return String(a.name).localeCompare(String(b.name));
  });

  const publicPlayer = ({ parentPhone, ...player }) => player;
  return {
    standings,
    playerStats: players.map(player => {
      const gen = generalPlayerStats.get(player.id);
      const isManual = Number(player.statsManualOverride) === 1;
      // Match events are the source of truth for profile totals whenever a
      // calculated value exists. Manual values remain a fallback for players
      // whose older records have no matching event history yet.
      const calculated = (key) => gen && Number(gen[key]) > 0
        ? Number(gen[key])
        : (isManual ? Number(player[key]) || 0 : 0);
      return {
        ...publicPlayer(player),
        goals: calculated('goals'),
        assists: calculated('assists'),
        appearances: calculated('appearances'),
        cleanSheets: calculated('cleanSheets'),
        yellowCards: calculated('yellowCards'),
        redCards: calculated('redCards'),
      };
    }),
    playerStatsByCompetition: Object.fromEntries(
      [...playerStatsByCompetition].map(([competitionId, stats]) => [
        competitionId,
        [...stats.values()].map(publicPlayer),
      ])
    ),
    playerGoalBreakdown: Object.fromEntries(
      [...playerGoalBreakdown].map(([playerId, rows]) => [playerId, [...rows.values()]]),
    ),
    liveLeagueIds: [...new Set(relevantMatches.filter(match => match.status === 'live').map(match => match.leagueId))],
  };
}

// Team sessions are signed by the server.  The team id is never accepted from
// the client when reading a team workspace.
const sessionSecret = process.env.SESSION_SECRET;
if (!sessionSecret && process.env.NODE_ENV === 'production') {
  throw new Error('SESSION_SECRET must be set in production');
}
const signingSecret = sessionSecret || 'development-only-change-me';
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const signSession = teamId => {
  const payload = encode({ teamId, exp: Date.now() + 8 * 60 * 60 * 1000 });
  const signature = crypto.createHmac('sha256', signingSecret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
};
const requireTeamSession = (req, res, next) => {
  const token = req.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token || !token.includes('.')) return res.status(401).json({ error: 'Authentication required' });
  const [payload, signature] = token.split('.');
  const expected = crypto.createHmac('sha256', signingSecret).update(payload).digest('base64url');
  if (signature.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    return res.status(401).json({ error: 'Invalid session' });
  }
  try {
    const session = JSON.parse(Buffer.from(payload, 'base64url').toString());
    if (!session.teamId || session.exp < Date.now()) return res.status(401).json({ error: 'Session expired' });
    req.teamId = session.teamId;
    next();
  } catch (_) { return res.status(401).json({ error: 'Invalid session' }); }
};

// ─── OPTIMIZED: Consolidated app data endpoint ──────────────────────────────
// Single endpoint that returns all data the mobile app needs, with ETag caching.
// This dramatically reduces the number of HTTP requests and database queries.
const { createHash } = require('crypto');

const computeAppDataETag = (data) => {
  const hash = createHash('sha256');
  hash.update(JSON.stringify({
    teams: data.teams?.length,
    players: data.players?.length,
    matches: (data.matches || []).map(match => ({
      id: match.id,
      status: match.status,
      minute: match.minute,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
    })),
    leagues: data.leagues?.length,
    teamCompetitions: data.teamCompetitions?.length,
    teamSquadMembers: data.teamSquadMembers?.length,
    events: data.events?.length,
    news: data.news?.length,
    videos: data.videos?.length,
    sponsorships: data.sponsorships?.length,
    ledger: data.ledger?.length,
    injuries: data.injuries?.length,
    playerScoutRatings: data.playerScoutRatings,
    playerGoalBreakdown: data.playerGoalBreakdown,
  }));
  return `"${hash.digest('hex').substring(0, 16)}"`;
};

app.get('/backend/api/app-data', async (req, res) => {
  try {
    const startTime = Date.now();
    await syncLiveMatchMinutes(pool);
    // Backfill teams from every completed league match before building standings.
    await reconcilePlayedMatchTeams(pool);
    // Repair any bracket that was completed before the second semifinal was
    // recorded. This also makes an existing final pick up both winners.
    await reconcileKnockoutFixtures(pool);
    
    // Fetch all data in PARALLEL instead of sequential
    const [
      [teams],
      [players],
      [matches],
      [leagues],
      [news],
      [videos],
      [sponsorships],
      [ledger],
      [injuries],
      [attendance],
      [disciplinary],
      [referees],
      [refereeRatings],
      [transfers],
      [consent],
      leagueData,
      [playerScoutRatings],
      [events],
      [teamCompetitions],
      [teamSquadMembers],
    ] = await Promise.all([
      pool.query('SELECT id, name, wardId, wardName, leagueId, leagueName, foundedYear, coachName, sponsorName, groupName, logoUrl, played, won, drawn, lost, goalsFor, goalsAgainst, IFNULL(teamType, "club") AS teamType FROM teams WHERE dashboardOnly = 0 AND (isExternal = 0 OR isExternal IS NULL)'),
      pool.query('SELECT p.id, p.name, p.age, p.position, p.teamId, p.teamName, p.wardName, p.jerseyNumber, p.preferredFoot, p.heightM, p.goals, p.assists, p.appearances, p.cleanSheets, p.yellowCards, p.redCards, IFNULL(p.clubStatus, "club") AS clubStatus FROM players p LEFT JOIN teams t ON t.id = p.teamId WHERE t.id IS NULL OR (t.dashboardOnly = 0 AND (t.isExternal = 0 OR t.isExternal IS NULL))'),
      pool.query('SELECT m.* FROM matches m JOIN teams h ON h.id=m.homeTeamId JOIN teams a ON a.id=m.awayTeamId WHERE h.dashboardOnly=0 AND a.dashboardOnly=0 AND (h.isExternal=0 OR h.isExternal IS NULL) AND (a.isExternal=0 OR a.isExternal IS NULL) AND (m.isPrivate=0 OR m.isPrivate IS NULL) ORDER BY m.kickoff DESC LIMIT 100'),
      pool.query('SELECT * FROM leagues ORDER BY name'),
      pool.query('SELECT * FROM news ORDER BY date DESC LIMIT 50'),
      pool.query('SELECT * FROM video_clips ORDER BY uploadDate DESC LIMIT 50'),
      pool.query('SELECT * FROM sponsorships ORDER BY date DESC LIMIT 50'),
      pool.query('SELECT * FROM ledger ORDER BY date DESC LIMIT 100'),
      pool.query('SELECT * FROM injuries ORDER BY date DESC LIMIT 50'),
      pool.query('SELECT * FROM attendance ORDER BY weekOf DESC LIMIT 50'),
      pool.query('SELECT * FROM disciplinary ORDER BY date DESC LIMIT 50'),
      pool.query('SELECT * FROM referees'),
      pool.query('SELECT * FROM referee_ratings ORDER BY date DESC LIMIT 50'),
      pool.query('SELECT * FROM transfers ORDER BY date DESC LIMIT 50'),
      pool.query('SELECT * FROM consent_logs ORDER BY sentDate DESC LIMIT 50'),
      calculateLeagueLiveData(),
      pool.query(`SELECT playerId, COUNT(*) AS totalVotes,
        AVG(pace) AS pace, AVG(shooting) AS shooting, AVG(passing) AS passing,
        AVG(dribbling) AS dribbling, AVG(defending) AS defending, AVG(physical) AS physical
        FROM player_scout_ratings GROUP BY playerId`),
      pool.query('SELECT * FROM match_events ORDER BY minute ASC LIMIT 500'),
      pool.query('SELECT * FROM team_competitions').catch(() => [[]]),
      pool.query('SELECT * FROM team_squad_members').catch(() => [[]]),
    ]);

    const livePlayerMap = new Map((leagueData.playerStats || []).map(p => [p.id, p]));

    const data = {
      teams: teams || [],
      players: (players || []).map(p => {
        const live = livePlayerMap.get(p.id);
        return live ? { ...p, ...live } : p;
      }),
      matches: (matches || []).map(m => ({
        ...m,
        events: (events || []).filter(e => e.matchId === m.id)
      })),
      leagues: leagues || [],
      teamCompetitions: teamCompetitions || [],
      teamSquadMembers: teamSquadMembers || [],
      news: news || [],
      videos: videos || [],
      sponsorships: sponsorships || [],
      ledger: ledger || [],
      injuries: injuries || [],
      attendance: attendance || [],
      disciplinary: disciplinary || [],
      referees: referees || [],
      refereeRatings: refereeRatings || [],
      transfers: transfers || [],
      consentLogs: consent || [],
      playerScoutRatings: playerScoutRatings || [],
      // Live calculated data
      standings: leagueData.standings,
      playerStats: leagueData.playerStats,
      playerStatsByCompetition: leagueData.playerStatsByCompetition,
      playerGoalBreakdown: leagueData.playerGoalBreakdown,
      liveLeagueIds: leagueData.liveLeagueIds,
    };

    const etag = computeAppDataETag(data);
    
    // If client already has this version, return 304 Not Modified (very fast!)
    if (req.get('If-None-Match') === etag) {
      console.log(`[APP-DATA] 304 Not Modified after ${Date.now() - startTime}ms`);
      return res.status(304).end();
    }

    res.set('ETag', etag);
    res.set('Cache-Control', 'public, max-age=5'); // 5-second browser cache
    console.log(`[APP-DATA] Complete data bundle: ${data.teams.length} teams, ${data.players.length} players, ${data.matches.length} matches (${Date.now() - startTime}ms)`);
    res.json(data);
  } catch (e) {
    console.error('[APP-DATA] Error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ─── Health & Root check ───────────────────────────────────────────────────
app.get(['/backend/api/health', '/api/health', '/health'], (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));
app.get(['/backend/api', '/backend/api/', '/api', '/api/', '/'], (req, res) => res.json({ status: 'ok', name: 'NAYSA API', version: '1.0.0' }));

// ─── Public match lineups ─────────────────────────────────────────────────────
// ─── Public match lineups ─────────────────────────────────────────────────────
// Returns both home and away team lineup player IDs & formations for a match (no auth required).
app.get('/backend/api/match-lineups/:matchId', async (req, res) => {
  try {
    const { matchId } = req.params;
    const [matchRows] = await pool.query(
      'SELECT homeTeamId, awayTeamId FROM matches WHERE id = ?', [matchId]
    );
    if (!matchRows || !matchRows.length) return res.status(404).json({ error: 'Match not found' });
    const { homeTeamId, awayTeamId } = matchRows[0];
    const [lineupRows] = await pool.query(
      'SELECT teamId, playerIds, formation FROM team_lineups WHERE (matchId = ? OR matchId IS NULL) AND teamId IN (?, ?)',
      [matchId, homeTeamId, awayTeamId]
    );
    const result = { homeTeamId, awayTeamId, home: [], homeFormation: '4-4-2', away: [], awayFormation: '4-4-2' };
    for (const row of lineupRows) {
      const ids = typeof row.playerIds === 'string' ? JSON.parse(row.playerIds) : row.playerIds;
      if (row.teamId === homeTeamId && !result.home.length) {
        result.home = ids;
        if (row.formation) result.homeFormation = row.formation;
      }
      if (row.teamId === awayTeamId && !result.away.length) {
        result.away = ids;
        if (row.formation) result.awayFormation = row.formation;
      }
    }

    // Fallback to top 11 registered players if no saved lineup exists
    if (!result.home.length) {
      const [homePlayers] = await pool.query('SELECT id FROM players WHERE teamId = ? ORDER BY jerseyNumber ASC LIMIT 11', [homeTeamId]);
      result.home = homePlayers.map(p => p.id);
    }
    if (!result.away.length) {
      const [awayPlayers] = await pool.query('SELECT id FROM players WHERE teamId = ? ORDER BY jerseyNumber ASC LIMIT 11', [awayTeamId]);
      result.away = awayPlayers.map(p => p.id);
    }

    res.json(result);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Private workspace for a signed-in team.  Every query is anchored to the
// team id in the signed session, never a URL parameter supplied by the app.
app.get('/backend/api/team-workspace', requireTeamSession, async (req, res) => {
  try {
    await syncLiveMatchMinutes(pool);
    const teamId = req.teamId;
    const [[teamRows], [players], [matches], [injuries], [attendance], [disciplinary], [videos], [sponsorships], [transfers], [consentLogs], [lineups]] = await Promise.all([
      pool.query('SELECT * FROM teams WHERE id = ?', [teamId]),
      pool.query('SELECT * FROM players WHERE teamId = ?', [teamId]),
      pool.query('SELECT * FROM matches WHERE homeTeamId = ? OR awayTeamId = ? ORDER BY kickoff DESC', [teamId, teamId]),
      pool.query('SELECT i.* FROM injuries i JOIN players p ON p.id = i.playerId WHERE p.teamId = ? ORDER BY i.date DESC', [teamId]),
      pool.query('SELECT a.* FROM attendance a JOIN players p ON p.id = a.playerId WHERE p.teamId = ? ORDER BY a.weekOf DESC', [teamId]),
      pool.query('SELECT d.* FROM disciplinary d JOIN players p ON p.id = d.playerId WHERE p.teamId = ? ORDER BY d.date DESC', [teamId]),
      pool.query('SELECT v.* FROM video_clips v JOIN players p ON p.id = v.playerId WHERE p.teamId = ? ORDER BY v.uploadDate DESC', [teamId]),
      pool.query('SELECT s.* FROM sponsorships s JOIN teams t ON t.name = s.targetName WHERE t.id = ? ORDER BY s.date DESC', [teamId]),
      pool.query('SELECT tr.* FROM transfers tr JOIN teams t ON t.name IN (tr.sellingTeam, tr.buyingTeam) WHERE t.id = ? ORDER BY tr.date DESC', [teamId]),
      pool.query('SELECT c.* FROM consent_logs c JOIN players p ON p.id = c.playerId WHERE p.teamId = ? ORDER BY c.sentDate DESC', [teamId]),
      pool.query('SELECT matchId, playerIds, formation FROM team_lineups WHERE teamId = ?', [teamId]),
    ]);
    if (!teamRows.length) return res.status(404).json({ error: 'Team not found' });
    const playersWithImages = players.filter(player => player.imageUrl && String(player.imageUrl).trim() && player.imageUrl !== 'null');
    console.info(`[TEAM WORKSPACE] team=${teamId} players=${players.length} playerImages=${playersWithImages.length}`);
    const [events] = await pool.query('SELECT e.* FROM match_events e JOIN matches m ON m.id = e.matchId WHERE m.homeTeamId = ? OR m.awayTeamId = ? ORDER BY e.minute ASC', [teamId, teamId]);
    const eventMap = {};
    events.forEach(event => { (eventMap[event.matchId] ||= []).push(event); });
    const team = teamRows[0];
    let competitionStatus = null;
    let competitionStandings = [];
    if (team.leagueId) {
      const [[leagueRows], liveData] = await Promise.all([
        pool.query('SELECT name, format FROM leagues WHERE id = ?', [team.leagueId]),
        calculateLeagueLiveData(),
      ]);
      const league = leagueRows[0] || { name: team.leagueName || 'Competition', format: 'league' };
      const competitionMatches = matches.filter(match => match.leagueId === team.leagueId);
      const upcoming = competitionMatches
        .filter(match => match.status === 'upcoming')
        .sort((a, b) => new Date(a.kickoff) - new Date(b.kickoff))[0];
      const knockoutStages = ['Round of 32', 'Round of 16', 'Quarter-Final', 'Semi-Final', 'Third Place', 'Final'];
      const latestKnockout = competitionMatches
        .filter(match => knockoutStages.includes(match.stage) && match.status === 'fullTime')
        .sort((a, b) => new Date(b.kickoff) - new Date(a.kickoff))[0];
      const lostLatestKnockout = latestKnockout &&
        ((latestKnockout.homeTeamId === teamId && Number(latestKnockout.homeScore) < Number(latestKnockout.awayScore)) ||
         (latestKnockout.awayTeamId === teamId && Number(latestKnockout.awayScore) < Number(latestKnockout.homeScore)));
      const knockoutActive = league.format === 'knockout' || (league.format === 'group_knockout' && Boolean(latestKnockout));
      const table = liveData.standings.filter(row => row.leagueId === team.leagueId);
      competitionStandings = table;
      const position = table.findIndex(row => row.id === teamId) + 1;
      const eliminated = Boolean(knockoutActive && lostLatestKnockout && !upcoming);
      competitionStatus = {
        competitionName: league.name || team.leagueName,
        format: league.format || 'league',
        position: position || null,
        totalTeams: table.length || null,
        eliminated,
        status: eliminated
          ? `Knocked out in ${latestKnockout.stage}`
          : knockoutActive
            ? (upcoming ? `Knockout — ${upcoming.stage}` : 'Knockout — awaiting next fixture')
            : (position ? `League position ${position} of ${table.length}` : 'League table will appear after results'),
      };
    }
    res.json({
      team,
      players,
      matches: matches.map(match => ({ ...match, events: eventMap[match.id] || [] })),
      injuries,
      attendance,
      disciplinary,
      videos,
      sponsorships,
      transfers,
      consentLogs,
      lineups,
      competitionStatus,
      competitionStandings,
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Save either the default XI or a fixture-specific XI.  The server validates
// all player and fixture ownership instead of trusting values from the app.
app.put('/backend/api/team-lineups/:scope', requireTeamSession, async (req, res) => {
  try {
    const { playerIds, formation } = req.body;
    const lineupFormation = formation && typeof formation === 'string' ? formation : '4-4-2';
    const isDefault = req.params.scope === 'default';
    const matchId = isDefault ? null : req.params.scope;
    if (!Array.isArray(playerIds) || playerIds.length !== 11 || new Set(playerIds).size !== 11 || !playerIds.every(id => typeof id === 'string')) {
      return res.status(400).json({ error: 'A lineup must contain exactly 11 different players.' });
    }
    const [ownedPlayers] = await pool.query(
      `SELECT id FROM players WHERE teamId = ? AND id IN (${playerIds.map(() => '?').join(',')})`,
      [req.teamId, ...playerIds],
    );
    if (ownedPlayers.length !== 11) return res.status(403).json({ error: 'A lineup can only contain players from your team.' });
    if (matchId) {
      const [fixtures] = await pool.query('SELECT id FROM matches WHERE id = ? AND (homeTeamId = ? OR awayTeamId = ?)', [matchId, req.teamId, req.teamId]);
      if (!fixtures.length) return res.status(403).json({ error: 'You cannot set a lineup for this fixture.' });
    }
    const id = `${req.teamId}:${matchId || 'default'}`;
    await pool.query(
      `INSERT INTO team_lineups (id, teamId, matchId, playerIds, formation) VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE playerIds = VALUES(playerIds), formation = VALUES(formation), updatedAt = CURRENT_TIMESTAMP`,
      [id, req.teamId, matchId, JSON.stringify(playerIds), lineupFormation],
    );
    res.json({ saved: true, matchId, playerIds, formation: lineupFormation });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Teams ───────────────────────────────────────────────────────────────────
// A coach can only create players for the team encoded in their session.
app.post('/backend/api/team-players', requireTeamSession, async (req, res) => {
  try {
    const { id, name, age, position, jerseyNumber, preferredFoot, heightM, bio, parentPhone, imageUrl } = req.body;
    if (!id || !name || !position || !Number.isInteger(age) || !Number.isInteger(jerseyNumber)) {
      return res.status(400).json({ error: 'Missing or invalid player details.' });
    }
    const [teams] = await pool.query('SELECT name, wardName FROM teams WHERE id = ?', [req.teamId]);
    if (!teams.length) return res.status(404).json({ error: 'Team not found.' });
    const team = teams[0];
    await pool.query(
      `INSERT INTO players (id, name, age, position, teamId, teamName, wardName, jerseyNumber, preferredFoot, heightM, bio, parentPhone, imageUrl)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id, name.trim(), age, position, req.teamId, team.name, team.wardName, jerseyNumber, preferredFoot || 'Right', heightM || 0, bio || '', parentPhone || null, imageUrl || null],
    );
    res.status(201).json({ id });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'A player with this ID already exists. Please try again.' });
    res.status(500).json({ error: e.message });
  }
});

// A coach may edit only a player who belongs to the team in their signed
// session. Competition statistics and consent records are intentionally not
// editable through this profile endpoint.
app.put('/backend/api/team-players/:id', requireTeamSession, async (req, res) => {
  try {
    const { name, age, position, jerseyNumber, preferredFoot, heightM, bio, parentPhone, imageUrl } = req.body;
    if (!name || !position || !Number.isInteger(age) || !Number.isInteger(jerseyNumber)) {
      return res.status(400).json({ error: 'Missing or invalid player details.' });
    }
    const [result] = await pool.query(
      `UPDATE players
       SET name=?, age=?, position=?, jerseyNumber=?, preferredFoot=?, heightM=?, bio=?, parentPhone=?, imageUrl=?
       WHERE id=? AND teamId=?`,
      [name.trim(), age, position, jerseyNumber, preferredFoot || 'Right', heightM || 0, bio || '', parentPhone || null, imageUrl || null, req.params.id, req.teamId],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Player not found for your team.' });
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/team-profile/logo', requireTeamSession, async (req, res) => {
  try {
    const logoUrl = typeof req.body.logoUrl === 'string' ? req.body.logoUrl.trim() : '';
    if (!logoUrl.startsWith('http')) {
      return res.status(400).json({ error: 'A valid logo URL is required.' });
    }
    await pool.query('UPDATE teams SET logoUrl = ? WHERE id = ?', [logoUrl, req.teamId]);
    res.json({ updated: true, logoUrl });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/backend/api/teams', async (req, res) => {
  try {
    const includeAll = req.query.includeAll === 'true' || req.query.all === 'true';
    const [rows] = await pool.query(
      `SELECT id, name, wardId, wardName, leagueId, leagueName, foundedYear,
              coachName, sponsorName, groupName, logoUrl, dashboardOnly, isExternal, IFNULL(teamType, 'club') AS teamType,
              played, won, drawn, lost, goalsFor, goalsAgainst
       FROM teams ${includeAll ? '' : 'WHERE dashboardOnly = 0 AND (isExternal = 0 OR isExternal IS NULL)'}`
    );
    try {
      const { standings } = await calculateLeagueLiveData();
      const standingsMap = new Map((standings || []).map(s => [s.id, s]));
      for (const row of rows) {
        if (Number(row.played) === 0 && standingsMap.has(row.id)) {
          const s = standingsMap.get(row.id);
          if (s.played > 0) {
            row.played = s.played;
            row.won = s.won;
            row.drawn = s.drawn;
            row.lost = s.lost;
            row.goalsFor = s.goalsFor;
            row.goalsAgainst = s.goalsAgainst;
          }
        }
      }
    } catch (_) {}
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Multi-competition endpoints
app.get('/backend/api/team-competitions', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM team_competitions');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/backend/api/team-squad-members', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM team_squad_members');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/backend/api/players/:id/stats-by-competition', async (req, res) => {
  try {
    const { playerStatsByCompetition, playerStats } = await calculateLeagueLiveData();
    const general = (playerStats || []).find(p => p.id === req.params.id) || null;
    const byComp = {};
    for (const [compId, pList] of Object.entries(playerStatsByCompetition || {})) {
      const match = pList.find(p => p.id === req.params.id);
      if (match) byComp[compId] = match;
    }
    res.json({ playerId: req.params.id, general, byCompetition: byComp });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Leagues
app.get('/backend/api/leagues', async (req, res) => {
  try {
    const includeCompleted = req.query.includeCompleted === 'true' || req.query.all === 'true';
    const [rows] = await pool.query('SELECT * FROM leagues ORDER BY name');

    // 1. Check for knockout/cup competitions that have a finished final
    let completedLeagueIds = new Set();
    let completedCompNames = new Set();
    try {
      const [knockoutFinals] = await pool.query(`
        SELECT DISTINCT leagueId, competition FROM matches 
        WHERE (stage = 'Final' OR stage = 'Cup Final')
          AND status = 'fullTime'
      `);
      completedLeagueIds = new Set(knockoutFinals.map(m => m.leagueId).filter(Boolean));
      completedCompNames = new Set(knockoutFinals.map(m => (m.competition || '').trim().toLowerCase()).filter(Boolean));
    } catch (e) {}

    // 2. Check for competitions where all scheduled matches are fullTime (at least 1 match exists)
    try {
      const [matchStats] = await pool.query(`
        SELECT leagueId, competition,
               COUNT(*) as totalMatches,
               SUM(CASE WHEN status = 'fullTime' THEN 1 ELSE 0 END) as doneMatches
        FROM matches
        WHERE status IS NOT NULL AND status != ''
        GROUP BY leagueId, competition
      `);
      for (const stat of matchStats) {
        if (stat.totalMatches > 0 && stat.totalMatches === stat.doneMatches) {
          if (stat.leagueId) completedLeagueIds.add(stat.leagueId);
          if (stat.competition) completedCompNames.add((stat.competition || '').trim().toLowerCase());
        }
      }
    } catch (e) {}

    const result = rows.map(l => {
      const nameKey = (l.name || '').trim().toLowerCase();
      const isStatusCompleted = (l.status || '').toLowerCase() === 'completed' || (l.status || '').toLowerCase() === 'finished' || (l.status || '').toLowerCase() === 'archived';
      const isDoneByMatches = completedLeagueIds.has(l.id) || completedCompNames.has(nameKey);
      const isCompleted = Boolean(isStatusCompleted || isDoneByMatches);
      return {
        ...l,
        status: isCompleted ? 'completed' : (l.status || 'active'),
        isCompleted
      };
    });

    if (!includeCompleted) {
      // Exclude completed leagues/cups so team registration only shows active/open competitions
      return res.json(result.filter(l => !l.isCompleted));
    }

    res.json(result);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/leagues', async (req, res) => {
  try {
    const { id, name, description, format, advancingTeams } = req.body;
    await pool.query('INSERT INTO leagues (id, name, description, format, advancingTeams) VALUES (?,?,?,?,?)', [id, name, description || null, format || 'league', Math.max(1, Number(advancingTeams) || 2)]);
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/leagues/:id', async (req, res) => {
  try {
    const { name, description, format, advancingTeams } = req.body;
    await pool.query('UPDATE leagues SET name=?, description=?, format=?, advancingTeams=? WHERE id=?', [name, description || null, format || 'league', Math.max(1, Number(advancingTeams) || 2), req.params.id]);
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get(['/backend/api/teams/:id', '/api/teams/:id'], async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM teams WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const team = rows[0];
    if (Number(team.played) === 0) {
      try {
        const { standings } = await calculateLeagueLiveData();
        const s = (standings || []).find(x => x.id === team.id);
        if (s && s.played > 0) {
          team.played = s.played;
          team.won = s.won;
          team.drawn = s.drawn;
          team.lost = s.lost;
          team.goalsFor = s.goalsFor;
          team.goalsAgainst = s.goalsAgainst;
        }
      } catch (_) {}
    }
    res.json(team);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

async function findDuplicateTeam(name, excludeId = null) {
  const [rows] = await pool.query(
    `SELECT id, name FROM teams
     WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) ${excludeId ? 'AND id <> ?' : ''}
     LIMIT 1`,
    excludeId ? [name, excludeId] : [name]
  );
  return rows[0] || null;
}

async function findDuplicatePlayer(name, teamId, excludeId = null) {
  const [rows] = await pool.query(
    `SELECT id, name FROM players
     WHERE teamId = ? AND LOWER(TRIM(name)) = LOWER(TRIM(?)) ${excludeId ? 'AND id <> ?' : ''}
     LIMIT 1`,
    excludeId ? [teamId, name, excludeId] : [teamId, name]
  );
  return rows[0] || null;
}

app.post('/backend/api/teams', async (req, res) => {
  try {
    const { id, name, wardId, wardName, leagueId, leagueName, foundedYear, coachName, sponsorName, groupName, logoUrl, dashboardOnly, isExternal } = req.body;
    const duplicate = await findDuplicateTeam(name);
    if (duplicate) return res.status(409).json({ error: `A team named "${duplicate.name}" already exists.`, duplicateId: duplicate.id });
    await pool.query(
      'INSERT INTO teams (id, name, wardId, wardName, leagueId, leagueName, foundedYear, coachName, sponsorName, groupName, logoUrl, dashboardOnly, isExternal) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [id, name, wardId, wardName, leagueId || null, leagueName || null, foundedYear, coachName, sponsorName, groupName || null, logoUrl || null, Number(dashboardOnly) === 1 ? 1 : 0, Number(isExternal) === 1 ? 1 : 0]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/teams/:id', async (req, res) => {
  try {
    const { name, wardId, wardName, leagueId, leagueName, foundedYear, coachName, sponsorName, groupName, logoUrl, dashboardOnly, isExternal, played, won, drawn, lost, goalsFor, goalsAgainst } = req.body;
    const duplicate = await findDuplicateTeam(name, req.params.id);
    if (duplicate) return res.status(409).json({ error: `A team named "${duplicate.name}" already exists.`, duplicateId: duplicate.id });
    await pool.query(
      `UPDATE teams SET name=?, wardId=?, wardName=?, leagueId=?, leagueName=?, foundedYear=?, coachName=?, sponsorName=?, groupName=?, logoUrl=?, dashboardOnly=?, isExternal=?,
       played=?, won=?, drawn=?, lost=?, goalsFor=?, goalsAgainst=? WHERE id=?`,
      [name, wardId, wardName, leagueId || null, leagueName || null, foundedYear, coachName, sponsorName, groupName || null, logoUrl || null, Number(dashboardOnly) === 1 ? 1 : 0, Number(isExternal) === 1 ? 1 : 0, played, won, drawn, lost, goalsFor, goalsAgainst, req.params.id]
    );
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Players ─────────────────────────────────────────────────────────────────
app.get('/backend/api/players', async (req, res) => {
  try {
    const { teamId } = req.query;
    let sql = 'SELECT * FROM players';
    const params = [];
    if (teamId) { sql += ' WHERE teamId = ?'; params.push(teamId); }
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get(['/backend/api/players/:id', '/api/players/:id'], async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM players WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/players', requireTeamSession, async (req, res) => {
  try {
    const { id = `p${Date.now()}`, name, age, position, teamId, teamName, wardName, jerseyNumber, preferredFoot, heightM, bio, parentPhone, imageUrl } = req.body;
    const duplicate = await findDuplicatePlayer(name, teamId);
    if (duplicate) return res.status(409).json({ error: `This team already has a player named "${duplicate.name}".`, duplicateId: duplicate.id });
    await pool.query(
      `INSERT INTO players (id, name, age, position, teamId, teamName, wardName, jerseyNumber, preferredFoot, heightM, bio, parentPhone, imageUrl)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id, name, age || 0, position, teamId, teamName, wardName, jerseyNumber || 0, preferredFoot || 'Right', heightM || 0, bio || '', parentPhone || null, imageUrl || null]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/players/:id', async (req, res) => {
  try {
    const { goals, assists, appearances, cleanSheets, yellowCards, redCards, consentStatus } = req.body;
    await pool.query(
      `UPDATE players SET goals=?, assists=?, appearances=?, cleanSheets=?, yellowCards=?, redCards=?, consentStatus=? WHERE id=?`,
      [goals, assists, appearances, cleanSheets, yellowCards, redCards, consentStatus, req.params.id]
    );
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Matches ─────────────────────────────────────────────────────────────────
app.get('/backend/api/league-live-data', async (req, res) => {
  try {
    res.json(await calculateLeagueLiveData());
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/backend/api/matches', async (req, res) => {
  try {
    await syncLiveMatchMinutes(pool);
    const [rows] = await pool.query('SELECT * FROM matches ORDER BY kickoff DESC');
    let events = [];
    try {
      const [evRows] = await pool.query('SELECT * FROM match_events ORDER BY minute ASC');
      events = evRows;
    } catch (_) { /* match_events table may not exist yet */ }
    const matchMap = {};
    rows.forEach(m => { matchMap[m.id] = { ...m, events: [] }; });
    events.forEach(e => { if (matchMap[e.matchId]) matchMap[e.matchId].events.push(e); });
    res.json(Object.values(matchMap));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get(['/backend/api/matches/:id', '/api/matches/:id'], async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM matches WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const [events] = await pool.query('SELECT * FROM match_events WHERE matchId = ? ORDER BY minute ASC', [req.params.id]);
    res.json({ ...rows[0], events });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/matches', async (req, res) => {
  try {
    const { id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, leagueId, leagueName, kickoff, travelDistanceKm, stage, groupName } = req.body;
    await pool.query(
      `INSERT INTO matches (id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, leagueId, leagueName, kickoff, travelDistanceKm, stage, groupName)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, leagueId || null, leagueName || null, kickoff, travelDistanceKm, stage || 'League Match', groupName || null]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

async function autoAdvanceKnockout(pool, matchId) {
  try {
    const [[match]] = await pool.query('SELECT * FROM matches WHERE id = ?', [matchId]);
    if (!match || !match.leagueId || match.status !== 'fullTime') return null;

    const stage = match.stage || '';
    const stageFlow = {
      'Round of 32': 'Round of 16',
      'Round of 16': 'Quarter-Final',
      'Quarter-Final': 'Semi-Final',
      'Semi-Final': 'Final'
    };

    const nextStage = stageFlow[stage];
    if (!nextStage) return null;

    const leagueId = match.leagueId;
    const [stageMatches] = await pool.query('SELECT * FROM matches WHERE leagueId = ? AND stage = ? ORDER BY id ASC', [leagueId, stage]);
    if (!stageMatches || stageMatches.length === 0) return null;

    const matchIndex = stageMatches.findIndex(m => m.id === matchId);
    if (matchIndex === -1) return null;

    const pairIndex   = Math.floor(matchIndex / 2);
    const isHomeSlot  = (matchIndex % 2 === 0);
    const partnerIndex = isHomeSlot ? matchIndex + 1 : matchIndex - 1;

    // A tied knockout match advances only after a recorded shootout winner.
    // Shootout goals are event records, not normal match/player goals.
    let homeWon = Number(match.homeScore) > Number(match.awayScore);
    if (Number(match.homeScore) === Number(match.awayScore)) {
      const [shootoutRows] = await pool.query(
        "SELECT teamName, COUNT(*) AS total FROM match_events WHERE matchId=? AND type='Shootout Goal' GROUP BY teamName",
        [matchId]
      );
      const shootout = new Map(shootoutRows.map(row => [row.teamName, Number(row.total)]));
      const homeShootout = shootout.get(match.homeTeamName) || 0;
      const awayShootout = shootout.get(match.awayTeamName) || 0;
      if (homeShootout === awayShootout) return null;
      homeWon = homeShootout > awayShootout;
    }
    const winnerCurrent = homeWon
      ? { id: match.homeTeamId, name: match.homeTeamName, ward: match.wardName || '' }
      : { id: match.awayTeamId, name: match.awayTeamName, ward: match.wardName || '' };

    const [nextMatches] = await pool.query('SELECT * FROM matches WHERE leagueId = ? AND stage = ? ORDER BY id ASC', [leagueId, nextStage]);

    if (nextMatches && nextMatches[pairIndex]) {
      // Fixture already exists — only update our slot
      const existingNext = nextMatches[pairIndex];
      if (isHomeSlot) {
        await pool.query('UPDATE matches SET homeTeamId=?, homeTeamName=? WHERE id=?',
          [winnerCurrent.id, winnerCurrent.name, existingNext.id]);
      } else {
        await pool.query('UPDATE matches SET awayTeamId=?, awayTeamName=? WHERE id=?',
          [winnerCurrent.id, winnerCurrent.name, existingNext.id]);
      }
      return { advanced: true, updatedMatchId: existingNext.id, stage: nextStage };
    } else {
      // No fixture yet — check partner and create fixture immediately
      const partnerMatch = stageMatches[partnerIndex];
      let winnerPartner = null;
      if (partnerMatch && partnerMatch.status === 'fullTime') {
        let partnerHomeWon = Number(partnerMatch.homeScore) > Number(partnerMatch.awayScore);
        if (Number(partnerMatch.homeScore) === Number(partnerMatch.awayScore)) {
          const [partnerShootoutRows] = await pool.query(
            "SELECT teamName, COUNT(*) AS total FROM match_events WHERE matchId=? AND type='Shootout Goal' GROUP BY teamName",
            [partnerMatch.id]
          );
          const shootout = new Map(partnerShootoutRows.map(row => [row.teamName, Number(row.total)]));
          const homeShootout = shootout.get(partnerMatch.homeTeamName) || 0;
          const awayShootout = shootout.get(partnerMatch.awayTeamName) || 0;
          if (homeShootout !== awayShootout) partnerHomeWon = homeShootout > awayShootout;
          else partnerHomeWon = null;
        }
        winnerPartner = partnerHomeWon == null ? null : partnerHomeWon
          ? { id: partnerMatch.homeTeamId, name: partnerMatch.homeTeamName, ward: partnerMatch.wardName || '' }
          : { id: partnerMatch.awayTeamId, name: partnerMatch.awayTeamName, ward: partnerMatch.wardName || '' };
      }

      const newId   = 'm' + Date.now().toString(36) + Math.random().toString(36).substring(2, 6);
      const venue   = match.venue || 'Tournament Main Arena';
      const comp    = match.competition || match.leagueName;
      const kickoff = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);

      let homeId, homeName, awayId, awayName;
      if (winnerPartner) {
        homeId   = isHomeSlot ? winnerCurrent.id   : winnerPartner.id;
        homeName = isHomeSlot ? winnerCurrent.name : winnerPartner.name;
        awayId   = isHomeSlot ? winnerPartner.id   : winnerCurrent.id;
        awayName = isHomeSlot ? winnerPartner.name : winnerCurrent.name;
      } else {
        homeId   = isHomeSlot ? winnerCurrent.id   : 'tbd';
        homeName = isHomeSlot ? winnerCurrent.name : 'TBD (Awaiting Opponent)';
        awayId   = isHomeSlot ? 'tbd'              : winnerCurrent.id;
        awayName = isHomeSlot ? 'TBD (Awaiting Opponent)' : winnerCurrent.name;
      }

      await pool.query(
        'INSERT INTO matches (id, homeTeamId, awayTeamId, homeTeamName, awayTeamName, venue, wardName, competition, leagueId, leagueName, kickoff, status, stage) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [newId, homeId, awayId, homeName, awayName, venue, winnerCurrent.ward, comp, leagueId, match.leagueName, kickoff, 'upcoming', nextStage]
      );
      return { advanced: true, createdMatchId: newId, stage: nextStage };
    }
  } catch (err) {
    console.error('autoAdvanceKnockout error:', err);
  }
  return null;
}

async function reconcilePlayedMatchTeams(pool) {
  const [matches] = await pool.query(
    `SELECT leagueId, homeTeamId, awayTeamId
     FROM matches
     WHERE status='fullTime'
       AND leagueId IS NOT NULL
       AND leagueId <> ''`
  );

  for (const match of matches) {
    const teamIds = new Set([match.homeTeamId, match.awayTeamId]
      .filter(teamId => teamId && teamId !== 'tbd'));
    for (const teamId of teamIds) {
      await pool.query(
        `INSERT IGNORE INTO team_competitions
         (id, teamId, leagueId, competitionRole)
         VALUES (?, ?, ?, 'participant')`,
        [`tc-${createHash('sha256').update(`${teamId}:${match.leagueId}`).digest('hex').substring(0, 32)}`, teamId, match.leagueId]
      );
    }
  }
}

async function reconcileKnockoutFixtures(pool) {
  const [completed] = await pool.query(
    `SELECT id FROM matches
     WHERE status='fullTime'
       AND stage IN ('Round of 32', 'Round of 16', 'Quarter-Final', 'Semi-Final')`
  );
  for (const match of completed) {
    await autoAdvanceKnockout(pool, match.id);
  }
}

app.put('/backend/api/matches/:id', async (req, res) => {
  try {
    const { status, homeScore, awayScore, minute, phase, leagueId, leagueName, stage, groupName, playerOfMatchId, playerOfMatchName } = req.body;
    await pool.query(
      `UPDATE matches SET status=?, homeScore=?, awayScore=?, minute=?, phase=?, leagueId=?, leagueName=?, stage=?, groupName=?, playerOfMatchId=?, playerOfMatchName=?,
       liveStartedAt = CASE WHEN ? = 'live' AND liveStartedAt IS NULL THEN NOW() WHEN ? <> 'live' THEN NULL ELSE liveStartedAt END
       WHERE id=?`,
      [status, homeScore, awayScore, minute, phase || 'First Half', leagueId || null, leagueName || null, stage || 'League Match', groupName || null, playerOfMatchId || null, playerOfMatchName || null, status, status, req.params.id]
    );
    if (status === 'fullTime') {
      await reconcilePlayedMatchTeams(pool);
      await autoAdvanceKnockout(pool, req.params.id);
    }
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/matches/:id/events', async (req, res) => {
  try {
    const { id, minute, type, teamName, playerName, assistName, isPenalty } = req.body;
    await pool.query(
      'INSERT INTO match_events (id, matchId, minute, type, teamName, playerName, assistName, isPenalty) VALUES (?,?,?,?,?,?,?,?)',
      [id, req.params.id, minute, type, teamName, playerName, assistName || null, isPenalty ? 1 : 0]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/matches/:id/events/:eventId', async (req, res) => {
  try {
    const { minute, playerName, assistName, isPenalty } = req.body;
    await pool.query(
      'UPDATE match_events SET minute=?, playerName=?, assistName=?, isPenalty=? WHERE id=? AND matchId=?',
      [minute, playerName, assistName || null, isPenalty ? 1 : 0, req.params.eventId, req.params.id]
    );
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/backend/api/matches/:id/events/:eventId', async (req, res) => {
  try {
    const [[ev]] = await pool.query('SELECT * FROM match_events WHERE id = ?', [req.params.eventId]);
    if (ev) {
      const [[m]] = await pool.query('SELECT * FROM matches WHERE id = ?', [req.params.id]);
      if (m && ev.type === 'Goal') {
        if (ev.teamName === m.homeTeamName) {
          await pool.query('UPDATE matches SET homeScore = GREATEST(homeScore-1,0) WHERE id=?', [m.id]);
        } else {
          await pool.query('UPDATE matches SET awayScore = GREATEST(awayScore-1,0) WHERE id=?', [m.id]);
        }
      } else if (m && ev.type === 'Own Goal') {
        if (ev.teamName === m.homeTeamName) {
          await pool.query('UPDATE matches SET awayScore = GREATEST(awayScore-1,0) WHERE id=?', [m.id]);
        } else {
          await pool.query('UPDATE matches SET homeScore = GREATEST(homeScore-1,0) WHERE id=?', [m.id]);
        }
      }
      await pool.query('DELETE FROM match_events WHERE id = ?', [req.params.eventId]);
    }
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Injuries ─────────────────────────────────────────────────────────────────
app.get('/backend/api/injuries', async (req, res) => {
  try {
    const { playerId } = req.query;
    let sql = 'SELECT * FROM injuries ORDER BY date DESC';
    const params = [];
    if (playerId) { sql = 'SELECT * FROM injuries WHERE playerId = ? ORDER BY date DESC'; params.push(playerId); }
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/injuries', async (req, res) => {
  try {
    const { id, playerId, playerName, date, injuryType, severity, recoveryDays, notes } = req.body;
    await pool.query(
      'INSERT INTO injuries (id, playerId, playerName, date, injuryType, severity, recoveryDays, notes) VALUES (?,?,?,?,?,?,?,?)',
      [id, playerId, playerName, date, injuryType, severity, recoveryDays, notes]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/injuries/:id/status', async (req, res) => {
  try {
    await pool.query('UPDATE injuries SET status=? WHERE id=?', [req.body.status, req.params.id]);
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Attendance ───────────────────────────────────────────────────────────────
app.get('/backend/api/attendance', async (req, res) => {
  try {
    const { playerId } = req.query;
    let sql = 'SELECT * FROM attendance ORDER BY weekOf DESC';
    const params = [];
    if (playerId) { sql = 'SELECT * FROM attendance WHERE playerId = ? ORDER BY weekOf DESC'; params.push(playerId); }
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/attendance', async (req, res) => {
  try {
    const { id, playerId, playerName, weekOf, daysPresent, daysTotal, loggedBy } = req.body;
    await pool.query(
      'INSERT INTO attendance (id, playerId, playerName, weekOf, daysPresent, daysTotal, loggedBy) VALUES (?,?,?,?,?,?,?)',
      [id, playerId, playerName, weekOf, daysPresent, daysTotal, loggedBy]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Disciplinary ─────────────────────────────────────────────────────────────
app.get('/backend/api/disciplinary', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM disciplinary ORDER BY date DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/disciplinary', async (req, res) => {
  try {
    const { id, playerId, playerName, teamName, matchLabel, cardType, reason, date, suspensionMatches, fineAmount } = req.body;
    await pool.query(
      'INSERT INTO disciplinary (id, playerId, playerName, teamName, matchLabel, cardType, reason, date, suspensionMatches, fineAmount) VALUES (?,?,?,?,?,?,?,?,?,?)',
      [id, playerId, playerName, teamName, matchLabel, cardType, reason, date, suspensionMatches, fineAmount]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/disciplinary/:id/pay', async (req, res) => {
  try {
    await pool.query('UPDATE disciplinary SET finePaid=1 WHERE id=?', [req.params.id]);
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Referees ─────────────────────────────────────────────────────────────────
app.get('/backend/api/referees', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM referees');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/backend/api/referee-ratings', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM referee_ratings ORDER BY date DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/referee-ratings', async (req, res) => {
  try {
    const { id, refereeId, refereeName, matchLabel, ratedByTeam, fairnessScore, communicationScore, comment, date } = req.body;
    await pool.query(
      'INSERT INTO referee_ratings (id, refereeId, refereeName, matchLabel, ratedByTeam, fairnessScore, communicationScore, comment, date) VALUES (?,?,?,?,?,?,?,?,?)',
      [id, refereeId, refereeName, matchLabel, ratedByTeam, fairnessScore, communicationScore, comment, date]
    );
    // Update avg scores
    const [ratings] = await pool.query('SELECT * FROM referee_ratings WHERE refereeId = ?', [refereeId]);
    const avgF = ratings.reduce((s, r) => s + r.fairnessScore, 0) / ratings.length;
    const avgC = ratings.reduce((s, r) => s + r.communicationScore, 0) / ratings.length;
    await pool.query('UPDATE referees SET avgFairness=?, avgCommunication=?, matchesOfficiated=matchesOfficiated+1 WHERE id=?', [avgF, avgC, refereeId]);
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Player scout ratings ───────────────────────────────────────────────────
app.get('/backend/api/player-scout-ratings', async (req, res) => {
  try {
    const [rows] = await pool.query(`SELECT playerId, COUNT(*) AS totalVotes,
      AVG(pace) AS pace, AVG(shooting) AS shooting, AVG(passing) AS passing,
      AVG(dribbling) AS dribbling, AVG(defending) AS defending, AVG(physical) AS physical
      FROM player_scout_ratings GROUP BY playerId`);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/player-scout-ratings', async (req, res) => {
  try {
    const { id, playerId, pace, shooting, passing, dribbling, defending, physical } = req.body;
    const values = [pace, shooting, passing, dribbling, defending, physical].map(Number);
    if (!id || !playerId || values.some(value => !Number.isInteger(value) || value < 0 || value > 100)) {
      return res.status(400).json({ error: 'A player and six ratings from 0 to 100 are required.' });
    }
    await pool.query(
      `INSERT INTO player_scout_ratings
        (id, playerId, pace, shooting, passing, dribbling, defending, physical, submittedAt)
       VALUES (?,?,?,?,?,?,?,?,NOW())`,
      [id, playerId, ...values]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Video Clips ──────────────────────────────────────────────────────────────
app.get('/backend/api/videos', async (req, res) => {
  try {
    const { playerId } = req.query;
    let sql = 'SELECT * FROM video_clips ORDER BY uploadDate DESC';
    const params = [];
    if (playerId) { sql = 'SELECT * FROM video_clips WHERE playerId = ? ORDER BY uploadDate DESC'; params.push(playerId); }
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/videos', async (req, res) => {
  try {
    const { id, playerId, playerName, teamName, title, durationSeconds, matchLabel } = req.body;
    const uploadDate = new Date().toISOString().slice(0, 19).replace('T', ' ');
    await pool.query(
      'INSERT INTO video_clips (id, playerId, playerName, teamName, title, durationSeconds, uploadDate, matchLabel) VALUES (?,?,?,?,?,?,?,?)',
      [id, playerId, playerName, teamName, title, durationSeconds, uploadDate, matchLabel]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Sponsorships ─────────────────────────────────────────────────────────────
app.get('/backend/api/sponsorships', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM sponsorships ORDER BY date DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/sponsorships', async (req, res) => {
  try {
    const body = req.body;
    const id = body.id || 's' + Date.now();
    await pool.query(
      `INSERT INTO sponsorships (id, sponsorName, isDiaspora, type, targetName, amountMwk, message, date, imageUrl, linkUrl) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id, body.sponsorName, body.isDiaspora ? 1 : 0, body.type,
        body.targetName, body.amountMwk || 0, body.message, body.date || new Date(),
        body.imageUrl || null, body.linkUrl || null
      ]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Ledger ───────────────────────────────────────────────────────────────────
app.get('/backend/api/ledger', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM ledger ORDER BY date DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/ledger', async (req, res) => {
  try {
    const { id, date, description, type, category, amountMwk } = req.body;
    await pool.query(
      'INSERT INTO ledger (id, date, description, type, category, amountMwk) VALUES (?,?,?,?,?,?)',
      [id, date, description, type, category, amountMwk]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Transfers ────────────────────────────────────────────────────────────────
app.get('/backend/api/transfers', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM transfers ORDER BY date DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/transfers', async (req, res) => {
  try {
    const { id, playerId, playerName, sellingTeam, buyingTeam, agreedFeeMwk, commissionPercent, date } = req.body;
    await pool.query(
      'INSERT INTO transfers (id, playerId, playerName, sellingTeam, buyingTeam, agreedFeeMwk, commissionPercent, date) VALUES (?,?,?,?,?,?,?,?)',
      [id, playerId, playerName, sellingTeam, buyingTeam, agreedFeeMwk, commissionPercent || 15, date]
    );
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/transfers/:id/advance', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM transfers WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const t = rows[0];
    const order = ['awaitingPayment', 'fundsHeld', 'clearanceReleased', 'completed'];
    const nextIdx = order.indexOf(t.status) + 1;
    if (nextIdx < order.length) {
      await pool.query('UPDATE transfers SET status=? WHERE id=?', [order[nextIdx], req.params.id]);
    }
    res.json({ status: order[Math.min(nextIdx, order.length - 1)] });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Consent Logs ─────────────────────────────────────────────────────────────
app.get('/backend/api/consent', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM consent_logs ORDER BY sentDate DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/consent', async (req, res) => {
  try {
    const { id, playerId, playerName, parentPhone, sentDate } = req.body;
    await pool.query(
      'INSERT INTO consent_logs (id, playerId, playerName, parentPhone, sentDate) VALUES (?,?,?,?,?)',
      [id, playerId, playerName, parentPhone, sentDate]
    );
    // Mark player consent as sent
    await pool.query('UPDATE players SET consentStatus=? WHERE id=?', ['sent', playerId]);
    res.status(201).json({ id });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/backend/api/consent/:playerId/approve', async (req, res) => {
  try {
    await pool.query('UPDATE consent_logs SET status=? WHERE playerId=?', ['approved', req.params.playerId]);
    await pool.query('UPDATE players SET consentStatus=? WHERE id=?', ['approved', req.params.playerId]);
    res.json({ updated: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── News ─────────────────────────────────────────────────────────────────────
app.get('/backend/api/news', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM news ORDER BY date DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Events ───────────────────────────────────────────────────────────────────
app.get('/backend/api/events', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM events ORDER BY date ASC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Team Portals & Registrations ─────────────────────────────────────────────

app.post('/backend/api/register', async (req, res) => {
  try {
    const { teamName, wardName, coachName, leagueId, leagueName, phone } = req.body;

    if (!teamName || !wardName || !coachName) {
      return res.status(400).json({ error: 'Team name, ward name, and coach name are required.' });
    }

    // Ensure columns exist on teams table
    try {
      const [cols] = await pool.query('SHOW COLUMNS FROM teams');
      const colNames = cols.map(c => c.Field);
      if (!colNames.includes('username')) await pool.query('ALTER TABLE teams ADD COLUMN username VARCHAR(100) DEFAULT NULL');
      if (!colNames.includes('password')) await pool.query('ALTER TABLE teams ADD COLUMN password VARCHAR(100) DEFAULT NULL');
      if (!colNames.includes('coachName')) await pool.query('ALTER TABLE teams ADD COLUMN coachName VARCHAR(255) DEFAULT NULL');
      if (!colNames.includes('leagueId')) await pool.query('ALTER TABLE teams ADD COLUMN leagueId VARCHAR(50) DEFAULT NULL');
      if (!colNames.includes('leagueName')) await pool.query('ALTER TABLE teams ADD COLUMN leagueName VARCHAR(255) DEFAULT NULL');
    } catch (e) {
      console.warn('Column check warning on teams table:', e.message);
    }

    // Resolve league / cup details if provided
    let finalLeagueId = leagueId || null;
    let finalLeagueName = leagueName || null;
    if (finalLeagueId && !finalLeagueName) {
      const [lRows] = await pool.query('SELECT name FROM leagues WHERE id = ?', [finalLeagueId]);
      if (lRows.length) finalLeagueName = lRows[0].name;
    }

    // Generate 2-word username with NO dashes (e.g. "Silver Strikers", "Area Comets", "Bullets FC")
    const cleanTokens = String(teamName)
      .replace(/[^a-zA-Z0-9\s]/g, ' ')
      .trim()
      .split(/\s+/)
      .filter(Boolean);

    const alphaWords = cleanTokens.filter(w => /^[a-zA-Z]+$/.test(w));
    const tokenPool = alphaWords.length >= 2 ? alphaWords : cleanTokens;

    let firstWord = '';
    let secondWord = '';

    if (tokenPool.length >= 2) {
      firstWord = tokenPool[0];
      secondWord = tokenPool[1];
    } else if (tokenPool.length === 1) {
      firstWord = tokenPool[0];
      secondWord = 'FC';
    } else {
      firstWord = 'Team';
      secondWord = 'United';
    }

    firstWord = firstWord.charAt(0).toUpperCase() + firstWord.slice(1).toLowerCase();
    secondWord = secondWord.charAt(0).toUpperCase() + secondWord.slice(1).toLowerCase();

    let candidateUsername = `${firstWord} ${secondWord}`;
    let counter = 1;

    // Ensure uniqueness in teams table (keep 2 words, no dashes)
    while (true) {
      const [existing] = await pool.query('SELECT id FROM teams WHERE username = ?', [candidateUsername]);
      if (existing.length === 0) break;
      counter++;
      candidateUsername = `${firstWord} ${secondWord}${counter}`;
    }

    // Generate clean password
    const password = `Naysa${Math.floor(1000 + Math.random() * 9000)}`;
    const teamId = `t${Date.now()}${Math.floor(10 + Math.random() * 90)}`;

    // 1. Create team account immediately
    await pool.query(
      'INSERT INTO teams (id, name, wardName, coachName, leagueId, leagueName, username, password) VALUES (?,?,?,?,?,?,?,?)',
      [teamId, teamName.trim(), wardName.trim(), coachName.trim(), finalLeagueId, finalLeagueName, candidateUsername, password]
    );

    // 2. Save registration record as completed & approved for free
    const chargeId = `reg${Date.now()}`;
    await pool.query(
      'INSERT INTO team_registrations (id, teamName, wardName, coachName, paymentReceiptRef, paymentStatus, status, requestDate) VALUES (?,?,?,?,?,"completed","approved", NOW())',
      [chargeId, teamName.trim(), wardName.trim(), coachName.trim(), 'FREE-REG']
    );

    const token = signSession(teamId);
    res.status(201).json({
      ok: true,
      message: 'Team registered successfully!',
      username: candidateUsername,
      password,
      team: {
        id: teamId,
        name: teamName.trim(),
        wardName: wardName.trim(),
        coachName: coachName.trim(),
        leagueId: finalLeagueId,
        leagueName: finalLeagueName,
        username: candidateUsername,
        token
      },
      token
    });
  } catch (e) {
    console.error('Register error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.get('/backend/api/register/verify/:chargeId', async (req, res) => {
  try {
    const { chargeId } = req.params;
    const https = require('https');
    
    const options = {
      hostname: 'api.paychangu.com',
      path: `/mobile-money/payments/${encodeURIComponent(chargeId)}/verify`,
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': `Bearer ${process.env.PAYCHANGU_SECRET_KEY}`
      }
    };

    let verifyData;
    try {
      verifyData = await new Promise((resolve, reject) => {
        const reqHttp = https.request(options, (resHttp) => {
          let data = '';
          resHttp.on('data', chunk => data += chunk);
          resHttp.on('end', () => {
            try { resolve(JSON.parse(data)); } catch (e) { resolve({ status: 'pending' }); }
          });
        });
        reqHttp.on('error', () => resolve({ status: 'pending' }));
        reqHttp.end();
      });
    } catch (e) {
      verifyData = { status: 'pending' };
    }

    const rawStatus = (verifyData.data?.status || verifyData.status || '').toLowerCase();
    let paymentStatus = 'pending';
    if (['success', 'successful', 'completed', 'approved'].includes(rawStatus)) {
      paymentStatus = 'completed';
    } else if (['failed', 'failed_charge', 'cancelled', 'expired', 'error'].includes(rawStatus)) {
      paymentStatus = 'failed';
    }

    await pool.query('UPDATE team_registrations SET paymentStatus = ? WHERE paymentReceiptRef = ?', [paymentStatus, chargeId]);
    res.json({ id: chargeId, paymentStatus, rawStatus });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/backend/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const cleanUser = String(username || '').trim();
    const cleanPass = String(password || '').trim();

    const [rows] = await pool.query(
      'SELECT * FROM teams WHERE (username = ? OR LOWER(username) = LOWER(?) OR REPLACE(LOWER(username), " ", "") = REPLACE(LOWER(?), " ", "")) AND password = ?',
      [cleanUser, cleanUser, cleanUser, cleanPass]
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }
    const team = rows[0];
    res.json({
      id: team.id,
      name: team.name,
      wardName: team.wardName,
      coachName: team.coachName,
      token: signSession(team.id),
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/backend/api/upload', requireTeamSession, (req, res) => {
  upload.single('image')(req, res, async (uploadError) => {
    if (uploadError) {
      const isTooLarge = uploadError.code === 'LIMIT_FILE_SIZE';
      console.warn(`[UPLOAD] rejected for team ${req.teamId}: ${uploadError.code || uploadError.message}`);
      return res.status(isTooLarge ? 413 : 415).json({
        code: isTooLarge ? 'IMAGE_TOO_LARGE' : 'UNSUPPORTED_IMAGE',
        error: isTooLarge
          ? 'Image is too large. Choose a photo smaller than 5 MB.'
          : 'Choose a JPG, PNG, or WebP image.',
      });
    }
  if (!req.file) {
      return res.status(400).json({ code: 'NO_IMAGE', error: 'Choose an image before uploading.' });
  }

  try {
    if (!r2Configured) {
        console.error('[UPLOAD] R2 is not configured. Missing:',
          ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET_NAME', 'R2_PUBLIC_URL']
            .filter((name) => !process.env[name]).join(', '));
        return res.status(503).json({
          code: 'IMAGE_STORAGE_NOT_CONFIGURED',
          error: 'Image storage is not configured. Please contact the administrator.',
        });
    }
      const ext = supportedImageTypes.get(req.file.mimetype);
      if (!ext) {
        return res.status(415).json({ code: 'UNSUPPORTED_IMAGE', error: 'Choose a JPG, PNG, or WebP image.' });
      }
    const filename = `players/${Date.now()}-${Math.round(Math.random()*1E9)}${ext.toLowerCase()}`;
    
    await s3Client.send(new PutObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME || 'naysa-media',
      Key: filename,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
      ContentDisposition: 'inline',
      CacheControl: 'public, max-age=31536000, immutable',
    }));
    
    // Construct the public R2 URL
    const publicUrl = process.env.R2_PUBLIC_URL.replace(/\/$/, '');
    const fileUrl = `${publicUrl}/${filename}`;
    
      console.info(`[UPLOAD] completed for team ${req.teamId}: ${filename} (${req.file.size} bytes)`);
      res.json({ url: fileUrl, key: filename });
  } catch (e) {
      console.error('[UPLOAD] R2 upload failed:', e.name, e.code || '', e.message);
      res.status(502).json({
        code: 'IMAGE_STORAGE_UPLOAD_FAILED',
        error: 'Image storage could not save this photo. Please try again.',
      });
  }
  });
});

// ── Heartbeat Ping Endpoint (Called by Mobile App every 60s) ──
app.post(['/api/ping', '/backend/api/ping'], async (req, res) => {
  try {
    const { deviceId, role, platform, appVersion } = req.body || {};
    if (!deviceId || typeof deviceId !== 'string' || deviceId.trim().length === 0) {
      return res.status(400).json({ ok: false, error: 'deviceId is required' });
    }

    const cleanDeviceId = deviceId.trim().slice(0, 100);
    const cleanRole = ['viewer', 'scout', 'team'].includes(role) ? role : 'viewer';
    const cleanPlatform = (platform || 'mobile').toString().slice(0, 50);
    const cleanVersion = (appVersion || '1.0.0').toString().slice(0, 50);

    await pool.query(
      `INSERT INTO app_active_sessions (deviceId, role, platform, appVersion, firstSeen, lastPing)
       VALUES (?, ?, ?, ?, NOW(), NOW())
       ON DUPLICATE KEY UPDATE
         role = VALUES(role),
         platform = VALUES(platform),
         appVersion = VALUES(appVersion),
         lastPing = NOW()`,
      [cleanDeviceId, cleanRole, cleanPlatform, cleanVersion]
    );

    res.json({ ok: true, timestamp: Date.now() });
  } catch (err) {
    console.error('[PING ERROR]', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ── Active Users Stats Endpoint ──
app.get(['/api/active-users', '/backend/api/active-users'], async (req, res) => {
  try {
    // Online now: ping within the last 90 seconds. The app sends a heartbeat every 60 seconds.
    const [[onlineRow]] = await pool.query(
      "SELECT COUNT(*) AS onlineCount FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 90 SECOND)"
    );

    // Today active (DAU): ping within last 24 hours
    const [[dauRow]] = await pool.query(
      "SELECT COUNT(*) AS dauCount FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 24 HOUR)"
    );

    // Breakdown by role (online now)
    const [rolesOnline] = await pool.query(
      `SELECT role, COUNT(*) AS count 
       FROM app_active_sessions 
      WHERE lastPing >= (NOW() - INTERVAL 90 SECOND) 
       GROUP BY role`
    );

    // Breakdown by role (today)
    const [rolesToday] = await pool.query(
      `SELECT role, COUNT(*) AS count 
       FROM app_active_sessions 
       WHERE lastPing >= (NOW() - INTERVAL 24 HOUR) 
       GROUP BY role`
    );

    const onlineByRole = { viewer: 0, scout: 0, team: 0 };
    for (const r of rolesOnline) {
      if (onlineByRole[r.role] !== undefined) onlineByRole[r.role] = Number(r.count);
    }

    const todayByRole = { viewer: 0, scout: 0, team: 0 };
    for (const r of rolesToday) {
      if (todayByRole[r.role] !== undefined) todayByRole[r.role] = Number(r.count);
    }

    res.json({
      ok: true,
      onlineNow: Number(onlineRow.onlineCount || 0),
      activeToday: Number(dauRow.dauCount || 0),
      onlineByRole,
      todayByRole,
    });
  } catch (err) {
    console.error('[ACTIVE USERS STATS ERROR]', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
reconcilePlayedMatchTeams(pool)
  .catch(error => console.error('Unable to reconcile played match teams:', error.message));

app.listen(PORT, () => console.log(`NAYSA API running → https://naysasport.com/backend (port ${PORT})`));

