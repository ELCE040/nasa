<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Teams';
$pdo = db();

// This page must stay usable on installations created before tournament
// groups were introduced. Upgrade the table before any team records are read.
try {
    $teamColumns = $pdo->query('SHOW COLUMNS FROM teams')->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('groupName', $teamColumns, true)) {
        $pdo->exec('ALTER TABLE teams ADD COLUMN groupName VARCHAR(50) DEFAULT NULL');
    }
    if (!in_array('dashboardOnly', $teamColumns, true)) {
        $pdo->exec('ALTER TABLE teams ADD COLUMN dashboardOnly TINYINT(1) NOT NULL DEFAULT 0');
    }
    if (!in_array('isExternal', $teamColumns, true)) {
        $pdo->exec('ALTER TABLE teams ADD COLUMN isExternal TINYINT(1) NOT NULL DEFAULT 0');
    }
} catch (PDOException $error) {
    // The normal team page still works without groups if the host account
    // cannot alter tables; do not turn the entire admin screen into a 500.
}

$leagues = $pdo->query('SELECT * FROM leagues ORDER BY name')->fetchAll();

// Calculate actual match stats for all teams from matches
$matchesStmt = $pdo->query("SELECT * FROM matches WHERE (status IN ('live', 'fullTime', 'completed', 'finished') OR status NOT IN ('upcoming', 'postponed')) AND homeTeamId IS NOT NULL AND awayTeamId IS NOT NULL");
$allMatches = $matchesStmt ? $matchesStmt->fetchAll() : [];

$leagueStats = [];
$overallStats = [];

foreach ($allMatches as $m) {
    $hId = $m['homeTeamId'];
    $aId = $m['awayTeamId'];
    $hScore = (int)($m['homeScore'] ?? 0);
    $aScore = (int)($m['awayScore'] ?? 0);
    $lid = $m['leagueId'] ?: '__noliga__';

    foreach ([$hId => [$hScore, $aScore], $aId => [$aScore, $hScore]] as $tid => [$gf, $ga]) {
        if (!$tid) continue;
        foreach ([$lid, '__overall__'] as $scope) {
            // PHP cannot assign a reference to a ternary expression. Select
            // the real array slot first, otherwise this page fails with 500.
            if ($scope === '__overall__') {
                $ref =& $overallStats[$tid];
            } else {
                $ref =& $leagueStats[$scope][$tid];
            }
            if (!isset($ref)) {
                $ref = ['played' => 0, 'won' => 0, 'drawn' => 0, 'lost' => 0, 'goalsFor' => 0, 'goalsAgainst' => 0, 'gd' => 0, 'points' => 0];
            }
            $ref['played'] += 1;
            $ref['goalsFor'] += $gf;
            $ref['goalsAgainst'] += $ga;
            if ($gf > $ga) $ref['won'] += 1;
            elseif ($gf === $ga) $ref['drawn'] += 1;
            else $ref['lost'] += 1;
            $ref['gd'] = $ref['goalsFor'] - $ref['goalsAgainst'];
            $ref['points'] = ($ref['won'] * 3) + $ref['drawn'];
            unset($ref);
        }
    }
}

