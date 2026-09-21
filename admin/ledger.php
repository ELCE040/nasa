<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'Finance Ledger';
$pdo = db();

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';
    if ($op==='create') {
        $pdo->prepare('INSERT INTO ledger (id,date,description,type,category,amountMwk) VALUES (?,NOW(),?,?,?,?)')
            ->execute(['l'.uniqid(),$_POST['description'],$_POST['type'],$_POST['category'],$_POST['amountMwk']]);
        flash('success','Entry recorded!');
        header('Location: ledger.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM ledger WHERE id=?')->execute([$_POST['id']]);
        flash('success','Entry removed.');
        header('Location: ledger.php'); exit;
    }
}

$income  = $pdo->query("SELECT COALESCE(SUM(amountMwk),0) FROM ledger WHERE type='income'")->fetchColumn();
$expense = $pdo->query("SELECT COALESCE(SUM(amountMwk),0) FROM ledger WHERE type='expense'")->fetchColumn();
$balance = $income - $expense;
$entries = $pdo->query('SELECT * FROM ledger ORDER BY date DESC')->fetchAll();
$categories = ['Sponsorship','Registration Fee','Transfer Commission','Equipment','Travel','Medical','Salaries','Other'];

require __DIR__.'/header.php';
?>
<!-- Summary strip -->
<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:24px;">
  <div class="card" style="border-color:rgba(74,222,128,.3);padding:16px">
    <div style="font-size:11px;color:#8BA3B8;text-transform:uppercase;margin-bottom:4px">Income</div>
    <div style="font-size:20px;font-weight:900;color:#4ade80">MWK <?= number_format($income,2) ?></div>
  </div>
  <div class="card" style="border-color:rgba(239,68,68,.3);padding:16px">
    <div style="font-size:11px;color:#8BA3B8;text-transform:uppercase;margin-bottom:4px">Expenses</div>
    <div style="font-size:20px;font-weight:900;color:#f87171">MWK <?= number_format($expense,2) ?></div>
  </div>
  <div class="card" style="border-color:<?= $balance>=0?'rgba(74,222,128,.3)':'rgba(239,68,68,.3)' ?>;padding:16px">
    <div style="font-size:11px;color:#8BA3B8;text-transform:uppercase;margin-bottom:4px">Net Balance</div>
    <div style="font-size:20px;font-weight:900;color:<?= $balance>=0?'#4ade80':'#f87171' ?>">MWK <?= number_format($balance,2) ?></div>
  </div>
</div>

<!-- Add entry form -->
<div class="card" style="margin-bottom:20px">
  <div class="section-title" style="margin-bottom:16px">Record Transaction</div>
  <form method="post">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group"><label>Type</label>
        <select name="type">
          <option value="income">💰 Income</option>
          <option value="expense">💸 Expense</option>
        </select>
      </div>
      <div class="form-group"><label>Category</label>
        <select name="category"><?php foreach($categories as $c): ?><option><?= $c ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Amount (MWK)</label><input type="number" step="0.01" name="amountMwk" required/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Description</label><input name="description" required/></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">add</span>Record</button>
    </div>
  </form>
</div>

<!-- Ledger table -->
<div class="card">
  <div class="section-title" style="margin-bottom:16px">All Transactions (<?= count($entries) ?>)</div>
  <div class="table-wrap">
  <table>
    <thead><tr><th>Date</th><th>Description</th><th>Category</th><th>Type</th><th>Amount</th><th></th></tr></thead>
    <tbody>
    <?php foreach($entries as $en): ?>
    <tr>
      <td style="color:#8BA3B8"><?= date('d M Y', strtotime($en['date'])) ?></td>
      <td><?= e($en['description']) ?></td>
      <td><span class="badge badge-gray"><?= e($en['category']) ?></span></td>
      <td><?= $en['type']==='income'?'<span class="badge badge-green">Income</span>':'<span class="badge badge-red">Expense</span>' ?></td>
      <td style="font-weight:700;color:<?= $en['type']==='income'?'#4ade80':'#f87171' ?>">
        <?= $en['type']==='income'?'+':'-' ?> MWK <?= number_format($en['amountMwk'],2) ?>
      </td>
      <td>
        <form method="post" style="display:inline" onsubmit="return confirm('Delete entry?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($en['id']) ?>"/>
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
