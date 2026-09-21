<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Duplicate Cleanup';
$pdo = db();

function duplicateGroups(PDO $pdo, string $table, string $teamScope = ''): array {
    $columns = $table === 'players' ? 'id,name,teamId' : 'id,name';
    $scope = $teamScope === '' ? '' : ' WHERE teamId <=> '. $pdo->quote($teamScope);
    $stmt = $pdo->query("SELECT {$columns} FROM {$table}{$scope} ORDER BY name,id");
    $groups = [];
    foreach ($stmt->fetchAll() as $row) {
        $key = mb_strtolower(trim((string)$row['name']));
        if ($table === 'players') $key = (string)($row['teamId'] ?? '') . ':' . $key;
        if ($key === '') continue;
        $groups[$key][] = $row;
    }
    return array_filter($groups, fn($rows) => count($rows) > 1);
}

function possiblePlayerDuplicates(PDO $pdo): array {
    $rows = $pdo->query('SELECT id,name,teamId FROM players WHERE name IS NOT NULL AND TRIM(name)<>"" ORDER BY teamId,name,id')->fetchAll();
    $possible = [];
    for ($i = 0; $i < count($rows); $i++) {
        for ($j = $i + 1; $j < count($rows); $j++) {
            if ($rows[$i]['teamId'] !== $rows[$j]['teamId']) continue;
            $left = preg_replace('/[^a-z0-9]/', '', mb_strtolower(trim($rows[$i]['name'])));
            $right = preg_replace('/[^a-z0-9]/', '', mb_strtolower(trim($rows[$j]['name'])));
            if ($left === $right || levenshtein($left, $right) > 1) continue;
            $possible[] = [$rows[$i], $rows[$j]];
        }
    }
    return $possible;
}