// Handle actions
$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    $groupName = !empty($_POST['groupName']) ? trim($_POST['groupName']) : null;
    $wardName = trim($_POST['wardName'] ?? '');
    $isExternal = (int)($_POST['isExternal'] ?? 0) === 1 ? 1 : 0;
    $dashboardOnly = ($isExternal === 1) ? 1 : ((int)($_POST['dashboardOnly'] ?? 0) === 1 ? 1 : 0);

    // A team must always have a typed area/ward. Do not allow blank records
    // even if a form is submitted outside this admin page.
    if (in_array($op, ['create', 'update'], true) && $wardName === '') {
        flash('error', 'Area / ward is required.');
        header('Location: teams.php'.($op === 'update' && !empty($_POST['id']) ? '?action=edit&id='.urlencode($_POST['id']) : '?action=add'));
        exit;
    }

    if ($op === 'sync_stats') {
        $allTeamsList = $pdo->query('SELECT id, leagueId FROM teams')->fetchAll();
        $updateStmt = $pdo->prepare('UPDATE teams SET played=?, won=?, drawn=?, lost=?, goalsFor=?, goalsAgainst=? WHERE id=?');
        $synced = 0;
        foreach ($allTeamsList as $tm) {
            $st = ($tm['leagueId'] ? ($leagueStats[$tm['leagueId']][$tm['id']] ?? null) : null) ?? $overallStats[$tm['id']] ?? null;
            if ($st && $st['played'] > 0) {
                $updateStmt->execute([
                    $st['played'], $st['won'], $st['drawn'], $st['lost'],
                    $st['goalsFor'], $st['goalsAgainst'], $tm['id']
                ]);
                $synced++;
            }
        }
        flash('success', "Team stats recalculated and synced from matches ({$synced} teams updated)!");
        header('Location: teams.php'); exit;
    }
    $teamType = in_array($_POST['teamType'] ?? '', ['club', 'national', 'regional', 'academy'], true)
        ? $_POST['teamType']
        : (($isExternal === 1) ? 'external' : 'club');

    if ($op === 'create') {
        $nid = 't'.uniqid();
      $duplicateTeam = $pdo->prepare('SELECT id,name FROM teams WHERE LOWER(TRIM(name))=LOWER(TRIM(?)) LIMIT 1');
      $duplicateTeam->execute([$_POST['name']]);
      if ($duplicateTeam->fetch()) {
        flash('error', 'A team with this name already exists. Use the existing team instead.');
        header('Location: teams.php?action=add'); exit;
      }
        $coachName = trim($_POST['coachName'] ?? '');
        if ($isExternal === 1 && $coachName === '') {
            $coachName = 'External Opponent';
        }
        $pdo->prepare('INSERT INTO teams (id,name,wardId,wardName,leagueId,leagueName,foundedYear,coachName,sponsorName,groupName,dashboardOnly,isExternal,teamType) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)')
            ->execute([$nid, $_POST['name'], $_POST['wardId'], $wardName, $_POST['leagueId']?:null, $_POST['leagueName']?:null,
                   $_POST['foundedYear']?:null, $coachName, $_POST['sponsorName']??null, $groupName, $dashboardOnly, $isExternal, $teamType]);
        if (!empty($_POST['leagueId'])) {
            try {
                $pdo->prepare("INSERT INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
                    VALUES (?, ?, ?, 'participant', NOW())
                    ON DUPLICATE KEY UPDATE enrolledAt=NOW()")
                    ->execute(['tc_'.$nid.'_'.$_POST['leagueId'], $nid, $_POST['leagueId']]);
            } catch (Throwable $e) {}
        }
        flash('success', $isExternal ? 'External opponent created successfully!' : ($teamType === 'national' ? 'National Team created!' : 'Team created successfully!'));
        header('Location: teams.php'); exit;
    }
    if ($op === 'update') {
        $coachName = trim($_POST['coachName'] ?? '');
        if ($isExternal === 1 && $coachName === '') {
            $coachName = 'External Opponent';
        }
        $duplicateTeam = $pdo->prepare('SELECT id,name FROM teams WHERE LOWER(TRIM(name))=LOWER(TRIM(?)) AND id<>? LIMIT 1');
        $duplicateTeam->execute([$_POST['name'], $_POST['id']]);
        if ($duplicateTeam->fetch()) {
          flash('error', 'A team with this name already exists.');
          header('Location: teams.php?action=edit&id='.urlencode($_POST['id'])); exit;
        }
        $pdo->prepare('UPDATE teams SET name=?,wardId=?,wardName=?,leagueId=?,leagueName=?,foundedYear=?,coachName=?,sponsorName=?,groupName=?,dashboardOnly=?,isExternal=?,teamType=?,
            played=?,won=?,drawn=?,lost=?,goalsFor=?,goalsAgainst=? WHERE id=?')
            ->execute([$_POST['name'],$_POST['wardId'],$wardName,$_POST['leagueId']?:null, $_POST['leagueName']?:null, $_POST['foundedYear']?:null,
                   $coachName,$_POST['sponsorName']??null, $groupName, $dashboardOnly, $isExternal, $teamType,
                   $_POST['played']??0,$_POST['won']??0,$_POST['drawn']??0,$_POST['lost']??0,
                   $_POST['goalsFor']??0,$_POST['goalsAgainst']??0,$_POST['id']]);
        if (!empty($_POST['leagueId'])) {
            try {
                $pdo->prepare("INSERT INTO team_competitions (id, teamId, leagueId, competitionRole, enrolledAt)
                    VALUES (?, ?, ?, 'participant', NOW())
                    ON DUPLICATE KEY UPDATE enrolledAt=NOW()")
                    ->execute(['tc_'.$_POST['id'].'_'.$_POST['leagueId'], $_POST['id'], $_POST['leagueId']]);
            } catch (Throwable $e) {}
        }
        flash('success','Team updated!');
        header('Location: teams.php'); exit;
    }
    if ($op === 'delete') {
        $pdo->prepare('DELETE FROM teams WHERE id=?')->execute([$_POST['id']]);
        flash('success','Team deleted.');
        header('Location: teams.php'); exit;
    }

    // ── Quick-enrol a team into another competition ───────────────────────────
    if ($op === 'team_enrol') {
        $teamId   = trim($_POST['enrol_teamId']   ?? '');
        $leagueId = trim($_POST['enrol_leagueId'] ?? '');
        if ($teamId && $leagueId) {
            $league = $pdo->prepare('SELECT name FROM leagues WHERE id=?');
            $league->execute([$leagueId]); $league = $league->fetch();
            if ($league) {
                $pdo->prepare("INSERT INTO team_competitions (id,teamId,leagueId,competitionRole,enrolledAt)
                    VALUES (?,?,?,'participant',NOW())
                    ON DUPLICATE KEY UPDATE enrolledAt=NOW()")
                    ->execute(['tc_'.$teamId.'_'.$leagueId, $teamId, $leagueId]);
                flash('success','Team enrolled in '.$league['name'].'!');
            }
        }
        header('Location: teams.php?action=edit&id='.urlencode($teamId)); exit;
    }
    if ($op === 'team_unenrol') {
        $teamId   = trim($_POST['unenrol_teamId']   ?? '');
        $leagueId = trim($_POST['unenrol_leagueId'] ?? '');
        if ($teamId && $leagueId) {
            $pdo->prepare("DELETE FROM team_competitions WHERE teamId=? AND leagueId=?")
                ->execute([$teamId, $leagueId]);
            flash('success','Team removed from competition.');
        }
        header('Location: teams.php?action=edit&id='.urlencode($teamId)); exit;
    }
}

$wards = ['Nancholi','Chilomoni','Zingwangwa','Ndirande','Bangwe','Mchesi','Kanjedza','Area 36'];

if ($action==='edit' && $id) {
    $team = $pdo->prepare('SELECT * FROM teams WHERE id=?');
    $team->execute([$id]);
    $team = $team->fetch();
}

require __DIR__.'/header.php';
?>

<?php if ($action==='edit' && isset($team)): ?>
<?php
  $actualStat = ($team['leagueId'] ? ($leagueStats[$team['leagueId']][$team['id']] ?? null) : null) ?? $overallStats[$team['id']] ?? null;
?>
<!-- Edit form -->
<div class="card">
  <div class="section-header">
    <span class="section-title">Edit Team — <?= e($team['name']) ?></span>
    <a href="teams.php" class="btn btn-outline btn-sm">← Back</a>
  </div>
  <?php if ($actualStat && $actualStat['played'] > 0): ?>
  <div style="background:rgba(210,176,89,.12);border:1px solid rgba(210,176,89,.35);border-radius:8px;padding:12px 16px;margin-bottom:18px;font-size:13px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;">
    <div>
      <strong style="color:#D2B059">Live Match Record:</strong>
      Played: <strong><?= $actualStat['played'] ?></strong> ·
      Won: <strong style="color:#4ade80"><?= $actualStat['won'] ?></strong> ·
      Drawn: <strong style="color:#fbbf24"><?= $actualStat['drawn'] ?></strong> ·
      Lost: <strong style="color:#f87171"><?= $actualStat['lost'] ?></strong> ·
      GF: <strong><?= $actualStat['goalsFor'] ?></strong> ·
      GA: <strong><?= $actualStat['goalsAgainst'] ?></strong> ·
      GD: <strong><?= ($actualStat['gd']>=0?'+':'').$actualStat['gd'] ?></strong> ·
      Pts: <strong style="color:#D2B059"><?= $actualStat['points'] ?></strong>
    </div>
    <span style="font-size:11px;color:var(--slate)">Matches in database are the source of truth</span>
  </div>
  <?php endif; ?>
  <form method="post">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($team['id']) ?>"/>
    <div class="form-grid">
      <div class="form-group"><label>Team Name</label><input name="name" required value="<?= e($team['name']) ?>"/></div>
      <div class="form-group"><label>Team Classification *</label>
        <select name="teamType" id="editTeamType">
          <option value="club" <?= ($team['teamType']??'club')==='club' && empty($team['isExternal'])?'selected':'' ?>>🛡️ Registered Club (Full Squad / Players)</option>
          <option value="national" <?= ($team['teamType']??'')==='national'?'selected':'' ?>>🌍 National Team (Representative Squad)</option>
          <option value="regional" <?= ($team['teamType']??'')==='regional'?'selected':'' ?>>⚡ Regional / Select Squad</option>
          <option value="academy" <?= ($team['teamType']??'')==='academy'?'selected':'' ?>>🎓 Academy / Youth Team</option>
          <option value="external" <?= !empty($team['isExternal'])?'selected':'' ?>>👤 External Opponent (Opponent Only, No Account/Roster)</option>
        </select>
        <input type="hidden" name="isExternal" id="editIsExternal" value="<?= !empty($team['isExternal'])?1:0 ?>"/>
        <script>
          document.getElementById('editTeamType').addEventListener('change', function() {
            const isExt = this.value === 'external';
            document.getElementById('editIsExternal').value = isExt ? '1' : '0';
            const d = document.getElementById('editDashboardOnly');
            if (d && isExt) d.value = '1';
          });
        </script>
        <small style="color:#8BA3B8">National and Regional teams can call up players already in the system from any registered club.</small>
      </div>
      <div class="form-group"><label>Area / Ward *</label><input name="wardName" required value="<?= e($team['wardName']) ?>" placeholder="Type area or ward"/></div>
      <div class="form-group"><label>Ward ID</label><input name="wardId" value="<?= e($team['wardId']) ?>"/></div>
      <div class="form-group"><label>Founded Year</label><input type="number" name="foundedYear" value="<?= e($team['foundedYear']) ?>"/></div>
      <div class="form-group"><label>Coach Name</label><input name="coachName" value="<?= e($team['coachName']) ?>"/></div>
      <div class="form-group"><label>Sponsor Name</label><input name="sponsorName" value="<?= e($team['sponsorName']) ?>"/></div>
      <div class="form-group"><label>League / Tournament</label>
        <select name="leagueId" onchange="this.form.querySelector('[name=leagueName]').value=this.options[this.selectedIndex].text">
          <option value="">(None)</option>
          <?php foreach($leagues as $L): ?>
          <option value="<?= e($L['id']) ?>" <?= ($team['leagueId']??'')===$L['id']?'selected':'' ?>><?= e($L['name']) ?></option>
          <?php endforeach; ?>
        </select>
        <input type="hidden" name="leagueName" value="<?= e($team['leagueName']??'') ?>"/>
      </div>
      <div class="form-group"><label>Tournament Group (Optional)</label>
        <input name="groupName" value="<?= e($team['groupName']??'') ?>" placeholder="e.g. Group A, Group B"/>
      </div>
      <div class="form-group"><label>Visibility *</label><select name="dashboardOnly" id="editDashboardOnly"><option value="0" <?= empty($team['dashboardOnly'])?'selected':'' ?>>Public in app</option><option value="1" <?= !empty($team['dashboardOnly'])?'selected':'' ?>>Dashboard only (private)</option></select><small style="color:#8BA3B8">Private teams can use their dashboard but do not appear in the public app.</small></div>
    </div>
    <h4 style="color:#D2B059;margin:20px 0 12px;font-size:13px;text-transform:uppercase;letter-spacing:.5px">League Stats</h4>
    <div class="form-grid">
      <?php
        $statDefaults = [
          'played' => ($team['played'] == 0 && $actualStat) ? $actualStat['played'] : ($team['played'] ?? 0),
          'won' => ($team['won'] == 0 && $actualStat) ? $actualStat['won'] : ($team['won'] ?? 0),
          'drawn' => ($team['drawn'] == 0 && $actualStat) ? $actualStat['drawn'] : ($team['drawn'] ?? 0),
          'lost' => ($team['lost'] == 0 && $actualStat) ? $actualStat['lost'] : ($team['lost'] ?? 0),
          'goalsFor' => ($team['goalsFor'] == 0 && $actualStat) ? $actualStat['goalsFor'] : ($team['goalsFor'] ?? 0),
          'goalsAgainst' => ($team['goalsAgainst'] == 0 && $actualStat) ? $actualStat['goalsAgainst'] : ($team['goalsAgainst'] ?? 0),
        ];
      ?>
      <?php foreach(['played','won','drawn','lost','goalsFor','goalsAgainst'] as $f): ?>
      <div class="form-group"><label><?= ucfirst($f) ?></label><input type="number" name="<?= $f ?>" value="<?= e($statDefaults[$f]) ?>"/></div>
      <?php endforeach; ?>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Save Changes</button>
      <a href="teams.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>

<!-- ── Competitions this team is enrolled in ─────────────────────────── -->
<?php
$teamComps = [];
try {
    $tcStmt = $pdo->prepare("SELECT tc.leagueId, l.name, l.format, l.status
        FROM team_competitions tc
        JOIN leagues l ON l.id = tc.leagueId
        WHERE tc.teamId = ?
        ORDER BY l.name");
    $tcStmt->execute([$team['id']]);
    $teamComps = $tcStmt->fetchAll();
} catch (Throwable $e) {}
?>
<div class="card">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;flex-wrap:wrap;gap:10px;">
    <span style="font-size:15px;font-weight:800;color:#D2B059;">🏆 Competitions &amp; Leagues</span>
    <small style="color:#8BA3B8;">This team can appear in unlimited competitions simultaneously — no duplicates.</small>
  </div>

  <!-- Enrolled list -->
  <?php if ($teamComps): ?>
  <div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;">
    <?php foreach($teamComps as $tc):
      $fmtColor = $tc['format']==='knockout' ? '#ef4444' : ($tc['format']==='group_knockout' ? '#8b5cf6' : '#60a5fa');
    ?>
    <div style="display:flex;align-items:center;gap:6px;background:rgba(255,255,255,.05);border:1px solid #1A3A5C;border-radius:8px;padding:7px 12px;">
      <span style="font-size:12px;color:<?= $fmtColor ?>;font-weight:700;">
        <?= $tc['format']==='knockout' ? '🏆' : ($tc['format']==='group_knockout' ? '⚡' : '📋') ?>
      </span>
      <span style="font-size:13px;font-weight:600;"><?= e($tc['name']) ?></span>
      <?php if(($tc['status']??'active')==='completed'): ?>
      <span style="font-size:10px;color:#8BA3B8;background:rgba(255,255,255,.07);padding:1px 6px;border-radius:4px;">Completed</span>
      <?php else: ?>
      <span style="font-size:10px;color:#4ade80;background:rgba(74,222,128,.1);padding:1px 6px;border-radius:4px;">Active</span>
      <?php endif; ?>
      <form method="post" style="display:inline;"
            onsubmit="return confirm('Remove from <?= e(addslashes($tc['name'])) ?>?')">
        <input type="hidden" name="op"              value="team_unenrol"/>
        <input type="hidden" name="unenrol_teamId"   value="<?= e($team['id']) ?>"/>
        <input type="hidden" name="unenrol_leagueId" value="<?= e($tc['leagueId']) ?>"/>
        <button title="Remove from this competition" style="background:none;border:none;color:#ef4444;cursor:pointer;padding:0;margin-left:2px;line-height:1;">
          <span class="material-icons-round" style="font-size:14px;">close</span>
        </button>
      </form>
    </div>
    <?php endforeach; ?>
  </div>
  <?php else: ?>
  <p style="color:#8BA3B8;font-size:13px;font-style:italic;margin-bottom:16px;">
    Not enrolled in any competition yet. Use the form below to add this team to a competition.
  </p>
  <?php endif; ?>

  <!-- Quick-enrol into another competition -->
  <?php
  $enrolledLeagueIds = array_column($teamComps, 'leagueId');
  $availableLeagues  = array_filter($leagues, fn($l) => !in_array($l['id'], $enrolledLeagueIds, true));
  ?>
  <?php if ($availableLeagues): ?>
  <form method="post" style="display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap;border-top:1px solid #1A3A5C;padding-top:14px;">
    <input type="hidden" name="op"           value="team_enrol"/>
    <input type="hidden" name="enrol_teamId" value="<?= e($team['id']) ?>"/>
    <div class="form-group" style="flex:1;min-width:220px;margin:0;">
      <label>Add to Competition</label>
      <select name="enrol_leagueId" required>
        <option value="">Select competition…</option>
        <?php foreach($availableLeagues as $L): ?>
        <option value="<?= e($L['id']) ?>"><?= e($L['name']) ?></option>
        <?php endforeach; ?>
      </select>
    </div>
    <button class="btn btn-gold" type="submit" style="margin-bottom:0;white-space:nowrap;">
      <span class="material-icons-round" style="font-size:16px;vertical-align:middle;">add</span>
      Enrol in Competition
    </button>
  </form>
  <?php else: ?>
  <p style="color:#4ade80;font-size:13px;border-top:1px solid #1A3A5C;padding-top:12px;">
    ✓ This team is enrolled in all available competitions.
  </p>
  <?php endif; ?>
</div>

<?php elseif ($action==='add'): ?>
<!-- Add form -->
<div class="card">
  <div class="section-header">
    <span class="section-title">Register New Team</span>
    <a href="teams.php" class="btn btn-outline btn-sm">← Back</a>
  </div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Team Name *</label><input name="name" required/></div>
      <div class="form-group"><label>Team Classification *</label>
        <select name="teamType" id="addTeamType">
          <option value="club">🛡️ Registered Club (Full Squad / Players)</option>
          <option value="national">🌍 National Team (Representative Squad)</option>
          <option value="regional">⚡ Regional / Select Squad</option>
          <option value="academy">🎓 Academy / Youth Team</option>
          <option value="external">👤 External Opponent (Opponent Only, No Account/Roster)</option>
        </select>
        <input type="hidden" name="isExternal" id="addIsExternal" value="0"/>
        <script>
          document.getElementById('addTeamType').addEventListener('change', function() {
            const isExt = this.value === 'external';
            document.getElementById('addIsExternal').value = isExt ? '1' : '0';
            const d = document.getElementById('addDashboardOnly');
            if (d && isExt) d.value = '1';
            const c = document.getElementById('addCoachName');
            if (c) { c.required = !isExt; c.placeholder = isExt ? 'Optional for external opponent' : 'Coach name'; }
          });
        </script>
        <small style="color:#8BA3B8">National and Regional teams can call up players already in the system from any registered club.</small>
      </div>
      <div class="form-group"><label>Area / Ward *</label><input name="wardName" required placeholder="Type area or ward"/></div>
      <div class="form-group"><label>Ward ID</label><input name="wardId" placeholder="e.g. w1"/></div>
      <div class="form-group"><label>Founded Year</label><input type="number" name="foundedYear" value="<?= date('Y') ?>"/></div>
      <div class="form-group"><label>Coach Name</label><input name="coachName" id="addCoachName" required placeholder="Coach name"/></div>
      <div class="form-group"><label>Sponsor Name</label><input name="sponsorName" placeholder="Optional"/></div>
      <div class="form-group"><label>League / Tournament</label>
        <select name="leagueId" onchange="this.form.querySelector('[name=leagueName]').value=this.options[this.selectedIndex].text">
          <option value="">(None)</option>
          <?php foreach($leagues as $L): ?>
          <option value="<?= e($L['id']) ?>"><?= e($L['name']) ?></option>
          <?php endforeach; ?>
        </select>
        <input type="hidden" name="leagueName" value=""/>
      </div>
      <div class="form-group"><label>Tournament Group (Optional)</label>
        <input name="groupName" placeholder="e.g. Group A, Group B"/>
      </div>
      <div class="form-group"><label>Visibility *</label><select name="dashboardOnly" id="addDashboardOnly"><option value="0">Public in app</option><option value="1">Dashboard only (private)</option></select><small style="color:#8BA3B8">Use private for teams in an external league that only need their own dashboard.</small></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">add</span>Register Team</button>
      <a href="teams.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>

<?php else: ?>
<!-- List -->
<div class="section-header">
  <span class="section-title">Teams by League (<?= $pdo->query('SELECT COUNT(*) FROM teams')->fetchColumn() ?>)</span>
  <div style="display:flex;gap:10px;align-items:center;">
    <form method="post" style="display:inline" onsubmit="return confirm('Recalculate and sync all team stats from finished matches?')">
      <input type="hidden" name="op" value="sync_stats"/>
      <button class="btn btn-outline" type="submit" title="Sync all team stats from match records into the database"><span class="material-icons-round">sync</span>Sync Match Stats</button>
    </form>
    <a href="teams.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>Register Team</a>
  </div>
</div>
<div class="card">
  <?php
    // Fetch all teams once and group by leagueId and team_competitions
    $allTeams = $pdo->query('SELECT * FROM teams ORDER BY name')->fetchAll();
    $teamCompsMap = [];
    try {
        $tcRows = $pdo->query("SELECT tc.leagueId, tc.teamId FROM team_competitions tc")->fetchAll();
        foreach ($tcRows as $r) {
            $teamCompsMap[$r['leagueId']][$r['teamId']] = true;
        }
    } catch (Throwable $e) {}

    $grouped = [];
    foreach ($leagues as $L) {
        $lid = $L['id'];
        $grouped[$lid] = [];
        foreach ($allTeams as $t) {
            if (($t['leagueId'] ?? '') === $lid || isset($teamCompsMap[$lid][$t['id']])) {
                $grouped[$lid][] = $t;
            }
        }
    }
    $grouped['__noliga__'] = [];
    foreach ($allTeams as $t) {
        $hasLeague = !empty($t['leagueId']);
        if (!$hasLeague) {
            foreach ($teamCompsMap as $lid => $tids) {
                if (isset($tids[$t['id']])) { $hasLeague = true; break; }
            }
        }
        if (!$hasLeague) {
            $grouped['__noliga__'][] = $t;
        }
    }
  ?>

  <?php foreach($leagues as $L): ?>
    <?php
      $leagueTeams = $grouped[$L['id']] ?? [];
      foreach ($leagueTeams as &$t) {
        $st = $leagueStats[$L['id']][$t['id']] ?? $overallStats[$t['id']] ?? null;
        $t['calc_p']  = ($st && $st['played'] > 0) ? $st['played'] : (int)($t['played'] ?? 0);
        $t['calc_w']  = ($st && $st['played'] > 0) ? $st['won']    : (int)($t['won'] ?? 0);
        $t['calc_d']  = ($st && $st['played'] > 0) ? $st['drawn']  : (int)($t['drawn'] ?? 0);
        $t['calc_l']  = ($st && $st['played'] > 0) ? $st['lost']   : (int)($t['lost'] ?? 0);
        $t['calc_gf'] = ($st && $st['played'] > 0) ? $st['goalsFor'] : (int)($t['goalsFor'] ?? 0);
        $t['calc_ga'] = ($st && $st['played'] > 0) ? $st['goalsAgainst'] : (int)($t['goalsAgainst'] ?? 0);
        $t['calc_gd'] = $t['calc_gf'] - $t['calc_ga'];
        $t['calc_pts']= ($t['calc_w'] * 3) + $t['calc_d'];
      }
      unset($t);

      usort($leagueTeams, function($a, $b) {
        if (!empty($a['groupName']) || !empty($b['groupName'])) {
          $gCmp = strcmp($a['groupName'] ?? '', $b['groupName'] ?? '');
          if ($gCmp !== 0) return $gCmp;
        }
        if ($b['calc_pts'] !== $a['calc_pts']) return $b['calc_pts'] <=> $a['calc_pts'];
        if ($b['calc_gd'] !== $a['calc_gd']) return $b['calc_gd'] <=> $a['calc_gd'];
        if ($b['calc_gf'] !== $a['calc_gf']) return $b['calc_gf'] <=> $a['calc_gf'];
        return strcmp($a['name'], $b['name']);
      });
    ?>
    <div style="padding:14px;border-bottom:1px solid var(--border)">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
        <button type="button" aria-expanded="false"
                aria-controls="teams-league-<?= e($L['id']) ?>"
                onclick="toggleTeamsLeague(this, 'teams-league-<?= e($L['id']) ?>')"
                style="display:flex;align-items:center;gap:4px;background:none;border:0;color:#fff;padding:0;cursor:pointer;font:inherit;text-align:left;">
          <strong style="font-size:16px"><?= e($L['name']) ?></strong>
          <span class="material-icons-round teams-league-icon" aria-hidden="true">expand_more</span>
        </button>
        <small style="color:var(--slate)"><?= count($leagueTeams) ?> teams</small>
      </div>
      <div id="teams-league-<?= e($L['id']) ?>" hidden>
      <?php if (!empty($leagueTeams)): ?>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th style="width:36px;text-align:center">#</th>
              <th>Name</th>
              <th>Group</th>
              <th>Ward</th>
              <th>Coach</th>
              <th>Sponsor</th>
              <th style="text-align:center" title="Matches Played">P</th>
              <th style="text-align:center" title="Won">W</th>
              <th style="text-align:center" title="Drawn">D</th>
              <th style="text-align:center" title="Lost">L</th>
              <th style="text-align:center" title="Goals For">GF</th>
              <th style="text-align:center" title="Goals Against">GA</th>
              <th style="text-align:center" title="Goal Difference">GD</th>
              <th style="text-align:center" title="Points">Pts</th>
              <th style="text-align:right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <?php $pos = 1; foreach($leagueTeams as $t): ?>
            <tr>
              <td style="color:var(--slate);font-weight:600;text-align:center"><?= $pos++ ?></td>
              <td>
                <strong style="color:#fff"><?= e($t['name']) ?></strong>
                <?= ($t['teamType'] ?? '') === 'national' ? '<span class="badge badge-gold" style="font-size:10px;margin-left:4px">🌍 National</span>' : '' ?>
                <?= ($t['teamType'] ?? '') === 'regional' ? '<span class="badge" style="background:#8b5cf6;color:#fff;font-size:10px;margin-left:4px">⚡ Regional</span>' : '' ?>
                <?= !empty($t['isExternal']) ? '<span class="badge" style="background:#f59e0b;color:#000;font-size:10px;margin-left:4px;font-weight:700">External</span>' : '' ?>
                <?= !empty($t['dashboardOnly']) && empty($t['isExternal']) ? '<span class="badge" style="background:#475569;color:#fff;font-size:10px;margin-left:4px">Private</span>' : '' ?>
              </td>
              <td><?= !empty($t['groupName']) ? '<span class="badge" style="background:#8b5cf6;color:#fff;">'.e($t['groupName']).'</span>' : '<span style="color:#8BA3B8">—</span>' ?></td>
              <td><span class="badge badge-blue"><?= e($t['wardName']) ?></span></td>
              <td><?= e($t['coachName']) ?></td>
              <td><?= $t['sponsorName']?'<span class="badge badge-gold">'.e($t['sponsorName']).'</span>':'<span style="color:#8BA3B8">—</span>' ?></td>
              <td style="text-align:center;font-weight:600"><?= $t['calc_p'] ?></td>
              <td style="text-align:center;color:#4ade80"><?= $t['calc_w'] ?></td>
              <td style="text-align:center;color:#fbbf24"><?= $t['calc_d'] ?></td>
              <td style="text-align:center;color:#f87171"><?= $t['calc_l'] ?></td>
              <td style="text-align:center"><?= $t['calc_gf'] ?></td>
              <td style="text-align:center"><?= $t['calc_ga'] ?></td>
              <td style="text-align:center;font-weight:600;color:<?= $t['calc_gd'] > 0 ? '#4ade80' : ($t['calc_gd'] < 0 ? '#f87171' : 'var(--slate)') ?>">
                <?= ($t['calc_gd'] > 0 ? '+'.$t['calc_gd'] : $t['calc_gd']) ?>
              </td>
              <td style="text-align:center"><strong style="color:#D2B059;font-size:15px"><?= $t['calc_pts'] ?></strong></td>
              <td style="text-align:right;white-space:nowrap;">
                <a href="teams.php?action=edit&id=<?= e($t['id']) ?>" class="btn btn-outline btn-sm" title="Edit / Competitions"><span class="material-icons-round" style="font-size:15px;">edit</span></a>
                <form method="post" style="display:inline" onsubmit="return confirm('Delete this team?')">
                  <input type="hidden" name="op" value="delete"/>
                  <input type="hidden" name="id" value="<?= e($t['id']) ?>"/>
                  <button class="btn btn-danger btn-sm" type="submit" title="Delete"><span class="material-icons-round" style="font-size:15px;">delete</span></button>
                </form>
              </td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
      <?php else: ?>
        <div style="color:var(--slate);padding:8px 0">No teams in this league.</div>
      <?php endif; ?>
      </div>
    </div>
  <?php endforeach; ?>

  <?php // Unassigned teams ?>
  <?php if (!empty($grouped['__noliga__'])): ?>
    <?php
      $unassignedTeams = $grouped['__noliga__'];
      foreach ($unassignedTeams as &$t) {
        $st = $overallStats[$t['id']] ?? null;
        $t['calc_p']  = ($st && $st['played'] > 0) ? $st['played'] : (int)($t['played'] ?? 0);
        $t['calc_w']  = ($st && $st['played'] > 0) ? $st['won']    : (int)($t['won'] ?? 0);
        $t['calc_d']  = ($st && $st['played'] > 0) ? $st['drawn']  : (int)($t['drawn'] ?? 0);
        $t['calc_l']  = ($st && $st['played'] > 0) ? $st['lost']   : (int)($t['lost'] ?? 0);
        $t['calc_gf'] = ($st && $st['played'] > 0) ? $st['goalsFor'] : (int)($t['goalsFor'] ?? 0);
        $t['calc_ga'] = ($st && $st['played'] > 0) ? $st['goalsAgainst'] : (int)($t['goalsAgainst'] ?? 0);
        $t['calc_gd'] = $t['calc_gf'] - $t['calc_ga'];
        $t['calc_pts']= ($t['calc_w'] * 3) + $t['calc_d'];
      }
      unset($t);
      usort($unassignedTeams, function($a, $b) {
        if ($b['calc_pts'] !== $a['calc_pts']) return $b['calc_pts'] <=> $a['calc_pts'];
        if ($b['calc_gd'] !== $a['calc_gd']) return $b['calc_gd'] <=> $a['calc_gd'];
        return strcmp($a['name'], $b['name']);
      });
    ?>
    <div style="padding:14px">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
        <strong style="font-size:16px">No League Assigned</strong>
        <small style="color:var(--slate)"><?= count($unassignedTeams) ?> teams</small>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th style="width:36px;text-align:center">#</th>
              <th>Name</th>
              <th>Ward</th>
              <th>Coach</th>
              <th>Sponsor</th>
              <th style="text-align:center" title="Matches Played">P</th>
              <th style="text-align:center" title="Won">W</th>
              <th style="text-align:center" title="Drawn">D</th>
              <th style="text-align:center" title="Lost">L</th>
              <th style="text-align:center" title="Goals For">GF</th>
              <th style="text-align:center" title="Goals Against">GA</th>
              <th style="text-align:center" title="Goal Difference">GD</th>
              <th style="text-align:center" title="Points">Pts</th>
              <th style="text-align:right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <?php $pos = 1; foreach($unassignedTeams as $t): ?>
            <tr>
              <td style="color:var(--slate);font-weight:600;text-align:center"><?= $pos++ ?></td>
              <td>
                <strong style="color:#fff"><?= e($t['name']) ?></strong>
                <?= !empty($t['isExternal']) ? '<span class="badge" style="background:#f59e0b;color:#000;font-size:10px;margin-left:4px;font-weight:700">External</span>' : '' ?>
                <?= !empty($t['dashboardOnly']) && empty($t['isExternal']) ? '<span class="badge" style="background:#475569;color:#fff;font-size:10px;margin-left:4px">Private</span>' : '' ?>
              </td>
              <td><span class="badge badge-blue"><?= e($t['wardName']) ?></span></td>
              <td><?= e($t['coachName']) ?></td>
              <td><?= $t['sponsorName']?'<span class="badge badge-gold">'.e($t['sponsorName']).'</span>':'<span style="color:#8BA3B8">—</span>' ?></td>
              <td style="text-align:center;font-weight:600"><?= $t['calc_p'] ?></td>
              <td style="text-align:center;color:#4ade80"><?= $t['calc_w'] ?></td>
              <td style="text-align:center;color:#fbbf24"><?= $t['calc_d'] ?></td>
              <td style="text-align:center;color:#f87171"><?= $t['calc_l'] ?></td>
              <td style="text-align:center"><?= $t['calc_gf'] ?></td>
              <td style="text-align:center"><?= $t['calc_ga'] ?></td>
              <td style="text-align:center;font-weight:600;color:<?= $t['calc_gd'] > 0 ? '#4ade80' : ($t['calc_gd'] < 0 ? '#f87171' : 'var(--slate)') ?>">
                <?= ($t['calc_gd'] > 0 ? '+'.$t['calc_gd'] : $t['calc_gd']) ?>
              </td>
              <td style="text-align:center"><strong style="color:#D2B059;font-size:15px"><?= $t['calc_pts'] ?></strong></td>
              <td style="text-align:right">
                <a href="teams.php?action=edit&id=<?= e($t['id']) ?>" class="btn btn-outline btn-sm" title="Edit"><span class="material-icons-round">edit</span></a>
                <form method="post" style="display:inline" onsubmit="return confirm('Delete this team?')">
                  <input type="hidden" name="op" value="delete"/>
                  <input type="hidden" name="id" value="<?= e($t['id']) ?>"/>
                  <button class="btn btn-danger btn-sm" type="submit" title="Delete"><span class="material-icons-round">delete</span></button>
                </form>
              </td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
  <?php endif; ?>
</div>
<?php endif; ?>

<script>
function toggleTeamsLeague(button, panelId) {
  const panel = document.getElementById(panelId);
  const isOpen = !panel.hidden;
  panel.hidden = isOpen;
  button.setAttribute('aria-expanded', String(!isOpen));
  button.querySelector('.teams-league-icon').textContent = isOpen ? 'expand_more' : 'expand_less';
}
</script>

<?php require __DIR__.'/footer.php'; ?>
