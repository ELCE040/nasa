<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Leagues';
$pdo = db();

try {
    $cols = $pdo->query("SHOW COLUMNS FROM leagues")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('status', $cols)) $pdo->exec("ALTER TABLE leagues ADD COLUMN status VARCHAR(50) DEFAULT 'active'");
    if (!in_array('advancingTeams', $cols)) $pdo->exec("ALTER TABLE leagues ADD COLUMN advancingTeams INT NOT NULL DEFAULT 2");
} catch (PDOException $e) {}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $op = $_POST['op'] ?? '';
    $format = in_array($_POST['format'] ?? '', ['league','knockout','group_knockout']) ? $_POST['format'] : 'league';
    $status = in_array($_POST['status'] ?? '', ['active','completed']) ? $_POST['status'] : 'active';
    $advancingTeams = max(1, min(16, (int)($_POST['advancingTeams'] ?? 2)));

    if ($op === 'create') {
        $nid = 'l'.uniqid();
        $pdo->prepare('INSERT INTO leagues (id,name,description,format,status,advancingTeams) VALUES (?,?,?,?,?,?)')
            ->execute([$nid, $_POST['name'], $_POST['description'] ?? null, $format, $status, $advancingTeams]);
        flash('success','Competition/League created!');
        header('Location: leagues.php'); exit;
    }
    if ($op === 'update') {
        $pdo->prepare('UPDATE leagues SET name=?,description=?,format=?,status=?,advancingTeams=? WHERE id=?')
            ->execute([$_POST['name'], $_POST['description'] ?? null, $format, $status, $advancingTeams, $_POST['id']]);
        flash('success','Competition updated!');
        header('Location: leagues.php'); exit;
    }
    if ($op === 'delete') {
        $pdo->prepare('DELETE FROM leagues WHERE id=?')->execute([$_POST['id']]);
        flash('success','League deleted.');
        header('Location: leagues.php'); exit;
    }

    // ── ENROL an existing team into a competition ─────────────────────────────
    if ($op === 'enrol_team') {
        $leagueId   = trim($_POST['enrol_leagueId'] ?? '');
        $teamId     = trim($_POST['enrol_teamId'] ?? '');
        $groupName  = trim($_POST['enrol_groupName'] ?? '');
        if ($leagueId && $teamId) {
            $league = $pdo->prepare('SELECT * FROM leagues WHERE id=?');
            $league->execute([$leagueId]); $league = $league->fetch();
            $team   = $pdo->prepare('SELECT * FROM teams   WHERE id=?');
            $team->execute([$teamId]);   $team   = $team->fetch();
            if ($league && $team) {
                $tcId = 'tc_'.$teamId.'_'.$leagueId;
                $pdo->prepare("INSERT INTO team_competitions (id,teamId,leagueId,competitionRole,enrolledAt)
                    VALUES (?,?,?,'participant',NOW())
                    ON DUPLICATE KEY UPDATE enrolledAt=NOW()")
                    ->execute([$tcId, $teamId, $leagueId]);
                // Keep teams.leagueId pointing at their PRIMARY league — only set if blank
                $primaryLeague = $pdo->prepare("SELECT leagueId FROM teams WHERE id=?");
                $primaryLeague->execute([$teamId]);
                $existing = $primaryLeague->fetchColumn();
                if (!$existing) {
                    $pdo->prepare("UPDATE teams SET leagueId=?, leagueName=? WHERE id=?")
                        ->execute([$leagueId, $league['name'], $teamId]);
                }
                // If group specified, record it against the match fixture side (no change to team master)
                // We store groupName mapping for when creating fixtures in this competition
                if ($groupName) {
                    $pdo->prepare("UPDATE teams SET groupName=? WHERE id=? AND (leagueId=? OR leagueId IS NULL OR leagueId='')")
                        ->execute([$groupName, $teamId, $leagueId]);
                }
                flash('success', e($team['name']).' enrolled in '.e($league['name']).'!');
            } else {
                flash('error','Invalid team or league selected.');
            }
        } else {
            flash('error','Please select both a team and a competition.');
        }
        header('Location: leagues.php'); exit;
    }

    // ── REMOVE a team from a competition ─────────────────────────────────────
    if ($op === 'unenrol_team') {
        $leagueId = trim($_POST['unenrol_leagueId'] ?? '');
        $teamId   = trim($_POST['unenrol_teamId']   ?? '');
        if ($leagueId && $teamId) {
            $pdo->prepare("DELETE FROM team_competitions WHERE teamId=? AND leagueId=?")
                ->execute([$teamId, $leagueId]);
            flash('success','Team removed from competition.');
        }
        header('Location: leagues.php'); exit;
    }
}

