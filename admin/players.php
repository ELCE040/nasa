<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Players';
$pdo = db();
// Existing installations pre-date profile-stat corrections. Upgrade the
// column here too, so saving a correction works as soon as this admin page is
// deployed (without waiting for the API process to restart).
$manualOverrideColumn = $pdo->query("SHOW COLUMNS FROM players LIKE 'statsManualOverride'")->fetch();
if (!$manualOverrideColumn) {
    $pdo->exec('ALTER TABLE players ADD COLUMN statsManualOverride TINYINT(1) NOT NULL DEFAULT 0');
}
$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    if ($op==='create') {
        $nid = 'p'.uniqid();
        $teamId = trim($_POST['teamId'] ?? '');
      $duplicatePlayer = $pdo->prepare('SELECT id FROM players WHERE teamId <=> ? AND LOWER(TRIM(name))=LOWER(TRIM(?)) LIMIT 1');
      $duplicatePlayer->execute([$teamId ?: null, $_POST['name']]);
      if ($duplicatePlayer->fetch()) {
        flash('error', 'This team already has a player with that name.');
        header('Location: players.php?action=add'); exit;
      }
        $clubStatus = $teamId ? 'club' : 'unattached';
        $teamRow = null;
        if ($teamId) {
            $teamRow = $pdo->prepare('SELECT name,wardName FROM teams WHERE id=?');
            $teamRow->execute([$teamId]); $teamRow = $teamRow->fetch();
        }
        $pdo->prepare('INSERT INTO players (id,name,age,position,teamId,teamName,wardName,jerseyNumber,preferredFoot,heightM,bio,parentPhone,clubStatus) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)')
            ->execute([$nid,$_POST['name'],$_POST['age'],$_POST['position'],
                       $teamId ?: null,
                       $teamRow['name'] ?? '',
                       $teamRow['wardName'] ?? '',
                       $_POST['jerseyNumber'],$_POST['preferredFoot'],
                       $_POST['heightM'],$_POST['bio'],$_POST['parentPhone'],
                       $clubStatus]);
        // Auto-add to squad_members for their primary team
        if ($teamId) {
            try {
                $pdo->prepare("INSERT IGNORE INTO team_squad_members (id,teamId,playerId,jerseyNumber,callupDate)
                    VALUES (?,?,?,?,NOW())")
                    ->execute(['sm_'.$teamId.'_'.$nid, $teamId, $nid, (int)($_POST['jerseyNumber']??0)]);
            } catch (Throwable $e) {}
        }
        flash('success','Player registered!');
        header('Location: players.php'); exit;
    }
    if ($op==='update') {
        $teamId = trim($_POST['teamId'] ?? '');
      $duplicatePlayer = $pdo->prepare('SELECT id FROM players WHERE teamId <=> ? AND LOWER(TRIM(name))=LOWER(TRIM(?)) AND id<>? LIMIT 1');
      $duplicatePlayer->execute([$teamId ?: null, $_POST['name'], $_POST['id']]);
      if ($duplicatePlayer->fetch()) {
        flash('error', 'This team already has a player with that name.');
        header('Location: players.php?action=edit&id='.urlencode($_POST['id'])); exit;
      }
        $teamRow = null;
        if ($teamId) {
            $teamRow = $pdo->prepare('SELECT name,wardName FROM teams WHERE id=?');
            $teamRow->execute([$teamId]); $teamRow = $teamRow->fetch();
        }
        $pdo->prepare('UPDATE players SET name=?,age=?,position=?,teamId=?,teamName=?,wardName=?,jerseyNumber=?,preferredFoot=?,heightM=?,bio=?,parentPhone=?,goals=?,assists=?,appearances=?,cleanSheets=?,yellowCards=?,redCards=?,statsManualOverride=1 WHERE id=?')
            ->execute([$_POST['name'],$_POST['age'],$_POST['position'],
                       $teamId ?: null,
                       $teamRow['name']??'',$teamRow['wardName']??'',$_POST['jerseyNumber'],
                       $_POST['preferredFoot'],$_POST['heightM'],$_POST['bio'],$_POST['parentPhone'],
                       max(0,(int)($_POST['goals']??0)),max(0,(int)($_POST['assists']??0)),max(0,(int)($_POST['appearances']??0)),
                       max(0,(int)($_POST['cleanSheets']??0)),max(0,(int)($_POST['yellowCards']??0)),max(0,(int)($_POST['redCards']??0)),
                       $_POST['id']]);
        flash('success','Player updated!');
        header('Location: players.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM players WHERE id=?')->execute([$_POST['id']]);
        flash('success','Player deleted.');
        header('Location: players.php'); exit;
    }

    // ── Add player to a squad (National Team callup / secondary squad) ─────────
    if ($op === 'squad_add') {
        $playerId  = trim($_POST['squad_playerId']  ?? '');
        $teamId    = trim($_POST['squad_teamId']    ?? '');
        $jerseyNo  = (int)($_POST['squad_jersey']   ?? 0);
        $isNat     = (int)($_POST['squad_national'] ?? 0);
        if ($playerId && $teamId) {
            $smId = 'sm_'.$teamId.'_'.$playerId;
            try {
                $pdo->prepare("INSERT INTO team_squad_members (id,teamId,playerId,jerseyNumber,isNationalTeam,status,callupDate)
                    VALUES (?,?,?,?,?,'active',NOW())
                    ON DUPLICATE KEY UPDATE jerseyNumber=VALUES(jerseyNumber),isNationalTeam=VALUES(isNationalTeam),status='active'")
                    ->execute([$smId, $teamId, $playerId, $jerseyNo ?: null, $isNat]);
                flash('success','Player added to squad.');
            } catch (Throwable $e) { flash('error','Could not add player: '.$e->getMessage()); }
        } else { flash('error','Select both a player and a squad/team.'); }
        header('Location: players.php?action=edit&id='.urlencode($playerId)); exit;
    }

    // ── Remove player from a secondary squad ──────────────────────────────────
    if ($op === 'squad_remove') {
        $playerId = trim($_POST['sq_playerId'] ?? '');
        $teamId   = trim($_POST['sq_teamId']   ?? '');
        if ($playerId && $teamId) {
            $pdo->prepare("DELETE FROM team_squad_members WHERE teamId=? AND playerId=?")
                ->execute([$teamId, $playerId]);
            flash('success','Player removed from squad.');
        }
        header('Location: players.php?action=edit&id='.urlencode($playerId)); exit;
    }
}

$teams = $pdo->query('SELECT id,name FROM teams ORDER BY name')->fetchAll();
$positions = ['Goalkeeper','Defender','Midfielder','Winger','Forward','Striker'];
$feet = ['Right','Left','Both'];
$sort = $_GET['sort'] ?? 'name';
$direction = strtolower($_GET['dir'] ?? 'asc') === 'desc' ? 'DESC' : 'ASC';
$sortColumns = [
    'name' => 'p.name', 'team' => 'p.teamName', 'apps' => 'actualAppearances',
    'goals' => 'actualGoals', 'assists' => 'actualAssists', 'yellow' => 'actualYellowCards', 'red' => 'actualRedCards',
];
$orderBy = $sortColumns[$sort] ?? $sortColumns['name'];
function statSortLink($key, $label, $sort, $direction) {
  $nextDirection = $sort === $key && $direction === 'ASC' ? 'desc' : 'asc';
  $arrow = $sort === $key ? ($direction === 'ASC' ? ' ↑' : ' ↓') : '';
  return '<a href="players.php?sort='.e($key).'&dir='.$nextDirection.'" style="color:inherit;text-decoration:none">'.$label.$arrow.'</a>';
}

if ($action==='edit' && $id) {
    $player = $pdo->prepare('SELECT * FROM players WHERE id=?');
    $player->execute([$id]);
    $player = $player->fetch();
    if ($player) {
        // Populate the correction form from real, recorded match data.
        // Shootout kicks are not normal goals and are intentionally excluded.
        $eventCount = function($type, $field) use ($pdo, $player) {
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM match_events e JOIN matches m ON m.id=e.matchId
                WHERE m.status IN ('live','fullTime') AND m.leagueId IS NOT NULL AND m.leagueId<>''
                  AND e.type=? AND e.teamName=? AND LOWER(TRIM(e.$field))=LOWER(TRIM(?))");
            $stmt->execute([$type, $player['teamName'], $player['name']]);
            return (int)$stmt->fetchColumn();
        };
        $realStats = [
            'goals' => $eventCount('Goal', 'playerName'),
            'assists' => $eventCount('Goal', 'assistName'),
            'yellowCards' => $eventCount('Yellow Card', 'playerName'),
            'redCards' => $eventCount('Red Card', 'playerName'),
            'appearances' => 0,
            'cleanSheets' => 0,
        ];
        $appearanceStmt = $pdo->prepare("SELECT COUNT(DISTINCT m.id) FROM matches m
            WHERE m.status IN ('live','fullTime') AND m.leagueId IS NOT NULL AND m.leagueId<>''
              AND (m.homeTeamId=? OR m.awayTeamId=?) AND (
                EXISTS (SELECT 1 FROM team_lineups tl WHERE tl.teamId=? AND tl.matchId=m.id AND JSON_CONTAINS(tl.playerIds, JSON_QUOTE(?)))
                OR (NOT EXISTS (SELECT 1 FROM team_lineups fixtureTl WHERE fixtureTl.teamId=? AND fixtureTl.matchId=m.id)
                    AND EXISTS (SELECT 1 FROM team_lineups defaultTl WHERE defaultTl.teamId=? AND defaultTl.matchId IS NULL AND JSON_CONTAINS(defaultTl.playerIds, JSON_QUOTE(?))))
                OR EXISTS (SELECT 1 FROM match_events e WHERE e.matchId=m.id AND e.teamName=?
                    AND (LOWER(TRIM(e.playerName))=LOWER(TRIM(?)) OR LOWER(TRIM(e.assistName))=LOWER(TRIM(?))))
              )");
        $appearanceStmt->execute([$player['teamId'], $player['teamId'], $player['teamId'], $player['id'], $player['teamId'], $player['teamId'], $player['id'], $player['teamName'], $player['name'], $player['name']]);
        $realStats['appearances'] = (int)$appearanceStmt->fetchColumn();
        if (stripos($player['position'], 'goal') !== false || stripos($player['position'], 'gk') !== false) {
            $cleanSheetStmt = $pdo->prepare("SELECT COUNT(DISTINCT m.id) FROM matches m
                WHERE m.status='fullTime' AND m.leagueId IS NOT NULL AND m.leagueId<>''
                  AND ((m.homeTeamId=? AND m.awayScore=0) OR (m.awayTeamId=? AND m.homeScore=0))
                  AND (EXISTS (SELECT 1 FROM team_lineups tl WHERE tl.teamId=? AND (tl.matchId=m.id OR tl.matchId IS NULL) AND JSON_CONTAINS(tl.playerIds, JSON_QUOTE(?))))");
            $cleanSheetStmt->execute([$player['teamId'], $player['teamId'], $player['teamId'], $player['id']]);
            $realStats['cleanSheets'] = (int)$cleanSheetStmt->fetchColumn();
        }
        // Once an administrator saves a correction, show that saved value on
        // later edits instead of replacing it with the original event count.
        $hasLegacyCorrection = false;
        foreach (array_keys($realStats) as $stat) {
            if ((int)($player[$stat] ?? 0) !== 0 && (int)($player[$stat] ?? 0) !== $realStats[$stat]) {
                $hasLegacyCorrection = true;
                break;
            }
        }
        if ((int)($player['statsManualOverride'] ?? 0) === 1 || $hasLegacyCorrection) {
            foreach (array_keys($realStats) as $stat) {
                $realStats[$stat] = max(0, (int)($player[$stat] ?? 0));
            }
        }
    }
}

require __DIR__.'/header.php';
?>
<?php if ($action==='add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Register New Player</span><a href="players.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Full Name *</label><input name="name" required/></div>
      <div class="form-group"><label>Primary Club (Optional)</label>
        <select name="teamId">
          <option value="">(None / Unattached / National Team Only)</option>
          <?php foreach($teams as $t): ?><option value="<?= e($t['id']) ?>"><?= e($t['name']) ?></option><?php endforeach; ?>
        </select>
        <small style="color:#8BA3B8">National team players without registered clubs stay unattached until linked later.</small>
      </div>
      <div class="form-group"><label>Age</label><input type="number" name="age" min="8" max="25" value="16"/></div>
      <div class="form-group"><label>Position</label>
        <select name="position">
          <?php foreach($positions as $p): ?><option><?= $p ?></option><?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Jersey #</label><input type="number" name="jerseyNumber" min="1" max="99"/></div>
      <div class="form-group"><label>Preferred Foot</label>
        <select name="preferredFoot"><?php foreach($feet as $f): ?><option><?= $f ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Height (m)</label><input type="number" step="0.01" name="heightM" value="1.70"/></div>
      <div class="form-group"><label>Parent Phone</label><input name="parentPhone" placeholder="+265 ..."/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Bio</label><textarea name="bio"></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">person_add</span>Register Player</button>
      <a href="players.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>

<?php elseif ($action==='edit' && isset($player)): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Edit — <?= e($player['name']) ?></span><a href="players.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($player['id']) ?>"/>
    <div class="form-grid">
      <div class="form-group"><label>Full Name</label><input name="name" value="<?= e($player['name']) ?>"/></div>
      <div class="form-group"><label>Primary Club</label>
        <select name="teamId">
          <option value="">(None / Unattached / National Team Only)</option>
          <?php foreach($teams as $t): ?>
          <option value="<?= e($t['id']) ?>" <?= ($player['teamId']??'')===$t['id']?'selected':'' ?>><?= e($t['name']) ?></option>
          <?php endforeach; ?>
        </select>
        <small style="color:#8BA3B8">Assign to their club when registered.</small>
      </div>
      <div class="form-group"><label>Age</label><input type="number" name="age" value="<?= e($player['age']) ?>"/></div>
      <div class="form-group"><label>Position</label>
        <select name="position"><?php foreach($positions as $p): ?><option <?= $player['position']===$p?'selected':'' ?>><?= $p ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Jersey #</label><input type="number" name="jerseyNumber" value="<?= e($player['jerseyNumber']) ?>"/></div>
      <div class="form-group"><label>Preferred Foot</label>
        <select name="preferredFoot"><?php foreach($feet as $f): ?><option <?= $player['preferredFoot']===$f?'selected':'' ?>><?= $f ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Height (m)</label><input type="number" step="0.01" name="heightM" value="<?= e($player['heightM']) ?>"/></div>
      <div class="form-group"><label>Parent Phone</label><input name="parentPhone" value="<?= e($player['parentPhone']) ?>"/></div>
      <div class="form-group" style="grid-column:1/-1"><label style="color:#D2B059">Player Profile Stats (recorded data / manual correction)</label><small style="color:#8BA3B8">These fields load the real recorded totals. Change them only to correct a mistake; also correct the matching event for league/cup leaderboards.</small></div>
      <div class="form-group"><label>Goals</label><input type="number" min="0" name="goals" value="<?= e($realStats['goals']??0) ?>"/></div>
      <div class="form-group"><label>Assists</label><input type="number" min="0" name="assists" value="<?= e($realStats['assists']??0) ?>"/></div>
      <div class="form-group"><label>Appearances</label><input type="number" min="0" name="appearances" value="<?= e($realStats['appearances']??0) ?>"/></div>
      <div class="form-group"><label>Clean Sheets</label><input type="number" min="0" name="cleanSheets" value="<?= e($realStats['cleanSheets']??0) ?>"/></div>
      <div class="form-group"><label>Yellow Cards</label><input type="number" min="0" name="yellowCards" value="<?= e($realStats['yellowCards']??0) ?>"/></div>
      <div class="form-group"><label>Red Cards</label><input type="number" min="0" name="redCards" value="<?= e($realStats['redCards']??0) ?>"/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Bio</label><textarea name="bio"><?= e($player['bio']) ?></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Save Changes</button>
      <a href="players.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>

<!-- ── Squad Memberships ─────────────────────────────────────────────── -->
<?php
$playerSquads = [];
try {
    $sqStmt = $pdo->prepare("SELECT sm.teamId, sm.jerseyNumber, sm.isNationalTeam, sm.status,
        t.name AS teamName, t.teamType, t.wardName
        FROM team_squad_members sm
        JOIN teams t ON t.id = sm.teamId
        WHERE sm.playerId = ?
        ORDER BY sm.isNationalTeam DESC, t.name ASC");
    $sqStmt->execute([$player['id']]);
    $playerSquads = $sqStmt->fetchAll();
} catch (Throwable $e) { $playerSquads = []; }

$squadTeamIds    = array_column($playerSquads, 'teamId');
$allTeamsForSquad = $pdo->query('SELECT id, name, teamType, wardName FROM teams WHERE (isExternal=0 OR isExternal IS NULL) ORDER BY name')->fetchAll();
$availableSquads = array_filter($allTeamsForSquad, fn($t) => !in_array($t['id'], $squadTeamIds, true));
?>
<div class="card">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;flex-wrap:wrap;gap:10px;">
    <span style="font-size:15px;font-weight:800;color:#D2B059;">🏅 Squad Memberships</span>
    <small style="color:#8BA3B8;">Primary club + National/Representative squad callups. Stats tracked per squad automatically.</small>
  </div>
  <?php if ($playerSquads): ?>
  <div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;">
    <?php foreach($playerSquads as $sq):
      $isNat     = (int)($sq['isNationalTeam'] ?? 0) === 1 || ($sq['teamType'] ?? '') === 'national';
      $isPrimary = ($sq['teamId'] ?? '') === ($player['teamId'] ?? '');
    ?>
    <div style="display:flex;align-items:center;gap:7px;background:rgba(255,255,255,.05);border:1px solid <?= $isNat ? '#D2B059' : '#1A3A5C' ?>;border-radius:8px;padding:7px 12px;">
      <span><?= $isNat ? '🌍' : ($isPrimary ? '🏠' : '🛡️') ?></span>
      <div>
        <div style="font-size:13px;font-weight:700;color:<?= $isNat ? '#D2B059' : '#fff' ?>;">
          <?= e($sq['teamName']) ?>
          <?php if ($isPrimary): ?><span style="font-size:10px;color:#4ade80;background:rgba(74,222,128,.1);padding:1px 5px;border-radius:3px;margin-left:4px;">Primary Club</span><?php endif; ?>
          <?php if ($isNat): ?><span style="font-size:10px;color:#D2B059;background:rgba(210,176,89,.1);padding:1px 5px;border-radius:3px;margin-left:4px;">Nat. Team</span><?php endif; ?>
        </div>
        <?php if (!empty($sq['jerseyNumber'])): ?><div style="font-size:11px;color:#8BA3B8;">Jersey #<?= e($sq['jerseyNumber']) ?></div><?php endif; ?>
      </div>
      <?php if (!$isPrimary): ?>
      <form method="post" style="display:inline;margin-left:4px;"
            onsubmit="return confirm('Remove from <?= e(addslashes($sq['teamName'])) ?>?')">
        <input type="hidden" name="op"          value="squad_remove"/>
        <input type="hidden" name="sq_playerId" value="<?= e($player['id']) ?>"/>
        <input type="hidden" name="sq_teamId"   value="<?= e($sq['teamId']) ?>"/>
        <button title="Remove from squad" style="background:none;border:none;color:#ef4444;cursor:pointer;padding:0;line-height:1;"><span class="material-icons-round" style="font-size:14px;">close</span></button>
      </form>
      <?php endif; ?>
    </div>
    <?php endforeach; ?>
  </div>
  <?php else: ?>
  <p style="color:#8BA3B8;font-size:13px;font-style:italic;margin-bottom:16px;">No additional squad memberships. Add below to call this player up to a National or representative team.</p>
  <?php endif; ?>

  <?php if ($availableSquads): ?>
  <form method="post" style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end;border-top:1px solid #1A3A5C;padding-top:14px;">
    <input type="hidden" name="op"             value="squad_add"/>
    <input type="hidden" name="squad_playerId" value="<?= e($player['id']) ?>"/>
    <div class="form-group" style="flex:2;min-width:200px;margin:0;">
      <label>Add to Squad / National Team</label>
      <select name="squad_teamId" id="squadTeamSel" required>
        <option value="">Select team…</option>
        <?php foreach ($availableSquads as $sq):
          $isNatOpt = ($sq['teamType'] ?? '') === 'national';
        ?>
        <option value="<?= e($sq['id']) ?>" data-nat="<?= $isNatOpt ? '1' : '0' ?>">
          <?= $isNatOpt ? '🌍 ' : '🛡️ ' ?><?= e($sq['name']) ?><?= !empty($sq['wardName']) ? ' ('.$sq['wardName'].')' : '' ?>
        </option>
        <?php endforeach; ?>
      </select>
    </div>
    <div class="form-group" style="flex:1;min-width:100px;margin:0;">
      <label>Jersey # (optional)</label>
      <input type="number" name="squad_jersey" min="1" max="99" placeholder="e.g. 10"/>
    </div>
    <div class="form-group" style="margin:0;display:flex;align-items:center;gap:6px;padding-top:20px;">
      <input type="checkbox" name="squad_national" value="1" id="squadNatChk"/>
      <label for="squadNatChk" style="font-size:12px;color:#D2B059;text-transform:none;letter-spacing:0;">National Team callup</label>
    </div>
    <button class="btn btn-gold" type="submit" style="margin-bottom:0;white-space:nowrap;">
      <span class="material-icons-round" style="font-size:16px;vertical-align:middle;">group_add</span>
      Add to Squad
    </button>
  </form>
  <script>
    document.getElementById('squadTeamSel').addEventListener('change',function(){
      document.getElementById('squadNatChk').checked = this.options[this.selectedIndex].dataset.nat==='1';
    });
  </script>
  <?php endif; ?>
</div>

<?php else: ?>
<div class="section-header">
  <span class="section-title">All Players (<?= $pdo->query('SELECT COUNT(*) FROM players')->fetchColumn() ?>)</span>
  <a href="players.php?action=add" class="btn btn-gold"><span class="material-icons-round">person_add</span>Add Player</a>
</div>
<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>#</th><th><?= statSortLink('name','Name',$sort,$direction) ?></th><th><?= statSortLink('team','Team',$sort,$direction) ?></th><th>Age</th><th>Position</th><th><?= statSortLink('apps','Apps',$sort,$direction) ?></th><th><?= statSortLink('goals','Goals',$sort,$direction) ?></th><th><?= statSortLink('assists','Assists',$sort,$direction) ?></th><th><?= statSortLink('yellow','YC',$sort,$direction) ?></th><th><?= statSortLink('red','RC',$sort,$direction) ?></th><th>Actions</th></tr></thead>
    <tbody>
    <?php
    $squadMap = [];
    try {
        $sqRows = $pdo->query("SELECT sm.playerId, t.name, sm.isNationalTeam FROM team_squad_members sm JOIN teams t ON t.id=sm.teamId")->fetchAll();
        foreach ($sqRows as $sq) {
            $squadMap[$sq['playerId']][] = $sq;
        }
    } catch (Throwable $e) {}

    $stmt = $pdo->query("SELECT p.*,
      (SELECT COUNT(*) FROM match_events e JOIN matches em ON em.id=e.matchId WHERE em.status IN ('live','fullTime') AND em.leagueId IS NOT NULL AND em.leagueId<>'' AND e.type='Goal' AND LOWER(TRIM(e.playerName))=LOWER(TRIM(p.name))) AS actualGoals,
      (SELECT COUNT(*) FROM match_events e JOIN matches em ON em.id=e.matchId WHERE em.status IN ('live','fullTime') AND em.leagueId IS NOT NULL AND em.leagueId<>'' AND e.type='Goal' AND LOWER(TRIM(e.assistName))=LOWER(TRIM(p.name))) AS actualAssists,
      (SELECT COUNT(*) FROM match_events e JOIN matches em ON em.id=e.matchId WHERE em.status IN ('live','fullTime') AND em.leagueId IS NOT NULL AND em.leagueId<>'' AND e.type='Yellow Card' AND LOWER(TRIM(e.playerName))=LOWER(TRIM(p.name))) AS actualYellowCards,
      (SELECT COUNT(*) FROM match_events e JOIN matches em ON em.id=e.matchId WHERE em.status IN ('live','fullTime') AND em.leagueId IS NOT NULL AND em.leagueId<>'' AND e.type='Red Card' AND LOWER(TRIM(e.playerName))=LOWER(TRIM(p.name))) AS actualRedCards,
      (SELECT COUNT(DISTINCT m.id) FROM matches m
         WHERE m.status IN ('live','fullTime') AND m.leagueId IS NOT NULL AND m.leagueId<>''
           AND ((p.teamId IS NOT NULL AND (m.homeTeamId=p.teamId OR m.awayTeamId=p.teamId))
             OR (EXISTS (SELECT 1 FROM team_squad_members tsm WHERE tsm.playerId=p.id AND (tsm.teamId=m.homeTeamId OR tsm.teamId=m.awayTeamId)))
             OR (EXISTS (SELECT 1 FROM team_lineups tl WHERE (tl.matchId=m.id OR tl.matchId IS NULL) AND JSON_CONTAINS(tl.playerIds, JSON_QUOTE(p.id))))
             OR EXISTS (SELECT 1 FROM match_events ae WHERE ae.matchId=m.id AND (LOWER(TRIM(ae.playerName))=LOWER(TRIM(p.name)) OR LOWER(TRIM(ae.assistName))=LOWER(TRIM(p.name)))))
       ) AS actualAppearances
      FROM players p");
    $players = $stmt->fetchAll();
    foreach ($players as &$row) {
      $actualStats = [
        'goals' => (int)($row['actualGoals'] ?? 0),
        'assists' => (int)($row['actualAssists'] ?? 0),
        'appearances' => (int)($row['actualAppearances'] ?? 0),
        'yellowCards' => (int)($row['actualYellowCards'] ?? 0),
        'redCards' => (int)($row['actualRedCards'] ?? 0),
      ];
      $hasSavedCorrection = (int)($row['statsManualOverride'] ?? 0) === 1;
      foreach ($actualStats as $key => $actual) {
        if ((int)($row[$key] ?? 0) !== 0 && (int)($row[$key] ?? 0) !== $actual) {
          $hasSavedCorrection = true;
        }
      }
      foreach ($actualStats as $key => $actual) {
        $row['shown'.ucfirst($key)] = $hasSavedCorrection ? max(0, (int)($row[$key] ?? 0)) : $actual;
      }
    }
    unset($row);
    $sortKeys = [
      'name' => 'name', 'team' => 'teamName', 'apps' => 'shownAppearances',
      'goals' => 'shownGoals', 'assists' => 'shownAssists',
      'yellow' => 'shownYellowCards', 'red' => 'shownRedCards',
    ];
    $sortKey = $sortKeys[$sort] ?? 'name';
    usort($players, function($a, $b) use ($sortKey, $direction) {
      $aValue = $a[$sortKey] ?? '';
      $bValue = $b[$sortKey] ?? '';
      $comparison = is_numeric($aValue) && is_numeric($bValue)
        ? ((int)$aValue <=> (int)$bValue)
        : strcasecmp((string)$aValue, (string)$bValue);
      if ($comparison === 0) $comparison = strcasecmp($a['name'], $b['name']);
      return $direction === 'DESC' ? -$comparison : $comparison;
    });
    $i = 1;
    foreach($players as $p):
    ?>
    <tr>
      <td style="color:#8BA3B8"><?= $i++ ?></td>
      <td><strong style="color:#fff"><?= e($p['name']) ?></strong><br><small style="color:#8BA3B8"><?= e($p['wardName']) ?></small></td>
      <td>
        <?php if (!empty($p['teamName'])): ?>
          <span class="badge badge-blue"><?= e($p['teamName']) ?></span>
        <?php else: ?>
          <span class="badge badge-gold" style="font-size:11px;">🌍 Unattached</span>
        <?php endif; ?>
        <?php if (!empty($squadMap[$p['id']])): ?>
          <div style="display:flex;flex-wrap:wrap;gap:2px;margin-top:3px;">
            <?php foreach ($squadMap[$p['id']] as $sq): ?>
              <?php if ($sq['name'] !== $p['teamName']): ?>
                <span class="badge" style="background:<?= !empty($sq['isNationalTeam']) ? 'rgba(210,176,89,.2);color:#D2B059' : 'rgba(255,255,255,.08);color:#cbd5e1' ?>;font-size:10px;padding:1px 5px;">
                  <?= !empty($sq['isNationalTeam']) ? '🌍 ' : '' ?><?= e($sq['name']) ?>
                </span>
              <?php endif; ?>
            <?php endforeach; ?>
          </div>
        <?php endif; ?>
      </td>
      <td><?= e($p['age']) ?></td>
      <td><?= e($p['position']) ?></td>
      <td><?= e($p['shownAppearances']??0) ?></td>
      <td><strong style="color:#D2B059"><?= e($p['shownGoals']??0) ?></strong></td>
      <td><?= e($p['shownAssists']??0) ?></td>
      <td style="color:#eab308"><?= e($p['shownYellowCards']??0) ?></td>
      <td style="color:#ef4444"><?= e($p['shownRedCards']??0) ?></td>
      <td>
        <a href="players.php?action=edit&id=<?= e($p['id']) ?>" class="btn btn-outline btn-sm"><span class="material-icons-round">edit</span></a>
        <form method="post" style="display:inline" onsubmit="return confirm('Delete player?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($p['id']) ?>"/>
          <button class="btn btn-danger btn-sm" type="submit"><span class="material-icons-round">delete</span></button>
        </form>
      </td>
    </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
  </div>
</div>
<?php endif; ?>
<?php require __DIR__.'/footer.php'; ?>
