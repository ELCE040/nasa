<?php
require_once __DIR__.'/config.php';

function ensureMultiCompetitionTables(): void {
    static $done = false;
    if ($done) return;
    $done = true;

    $pdo = db();

    // 1. team_competitions junction table — maps any team to any league/cup
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS team_competitions (
            id VARCHAR(100) PRIMARY KEY,
            teamId VARCHAR(50) NOT NULL,
            leagueId VARCHAR(50) NOT NULL,
            competitionRole VARCHAR(50) DEFAULT 'participant',
            enrolledAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_team_league (teamId, leagueId),
            INDEX idx_tc_league (leagueId),
            INDEX idx_tc_team (teamId)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    } catch (Throwable $e) {}

    // 2. team_squad_members — player belongs to many squads (club + national etc.)
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS team_squad_members (
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    } catch (Throwable $e) {}

    // 3. Add teamType column to teams (club / national / regional_select / academy)
    try {
        $cols = $pdo->query("SHOW COLUMNS FROM teams")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('teamType', $cols, true)) {
            $pdo->exec("ALTER TABLE teams ADD COLUMN teamType VARCHAR(30) NOT NULL DEFAULT 'club'");
        }
    } catch (Throwable $e) {}

    // 4. Add clubStatus to players — 'club' or 'unattached' (national-only players)
    try {
        $cols = $pdo->query("SHOW COLUMNS FROM players")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('clubStatus', $cols, true)) {
            $pdo->exec("ALTER TABLE players ADD COLUMN clubStatus VARCHAR(30) NOT NULL DEFAULT 'club'");
        }
    } catch (Throwable $e) {}

    // 5. Backfill team_competitions from teams.leagueId (existing single-league assignments)
    try {
        $pdo->exec("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, enrolledAt)
            SELECT CONCAT('tc_', id, '_', leagueId), id, leagueId, NOW()
            FROM teams
            WHERE leagueId IS NOT NULL AND leagueId <> ''");
    } catch (Throwable $e) {}

    // 5b. Auto-enroll ANY team that has played or been scheduled in a competition match
    try {
        $pdo->exec("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
            SELECT DISTINCT CONCAT('tc_', m.homeTeamId, '_', m.leagueId), m.homeTeamId, m.leagueId, 'participant', NOW()
            FROM matches m
            WHERE m.leagueId IS NOT NULL AND m.leagueId <> '' AND m.homeTeamId IS NOT NULL AND m.homeTeamId <> ''
            UNION
            SELECT DISTINCT CONCAT('tc_', m.awayTeamId, '_', m.leagueId), m.awayTeamId, m.leagueId, 'participant', NOW()
            FROM matches m
            WHERE m.leagueId IS NOT NULL AND m.leagueId <> '' AND m.awayTeamId IS NOT NULL AND m.awayTeamId <> ''");
    } catch (Throwable $e) {}

    // 5c. If a team has no primary leagueId, set it from the first competition it played in
    try {
        $pdo->exec("UPDATE teams t
            JOIN (
                SELECT tc.teamId, MIN(tc.leagueId) AS primaryLeague
                FROM team_competitions tc
                GROUP BY tc.teamId
            ) first_comp ON first_comp.teamId = t.id
            SET t.leagueId = first_comp.primaryLeague
            WHERE (t.leagueId IS NULL OR t.leagueId = '')");
    } catch (Throwable $e) {}

    // 6. Backfill team_squad_members from players.teamId (existing club memberships)
    try {
        $pdo->exec("INSERT IGNORE INTO team_squad_members (id, teamId, playerId, jerseyNumber, callupDate)
            SELECT CONCAT('sm_', teamId, '_', id), teamId, id, jerseyNumber, NOW()
            FROM players
            WHERE teamId IS NOT NULL AND teamId <> ''");
    } catch (Throwable $e) {}

    // 7. Performance indexes (safe — ignore if already exist)
    try { $pdo->exec("CREATE INDEX idx_matches_status_league ON matches(status, leagueId)"); } catch (Throwable $e) {}
    try { $pdo->exec("CREATE INDEX idx_me_matchid ON match_events(matchId, minute)"); } catch (Throwable $e) {}
    try { $pdo->exec("CREATE INDEX idx_players_teamid ON players(teamId)"); } catch (Throwable $e) {}
}

function autoEnrolMatchTeams(PDO $pdo, ?string $leagueId, ?string $homeTeamId, ?string $awayTeamId): void {
    if (empty($leagueId)) return;
    foreach ([$homeTeamId, $awayTeamId] as $tid) {
        if (!empty($tid)) {
            try {
                $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
                    VALUES (?, ?, ?, 'participant', NOW())")
                    ->execute(['tc_'.$tid.'_'.$leagueId, $tid, $leagueId]);

                // Also ensure teams.leagueId is set if it was blank
                $pdo->prepare("UPDATE teams SET leagueId=? WHERE id=? AND (leagueId IS NULL OR leagueId='')")
                    ->execute([$leagueId, $tid]);
            } catch (Throwable $e) {}
        }
    }
}

ensureMultiCompetitionTables();