function mergeTeamInto(PDO $pdo, string $keepId, string $removeId): void {
    $get = $pdo->prepare('SELECT id,name FROM teams WHERE id IN (?,?)');
    $get->execute([$keepId, $removeId]);
    $teams = $get->fetchAll();
    if (count($teams) !== 2) throw new RuntimeException('Team record not found.');
    $names = array_column($teams, 'name', 'id');
    $pdo->prepare('UPDATE players SET teamId=?, teamName=? WHERE teamId=?')->execute([$keepId, $names[$keepId], $removeId]);
    $pdo->prepare('UPDATE matches SET homeTeamId=?, homeTeamName=? WHERE homeTeamId=?')->execute([$keepId, $names[$keepId], $removeId]);
    $pdo->prepare('UPDATE matches SET awayTeamId=?, awayTeamName=? WHERE awayTeamId=?')->execute([$keepId, $names[$keepId], $removeId]);
    $pdo->prepare('UPDATE match_events SET teamName=? WHERE teamName=?')->execute([$names[$keepId], $names[$removeId]]);
    $pdo->prepare('INSERT IGNORE INTO team_competitions (id,teamId,leagueId,competitionRole,enrolledAt)
        SELECT CONCAT("tc_", ?, "_", leagueId), ?, leagueId, competitionRole, enrolledAt FROM team_competitions WHERE teamId=?')
        ->execute([$keepId, $keepId, $removeId]);
    $pdo->prepare('DELETE FROM team_competitions WHERE teamId=?')->execute([$removeId]);
    $pdo->prepare('INSERT IGNORE INTO team_squad_members (id,teamId,playerId,jerseyNumber,isNationalTeam,status,callupDate)
        SELECT CONCAT("sm_", ?, "_", playerId), ?, playerId, jerseyNumber, isNationalTeam, status, callupDate FROM team_squad_members WHERE teamId=?')
        ->execute([$keepId, $keepId, $removeId]);
    $pdo->prepare('DELETE FROM team_squad_members WHERE teamId=?')->execute([$removeId]);
    $pdo->prepare('DELETE FROM teams WHERE id=?')->execute([$removeId]);
}

function mergePlayerInto(PDO $pdo, string $keepId, string $removeId): void {
    $get = $pdo->prepare('SELECT id,name,teamId FROM players WHERE id IN (?,?)');
    $get->execute([$keepId, $removeId]);
    $players = $get->fetchAll();
    if (count($players) !== 2 || $players[0]['teamId'] !== $players[1]['teamId']) {
        throw new RuntimeException('Duplicate players must belong to the same team.');
    }
    $names = array_column($players, 'name', 'id');
    $teamStmt = $pdo->prepare('SELECT name FROM teams WHERE id=?');
    $teamStmt->execute([$players[0]['teamId']]);
    $teamName = $teamStmt->fetchColumn();
    $pdo->prepare('UPDATE match_events SET playerName=? WHERE playerName=? AND teamName=?')
        ->execute([$names[$keepId], $names[$removeId], $teamName]);
    $pdo->prepare('UPDATE matches SET playerOfMatchId=?, playerOfMatchName=? WHERE playerOfMatchId=?')
        ->execute([$keepId, $names[$keepId], $removeId]);
    $pdo->prepare('UPDATE players p JOIN players d ON d.id=? SET p.goals=GREATEST(p.goals,d.goals), p.assists=GREATEST(p.assists,d.assists), p.appearances=GREATEST(p.appearances,d.appearances), p.cleanSheets=GREATEST(p.cleanSheets,d.cleanSheets), p.yellowCards=GREATEST(p.yellowCards,d.yellowCards), p.redCards=GREATEST(p.redCards,d.redCards) WHERE p.id=?')
        ->execute([$removeId, $keepId]);
    $pdo->prepare('DELETE FROM team_squad_members WHERE playerId=?')->execute([$removeId]);
    $pdo->prepare('DELETE FROM players WHERE id=?')->execute([$removeId]);
}

function mergeAllDuplicates(PDO $pdo): array {
    $merged = ['teams' => 0, 'players' => 0];
    $pdo->beginTransaction();
    try {
        foreach (duplicateGroups($pdo, 'teams') as $rows) {
            $keepId = $rows[0]['id'];
            for ($i = 1; $i < count($rows); $i++) {
                mergeTeamInto($pdo, $keepId, $rows[$i]['id']);
                $merged['teams']++;
            }
        }
        foreach (duplicateGroups($pdo, 'players') as $rows) {
            $keepId = $rows[0]['id'];
            for ($i = 1; $i < count($rows); $i++) {
                mergePlayerInto($pdo, $keepId, $rows[$i]['id']);
                $merged['players']++;
            }
        }
        $pdo->commit();
    } catch (Throwable $error) {
        $pdo->rollBack();
        throw $error;
    }
    return $merged;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (($_POST['type'] ?? '') === 'merge_all') {
        try {
            $merged = mergeAllDuplicates($pdo);
            flash('success', "Automatically merged {$merged['teams']} duplicate team(s) and {$merged['players']} duplicate player(s).");
        } catch (Throwable $error) {
            flash('error', 'Automatic merge failed: '.$error->getMessage());
        }
        header('Location: duplicates.php'); exit;
    }
    $type = $_POST['type'] ?? '';
    $keepId = trim($_POST['keepId'] ?? '');
    $removeId = trim($_POST['removeId'] ?? '');
    if (!$keepId || !$removeId || $keepId === $removeId) {
        flash('error', 'Choose two different records.');
        header('Location: duplicates.php'); exit;
    }

    try {
        $pdo->beginTransaction();
        if ($type === 'team') {
            $get = $pdo->prepare('SELECT id,name FROM teams WHERE id IN (?,?)');
            $get->execute([$keepId, $removeId]);
            $teams = $get->fetchAll();
            if (count($teams) !== 2) throw new RuntimeException('Team record not found.');
            $names = array_column($teams, 'name', 'id');

            $pdo->prepare('UPDATE players SET teamId=?, teamName=? WHERE teamId=?')->execute([$keepId, $names[$keepId], $removeId]);
            $pdo->prepare('UPDATE matches SET homeTeamId=?, homeTeamName=? WHERE homeTeamId=?')->execute([$keepId, $names[$keepId], $removeId]);
            $pdo->prepare('UPDATE matches SET awayTeamId=?, awayTeamName=? WHERE awayTeamId=?')->execute([$keepId, $names[$keepId], $removeId]);
            $pdo->prepare('UPDATE match_events SET teamName=? WHERE teamName=?')->execute([$names[$keepId], $names[$removeId]]);
            $pdo->prepare('INSERT IGNORE INTO team_competitions (id,teamId,leagueId,competitionRole,enrolledAt)
                SELECT CONCAT("tc_", ?, "_", leagueId), ?, leagueId, competitionRole, enrolledAt FROM team_competitions WHERE teamId=?')
                ->execute([$keepId, $keepId, $removeId]);
            $pdo->prepare('DELETE FROM team_competitions WHERE teamId=?')->execute([$removeId]);
            $pdo->prepare('INSERT IGNORE INTO team_squad_members (id,teamId,playerId,jerseyNumber,isNationalTeam,status,callupDate)
                SELECT CONCAT("sm_", ?, "_", playerId), ?, playerId, jerseyNumber, isNationalTeam, status, callupDate FROM team_squad_members WHERE teamId=?')
                ->execute([$keepId, $keepId, $removeId]);
            $pdo->prepare('DELETE FROM team_squad_members WHERE teamId=?')->execute([$removeId]);
            $pdo->prepare('DELETE FROM teams WHERE id=?')->execute([$removeId]);
            flash('success', 'Team merged successfully.');
        } elseif ($type === 'player') {
            $get = $pdo->prepare('SELECT id,name,teamId FROM players WHERE id IN (?,?)');
            $get->execute([$keepId, $removeId]);
            $players = $get->fetchAll();
            if (count($players) !== 2) throw new RuntimeException('Player record not found.');
            $names = array_column($players, 'name', 'id');
            if ($players[0]['teamId'] !== $players[1]['teamId']) {
                throw new RuntimeException('Players must belong to the same team to merge.');
            }
            $teamStmt = $pdo->prepare('SELECT name FROM teams WHERE id=?');
            $teamStmt->execute([$players[0]['teamId']]);
            $playerTeamName = $teamStmt->fetchColumn();
            $pdo->prepare('UPDATE match_events SET playerName=? WHERE playerName=? AND teamName=?')
                ->execute([$names[$keepId], $names[$removeId], $playerTeamName]);
            $pdo->prepare('UPDATE matches SET playerOfMatchId=?, playerOfMatchName=? WHERE playerOfMatchId=?')
                ->execute([$keepId, $names[$keepId], $removeId]);
            $pdo->prepare('UPDATE players p JOIN players d ON d.id=? SET p.goals=GREATEST(p.goals,d.goals), p.assists=GREATEST(p.assists,d.assists), p.appearances=GREATEST(p.appearances,d.appearances), p.cleanSheets=GREATEST(p.cleanSheets,d.cleanSheets), p.yellowCards=GREATEST(p.yellowCards,d.yellowCards), p.redCards=GREATEST(p.redCards,d.redCards) WHERE p.id=?')
                ->execute([$removeId, $keepId]);
            $pdo->prepare('DELETE FROM team_squad_members WHERE playerId=?')->execute([$removeId]);
            $pdo->prepare('DELETE FROM players WHERE id=?')->execute([$removeId]);
            flash('success', 'Player merged successfully.');
        } else {
            throw new RuntimeException('Unknown duplicate type.');
        }
        $pdo->commit();
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        flash('error', 'Merge failed: '.$error->getMessage());
    }
    header('Location: duplicates.php'); exit;
}

$autoMergeResult = ['teams' => 0, 'players' => 0];
try {
    $autoMergeResult = mergeAllDuplicates($pdo);
    if ($autoMergeResult['teams'] || $autoMergeResult['players']) {
        flash('success', "Automatically merged {$autoMergeResult['teams']} duplicate team(s) and {$autoMergeResult['players']} duplicate player(s).");
    }
} catch (Throwable $error) {
    flash('error', 'Automatic duplicate merge failed: '.$error->getMessage());
}
$teamDuplicates = duplicateGroups($pdo, 'teams');
$playerDuplicates = duplicateGroups($pdo, 'players');
$possiblePlayerDuplicates = possiblePlayerDuplicates($pdo);
require __DIR__.'/header.php';
?>
<div class="section-header"><span class="section-title">Duplicate Cleanup</span><a href="teams.php" class="btn btn-outline btn-sm">Teams</a></div>
<p style="color:#8BA3B8;font-size:13px;margin-bottom:18px;">Duplicate teams and same-team players are merged automatically when this page loads. The oldest record is retained as the canonical record and related matches, events, registrations, and squad links are moved to it.</p>

<?php foreach ([['Teams', 'team', $teamDuplicates], ['Players', 'player', $playerDuplicates]] as [$label, $type, $groups]): ?>
<div class="card" style="margin-bottom:20px;"><h3 style="color:#D2B059;margin-top:0;"><?= e($label) ?></h3>
<?php if (!$groups): ?><p style="color:#8BA3B8;">No duplicates found.</p><?php endif; ?>
<?php foreach ($groups as $rows): ?>
  <div style="border-top:1px solid #1A3A5C;padding:12px 0;">
    <strong style="color:#fff;"><?= e($rows[0]['name']) ?></strong>
    <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;">
    <?php foreach ($rows as $row): ?>
      <form method="post" style="display:inline;">
        <input type="hidden" name="type" value="<?= e($type) ?>"/>
        <input type="hidden" name="keepId" value="<?= e($row['id']) ?>"/>
        <?php foreach ($rows as $other): if ($other['id'] !== $row['id']): ?>
          <input type="hidden" name="removeId" value="<?= e($other['id']) ?>"/>
          <?php break; endif; endforeach; ?>
        <button class="btn btn-outline btn-sm" type="submit" onclick="return confirm('Keep this record and merge the other duplicate into it?')">Keep <?= e($row['id']) ?></button>
      </form>
    <?php endforeach; ?>
    </div>
  </div>
<?php endforeach; ?></div>
<?php endforeach; ?>
<?php if ($possiblePlayerDuplicates): ?>
<div class="card" style="margin-bottom:20px;"><h3 style="color:#fbbf24;margin-top:0;">Possible Player Name Variants</h3>
<p style="color:#8BA3B8;font-size:13px;">These names are nearly identical within the same team. Confirm before merging; the system does not merge spelling variants automatically.</p>
<?php foreach ($possiblePlayerDuplicates as [$left, $right]): ?>
    <div style="border-top:1px solid #1A3A5C;padding:12px 0;display:flex;align-items:center;gap:10px;flex-wrap:wrap;">
        <strong style="color:#fff;"><?= e($left['name']) ?> / <?= e($right['name']) ?></strong>
        <form method="post" style="display:inline;">
            <input type="hidden" name="type" value="player"/>
            <input type="hidden" name="keepId" value="<?= e($left['id']) ?>"/>
            <input type="hidden" name="removeId" value="<?= e($right['id']) ?>"/>
            <button class="btn btn-outline btn-sm" type="submit" onclick="return confirm('Merge these possible duplicate players?')">Merge</button>
        </form>
    </div>
<?php endforeach; ?></div>
<?php endif; ?>
<?php require __DIR__.'/footer.php'; ?>
