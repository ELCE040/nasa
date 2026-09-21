<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Sponsors & Ads';
$pdo = db();

// Auto-migrate to add image/link support
try {
    $pdo->query("ALTER TABLE sponsorships ADD COLUMN imageUrl TEXT, ADD COLUMN linkUrl TEXT");
} catch(Exception $e) {}

$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    
    // Handle banner upload
    $imageUrl = $_POST['existingImageUrl'] ?? null;
    if (!empty($_FILES['banner']['tmp_name'])) {
        $dir = __DIR__ . '/../backend/uploads/';
        if (!is_dir($dir)) mkdir($dir, 0777, true);
        $ext = pathinfo($_FILES['banner']['name'], PATHINFO_EXTENSION);
        $filename = 'sponsor_' . time() . '_' . rand(100,999) . '.' . $ext;
        if (move_uploaded_file($_FILES['banner']['tmp_name'], $dir . $filename)) {
            $imageUrl = '/backend/uploads/' . $filename;
        }
    }

    if ($op==='create') {
        $nid = 's'.uniqid();
        $pdo->prepare('INSERT INTO sponsorships (id,sponsorName,isDiaspora,type,targetName,amountMwk,message,date,imageUrl,linkUrl) VALUES (?,?,?,?,?,?,?,NOW(),?,?)')
            ->execute([$nid,$_POST['sponsorName'],$_POST['isDiaspora']??0,
                       $_POST['type'],$_POST['targetName'],$_POST['amountMwk'],$_POST['message'], $imageUrl, $_POST['linkUrl']]);
        flash('success','Sponsor added! They will appear in the app ads section.');
        header('Location: sponsors.php'); exit;
    }
    if ($op==='update') {
        $pdo->prepare('UPDATE sponsorships SET sponsorName=?,isDiaspora=?,type=?,targetName=?,amountMwk=?,message=?,imageUrl=?,linkUrl=? WHERE id=?')
            ->execute([$_POST['sponsorName'],$_POST['isDiaspora']??0,$_POST['type'],
                       $_POST['targetName'],$_POST['amountMwk'],$_POST['message'], $imageUrl, $_POST['linkUrl'], $_POST['id']]);
        flash('success','Sponsor updated!');
        header('Location: sponsors.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM sponsorships WHERE id=?')->execute([$_POST['id']]);
        flash('success','Sponsor removed.');
        header('Location: sponsors.php'); exit;
    }
}

$types = ['teamAdoption'=>'Team Adoption','tournamentPrizePool'=>'Tournament Prize Pool','kitSponsorship'=>'Kit Sponsorship'];

if ($action==='edit' && $id) {
    $sponsor = $pdo->prepare('SELECT * FROM sponsorships WHERE id=?');
    $sponsor->execute([$id]);
    $sponsor = $sponsor->fetch();
}

$teams = $pdo->query('SELECT name FROM teams ORDER BY name')->fetchAll(PDO::FETCH_COLUMN);

require __DIR__.'/header.php';
?>

<div style="background:rgba(210,176,89,.08);border:1px solid rgba(210,176,89,.3);border-radius:12px;padding:14px 18px;margin-bottom:20px;display:flex;align-items:center;gap:10px;font-size:13px;color:#D2B059">
  <span class="material-icons-round">info</span>
  Sponsors added here appear in the <strong>Ads / Sponsors section</strong> of the mobile app. Diaspora sponsors get a special badge.
</div>

