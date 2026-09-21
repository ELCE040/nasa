<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Dashboard';
$pdo = db();

// Auto-create app_active_sessions table if missing
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS app_active_sessions (
      deviceId VARCHAR(100) PRIMARY KEY,
      role VARCHAR(50) DEFAULT 'viewer',
      platform VARCHAR(50) DEFAULT 'mobile',
      appVersion VARCHAR(50) DEFAULT '1.0.0',
      firstSeen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      lastPing DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_lastPing (lastPing)
    )");
} catch (PDOException $e) {}

// Ajax endpoint for real-time dashboard live polling
if (isset($_GET['ajax']) && $_GET['ajax'] === 'active_users') {
    header('Content-Type: application/json');
    $on = (int)$pdo->query("SELECT COUNT(*) FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 90 SECOND)")->fetchColumn();
    $day = (int)$pdo->query("SELECT COUNT(*) FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 24 HOUR)")->fetchColumn();
    $roles = ['viewer'=>0, 'scout'=>0, 'team'=>0];
    $rRows = $pdo->query("SELECT role, COUNT(*) as cnt FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 90 SECOND) GROUP BY role")->fetchAll();
    foreach ($rRows as $r) {
        $k = strtolower($r['role']);
        if (isset($roles[$k])) $roles[$k] = (int)$r['cnt'];
    }
    echo json_encode(['onlineNow' => $on, 'activeToday' => $day, 'byRole' => $roles]);
    exit;
}


// Query Active User Stats
$onlineNow = 0;
$activeToday = 0;
$onlineByRole = ['viewer'=>0, 'scout'=>0, 'team'=>0];
try {
    $onlineNow = (int)$pdo->query("SELECT COUNT(*) FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 90 SECOND)")->fetchColumn();
    $activeToday = (int)$pdo->query("SELECT COUNT(*) FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 24 HOUR)")->fetchColumn();
    
    $roleRows = $pdo->query("SELECT role, COUNT(*) as cnt FROM app_active_sessions WHERE lastPing >= (NOW() - INTERVAL 90 SECOND) GROUP BY role")->fetchAll();
    foreach ($roleRows as $r) {
        $roleKey = strtolower($r['role']);
        if (isset($onlineByRole[$roleKey])) {
            $onlineByRole[$roleKey] = (int)$r['cnt'];
        }
    }
} catch (PDOException $e) {}

$counts = [];
foreach (['matches', 'news', 'events'] as $table) {
    $counts[$table] = $pdo->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();
}
$upcomingMatches = $pdo->query("SELECT * FROM matches WHERE status = 'upcoming' OR kickoff >= NOW() ORDER BY kickoff ASC LIMIT 5")->fetchAll();
$recentResults = $pdo->query("SELECT * FROM matches WHERE status IN ('completed','finished') OR (status NOT IN ('upcoming','live') AND kickoff < NOW()) ORDER BY kickoff DESC LIMIT 5")->fetchAll();
$recentNews = $pdo->query("SELECT * FROM news ORDER BY date DESC LIMIT 4")->fetchAll();
require __DIR__.'/header.php';
?>
<div class="stat-grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
  <!-- Realtime Active Users Stat Card -->
  <div class="stat-card" style="border: 1px solid rgba(74, 222, 128, 0.3); background: linear-gradient(145deg, rgba(74, 222, 128, 0.07), rgba(14, 51, 87, 0.6));">
    <div style="display:flex; justify-content:space-between; align-items:center;">
      <div class="stat-icon" style="background:rgba(74, 222, 128, 0.15)">
        <span class="material-icons-round" style="color:#4ade80;font-size:26px">sensors</span>
      </div>
      <span style="display:inline-flex; align-items:center; gap:6px; font-size:11px; font-weight:700; color:#4ade80; background:rgba(74, 222, 128, 0.15); padding:3px 8px; border-radius:20px;">
        <span style="width:7px; height:7px; border-radius:50%; background:#4ade80; display:inline-block; box-shadow: 0 0 8px #4ade80;"></span>
        LIVE
      </span>
    </div>
    <div class="stat-num" id="liveOnlineCount" style="color:#4ade80; margin-top:10px;"><?= number_format($onlineNow) ?></div>
    <div class="stat-label">Online Now (Active App Users)</div>
    <div style="margin-top:8px; font-size:11px; color:#8BA3B8; display:flex; gap:10px; flex-wrap:wrap;">
      <span>👁️ Viewers: <strong id="roleViewerCount" style="color:#fff"><?= $onlineByRole['viewer'] ?></strong></span>
      <span>⭐ Scouts: <strong id="roleScoutCount" style="color:#fff"><?= $onlineByRole['scout'] ?></strong></span>
      <span>🛡️ Teams: <strong id="roleTeamCount" style="color:#fff"><?= $onlineByRole['team'] ?></strong></span>
    </div>
  </div>

  <!-- Daily Active Users Stat Card -->
  <div class="stat-card" style="border: 1px solid rgba(210, 176, 89, 0.3); background: linear-gradient(145deg, rgba(210, 176, 89, 0.07), rgba(14, 51, 87, 0.6));">
    <div class="stat-icon" style="background:rgba(210, 176, 89, 0.15)">
      <span class="material-icons-round" style="color:#D2B059;font-size:26px">smartphone</span>
    </div>
    <div class="stat-num" id="liveTodayCount" style="color:#D2B059;"><?= number_format($activeToday) ?></div>
    <div class="stat-label">Active Today (Last 24 Hours)</div>
    <div style="margin-top:8px; font-size:11px; color:#8BA3B8;">Unique devices engaged</div>
  </div>

