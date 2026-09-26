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

    // 8. SET UP EXACT 8 TEAMS IN BLANTYRE CITY MAYOR'S BONANZA (l6a8ffc42d148f)
    $bonanzaTeams = [
        't178782255775', // Kukoma Ntopwa Women
        't178782266496', // Mighty Wanderers Queens
        't178785289061', // FCB Nyasa Big Bullets Women
        't178785312792', // Ekhaya Women fc
        't178785321184', // Emmanuel Bullets
        't178782260336', // Bangwe All Stars
        't178785302088', // Chilomoni Ladies
        't178782270244', // Kaso Ladies
    ];
    foreach ($bonanzaTeams as $tid) {
        $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
            VALUES (CONCAT('tc_', ?, '_l6a8ffc42d148f'), ?, 'l6a8ffc42d148f', 'participant', NOW())")
            ->execute([$tid, $tid]);
    }

    // 9. SET UP EXACT 10 TEAMS IN NBM WOMEN'S PREMIERSHIP (l6aae2aeb1789f) per official FAM graphic
    $nbm10Teams = [
        't178979951893354', // SILVER STRIKERS LADIES
        't6ab021f30b022',   // ASCENT SOCCER ACADEMY
        't178979963519413', // MDF LIONESS
        't178980138285462', // CIVIL SERVICE WOMEN
        't178785289061',   // FCB NYASA BIG BULLETS WOMEN
        't178979972929356', // FACT LADIES
        't178782255775',   // KUKOMA NTOPWA WOMEN
        't178979943341474', // CHITOLIRO HEROINES
        't178782266496',   // MIGHTY WANDERERS QUEENS
        't178979978087791', // RUMPHI SISTERS
    ];
    // Remove all others from NBM Women enrollment (e.g. Chilomoni Ladies)
    $inClause = "'" . implode("','", $nbm10Teams) . "'";
    $pdo->prepare("DELETE FROM team_competitions WHERE leagueId='l6aae2aeb1789f' AND teamId NOT IN ($inClause)")->execute();
    foreach ($nbm10Teams as $tid) {
        $pdo->prepare("INSERT IGNORE INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
            VALUES (CONCAT('tc_', ?, '_l6aae2aeb1789f'), ?, 'l6aae2aeb1789f', 'participant', NOW())")
            ->execute([$tid, $tid]);
    }
    // Delete mistaken NBM fixture involving Chilomoni Ladies
    $pdo->prepare("DELETE FROM matches WHERE leagueId='l6aae2aeb1789f' AND (homeTeamId='t178785302088' OR awayTeamId='t178785302088')")->execute();

    // 10. MERGE MIGHTY WANDERERS LADIES (t178980095565354) into MIGHTY WANDERERS QUEENS (t178782266496)
    $pdo->prepare("UPDATE matches SET homeTeamId='t178782266496', homeTeamName='MIGHTY WANDERERS QUEENS' WHERE homeTeamId='t178980095565354'")->execute();
    $pdo->prepare("UPDATE matches SET awayTeamId='t178782266496', awayTeamName='MIGHTY WANDERERS QUEENS' WHERE awayTeamId='t178980095565354'")->execute();
    $pdo->prepare("UPDATE players SET teamId='t178782266496', teamName='MIGHTY WANDERERS QUEENS' WHERE teamId='t178980095565354'")->execute();
    $pdo->prepare("UPDATE team_lineups SET teamId='t178782266496' WHERE teamId='t178980095565354'")->execute();
    $pdo->prepare("UPDATE match_events SET teamName='MIGHTY WANDERERS QUEENS' WHERE teamName='MIGHTY WANDERERS LADIES'")->execute();
    $pdo->prepare("UPDATE teams SET name='MIGHTY WANDERERS QUEENS' WHERE id='t178782266496'")->execute();
    $pdo->prepare("DELETE FROM team_competitions WHERE teamId='t178980095565354'")->execute();
    $pdo->prepare("DELETE FROM teams WHERE id='t178980095565354'")->execute();

    // 11. MERGE ASCENT ACADEMY (t178979957206928) into ASCENT SOCCER ACADEMY (t6ab021f30b022)
    $pdo->prepare("UPDATE matches SET homeTeamId='t6ab021f30b022', homeTeamName='ASCENT SOCCER ACADEMY' WHERE homeTeamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE matches SET awayTeamId='t6ab021f30b022', awayTeamName='ASCENT SOCCER ACADEMY' WHERE awayTeamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE players SET teamId='t6ab021f30b022', teamName='ASCENT SOCCER ACADEMY' WHERE teamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE team_lineups SET teamId='t6ab021f30b022' WHERE teamId='t178979957206928'")->execute();
    $pdo->prepare("UPDATE match_events SET teamName='ASCENT SOCCER ACADEMY' WHERE teamName='ASCENT ACADEMY'")->execute();
    $pdo->prepare("DELETE FROM team_competitions WHERE teamId='t178979957206928'")->execute();
    $pdo->prepare("DELETE FROM teams WHERE id='t178979957206928'")->execute();

    // 12. RECORD ASCENT SOCCER ACADEMY 5 - 1 RUMPHI SISTERS (Match m6ab56b29c14f9)
    // Per official FAM Week 2 graphic: Ascent has P:2 GF:6 GA:2 Pts:4; Rumphi has P:2 GF:1 GA:6 Pts:0
    $pdo->prepare("UPDATE matches SET status='fullTime', homeScore=5, awayScore=1, homeTeamId='t6ab021f30b022', homeTeamName='ASCENT SOCCER ACADEMY', awayTeamId='t178979978087791', awayTeamName='RUMPHI SISTERS' WHERE id='m6ab56b29c14f9'")->execute();

    // 13. CLEAR STORED PHANTOM STATS ON TEAMS TABLE
    $pdo->prepare("UPDATE teams SET played=0, won=0, drawn=0, lost=0, goalsFor=0, goalsAgainst=0 WHERE leagueId='l6aae2aeb1789f' OR id IN ($inClause)")->execute();

    echo json_encode([
        'ok' => true,
        'message' => 'All fixes applied: Mayor Bonanza 8 teams intact, NBM Women exact 10 teams per FAM graphic, Ascent 5-1 Rumphi recorded, duplicates merged.'
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => $e->getMessage()]);
}
