<?php
/* Shared navigation sidebar — included by every page */
$role = $_SESSION['admin_role'] ?? 'superadmin';
if ($role === 'official') {
    $pages = [
        'matches.php' => ['icon'=>'sports_soccer',   'label'=>'Fixtures & Results'],
        'live.php'    => ['icon'=>'sensors',         'label'=>'🔴 Live Matches',  'highlight'=>true],
    ];
} else {
    $pages = [
        'dashboard.php'   => ['icon'=>'grid_view',      'label'=>'Dashboard'],
        'registrations.php'=>['icon'=>'assignment',      'label'=>'Registrations'],
        'leagues.php'     => ['icon'=>'flag',            'label'=>'Leagues'],
        'live.php'        => ['icon'=>'sensors',         'label'=>'🔴 Live Matches',  'highlight'=>true],
        'teams.php'       => ['icon'=>'shield',          'label'=>'Teams'],
        'players.php'     => ['icon'=>'person',          'label'=>'Players'],
        'duplicates.php'  => ['icon'=>'merge_type',      'label'=>'Duplicate Cleanup'],
        'matches.php'     => ['icon'=>'sports_soccer',   'label'=>'Fixtures & Results'],
        'news.php'        => ['icon'=>'newspaper',       'label'=>'News'],
        'events.php'      => ['icon'=>'event',           'label'=>'Events'],
        'sponsors.php'    => ['icon'=>'handshake',       'label'=>'Sponsors / Ads'],
        'referees.php'    => ['icon'=>'gavel',           'label'=>'Referees'],
        'ledger.php'      => ['icon'=>'account_balance', 'label'=>'Finance Ledger'],
        'transfers.php'   => ['icon'=>'swap_horiz',      'label'=>'Transfers'],
        'officials.php'   => ['icon'=>'manage_accounts', 'label'=>'Officials / Admins'],
    ];
}
$current = basename($_SERVER['PHP_SELF']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>NAYSA Admin — <?= $pageTitle ?? 'Dashboard' ?></title>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/icon?family=Material+Icons+Round" rel="stylesheet"/>
<style>
:root{
  --navy:#0E3357;--dark:#081C30;--gold:#D2B059;--red:#AF2329;
  --white:#FEFEFE;--slate:#8BA3B8;--card:#0D2540;--border:#1A3A5C;
  --radius:12px;--sidebar:240px;
}
*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:'Inter',sans-serif;background:var(--dark);color:var(--white);display:flex;min-height:100vh;}
a{text-decoration:none;color:inherit;}