$leagues  = $pdo->query('SELECT * FROM leagues ORDER BY name')->fetchAll();
$allTeams = $pdo->query('SELECT id, name, wardName, leagueId FROM teams WHERE isExternal=0 OR isExternal IS NULL ORDER BY name')->fetchAll();

// Build map: leagueId -> enrolled teams
$enrolledMap = [];
try {
    $rows = $pdo->query("SELECT tc.leagueId, t.id, t.name, t.wardName
        FROM team_competitions tc
        JOIN teams t ON t.id = tc.teamId
        ORDER BY t.name")->fetchAll();
    foreach ($rows as $r) {
        $enrolledMap[$r['leagueId']][] = $r;
    }
} catch (Throwable $e) {}

require __DIR__.'/header.php';
?>

<!-- ── Quick Enrol modal ──────────────────────────────────────────── -->
<div id="enrolModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:9999;align-items:center;justify-content:center;">
  <div style="background:#0D2540;border:1px solid #1A3A5C;border-radius:16px;padding:32px;width:480px;max-width:94vw;max-height:90vh;overflow-y:auto;">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
      <span style="font-size:16px;font-weight:800;color:#D2B059;">➕ Add Team to Competition</span>
      <button onclick="closeEnrol()" style="background:none;border:none;color:#8BA3B8;font-size:22px;cursor:pointer;">✕</button>
    </div>
    <form method="post" action="leagues.php">
      <input type="hidden" name="op" value="enrol_team"/>
      <div class="form-group">
        <label>Competition *</label>
        <select name="enrol_leagueId" id="enrolLeagueId" required>
          <option value="">Select competition…</option>
          <?php foreach($leagues as $l): ?>
          <option value="<?= e($l['id']) ?>"><?= e($l['name']) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="form-group">
        <label>Team *</label>
        <input type="text" id="enrolTeamSearch" placeholder="Search team name…" autocomplete="off"
               style="margin-bottom:6px;"
               oninput="filterEnrolTeams(this.value)"/>
        <select name="enrol_teamId" id="enrolTeamSelect" required size="6" style="height:auto;min-height:120px;">
          <?php foreach($allTeams as $t): ?>
          <option value="<?= e($t['id']) ?>" data-name="<?= strtolower(e($t['name'])) ?>">
            <?= e($t['name']) ?><?= $t['wardName'] ? ' ('.$t['wardName'].')' : '' ?>
          </option>
          <?php endforeach; ?>
        </select>
        <small style="color:#8BA3B8;">Scroll to find team. All registered clubs are available — no duplicates needed.</small>
      </div>
      <div class="form-group">
        <label>Group / Pool (optional)</label>
        <input name="enrol_groupName" placeholder="e.g. Group A, Northern Pool"/>
        <small style="color:#8BA3B8;">Leave blank for knockout or single-group competitions.</small>
      </div>
      <div class="form-actions">
        <button class="btn btn-gold" type="submit">Enrol Team</button>
        <button type="button" onclick="closeEnrol()" class="btn btn-outline">Cancel</button>
      </div>
    </form>
  </div>
</div>

<div class="section-header">
  <span class="section-title">Leagues &amp; Competitions (<?= count($leagues) ?>)</span>
  <div style="display:flex;gap:10px;">
    <button class="btn btn-outline" onclick="openEnrol()" style="display:flex;align-items:center;gap:6px;">
      <span class="material-icons-round" style="font-size:18px;">group_add</span>Add Team to Competition
    </button>
    <a href="leagues.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>New Competition</a>
  </div>
</div>

<?php $flash_s = flash('success'); $flash_e = flash('error'); ?>
<?php if ($flash_s): ?><div class="alert alert-success" style="background:rgba(74,222,128,.1);border:1px solid rgba(74,222,128,.3);color:#4ade80;padding:12px 18px;border-radius:8px;margin-bottom:16px;"><?= e($flash_s) ?></div><?php endif; ?>
<?php if ($flash_e): ?><div class="alert alert-danger"  style="background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.3);color:#f87171;padding:12px 18px;border-radius:8px;margin-bottom:16px;"><?= e($flash_e) ?></div><?php endif; ?>

<?php if (($_GET['action'] ?? '') === 'add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Create Competition / League</span><a href="leagues.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" action="leagues.php"><input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Name *</label><input name="name" required placeholder="e.g. NAYSA Champions Trophy"/></div>
      <div class="form-group"><label>Format *</label>
        <select name="format" required>
          <option value="league">Standard League (Round-Robin Table)</option>
          <option value="knockout">Cup / Knockout (Elimination Tournament)</option>
          <option value="group_knockout">Group Stage + Knockout (Hybrid)</option>
        </select>
      </div>
      <div class="form-group"><label>Status *</label>
        <select name="status" required>
          <option value="active">Active (Open)</option>
          <option value="completed">Completed (Finished)</option>
        </select>
      </div>
      <div class="form-group"><label>Teams Advancing Per Group *</label>
        <input type="number" name="advancingTeams" min="1" max="16" value="2" required/>
        <small style="color:#8BA3B8;">For group-stage competitions: 2, 3, 4 etc.</small>
      </div>
      <div class="form-group" style="grid-column:1/-1;"><label>Description</label><textarea name="description" placeholder="Brief description…"></textarea></div>
    </div>
    <div class="form-actions"><button class="btn btn-gold">Create Competition</button><a href="leagues.php" class="btn btn-outline">Cancel</a></div>
  </form>
</div>

<?php elseif (($_GET['action'] ?? '') === 'edit' && !empty($_GET['id'])): ?>
<?php
  $editLeague = $pdo->prepare('SELECT * FROM leagues WHERE id=?');
  $editLeague->execute([$_GET['id']]);
  $editLeague = $editLeague->fetch();
?>
<?php if ($editLeague): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Edit — <?= e($editLeague['name']) ?></span><a href="leagues.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" action="leagues.php"><input type="hidden" name="op" value="update"/><input type="hidden" name="id" value="<?= e($editLeague['id']) ?>"/>
    <div class="form-grid">
      <div class="form-group"><label>Name *</label><input name="name" required value="<?= e($editLeague['name']) ?>"/></div>
      <div class="form-group"><label>Format *</label>
        <select name="format" required>
          <option value="league" <?= ($editLeague['format']??'league')==='league'?'selected':'' ?>>Standard League (Round-Robin Table)</option>
          <option value="knockout" <?= ($editLeague['format']??'')==='knockout'?'selected':'' ?>>Cup / Knockout (Elimination)</option>
          <option value="group_knockout" <?= ($editLeague['format']??'')==='group_knockout'?'selected':'' ?>>Group Stage + Knockout (Hybrid)</option>
        </select>
      </div>
      <div class="form-group"><label>Status *</label>
        <select name="status" required>
          <option value="active" <?= ($editLeague['status']??'active')==='active'?'selected':'' ?>>Active</option>
          <option value="completed" <?= ($editLeague['status']??'')==='completed'?'selected':'' ?>>Completed</option>
        </select>
      </div>
      <div class="form-group"><label>Teams Advancing Per Group *</label>
        <input type="number" name="advancingTeams" min="1" max="16" value="<?= e($editLeague['advancingTeams']??2) ?>" required/>
      </div>
      <div class="form-group" style="grid-column:1/-1;"><label>Description</label><textarea name="description"><?= e($editLeague['description']??'') ?></textarea></div>
    </div>
    <div class="form-actions"><button class="btn btn-gold">Save Changes</button><a href="leagues.php" class="btn btn-outline">Cancel</a></div>
  </form>
</div>
<?php endif; ?>

<?php else: ?>
<!-- ── Competition list with enrolled teams ──────────────────────────── -->
<?php foreach($leagues as $l):
  $fmt = $l['format'] ?? 'league';
  $fmtLabels = [
    'league'         => '<span class="badge badge-blue">League Table</span>',
    'knockout'       => '<span class="badge badge-red">Cup / Knockout</span>',
    'group_knockout' => '<span class="badge" style="background:#8b5cf6;color:#fff;">Group + Knockout</span>',
  ];
  $stat = $l['status'] ?? 'active';
  $statBadge = $stat === 'completed'
    ? '<span class="badge badge-gray">Completed</span>'
    : '<span class="badge badge-green">Active</span>';
  $enrolled = $enrolledMap[$l['id']] ?? [];
?>
<div class="card" style="margin-bottom:20px;">
  <!-- Competition header row -->
  <div style="display:flex;align-items:flex-start;justify-content:space-between;flex-wrap:wrap;gap:10px;margin-bottom:12px;">
    <div>
      <div style="font-size:17px;font-weight:800;color:#fff;margin-bottom:4px;"><?= e($l['name']) ?></div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;">
        <?= $fmtLabels[$fmt] ?? '<span class="badge badge-gray">League</span>' ?>
        <?= $statBadge ?>
        <?php if($fmt==='group_knockout'): ?>
        <span class="badge badge-green">Top <?= e($l['advancingTeams']??2) ?> advance</span>
        <?php endif; ?>
        <span style="font-size:12px;color:#8BA3B8;"><?= count($enrolled) ?> team<?= count($enrolled)!==1?'s':'' ?> enrolled</span>
      </div>
      <?php if(!empty($l['description'])): ?>
      <div style="font-size:12px;color:#8BA3B8;margin-top:6px;"><?= e($l['description']) ?></div>
      <?php endif; ?>
    </div>
    <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
      <!-- Quick-enrol button pre-selecting this competition -->
      <button class="btn btn-gold btn-sm" onclick="openEnrolFor('<?= e($l['id']) ?>')"
              style="display:flex;align-items:center;gap:5px;">
        <span class="material-icons-round" style="font-size:16px;">group_add</span>+ Add Team
      </button>
      <a href="leagues.php?action=edit&id=<?= e($l['id']) ?>" class="btn btn-outline btn-sm">Edit</a>
      <form method="post" style="display:inline" onsubmit="return confirm('Delete this competition?')">
        <input type="hidden" name="op" value="delete"/>
        <input type="hidden" name="id" value="<?= e($l['id']) ?>"/>
        <button class="btn btn-danger btn-sm">Delete</button>
      </form>
    </div>
  </div>

  <!-- Enrolled teams list -->
  <?php if (count($enrolled) > 0): ?>
  <div style="border-top:1px solid #1A3A5C;padding-top:12px;">
    <div style="font-size:11px;font-weight:700;color:#D2B059;text-transform:uppercase;letter-spacing:.6px;margin-bottom:8px;">
      Enrolled Teams
    </div>
    <div style="display:flex;flex-wrap:wrap;gap:8px;">
      <?php foreach($enrolled as $et): ?>
      <div style="display:flex;align-items:center;gap:6px;background:rgba(255,255,255,.05);border:1px solid #1A3A5C;border-radius:8px;padding:6px 10px;">
        <span class="material-icons-round" style="font-size:15px;color:#D2B059;">shield</span>
        <span style="font-size:13px;font-weight:600;"><?= e($et['name']) ?></span>
        <?php if(!empty($et['wardName'])): ?>
        <span style="font-size:11px;color:#8BA3B8;"><?= e($et['wardName']) ?></span>
        <?php endif; ?>
        <form method="post" style="display:inline;margin-left:4px;"
              onsubmit="return confirm('Remove <?= e(addslashes($et['name'])) ?> from this competition?')">
          <input type="hidden" name="op" value="unenrol_team"/>
          <input type="hidden" name="unenrol_leagueId" value="<?= e($l['id']) ?>"/>
          <input type="hidden" name="unenrol_teamId"   value="<?= e($et['id']) ?>"/>
          <button title="Remove from competition" style="background:none;border:none;color:#ef4444;cursor:pointer;padding:0;line-height:1;">
            <span class="material-icons-round" style="font-size:14px;">close</span>
          </button>
        </form>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
  <?php else: ?>
  <div style="border-top:1px solid #1A3A5C;padding-top:12px;color:#8BA3B8;font-size:13px;font-style:italic;">
    No teams enrolled yet. Click <strong style="color:#D2B059;">+ Add Team</strong> to enrol existing registered clubs.
  </div>
  <?php endif; ?>
</div>
<?php endforeach; ?>
<?php if(empty($leagues)): ?>
<div class="card" style="text-align:center;color:#8BA3B8;padding:40px;">No competitions created yet.</div>
<?php endif; ?>
<?php endif; ?>

<script>
function openEnrol()         { const m=document.getElementById('enrolModal'); m.style.display='flex'; }
function openEnrolFor(lid)   {
  document.getElementById('enrolLeagueId').value = lid;
  document.getElementById('enrolModal').style.display='flex';
}
function closeEnrol()        { document.getElementById('enrolModal').style.display='none'; }
function filterEnrolTeams(q) {
  const sel = document.getElementById('enrolTeamSelect');
  q = q.toLowerCase().trim();
  for (let o of sel.options) {
    o.style.display = (!q || o.dataset.name.includes(q)) ? '' : 'none';
  }
}
document.getElementById('enrolModal').addEventListener('click', function(e){
  if(e.target===this) closeEnrol();
});
</script>

<?php require __DIR__.'/footer.php'; ?>
