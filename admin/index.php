<?php
require_once __DIR__.'/config.php';
require_once __DIR__.'/migrate_officials.php';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $u = trim($_POST['username'] ?? '');
    $p = $_POST['password'] ?? '';
    
    $pdo = db();
    $stmt = $pdo->prepare("SELECT * FROM admin_users WHERE username = ?");
    $stmt->execute([$u]);
    $user = $stmt->fetch();
    
    $authenticated = false;
    if ($user) {
        if (password_verify($p, $user['password'])) {
            $authenticated = true;
        } elseif ($p === $user['password']) {
            // Upgrade plain password to hash
            $newHash = password_hash($p, PASSWORD_DEFAULT);
            $pdo->prepare("UPDATE admin_users SET password = ? WHERE id = ?")->execute([$newHash, $user['id']]);
            $authenticated = true;
        }
    } elseif ($u === ADMIN_USER && $p === ADMIN_PASS) {
        // Fallback for default config admin
        $authenticated = true;
        $user = [
            'id' => 'u_admin_master',
            'username' => ADMIN_USER,
            'name' => 'Super Admin',
            'role' => 'superadmin',
            'leagueId' => null,
            'leagueName' => null
        ];
    }
    
    if ($authenticated && $user) {
        $_SESSION['admin_logged_in'] = true;
        $_SESSION['admin_user_id'] = $user['id'];
        $_SESSION['admin_user'] = $user['username'];
        $_SESSION['admin_name'] = $user['name'] ?? $user['username'];
        $_SESSION['admin_role'] = $user['role'] ?? 'superadmin';
        $_SESSION['admin_league_id'] = $user['leagueId'] ?? null;
        $_SESSION['admin_league_name'] = $user['leagueName'] ?? null;
        
        if (($user['role'] ?? '') === 'official') {
            header('Location: matches.php'); exit;
        } else {
            header('Location: dashboard.php'); exit;
        }
    }
    $loginError = 'Invalid credentials. Please try again.';
}
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>NAYSA Admin — Login</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/icon?family=Material+Icons+Round" rel="stylesheet"/>
<style>
*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:'Inter',sans-serif;background:#081C30;min-height:100vh;
  display:flex;align-items:center;justify-content:center;
  background-image:radial-gradient(ellipse at 20% 50%,rgba(14,51,87,.6) 0%,transparent 60%),
    radial-gradient(ellipse at 80% 20%,rgba(210,176,89,.08) 0%,transparent 50%);
}
.login-card{
  background:#0D2540;border:1px solid #1A3A5C;border-radius:20px;
  padding:48px 40px;width:100%;max-width:420px;
  box-shadow:0 24px 80px rgba(0,0,0,.5);
}
.logo-wrap{text-align:center;margin-bottom:32px;}
.logo-img{width:72px;height:72px;border-radius:16px;
  background:rgba(210,176,89,.15);border:2px solid #D2B059;
  padding:10px;margin:0 auto 14px;display:flex;align-items:center;justify-content:center;}
.logo-img img{width:100%;height:100%;object-fit:contain;}
.logo-title{font-size:24px;font-weight:900;letter-spacing:2px;color:#fff;}
.logo-sub{font-size:12px;color:#D2B059;font-weight:600;letter-spacing:1px;margin-top:4px;}
.form-group{margin-bottom:18px;}
label{display:block;font-size:11px;font-weight:700;color:#D2B059;
  text-transform:uppercase;letter-spacing:.7px;margin-bottom:6px;}
input{width:100%;background:rgba(255,255,255,.05);border:1px solid #1A3A5C;
  border-radius:10px;padding:13px 16px;color:#fff;font-size:15px;font-family:'Inter',sans-serif;
  outline:none;transition:border .15s;}
input:focus{border-color:#D2B059;}
.btn-login{
  width:100%;background:#D2B059;color:#000;border:none;border-radius:10px;
  padding:14px;font-size:15px;font-weight:800;cursor:pointer;letter-spacing:.5px;
  transition:background .15s;margin-top:8px;
}
.btn-login:hover{background:#e6c86a;}
.error{background:rgba(239,68,68,.1);color:#f87171;border:1px solid rgba(239,68,68,.3);
  border-radius:8px;padding:10px 14px;font-size:13px;margin-bottom:16px;
  display:flex;align-items:center;gap:8px;}
.input-wrap{position:relative;}
.input-icon{position:absolute;right:14px;top:50%;transform:translateY(-50%);
  color:#8BA3B8;font-size:20px;}
</style>
</head>
<body>
<div class="login-card">
  <div class="logo-wrap">
    <div class="logo-img">
      <img src="assets/logo.png" onerror="this.src=''" alt="NAYSA"/>
    </div>
    <div class="logo-title">NAYSA</div>
    <div class="logo-sub">Admin & Officials Portal</div>
  </div>
  <?php if(!empty($loginError)): ?>
  <div class="error">
    <span class="material-icons-round" style="font-size:18px">error</span>
    <?= htmlspecialchars($loginError) ?>
  </div>
  <?php endif; ?>
  <form method="post">
    <div class="form-group">
      <label>Username</label>
      <div class="input-wrap">
        <input type="text" name="username" required autocomplete="username"
          value="<?= htmlspecialchars($_POST['username'] ?? '') ?>"/>
        <span class="input-icon material-icons-round">person</span>
      </div>
    </div>
    <div class="form-group">
      <label>Password</label>
      <div class="input-wrap">
        <input type="password" name="password" required autocomplete="current-password"/>
        <span class="input-icon material-icons-round">lock</span>
      </div>
    </div>
    <button class="btn-login" type="submit">SIGN IN →</button>
  </form>
</div>
</body>
</html>