/* ── Sidebar ── */
.sidebar{
  width:var(--sidebar);min-height:100vh;background:var(--navy);
  display:flex;flex-direction:column;position:fixed;left:0;top:0;bottom:0;z-index:100;
  border-right:1px solid var(--border);
}
.sidebar-logo{
  padding:24px 20px 16px;border-bottom:1px solid var(--border);
  display:flex;align-items:center;gap:10px;
}
.sidebar-logo img{width:36px;height:36px;border-radius:8px;background:var(--gold);padding:4px;}
.sidebar-logo-text{font-size:16px;font-weight:900;letter-spacing:1px;color:var(--white);}
.sidebar-logo-sub{font-size:10px;color:var(--gold);font-weight:600;letter-spacing:0.5px;}
.sidebar-nav{padding:12px 0;flex:1;overflow-y:auto;}
.nav-item{
  display:flex;align-items:center;gap:12px;padding:11px 20px;
  font-size:13.5px;font-weight:500;color:var(--slate);
  transition:all .15s;cursor:pointer;border-left:3px solid transparent;
}
.nav-item:hover{background:rgba(210,176,89,.08);color:var(--white);}
.nav-item.active{background:rgba(210,176,89,.12);color:var(--gold);border-left-color:var(--gold);}
.nav-item .material-icons-round{font-size:20px;}
.nav-item.nav-live{color:#f87171;animation:pulse 2s infinite;}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.6}}
.nav-item.nav-live:hover,.nav-item.nav-live.active{background:rgba(248,113,113,.12);color:#f87171;border-left-color:#f87171;}
.logout-btn{
  display:flex;align-items:center;gap:10px;padding:10px 14px;
  background:rgba(175,35,41,.15);color:#e57373;border-radius:8px;
  font-size:13px;font-weight:600;cursor:pointer;border:none;width:100%;
  transition:background .15s;
}
.logout-btn:hover{background:rgba(175,35,41,.3);}

/* ── Main ── */
.main{margin-left:var(--sidebar);flex:1;display:flex;flex-direction:column;min-height:100vh;}
.topbar{
  padding:18px 28px;background:var(--navy);border-bottom:1px solid var(--border);
  display:flex;align-items:center;justify-content:space-between;
  position:sticky;top:0;z-index:50;
}
.topbar-title{font-size:20px;font-weight:800;color:var(--white);}
.topbar-user{font-size:13px;color:var(--gold);font-weight:600;display:flex;align-items:center;}
.content{padding:28px;flex:1;}

/* ── Cards ── */
.card{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);padding:24px;margin-bottom:20px;}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:16px;margin-bottom:24px;}
.stat-card{
  background:var(--card);border:1px solid var(--border);border-radius:var(--radius);
  padding:20px;display:flex;flex-direction:column;gap:6px;
}
.stat-icon{font-size:28px;width:48px;height:48px;border-radius:10px;
  display:flex;align-items:center;justify-content:center;margin-bottom:6px;}
.stat-num{font-size:28px;font-weight:900;color:var(--white);}
.stat-label{font-size:12px;color:var(--slate);font-weight:500;text-transform:uppercase;letter-spacing:.5px;}

/* ── Table ── */
.table-wrap{overflow-x:auto;}
table{width:100%;border-collapse:collapse;font-size:13.5px;}
thead th{padding:10px 14px;text-align:left;color:var(--gold);font-size:11px;
  text-transform:uppercase;letter-spacing:.7px;border-bottom:1px solid var(--border);}
