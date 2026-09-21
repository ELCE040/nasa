<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pdo = db();

// Ensure paymentStatus column exists in team_registrations
try {
    $cols = $pdo->query("SHOW COLUMNS FROM team_registrations")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('paymentStatus', $cols)) {
        $pdo->exec("ALTER TABLE team_registrations ADD COLUMN paymentStatus VARCHAR(50) DEFAULT 'pending'");
        $pdo->exec("UPDATE team_registrations SET paymentStatus = 'completed' WHERE status = 'approved' OR paymentReceiptRef LIKE 'CASH-%'");
    }
} catch (PDOException $e) {}

$leagues = $pdo->query('SELECT * FROM leagues ORDER BY name')->fetchAll();

// PayChangu Verification Helper
function verifyPayChanguStatus(string $chargeId): string {
    $secKey = getenv('PAYCHANGU_SECRET_KEY') ?: 'sec-key-xxx';
    $url = "https://api.paychangu.com/mobile-money/payments/" . urlencode($chargeId) . "/verify";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer {$secKey}",
        "Accept: application/json"
    ]);
    curl_setopt($ch, CURLOPT_TIMEOUT, 8);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($response && $httpCode === 200) {
        $json = json_decode($response, true);
        $statusStr = strtolower($json['data']['status'] ?? $json['status'] ?? '');
        if (in_array($statusStr, ['success', 'successful', 'completed', 'approved'])) {
            return 'completed';
        }
        if (in_array($statusStr, ['failed', 'failed_charge', 'cancelled', 'expired', 'error'])) {
            return 'failed';
        }
    }
    return 'pending';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    
    // ─── ACTION 1: Register Team Paid via Cash ───
    if ($_POST['action'] === 'register_cash') {
        $teamName   = trim($_POST['teamName'] ?? '');
        $wardName   = trim($_POST['wardName'] ?? '');
        $coachName  = trim($_POST['coachName'] ?? '');
        $leagueId   = $_POST['leagueId'] ?: null;
        $leagueName = $_POST['leagueName'] ?: null;
        $receiptRef = trim($_POST['receiptRef'] ?? '') ?: ('CASH-' . rand(1000, 9999));
        $username   = trim($_POST['username'] ?? '');
        $password   = trim($_POST['password'] ?? '');

        if (empty($teamName) || empty($username) || empty($password)) {
            flash('error', 'Team name, username, and password are required.');
        } else {
            try {
                // Ensure columns exist in teams table
                $cols = $pdo->query("SHOW COLUMNS FROM teams")->fetchAll(PDO::FETCH_COLUMN);
                if (!in_array('username', $cols))  $pdo->exec("ALTER TABLE teams ADD COLUMN username VARCHAR(100) DEFAULT NULL");
                if (!in_array('password', $cols))  $pdo->exec("ALTER TABLE teams ADD COLUMN password VARCHAR(100) DEFAULT NULL");
                if (!in_array('coachName', $cols)) $pdo->exec("ALTER TABLE teams ADD COLUMN coachName VARCHAR(255) DEFAULT NULL");
                if (!in_array('leagueId', $cols))  $pdo->exec("ALTER TABLE teams ADD COLUMN leagueId VARCHAR(50) DEFAULT NULL");
                if (!in_array('leagueName', $cols)) $pdo->exec("ALTER TABLE teams ADD COLUMN leagueName VARCHAR(255) DEFAULT NULL");

                // 1. Save in team_registrations table as approved and completed
                $regId = 'reg_cash_' . uniqid();
                $stmt = $pdo->prepare("INSERT INTO team_registrations (id, teamName, wardName, coachName, paymentReceiptRef, paymentStatus, status, requestDate) VALUES (?, ?, ?, ?, ?, 'completed', 'approved', NOW())");
                $stmt->execute([$regId, $teamName, $wardName, $coachName, $receiptRef]);

                // 2. Insert into teams table
                $duplicateTeam = $pdo->prepare("SELECT id FROM teams WHERE LOWER(TRIM(name))=LOWER(TRIM(?)) LIMIT 1");
                $duplicateTeam->execute([$teamName]);
                if ($duplicateTeam->fetch()) {
                    throw new RuntimeException('A team with this name already exists. Use the existing team record.');
                }
                $teamId = 't' . time() . rand(10, 99);
                $stmt = $pdo->prepare("INSERT INTO teams (id, name, wardName, coachName, leagueId, leagueName, username, password) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
                $stmt->execute([$teamId, $teamName, $wardName, $coachName, $leagueId, $leagueName, $username, $password]);

                // 3. Log in ledger table as income
                $ledgerId = 'l' . uniqid();
                $stmt = $pdo->prepare("INSERT INTO ledger (id, date, description, type, category, amountMwk) VALUES (?, NOW(), ?, 'income', 'Registration Fees', 40000.00)");
                $stmt->execute([$ledgerId, "Team Cash Registration — {$teamName} (Ref: {$receiptRef})"]);

                flash('success', "Team <strong>" . e($teamName) . "</strong> registered via Cash Payment!<br>Login Username: <strong>" . e($username) . "</strong> | Password: <strong>" . e($password) . "</strong>");
            } catch (PDOException $e) {
                flash('error', "Database error: " . $e->getMessage());
            }
        }
        header('Location: registrations.php');
        exit;
    }

    // ─── ACTION 2: Approve Pending Registration ───
    if ($_POST['action'] === 'approve') {
        $id       = $_POST['id'] ?? '';
        $username = trim($_POST['username'] ?? '');
        $password = trim($_POST['password'] ?? '');

        try {
            $stmt = $pdo->prepare("SELECT * FROM team_registrations WHERE id = ?");
            $stmt->execute([$id]);
            $reg = $stmt->fetch();

            if ($reg) {
                $duplicateTeam = $pdo->prepare("SELECT id FROM teams WHERE LOWER(TRIM(name))=LOWER(TRIM(?)) LIMIT 1");
                $duplicateTeam->execute([$reg['teamName']]);
                if ($duplicateTeam->fetch()) {
                    throw new RuntimeException('A team with this name already exists.');
                }
                $teamId = 't' . time();

                $cols = $pdo->query("SHOW COLUMNS FROM teams")->fetchAll(PDO::FETCH_COLUMN);
                if (!in_array('username', $cols))  $pdo->exec("ALTER TABLE teams ADD COLUMN username VARCHAR(100) DEFAULT NULL");
                if (!in_array('password', $cols))  $pdo->exec("ALTER TABLE teams ADD COLUMN password VARCHAR(100) DEFAULT NULL");
                if (!in_array('coachName', $cols)) $pdo->exec("ALTER TABLE teams ADD COLUMN coachName VARCHAR(255) DEFAULT NULL");
                if (!in_array('leagueId', $cols))  $pdo->exec("ALTER TABLE teams ADD COLUMN leagueId VARCHAR(50) DEFAULT NULL");
                if (!in_array('leagueName', $cols)) $pdo->exec("ALTER TABLE teams ADD COLUMN leagueName VARCHAR(255) DEFAULT NULL");

                $stmt = $pdo->prepare("INSERT INTO teams (id, name, wardName, coachName, leagueId, leagueName, username, password) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
                $stmt->execute([
                    $teamId,
                    $reg['teamName'],
                    $reg['wardName'],
                    $reg['coachName'],
                    $_POST['leagueId']?:null,
                    $_POST['leagueName']?:null,
                    $username,
                    $password
                ]);

                // Mark registration as approved and completed
                $pdo->prepare("UPDATE team_registrations SET status = 'approved', paymentStatus = 'completed' WHERE id = ?")->execute([$id]);

                flash('success', "Team <strong>" . e($reg['teamName']) . "</strong> approved! Login: <strong>" . e($username) . "</strong> / <strong>" . e($password) . "</strong>");
            } else {
                flash('error', "Registration not found.");
            }
        } catch (PDOException $e) {
            flash('error', "Database error: " . $e->getMessage());
        }
        header('Location: registrations.php');
        exit;
    }

    // ─── ACTION 3: Verify Payment via PayChangu API ───
    if ($_POST['action'] === 'verify_payment') {
        $id = $_POST['id'] ?? '';
        $stmt = $pdo->prepare("SELECT * FROM team_registrations WHERE id = ?");
        $stmt->execute([$id]);
        $reg = $stmt->fetch();

        if ($reg) {
            if (str_starts_with($reg['paymentReceiptRef'] ?? '', 'CASH-')) {
                $pdo->prepare("UPDATE team_registrations SET paymentStatus = 'completed' WHERE id = ?")->execute([$id]);
                flash('success', "Cash registration verified as COMPLETED.");
            } else {
                $statusResult = verifyPayChanguStatus($reg['paymentReceiptRef']);
                $pdo->prepare("UPDATE team_registrations SET paymentStatus = ? WHERE id = ?")->execute([$statusResult, $id]);
                
                if ($statusResult === 'completed') {
                    flash('success', "PayChangu Payment Verified: <strong>SUCCESSFUL / COMPLETED</strong> for " . e($reg['teamName']));
                } elseif ($statusResult === 'failed') {
                    flash('error', "PayChangu Payment Verified: <strong>FAILED / CANCELLED</strong> for " . e($reg['teamName']));
                } else {
                    flash('error', "PayChangu Payment Status: Still <strong>PENDING</strong> on user's phone.");
                }
            }
        }
        header('Location: registrations.php');
        exit;
    }

    // ─── ACTION 4: Delete / Purge Registration ───
    if ($_POST['action'] === 'delete_reg') {
        $id = $_POST['id'] ?? '';
        $pdo->prepare("DELETE FROM team_registrations WHERE id = ?")->execute([$id]);
        flash('success', "Registration record deleted.");
        header('Location: registrations.php');
        exit;
    }
}

// Filter handling
$filter = $_GET['filter'] ?? 'paid'; // Default tab: paid / completed

// Counts for filter tabs
$counts = [
    'paid'    => (int)$pdo->query("SELECT COUNT(*) FROM team_registrations WHERE paymentStatus = 'completed' OR paymentReceiptRef LIKE 'CASH-%' OR status = 'approved'")->fetchColumn(),
    'pending' => (int)$pdo->query("SELECT COUNT(*) FROM team_registrations WHERE (paymentStatus = 'pending' OR paymentStatus IS NULL) AND status != 'approved' AND paymentReceiptRef NOT LIKE 'CASH-%'")->fetchColumn(),
    'failed'  => (int)$pdo->query("SELECT COUNT(*) FROM team_registrations WHERE paymentStatus = 'failed'")->fetchColumn(),
    'all'     => (int)$pdo->query("SELECT COUNT(*) FROM team_registrations")->fetchColumn(),
];

// Query based on selected filter tab
if ($filter === 'paid') {
    $stmt = $pdo->query("SELECT * FROM team_registrations WHERE paymentStatus = 'completed' OR paymentReceiptRef LIKE 'CASH-%' OR status = 'approved' ORDER BY requestDate DESC");
} elseif ($filter === 'pending') {
    $stmt = $pdo->query("SELECT * FROM team_registrations WHERE (paymentStatus = 'pending' OR paymentStatus IS NULL) AND status != 'approved' AND paymentReceiptRef NOT LIKE 'CASH-%' ORDER BY requestDate DESC");
} elseif ($filter === 'failed') {
    $stmt = $pdo->query("SELECT * FROM team_registrations WHERE paymentStatus = 'failed' ORDER BY requestDate DESC");
} else { // 'all'
    $stmt = $pdo->query("SELECT * FROM team_registrations ORDER BY requestDate DESC");
}
$registrations = $stmt->fetchAll();

$pageTitle = 'Team Registrations';
require __DIR__.'/header.php';
?>

<div class="section-header">
    <div class="section-title">Team Registrations</div>
    <button class="btn btn-gold" onclick="openCashRegisterModal()">
        <span class="material-icons-round">payments</span> + Register Cash-Paid Team
    </button>
</div>

<!-- Filter Tabs -->
<div style="display:flex; gap:10px; margin-bottom:20px; flex-wrap:wrap;">
    <a href="registrations.php?filter=paid" class="btn btn-sm <?= ($filter==='paid'?'btn-gold':'btn-outline') ?>">
        ✓ Paid & Approved (<?= $counts['paid'] ?>)
    </a>
    <a href="registrations.php?filter=pending" class="btn btn-sm <?= ($filter==='pending'?'btn-gold':'btn-outline') ?>">
        ⏳ Pending Payment (<?= $counts['pending'] ?>)
    </a>
    <a href="registrations.php?filter=failed" class="btn btn-sm <?= ($filter==='failed'?'btn-gold':'btn-outline') ?>">
        ❌ Failed Payments (<?= $counts['failed'] ?>)
    </a>
    <a href="registrations.php?filter=all" class="btn btn-sm <?= ($filter==='all'?'btn-gold':'btn-outline') ?>">
        All Records (<?= $counts['all'] ?>)
    </a>
</div>

<div class="card">
    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Team Name</th>
                    <th>Ward</th>
                    <th>Coach</th>
                    <th>Payment Ref / Receipt</th>
                    <th>Payment Status</th>
                    <th>Approval Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach($registrations as $r): 
                    $isCash = str_starts_with($r['paymentReceiptRef'] ?? '', 'CASH-');
                    $payStat = $r['paymentStatus'] ?? ($isCash || $r['status']==='approved' ? 'completed' : 'pending');
                ?>
                <tr>
                    <td><small style="color:var(--slate)"><?= e(date('M d, H:i', strtotime($r['requestDate']))) ?></small></td>
                    <td><strong style="color:var(--white)"><?= e($r['teamName']) ?></strong></td>
                    <td><?= e($r['wardName']) ?></td>
                    <td><?= e($r['coachName']) ?></td>
                    <td>
                        <?php if ($isCash): ?>
                            <span class="badge badge-gold">💵 <?= e($r['paymentReceiptRef']) ?></span>
                        <?php else: ?>
                            <code style="font-size:11px"><?= e($r['paymentReceiptRef']) ?></code>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?php if ($payStat === 'completed' || $isCash): ?>
                            <span class="badge badge-green">✓ Paid</span>
                        <?php elseif ($payStat === 'failed'): ?>
                            <span class="badge badge-red">❌ Failed</span>
                        <?php else: ?>
                            <span class="badge badge-gold">⏳ Pending</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?php if ($r['status'] === 'approved'): ?>
                            <span class="badge badge-green">Approved</span>
                        <?php else: ?>
                            <span class="badge badge-gray">Awaiting Approval</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <div style="display:flex; gap:6px; flex-wrap:wrap;">
                            <?php if ($r['status'] === 'pending'): ?>
                                <button class="btn btn-sm btn-gold" onclick="openApproveModal('<?= e($r['id']) ?>', '<?= e($r['teamName']) ?>')">
                                    <span class="material-icons-round">check</span> Approve
                                </button>
                            <?php endif; ?>

                            <?php if (!$isCash && $payStat !== 'completed'): ?>
                                <form method="post" style="display:inline">
                                    <input type="hidden" name="action" value="verify_payment">
                                    <input type="hidden" name="id" value="<?= e($r['id']) ?>">
                                    <button class="btn btn-sm btn-outline" type="submit" title="Check PayChangu API status">
                                        <span class="material-icons-round">sync</span> Verify PayChangu
                                    </button>
                                </form>
                            <?php endif; ?>

                            <form method="post" style="display:inline" onsubmit="return confirm('Delete this registration record?');">
                                <input type="hidden" name="action" value="delete_reg">
                                <input type="hidden" name="id" value="<?= e($r['id']) ?>">
                                <button class="btn btn-sm btn-danger" type="submit" title="Delete record">
                                    <span class="material-icons-round">delete</span>
                                </button>
                            </form>
                        </div>
                    </td>
                </tr>
                <?php endforeach; ?>
                <?php if (empty($registrations)): ?>
                <tr>
                    <td colspan="8" style="text-align:center; padding:24px; color:var(--slate);">No registration records found for this filter tab.</td>
                </tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<!-- Modal 1: Register Cash-Paid Team (Admin Direct Entry) -->
<div id="cashRegisterModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.6); z-index:9999; align-items:center; justify-content:center;">
    <div style="background:var(--card); width:460px; padding:24px; border-radius:12px; border:1px solid var(--border); max-height:90vh; overflow-y:auto;">
        <h3 style="margin-bottom:6px; color:var(--white);">Register Cash Payment Team</h3>
        <p style="font-size:12px; color:var(--slate); margin-bottom:18px;">Register a team that paid cash directly to Admin. This will approve them and generate their portal credentials instantly.</p>
        
        <form method="post" action="registrations.php">
            <input type="hidden" name="action" value="register_cash">

            <div class="form-group" style="margin-bottom:12px;">
                <label>Team Name *</label>
                <input type="text" name="teamName" id="cashTeamName" required placeholder="e.g. Ndirande Strikers FC" oninput="autoGenerateCashCredentials()">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Ward Name</label>
                <input type="text" name="wardName" placeholder="e.g. Ndirande Ward">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Coach Name</label>
                <input type="text" name="coachName" placeholder="e.g. Coach Isaac Chirwa">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Assign League</label>
                <select name="leagueId" id="cashLeagueSelect" onchange="document.getElementById('cashLeagueNameInput').value = this.options[this.selectedIndex].text">
                    <option value="">(Select League...)</option>
                    <?php foreach($leagues as $L): ?>
                    <option value="<?= e($L['id']) ?>"><?= e($L['name']) ?></option>
                    <?php endforeach; ?>
                </select>
                <input type="hidden" name="leagueName" id="cashLeagueNameInput" value="">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Cash Receipt / Reference #</label>
                <input type="text" name="receiptRef" id="cashReceiptRef" placeholder="e.g. CASH-8492">
            </div>

            <div style="background:rgba(210,176,89,.08); border:1px solid rgba(210,176,89,.2); border-radius:8px; padding:12px; margin-bottom:16px;">
                <div style="font-size:11px; font-weight:700; color:var(--gold); text-transform:uppercase; margin-bottom:8px;">Assign Team Portal Credentials</div>
                <div class="form-group" style="margin-bottom:10px;">
                    <label>Team Username</label>
                    <input type="text" name="username" id="cashUsername" required placeholder="e.g. ndirande_strikers">
                </div>
                <div class="form-group">
                    <label>Team Password</label>
                    <input type="text" name="password" id="cashPassword" required placeholder="Team login password">
                </div>
            </div>

            <div style="display:flex; gap:10px; justify-content:flex-end;">
                <button type="button" class="btn btn-outline" onclick="document.getElementById('cashRegisterModal').style.display='none'">Cancel</button>
                <button type="submit" class="btn btn-gold">Approve & Register Team</button>
            </div>
        </form>
    </div>
</div>

<!-- Modal 2: Approve Existing Pending Online Registration -->
<div id="approveModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.6); z-index:9999; align-items:center; justify-content:center;">
    <div style="background:var(--card); width:420px; padding:24px; border-radius:12px; border:1px solid var(--border);">
        <h3 style="margin-bottom:16px; color:var(--white);" id="approveTitle">Approve Team</h3>
        <form method="post" action="registrations.php">
            <input type="hidden" name="action" value="approve">
            <input type="hidden" name="id" id="approveId">

            <div class="form-group" style="margin-bottom:12px;">
                <label>Assign Username</label>
                <input type="text" name="username" required placeholder="e.g. mtandire_eagles" id="approveUsername">
            </div>
            <div class="form-group" style="margin-bottom:16px;">
                <label>Assign Password</label>
                <input type="text" name="password" required placeholder="Temporary password" id="approvePassword">
            </div>
            <div class="form-group" style="margin-bottom:20px;">
                <label>Assign League</label>
                <select name="leagueId" id="approveLeague" onchange="document.getElementById('approveLeagueName').value=this.options[this.selectedIndex].text">
                  <option value="">(None)</option>
                  <?php foreach($leagues as $L): ?>
                  <option value="<?= e($L['id']) ?>"><?= e($L['name']) ?></option>
                  <?php endforeach; ?>
                </select>
                <input type="hidden" name="leagueName" id="approveLeagueName" value="" />
            </div>

            <div style="display:flex; gap:10px; justify-content:flex-end;">
                <button type="button" class="btn btn-outline" onclick="document.getElementById('approveModal').style.display='none'">Cancel</button>
                <button type="submit" class="btn btn-gold">Approve & Save Credentials</button>
            </div>
        </form>
    </div>
</div>

<script>
function openCashRegisterModal() {
    document.getElementById('cashReceiptRef').value = 'CASH-' + Math.floor(1000 + Math.random() * 9000);
    document.getElementById('cashPassword').value = 'Naysa' + Math.floor(1000 + Math.random() * 9000);
    document.getElementById('cashRegisterModal').style.display = 'flex';
}

function autoGenerateCashCredentials() {
    const name = document.getElementById('cashTeamName').value;
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_').replace(/^_+|_+$/g, '');
    document.getElementById('cashUsername').value = slug;
}

function openApproveModal(id, teamName) {
    document.getElementById('approveId').value = id;
    document.getElementById('approveTitle').innerText = 'Approve: ' + teamName;
    const genUser = teamName.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_').replace(/^_+|_+$/g, '');
    document.getElementById('approveUsername').value = genUser;
    document.getElementById('approvePassword').value = 'Naysa' + Math.floor(1000 + Math.random() * 9000);
    document.getElementById('approveModal').style.display = 'flex';
}
</script>

<?php require __DIR__.'/footer.php'; ?>
