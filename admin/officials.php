<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();

$pdo = db();
$pageTitle = 'Officials & Admin Users';

// Fetch leagues for dropdown
$leagues = $pdo->query('SELECT * FROM leagues ORDER BY name')->fetchAll();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'create') {
        $name     = trim($_POST['name'] ?? '');
        $username = trim($_POST['username'] ?? '');
        $password = trim($_POST['password'] ?? '');
        $role     = $_POST['role'] ?? 'official';
        $leagueId = $_POST['leagueId'] ?: null;
        $leagueName = $_POST['leagueName'] ?: null;

        if (empty($name) || empty($username) || empty($password)) {
            flash('error', 'Please fill in all required fields.');
        } else {
            try {
                // Check username unique
                $check = $pdo->prepare('SELECT COUNT(*) FROM admin_users WHERE username = ?');
                $check->execute([$username]);
                if ($check->fetchColumn() > 0) {
                    flash('error', "Username '$username' is already taken.");
                } else {
                    $uid = 'u_'.uniqid();
                    $hash = password_hash($password, PASSWORD_DEFAULT);

                    $stmt = $pdo->prepare('INSERT INTO admin_users (id, username, password, name, role, leagueId, leagueName) VALUES (?, ?, ?, ?, ?, ?, ?)');
                    $stmt->execute([$uid, $username, $hash, $name, $role, $leagueId, $leagueName]);

                    flash('success', "Official <strong>" . e($name) . "</strong> created successfully! Login: <strong>" . e($username) . "</strong> / <strong>" . e($password) . "</strong>");
                    header('Location: officials.php');
                    exit;
                }
            } catch (PDOException $e) {
                flash('error', 'Database error: ' . $e->getMessage());
            }
        }
    }

    if ($action === 'delete') {
        $id = $_POST['id'] ?? '';
        if ($id === ($_SESSION['admin_user_id'] ?? '')) {
            flash('error', 'You cannot delete your own account while logged in.');
        } else {
            $pdo->prepare('DELETE FROM admin_users WHERE id = ?')->execute([$id]);
            flash('success', 'User deleted successfully.');
        }
        header('Location: officials.php');
        exit;
    }
}

$users = $pdo->query('SELECT * FROM admin_users ORDER BY createdAt DESC')->fetchAll();
require __DIR__.'/header.php';
?>

<div class="section-header">
    <span class="section-title">Officials & Admin Accounts (<?= count($users) ?>)</span>
    <button class="btn btn-gold" onclick="document.getElementById('addOfficialModal').style.display='flex'">
        <span class="material-icons-round">person_add</span> Add New Official / Admin
    </button>
</div>

<div class="card">
    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Username</th>
                    <th>Role</th>
                    <th>Assigned League</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($users as $u): ?>
                <tr>
                    <td><strong style="color:var(--white)"><?= e($u['name']) ?></strong></td>
                    <td><code><?= e($u['username']) ?></code></td>
                    <td>
                        <?php if ($u['role'] === 'superadmin'): ?>
                            <span class="badge badge-blue">Superadmin</span>
                        <?php else: ?>
                            <span class="badge badge-gold">League Official</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?= $u['leagueName'] ? e($u['leagueName']) : '<span style="color:var(--slate)">(All Leagues)</span>' ?>
                    </td>
                    <td><small style="color:var(--slate)"><?= date('d M Y', strtotime($u['createdAt'])) ?></small></td>
                    <td>
                        <?php if ($u['id'] !== ($_SESSION['admin_user_id'] ?? '')): ?>
                        <form method="post" style="display:inline;" onsubmit="return confirm('Delete official <?= e($u['name']) ?>?');">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="<?= e($u['id']) ?>">
                            <button class="btn btn-danger btn-sm" type="submit">
                                <span class="material-icons-round">delete</span>
                            </button>
                        </form>
                        <?php else: ?>
                            <small style="color:var(--slate)">You</small>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
                <?php if (empty($users)): ?>
                <tr>
                    <td colspan="6" style="text-align:center; padding:20px; color:var(--slate);">No officials found.</td>
                </tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<!-- Modal: Add New Official -->
<div id="addOfficialModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.6); z-index:9999; align-items:center; justify-content:center;">
    <div style="background:var(--card); width:440px; padding:24px; border-radius:12px; border:1px solid var(--border);">
        <h3 style="margin-bottom:16px; color:var(--white);">Add Official / Admin User</h3>
        <form method="post" action="officials.php">
            <input type="hidden" name="action" value="create">

            <div class="form-group" style="margin-bottom:12px;">
                <label>Full Name *</label>
                <input type="text" name="name" required placeholder="e.g. Official Felix Banda">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Username *</label>
                <input type="text" name="username" required placeholder="e.g. felix_official">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Password *</label>
                <input type="text" name="password" required placeholder="Assign password">
            </div>

            <div class="form-group" style="margin-bottom:12px;">
                <label>Role</label>
                <select name="role" id="roleSelect" onchange="toggleLeagueField()">
                    <option value="official">League Official (Restricted access)</option>
                    <option value="superadmin">Superadmin (Full system access)</option>
                </select>
            </div>

            <div class="form-group" id="leagueGroup" style="margin-bottom:20px;">
                <label>Assigned League *</label>
                <select name="leagueId" id="leagueIdSelect" onchange="document.getElementById('leagueNameInput').value = this.options[this.selectedIndex].text">
                    <option value="">Select League...</option>
                    <?php foreach ($leagues as $L): ?>
                    <option value="<?= e($L['id']) ?>"><?= e($L['name']) ?></option>
                    <?php endforeach; ?>
                </select>
                <input type="hidden" name="leagueName" id="leagueNameInput" value="">
            </div>

            <div style="display:flex; gap:10px; justify-content:flex-end;">
                <button type="button" class="btn btn-outline" onclick="document.getElementById('addOfficialModal').style.display='none'">Cancel</button>
                <button type="submit" class="btn btn-gold">Create Account</button>
            </div>
        </form>
    </div>
</div>

<script>
function toggleLeagueField() {
    const role = document.getElementById('roleSelect').value;
    const lg = document.getElementById('leagueGroup');
    if (role === 'superadmin') {
        lg.style.display = 'none';
        document.getElementById('leagueIdSelect').required = false;
    } else {
        lg.style.display = 'flex';
        document.getElementById('leagueIdSelect').required = true;
    }
}
toggleLeagueField();
</script>

<?php require __DIR__.'/footer.php'; ?>