tbody tr{border-bottom:1px solid rgba(255,255,255,.04);transition:background .1s;}
tbody tr:hover{background:rgba(255,255,255,.03);}
td{padding:11px 14px;color:#c9d8e8;vertical-align:middle;}
.badge{display:inline-block;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:700;}
.badge-gold{background:rgba(210,176,89,.15);color:var(--gold);}
.badge-red{background:rgba(175,35,41,.2);color:#e57373;}
.badge-green{background:rgba(46,196,98,.15);color:#4ade80;}
.badge-blue{background:rgba(59,130,246,.15);color:#60a5fa;}
.badge-gray{background:rgba(255,255,255,.08);color:var(--slate);}

/* ── Buttons ── */
.btn{display:inline-flex;align-items:center;gap:6px;padding:9px 18px;border-radius:8px;
  font-size:13px;font-weight:700;cursor:pointer;border:none;transition:all .15s;}
.btn-gold{background:var(--gold);color:#000;}
.btn-gold:hover{background:#e6c86a;}
.btn-outline{background:transparent;color:var(--gold);border:1px solid var(--gold);}
.btn-outline:hover{background:rgba(210,176,89,.1);}
.btn-danger{background:rgba(175,35,41,.2);color:#e57373;border:1px solid rgba(175,35,41,.4);}
.btn-danger:hover{background:rgba(175,35,41,.4);}
.btn-sm{padding:5px 12px;font-size:12px;}
.btn .material-icons-round{font-size:16px;}

/* ── Forms ── */
.form-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px;}
.form-group{display:flex;flex-direction:column;gap:6px;}
.form-group label{font-size:12px;font-weight:600;color:var(--gold);text-transform:uppercase;letter-spacing:.5px;}
input,select,textarea{
  background:rgba(255,255,255,.05);border:1px solid var(--border);
  border-radius:8px;padding:10px 14px;color:var(--white);font-family:'Inter',sans-serif;
  font-size:14px;width:100%;outline:none;transition:border .15s;
}
input:focus,select:focus,textarea:focus{border-color:var(--gold);}
select option{background:var(--dark);}
textarea{resize:vertical;min-height:80px;}
.form-actions{margin-top:20px;display:flex;gap:10px;}

/* ── Alerts ── */
.alert{padding:12px 18px;border-radius:8px;font-size:13px;font-weight:600;margin-bottom:16px;display:flex;align-items:center;gap:8px;}
.alert-success{background:rgba(74,222,128,.1);color:#4ade80;border:1px solid rgba(74,222,128,.3);}
.alert-error{background:rgba(239,68,68,.1);color:#f87171;border:1px solid rgba(239,68,68,.3);}
.section-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px;}
.section-title{font-size:17px;font-weight:800;color:var(--white);}

@media (max-width:1024px){
  body{display:block}.sidebar{position:sticky;top:0;width:100%;min-height:0;height:auto}
  .sidebar-logo{padding:12px 16px;border-bottom:0}.sidebar-nav{display:flex;padding:0;overflow-x:auto;border-top:1px solid var(--border)}
  .nav-item{flex:0 0 auto;padding:10px 14px;border-left:0;border-bottom:3px solid transparent;font-size:12px}.nav-item.active{border-left:0;border-bottom-color:var(--gold)}
  .sidebar-footer{display:none}.main{margin-left:0;min-height:0}.topbar{padding:14px 16px;position:static}.content{padding:16px}.card{padding:16px}
  .stat-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.stat-card{padding:14px}.form-actions,.section-header{flex-wrap:wrap;gap:10px}td,thead th{padding:10px 8px}
}
@media (max-width:420px){.sidebar-logo-sub,.nav-item .material-icons-round{display:none}.nav-item{padding:10px 12px}.topbar-user{display:none}}
</style>
</head>
<body>
<aside class="sidebar">
  <div class="sidebar-logo">
    <img src="assets/logo.png" onerror="this.style.background='#D2B059';this.src=''" alt="NAYSA"/>
    <div>
      <div class="sidebar-logo-text">NAYSA</div>
      <div class="sidebar-logo-sub"><?= $role==='official' ? 'Official Panel' : 'Admin Panel' ?></div>
    </div>
  </div>
  <nav class="sidebar-nav">
    <?php foreach($pages as $file => $info):
      $cls = ($current===$file?'active':'').(!empty($info['highlight'])?' nav-live':'');
    ?>
    <a class="nav-item <?= $cls ?>" href="<?= $file ?>">
      <span class="material-icons-round"><?= $info['icon'] ?></span>
      <?= $info['label'] ?>
    </a>
    <?php endforeach; ?>
  </nav>
  <div class="sidebar-footer">
    <form method="post" action="logout.php">
      <button class="logout-btn" type="submit">
        <span class="material-icons-round" style="font-size:18px">logout</span>
        Sign Out
      </button>
    </form>
  </div>
</aside>
<div class="main">
  <div class="topbar">
    <span class="topbar-title"><?= $pageTitle ?? 'Dashboard' ?></span>
    <span class="topbar-user">
      ⚙ <?= e($_SESSION['admin_name'] ?? $_SESSION['admin_user'] ?? 'admin') ?>
      <?php if ($role === 'official'): ?>
        <span class="badge badge-gold" style="margin-left:6px;font-size:10px;"><?= e($_SESSION['admin_league_name'] ?? 'Official') ?></span>
      <?php else: ?>
        <span class="badge badge-blue" style="margin-left:6px;font-size:10px;">Superadmin</span>
      <?php endif; ?>
    </span>
  </div>
  <div class="content">
<?php
// Flash messages
$ok = flash('success'); $err = flash('error');
if($ok) echo '<div class="alert alert-success"><span class="material-icons-round">check_circle</span>'.e($ok).'</div>';
if($err) echo '<div class="alert alert-error"><span class="material-icons-round">error</span>'.e($err).'</div>';
?>