<?php if ($action==='add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Add New Sponsor</span><a href="sponsors.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" enctype="multipart/form-data">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Sponsor / Company Name *</label><input name="sponsorName" required/></div>
      <div class="form-group"><label>Sponsorship Type *</label>
        <select name="type" required>
          <?php foreach($types as $k=>$v): ?><option value="<?= $k ?>"><?= $v ?></option><?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Target (Team / Tournament)</label>
        <input list="team-list" name="targetName" placeholder="e.g. Nancholi Warriors FC"/>
        <datalist id="team-list">
          <?php foreach($teams as $t): ?><option value="<?= e($t) ?>"/><?php endforeach; ?>
        </datalist>
      </div>
      <div class="form-group"><label>Amount (MWK)</label><input type="number" step="0.01" name="amountMwk" value="0"/></div>
      <div class="form-group">
        <label>Diaspora Sponsor?</label>
        <select name="isDiaspora">
          <option value="0">No — Local Business</option>
          <option value="1">Yes — Diaspora (abroad)</option>
        </select>
      </div>
      <div class="form-group"><label>Link URL (App/Social Media)</label><input type="url" name="linkUrl" placeholder="https://..."/></div>
      <div class="form-group"><label>Image Banner (Shown in App Ads)</label><input type="file" name="banner" accept="image/*"/></div>
      
      <div class="form-group" style="grid-column:1/-1"><label>Sponsor Message / Tagline (shown in app)</label>
        <textarea name="message" placeholder="e.g. Proud supporter of youth football in Nancholi!"></textarea>
      </div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">handshake</span>Add Sponsor</button>
      <a href="sponsors.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>

<?php elseif ($action==='edit' && isset($sponsor)): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Edit Sponsor — <?= e($sponsor['sponsorName']) ?></span><a href="sponsors.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" enctype="multipart/form-data">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($sponsor['id']) ?>"/>
    <input type="hidden" name="existingImageUrl" value="<?= e($sponsor['imageUrl'] ?? '') ?>"/>
    <div class="form-grid">
      <div class="form-group"><label>Sponsor Name</label><input name="sponsorName" value="<?= e($sponsor['sponsorName']) ?>"/></div>
      <div class="form-group"><label>Type</label>
        <select name="type">
          <?php foreach($types as $k=>$v): ?>
          <option value="<?= $k ?>" <?= $sponsor['type']===$k?'selected':'' ?>><?= $v ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Target</label><input list="team-list" name="targetName" value="<?= e($sponsor['targetName']) ?>"/>
        <datalist id="team-list"><?php foreach($teams as $t): ?><option value="<?= e($t) ?>"/><?php endforeach; ?></datalist>
      </div>
      <div class="form-group"><label>Amount (MWK)</label><input type="number" step="0.01" name="amountMwk" value="<?= e($sponsor['amountMwk']) ?>"/></div>
      <div class="form-group"><label>Diaspora?</label>
        <select name="isDiaspora">
          <option value="0" <?= !$sponsor['isDiaspora']?'selected':'' ?>>No</option>
          <option value="1" <?= $sponsor['isDiaspora']?'selected':'' ?>>Yes</option>
        </select>
      </div>
      <div class="form-group"><label>Link URL</label><input type="url" name="linkUrl" value="<?= e($sponsor['linkUrl'] ?? '') ?>"/></div>
      <div class="form-group"><label>Image Banner (Replace existing)</label><input type="file" name="banner" accept="image/*"/>
        <?php if(!empty($sponsor['imageUrl'])): ?>
          <small style="color:#4ade80">Current: <?= e($sponsor['imageUrl']) ?></small>
        <?php endif; ?>
      </div>
      <div class="form-group" style="grid-column:1/-1"><label>Message</label><textarea name="message"><?= e($sponsor['message']) ?></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Save Changes</button>
      <a href="sponsors.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>

<?php else: ?>
<div class="section-header">
  <span class="section-title">Sponsors & Advertisers (<?= $pdo->query('SELECT COUNT(*) FROM sponsorships')->fetchColumn() ?>)</span>
  <a href="sponsors.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>Add Sponsor</a>
</div>
<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>Sponsor</th><th>Type</th><th>Target</th><th>Amount (MWK)</th><th>Diaspora</th><th>Date</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach($pdo->query('SELECT * FROM sponsorships ORDER BY date DESC')->fetchAll() as $s): ?>
    <tr>
      <td>
        <?php if(!empty($s['imageUrl'])): ?>
          <img src="<?= e($s['imageUrl']) ?>" style="height:40px;border-radius:4px;vertical-align:middle;margin-right:10px;">
        <?php endif; ?>
        <div style="display:inline-block;vertical-align:middle;">
          <strong style="color:#fff"><?= e($s['sponsorName']) ?></strong><br>
          <small style="color:#8BA3B8"><?= e($s['message']) ?></small>
          <?php if(!empty($s['linkUrl'])): ?>
            <br><a href="<?= e($s['linkUrl']) ?>" target="_blank" style="color:#4ade80;font-size:11px;">View Link ↗</a>
          <?php endif; ?>
        </div>
      </td>
      <td><span class="badge badge-gold"><?= e($types[$s['type']] ?? $s['type']) ?></span></td>
      <td><?= e($s['targetName']) ?></td>
      <td><strong style="color:#4ade80"><?= number_format($s['amountMwk'],2) ?></strong></td>
      <td><?= $s['isDiaspora']?'<span class="badge badge-blue">🌍 Diaspora</span>':'<span class="badge badge-gray">Local</span>' ?></td>
      <td style="color:#8BA3B8"><?= date('d M Y', strtotime($s['date'])) ?></td>
      <td>
        <a href="sponsors.php?action=edit&id=<?= e($s['id']) ?>" class="btn btn-outline btn-sm"><span class="material-icons-round">edit</span></a>
        <form method="post" style="display:inline" onsubmit="return confirm('Remove sponsor?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($s['id']) ?>"/>
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