<?php foreach ([
  ['sports_soccer', '#4ade80', $counts['matches'], 'Fixtures & Results'],
  ['newspaper', '#fbbf24', $counts['news'], 'News'],
  ['event', '#60a5fa', $counts['events'], 'Events'],
] as [$icon, $color, $number, $label]): ?>
  <div class="stat-card"><div class="stat-icon" style="background:rgba(255,255,255,.06)"><span class="material-icons-round" style="color:<?= $color ?>;font-size:26px"><?= $icon ?></span></div><div class="stat-num"><?= number_format($number) ?></div><div class="stat-label"><?= $label ?></div></div>
<?php endforeach; ?>
</div>


<div class="dashboard-grid" style="display:grid;grid-template-columns:1fr 1fr;gap:20px">
  <section class="card"><div class="section-header"><span class="section-title">Upcoming Fixtures</span><a href="matches.php" class="btn btn-outline btn-sm">Manage</a></div><div class="table-wrap"><table><thead><tr><th>Fixture</th><th>Kickoff</th><th>Venue</th></tr></thead><tbody>
  <?php foreach($upcomingMatches as $m): ?><tr><td><strong><?= e($m['homeTeamName']) ?> vs <?= e($m['awayTeamName']) ?></strong></td><td><?= date('d M, H:i', strtotime($m['kickoff'])) ?></td><td><?= e($m['venue']) ?></td></tr><?php endforeach; ?>
  <?php if (!$upcomingMatches): ?><tr><td colspan="3">No upcoming fixtures.</td></tr><?php endif; ?>
  </tbody></table></div></section>
  <section class="card"><div class="section-header"><span class="section-title">Recent Results</span><a href="matches.php" class="btn btn-outline btn-sm">View All</a></div>
  <?php foreach($recentResults as $m): ?><div style="padding:10px 0;border-bottom:1px solid rgba(255,255,255,.05)"><strong><?= e($m['homeTeamName']) ?> <span class="badge badge-gold"><?= $m['homeScore'] ?> - <?= $m['awayScore'] ?></span> <?= e($m['awayTeamName']) ?></strong><div style="font-size:11px;color:#8BA3B8;margin-top:3px"><?= date('d M Y', strtotime($m['kickoff'])) ?></div></div><?php endforeach; ?>
  <?php if (!$recentResults): ?><div style="color:#8BA3B8">No results published yet.</div><?php endif; ?>
  </section>
</div>
<section class="card" style="margin-top:20px"><div class="section-header"><span class="section-title">Latest News</span><a href="news.php" class="btn btn-outline btn-sm">Manage News</a></div>
<?php foreach($recentNews as $n): ?><div style="padding:10px 0;border-bottom:1px solid rgba(255,255,255,.05)"><strong><?= e($n['title']) ?></strong><span style="color:#8BA3B8;font-size:12px"> · <?= e($n['category']) ?> · <?= date('d M Y', strtotime($n['date'])) ?></span></div><?php endforeach; ?>
<?php if (!$recentNews): ?><div style="color:#8BA3B8">No news published yet.</div><?php endif; ?></section>
<style>@media(max-width:760px){.dashboard-grid{grid-template-columns:1fr !important;}}</style>
<script>
// Auto-refresh active users count every 10 seconds
setInterval(() => {
  fetch('dashboard.php?ajax=active_users')
    .then(res => res.json())
    .then(data => {
      if (data) {
        const elOnline = document.getElementById('liveOnlineCount');
        const elToday = document.getElementById('liveTodayCount');
        const elViewer = document.getElementById('roleViewerCount');
        const elScout = document.getElementById('roleScoutCount');
        const elTeam = document.getElementById('roleTeamCount');
        if (elOnline) elOnline.textContent = Number(data.onlineNow || 0).toLocaleString();
        if (elToday) elToday.textContent = Number(data.activeToday || 0).toLocaleString();
        if (elViewer && data.byRole) elViewer.textContent = data.byRole.viewer || 0;
        if (elScout && data.byRole) elScout.textContent = data.byRole.scout || 0;
        if (elTeam && data.byRole) elTeam.textContent = data.byRole.team || 0;
      }
    })
    .catch(() => {});
}, 10000);
</script>
<?php require __DIR__.'/footer.php'; ?>
