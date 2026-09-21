<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Referees';
$pdo = db();
$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    if ($op==='create') {
        $pdo->prepare('INSERT INTO referees (id,name,matchesOfficiated,avgFairness,avgCommunication) VALUES (?,?,?,?,?)')
            ->execute(['r'.uniqid(),$_POST['name'],$_POST['matchesOfficiated']??0,0,0]);
        flash('success','Referee added!');
        header('Location: referees.php'); exit;
    }
    if ($op==='update') {
        $pdo->prepare('UPDATE referees SET name=?,matchesOfficiated=? WHERE id=?')
            ->execute([$_POST['name'],$_POST['matchesOfficiated']??0,$_POST['id']]);
        flash('success','Referee updated!');
        header('Location: referees.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM referees WHERE id=?')->execute([$_POST['id']]);
        flash('success','Referee removed.');
        header('Location: referees.php'); exit;
    }
}
if ($action==='edit' && $id) {
    $ref = $pdo->prepare('SELECT * FROM referees WHERE id=?');
    $ref->execute([$id]);
    $ref = $ref->fetch();
}
require __DIR__.'/header.php';
?>
<?php if ($action==='add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Register Referee</span><a href="referees.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Full Name *</label><input name="name" required/></div>
      <div class="form-group"><label>Matches Officiated</label><input type="number" name="matchesOfficiated" value="0"/></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">person_add</span>Register</button>
      <a href="referees.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<?php elseif ($action==='edit' && isset($ref)): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Edit Referee</span><a href="referees.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($ref['id']) ?>"/>
    <div class="form-grid">
      <div class="form-group"><label>Full Name</label><input name="name" value="<?= e($ref['name']) ?>"/></div>
      <div class="form-group"><label>Matches Officiated</label><input type="number" name="matchesOfficiated" value="<?= e($ref['matchesOfficiated']??0) ?>"/></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Save</button>
      <a href="referees.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<?php else: ?>
<div class="section-header">
  <span class="section-title">Referees (<?= $pdo->query('SELECT COUNT(*) FROM referees')->fetchColumn() ?>)</span>
  <a href="referees.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>Add Referee</a>
</div>
<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>Name</th><th>Matches</th><th>Avg Fairness</th><th>Avg Communication</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach($pdo->query('SELECT * FROM referees ORDER BY name')->fetchAll() as $r): ?>
    <tr>
      <td><strong style="color:#fff"><?= e($r['name']) ?></strong></td>
      <td><?= e($r['matchesOfficiated']??0) ?></td>
      <td><?php $f=round($r['avgFairness']??0,1); echo '<span style="color:'.($f>=4?'#4ade80':($f>=3?'#D2B059':'#f87171')).'">'.$f.'/5</span>'; ?></td>
      <td><?php $c=round($r['avgCommunication']??0,1); echo '<span style="color:'.($c>=4?'#4ade80':($c>=3?'#D2B059':'#f87171')).'">'.$c.'/5</span>'; ?></td>
      <td>
        <a href="referees.php?action=edit&id=<?= e($r['id']) ?>" class="btn btn-outline btn-sm"><span class="material-icons-round">edit</span></a>
        <form method="post" style="display:inline" onsubmit="return confirm('Delete referee?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($r['id']) ?>"/>
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
