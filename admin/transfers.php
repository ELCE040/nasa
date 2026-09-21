<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Transfers';
$pdo = db();

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    if ($op==='create') {
        $player = $pdo->prepare('SELECT name FROM players WHERE id=?');
        $player->execute([$_POST['playerId']]);
        $player = $player->fetch();
        $pdo->prepare('INSERT INTO transfers (id,playerId,playerName,sellingTeam,buyingTeam,agreedFeeMwk,commissionPercent,status,date) VALUES (?,?,?,?,?,?,15,"awaitingPayment",NOW())')
            ->execute(['tr'.uniqid(),$_POST['playerId'],$player['name']??'Unknown',
                       $_POST['sellingTeam'],$_POST['buyingTeam'],$_POST['agreedFeeMwk']]);
        flash('success','Transfer initiated!');
        header('Location: transfers.php'); exit;
    }
    if ($op==='advance') {
        $t = $pdo->prepare('SELECT status FROM transfers WHERE id=?');
        $t->execute([$_POST['id']]);
        $t = $t->fetch();
        $next = ['awaitingPayment'=>'fundsHeld','fundsHeld'=>'clearanceReleased','clearanceReleased'=>'completed'];
        if (isset($next[$t['status']])) {
            $pdo->prepare('UPDATE transfers SET status=? WHERE id=?')->execute([$next[$t['status']],$_POST['id']]);
            flash('success','Transfer status advanced!');
        }
        header('Location: transfers.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM transfers WHERE id=?')->execute([$_POST['id']]);
        flash('success','Transfer removed.');
        header('Location: transfers.php'); exit;
    }
}
$players = $pdo->query('SELECT id,name,teamName FROM players ORDER BY name')->fetchAll();
$teams   = $pdo->query('SELECT name FROM teams ORDER BY name')->fetchAll(PDO::FETCH_COLUMN);
$statuses= ['awaitingPayment'=>['Awaiting Payment','badge-blue'],
            'fundsHeld'=>['Funds Held','badge-gold'],
            'clearanceReleased'=>['Clearance Released','badge-green'],
            'completed'=>['Completed','badge-gray']];
require __DIR__.'/header.php';
?>
<div class="section-header" style="margin-bottom:20px">
  <span class="section-title">Transfer Escrow</span>
</div>

<div class="card" style="margin-bottom:20px">
  <div class="section-title" style="margin-bottom:16px">Initiate Transfer</div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Player *</label>
        <select name="playerId" required><option value="">Select player...</option>
          <?php foreach($players as $p): ?><option value="<?= e($p['id']) ?>"><?= e($p['name']) ?> (<?= e($p['teamName']) ?>)</option><?php endforeach; ?>
        </select>
      </div>
      <div class="form-group"><label>Selling Team *</label>
        <input list="team-list" name="sellingTeam" required/>
        <datalist id="team-list"><?php foreach($teams as $t): ?><option value="<?= e($t) ?>"/><?php endforeach; ?></datalist>
      </div>
      <div class="form-group"><label>Buying Team *</label><input list="team-list" name="buyingTeam" required/></div>
      <div class="form-group"><label>Agreed Fee (MWK)</label><input type="number" step="0.01" name="agreedFeeMwk" required/></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">swap_horiz</span>Initiate Transfer</button>
    </div>
  </form>
</div>

<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>Player</th><th>Selling Club</th><th>Buying Club</th><th>Fee (MWK)</th><th>Commission</th><th>Status</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach($pdo->query('SELECT * FROM transfers ORDER BY date DESC')->fetchAll() as $tr):
      $comm = $tr['agreedFeeMwk'] * ($tr['commissionPercent']/100);
      [$sl,$sc] = $statuses[$tr['status']] ?? ['Unknown','badge-gray'];
    ?>
    <tr>
      <td><strong style="color:#fff"><?= e($tr['playerName']) ?></strong></td>
      <td><?= e($tr['sellingTeam']) ?></td>
      <td><?= e($tr['buyingTeam']) ?></td>
      <td><strong style="color:#D2B059"><?= number_format($tr['agreedFeeMwk'],2) ?></strong></td>
      <td style="color:#8BA3B8"><?= number_format($comm,2) ?> (<?= $tr['commissionPercent'] ?>%)</td>
      <td><span class="badge <?= $sc ?>"><?= $sl ?></span></td>
      <td style="display:flex;gap:6px;align-items:center">
        <?php if ($tr['status']!=='completed'): ?>
        <form method="post"><input type="hidden" name="op" value="advance"/>
          <input type="hidden" name="id" value="<?= e($tr['id']) ?>"/>
          <button class="btn btn-outline btn-sm" type="submit" title="Advance status">→</button>
        </form>
        <?php endif; ?>
        <form method="post" onsubmit="return confirm('Delete?')"><input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($tr['id']) ?>"/>
          <button class="btn btn-danger btn-sm" type="submit"><span class="material-icons-round">delete</span></button>
        </form>
      </td>
    </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
  </div>
</div>
<?php require __DIR__.'/footer.php'; ?>
