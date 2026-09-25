<?php
require_once __DIR__.'/config.php';
$pdo = db();

header('Content-Type: application/json');

try {
    // 1. Differentiate the teams
    // Team t178973490397122 -> MALAWI U-20 in CAF U-20 (GROUP C)
    $pdo->prepare("UPDATE teams SET name = 'MALAWI U-20', ageGroup = 'U-20', leagueId = 'l6aad2eb551ec2', leagueName = 'CAF U-20 AFRICAN CUP OF NATION Q', groupName = 'GROUP C' WHERE id = 't178973490397122'")->execute();
    $pdo->prepare("UPDATE players SET teamName = 'MALAWI U-20' WHERE teamId = 't178973490397122'")->execute();
    $pdo->prepare("UPDATE matches SET homeTeamName = 'MALAWI U-20' WHERE homeTeamId = 't178973490397122' AND leagueId = 'l6aad2eb551ec2'")->execute();
    $pdo->prepare("UPDATE matches SET awayTeamName = 'MALAWI U-20' WHERE awayTeamId = 't178973490397122' AND leagueId = 'l6aad2eb551ec2'")->execute();

    // Team t179034682757713 -> MALAWI Senior in AFCON 2027 (GROUP B)
    $pdo->prepare("UPDATE teams SET name = 'MALAWI', ageGroup = 'Senior', leagueId = 'l6ab63b8dddb11', leagueName = 'AFCON 2027 PAMOJA QUALIFIERS - GROUP B', groupName = 'GROUP B' WHERE id = 't179034682757713'")->execute();

    // 2. Fix the played match m6ab65b382c409 (MALAWI vs SOUTH SUDAN, 2-1 FT)
    // Update homeTeamId to Senior (t179034682757713) and set group to GROUP B
    $pdo->prepare("UPDATE matches SET homeTeamId = 't179034682757713', homeTeamName = 'MALAWI', groupName = 'GROUP B', leagueId = 'l6ab63b8dddb11' WHERE id = 'm6ab65b382c409'")->execute();

    // 3. Move any lineup recorded for the duplicate m6ab687cdb0a39 to m6ab65b382c409
    $stmt = $pdo->prepare("SELECT playerIds, formation FROM team_lineups WHERE matchId = 'm6ab687cdb0a39'");
    $stmt->execute();
    $lRow = $stmt->fetch();
    if ($lRow) {
        $pdo->prepare("REPLACE INTO team_lineups (id, teamId, matchId, playerIds, formation) VALUES (?, ?, ?, ?, ?)")
            ->execute(['tl_m6ab65b382c409_home', 't179034682757713', 'm6ab65b382c409', $lRow['playerIds'], $lRow['formation'] ?: '4-4-2']);
    }
    // Also ensure default lineup for t179034682757713 exists with matchId IS NULL
    $chkDef = $pdo->prepare("SELECT id FROM team_lineups WHERE teamId = 't179034682757713' AND matchId IS NULL LIMIT 1");
    $chkDef->execute();
    if (!$chkDef->fetchColumn() && $lRow) {
        $pdo->prepare("INSERT INTO team_lineups (id, teamId, matchId, playerIds, formation) VALUES (?, ?, NULL, ?, ?)")
            ->execute(['tl_t179034682757713_def', 't179034682757713', $lRow['playerIds'], $lRow['formation'] ?: '4-4-2']);
    }

    // 4. Delete the duplicate unplayed fixture m6ab687cdb0a39
    $pdo->prepare("DELETE FROM team_lineups WHERE matchId = 'm6ab687cdb0a39'")->execute();
    $pdo->prepare("DELETE FROM match_events WHERE matchId = 'm6ab687cdb0a39'")->execute();
    $pdo->prepare("DELETE FROM matches WHERE id = 'm6ab687cdb0a39'")->execute();

    // 5. Clean up duplicate AFCON fixtures that used the old U-20 team ID
    $pdo->prepare("DELETE FROM matches WHERE id = 'm6ab647f5a7bd0'")->execute();
    $pdo->prepare("DELETE FROM matches WHERE id = 'm6ab64afd3aa7c'")->execute();
    $pdo->prepare("DELETE FROM matches WHERE id = 'm6ab649c500dee'")->execute();
    $pdo->prepare("UPDATE matches SET awayTeamId = 't179034682757713' WHERE id = 'm6ab64a4a4f306'")->execute();

    // 6. Ensure team_competitions has Senior Malawi in AFCON 2027
    $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt) VALUES (?, ?, ?, 'participant', NOW())")
        ->execute(['tc_t179034682757713_l6ab63b8dddb11', 't179034682757713', 'l6ab63b8dddb11']);

    echo json_encode([
        'ok' => true,
        'message' => 'Malawi teams, played match m6ab65b382c409, lineups, and fixtures reconciled successfully'
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => $e->getMessage()]);
}
