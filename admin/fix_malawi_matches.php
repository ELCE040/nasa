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

    // 7. Fix AFCON 2027 league format from 'knockout' to 'group_knockout'
    $pdo->prepare("UPDATE leagues SET format = 'group_knockout' WHERE id = 'l6ab63b8dddb11'")->execute();

    // 8. Remove ghost teams from NBM Women's team_competitions.
    // 8. RESTORE all legitimate NBM Women's teams.
    // FCB Nyasa Big Bullets Women (t178785289061) and Kukoma Ntopwa Women (t178782255775)
    // have real played NBM Women matches and ARE legitimate members — they were wrongly removed.
    // Mighty Wanderers Queens (t178782266496) and Chilomoni Ladies (t178785302088)
    // have upcoming NBM Women fixtures and should also appear in the standings at 0pts.
    $restoreTeams = [
        't178782255775',   // Kukoma Ntopwa Women
        't178785289061',   // FCB Nyasa Big Bullets Women
        't178782266496',   // Mighty Wanderers Queens
        't178785302088',   // Chilomoni Ladies
    ];
    foreach ($restoreTeams as $tid) {
        // Re-enrol in team_competitions
        $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
            VALUES (CONCAT('tc_', ?, '_l6aae2aeb1789f'), ?, 'l6aae2aeb1789f', 'participant', NOW())")
            ->execute([$tid, $tid]);
    }
    // Un-hide any upcoming fixtures that were wrongly made private
    $pdo->prepare("UPDATE matches SET isPrivate = 0 WHERE leagueId = 'l6aae2aeb1789f' AND status = 'upcoming' AND (
        homeTeamId IN ('t178782255775','t178785289061','t178782266496','t178785302088') OR
        awayTeamId IN ('t178782255775','t178785289061','t178782266496','t178785302088')
    )")->execute();

    // 9. Clear phantom stored stats for ASCENT SOCCER ACADEMY (t6ab021f30b022).
    // Someone manually set played=1,won=1,goalsFor=1 in the teams table even though
    // it has zero real fullTime matches — making it appear as a duplicate of FACT LADIES.
    // The admin falls back to stored stats when no match data exists.
    $pdo->prepare("UPDATE teams SET played=0, won=0, drawn=0, lost=0, goalsFor=0, goalsAgainst=0 WHERE id='t6ab021f30b022'")->execute();

    // 10. MERGE ASCENT ACADEMY (t178979957206928) into ASCENT SOCCER ACADEMY (t6ab021f30b022)
    // They are the same club. Reassign the 1-1 match vs MDF LIONESS to the correct team ID.
    $pdo->prepare("UPDATE matches SET homeTeamId='t6ab021f30b022', homeTeamName='ASCENT SOCCER ACADEMY' WHERE homeTeamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE matches SET awayTeamId='t6ab021f30b022', awayTeamName='ASCENT SOCCER ACADEMY' WHERE awayTeamId='t178979957206928'")->execute();
    // Move any players, lineups, events
    $pdo->prepare("UPDATE players SET teamId='t6ab021f30b022', teamName='ASCENT SOCCER ACADEMY' WHERE teamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE team_lineups SET teamId='t6ab021f30b022' WHERE teamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE match_events SET teamName='ASCENT SOCCER ACADEMY' WHERE teamName='ASCENT ACADEMY'")->execute();
    // Remove from team_competitions and delete duplicate team record
    $pdo->prepare("DELETE FROM team_competitions WHERE teamId='t178979957206928'")->execute();
    $pdo->prepare("DELETE FROM teams WHERE id='t178979957206928'")->execute();

    echo json_encode([
        'ok' => true,
        'message' => 'All fixes applied: Malawi, AFCON format, lineups, NBM ghost teams, ASCENT ACADEMY merged into ASCENT SOCCER ACADEMY.'
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => $e->getMessage()]);
}
