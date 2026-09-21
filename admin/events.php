<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Events';
$pdo = db();
$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    if ($op==='create') {
        $nid = 'ev'.uniqid();
        $pdo->prepare('INSERT INTO events (id,title,description,date,venue,wardName,type) VALUES (?,?,?,?,?,?,?)')
            ->execute([$nid,$_POST['title'],$_POST['description'],$_POST['date']?:null,$_POST['venue'],$_POST['wardName'],$_POST['type']]);
        flash('success','Event created!');
        header('Location: events.php'); exit;
    }
    if ($op==='update') {
        $pdo->prepare('UPDATE events SET title=?,description=?,date=?,venue=?,wardName=?,type=? WHERE id=?')
            ->execute([$_POST['title'],$_POST['description'],$_POST['date']?:null,$_POST['venue'],$_POST['wardName'],$_POST['type'],$_POST['id']]);
        flash('success','Event updated!');
        header('Location: events.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM events WHERE id=?')->execute([$_POST['id']]);
        flash('success','Event deleted.');
        header('Location: events.php'); exit;
    }
}

$types = ['tournament','trial','festival','coachingClinic'];
$wards = ['Nancholi','Chilomoni','Zingwangwa','Ndirande','Bangwe','Mchesi','Kanjedza'];

if ($action==='edit' && $id) {
    $event = $pdo->prepare('SELECT * FROM events WHERE id=?');
    $event->execute([$id]);
    $event = $event->fetch();
}
require __DIR__.'/header.php';
?>
<?php if ($action==='add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Create Event</span><a href="events.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group" style="grid-column:1/-1"><label>Event Title *</label><input name="title" required/></div>
      <div class="form-group"><label>Type</label>
        <select name="type"><?php foreach($types as $t): ?><option><?= $t ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Ward</label>
        <select name="wardName"><?php foreach($wards as $w): ?><option><?= $w ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Venue</label><input name="venue"/></div>
      <div class="form-group"><label>Date</label><input type="datetime-local" name="date"/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Description</label><textarea name="description" style="min-height:100px"></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">event</span>Create Event</button>
      <a href="events.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<?php elseif ($action==='edit' && isset($event)): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Edit Event</span><a href="events.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" action="events.php">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($event['id']) ?>"/>
    <div class="form-grid">
      <div class="form-group" style="grid-column:1/-1"><label>Title</label><input name="title" value="<?= e($event['title']) ?>"/></div>
      <div class="form-group"><label>Type</label>
        <select name="type"><?php foreach($types as $t): ?><option <?= $event['type']===$t?'selected':'' ?>><?= $t ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Ward</label>
        <select name="wardName"><?php foreach($wards as $w): ?><option <?= $event['wardName']===$w?'selected':'' ?>><?= $w ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Venue</label><input name="venue" value="<?= e($event['venue']) ?>"/></div>
      <div class="form-group"><label>Date</label><input type="datetime-local" name="date" value="<?= $event['date'] ? date('Y-m-d\TH:i', strtotime($event['date'])) : '' ?>"/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Description</label><textarea name="description" style="min-height:100px"><?= e($event['description']) ?></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Save Changes</button>
      <a href="events.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<?php else: ?>
<div class="section-header">
  <span class="section-title">Events (<?= $pdo->query('SELECT COUNT(*) FROM events')->fetchColumn() ?>)</span>
  <a href="events.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>Create Event</a>
</div>
<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>Event</th><th>Type</th><th>Ward</th><th>Venue</th><th>Date</th><th>Actions</th></tr></thead>
    <tbody>
    <?php $typeBadge=['tournament'=>'badge-gold','trial'=>'badge-blue','festival'=>'badge-green','coachingClinic'=>'badge-blue']; ?>
    <?php foreach($pdo->query('SELECT * FROM events ORDER BY date DESC')->fetchAll() as $ev): ?>
    <tr>
      <td><strong style="color:#fff"><?= e($ev['title']) ?></strong><br><small style="color:#8BA3B8"><?= e(substr($ev['description']??'',0,60)) ?>...</small></td>
      <td><span class="badge <?= $typeBadge[$ev['type']]??'badge-gray' ?>"><?= e($ev['type']) ?></span></td>
      <td><?= e($ev['wardName']) ?></td>
      <td><?= e($ev['venue']) ?></td>
      <td style="color:#8BA3B8"><?= $ev['date'] ? date('d M Y', strtotime($ev['date'])) : 'TBD' ?></td>
      <td>
        <a href="events.php?action=edit&id=<?= e($ev['id']) ?>" class="btn btn-outline btn-sm"><span class="material-icons-round">edit</span></a>
        <form method="post" style="display:inline" onsubmit="return confirm('Delete event?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($ev['id']) ?>"/>
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
