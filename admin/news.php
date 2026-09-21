<?php
require_once __DIR__.'/auth.php';
requireSuperAdmin();
$pageTitle = 'News';
$pdo = db();

// Auto-migrate to add imageUrl column
try { $pdo->query("ALTER TABLE news ADD COLUMN imageUrl TEXT"); } catch(Exception $e) {}

$action = $_GET['action'] ?? 'list';
$id     = $_GET['id'] ?? '';

if ($_SERVER['REQUEST_METHOD']==='POST') {
    $op = $_POST['op'] ?? '';

    // Handle image upload
    $imageUrl = $_POST['existingImageUrl'] ?? null;
    if (!empty($_FILES['banner']['tmp_name'])) {
        $dir = __DIR__ . '/../backend/uploads/';
        if (!is_dir($dir)) mkdir($dir, 0777, true);
        $ext = pathinfo($_FILES['banner']['name'], PATHINFO_EXTENSION);
        $filename = 'news_' . time() . '_' . rand(100,999) . '.' . $ext;
        if (move_uploaded_file($_FILES['banner']['tmp_name'], $dir . $filename)) {
            $imageUrl = '/backend/uploads/' . $filename;
        }
    }

    if ($op==='create') {
        $nid = 'n'.uniqid();
        $pdo->prepare('INSERT INTO news (id,title,summary,body,date,category,author,imageUrl) VALUES (?,?,?,?,NOW(),?,?,?)')
            ->execute([$nid,$_POST['title'],$_POST['summary'],$_POST['body'],$_POST['category'],$_POST['author'],$imageUrl]);
        flash('success','Article published!');
        header('Location: news.php'); exit;
    }
    if ($op==='update') {
        $pdo->prepare('UPDATE news SET title=?,summary=?,body=?,category=?,author=?,imageUrl=? WHERE id=?')
            ->execute([$_POST['title'],$_POST['summary'],$_POST['body'],$_POST['category'],$_POST['author'],$imageUrl,$_POST['id']]);
        flash('success','Article updated!');
        header('Location: news.php'); exit;
    }
    if ($op==='delete') {
        $pdo->prepare('DELETE FROM news WHERE id=?')->execute([$_POST['id']]);
        flash('success','Article deleted.');
        header('Location: news.php'); exit;
    }
}

$categories = ['Match Report','Announcement','Tournament','Player Spotlight','Club News','Transfer News'];
if ($action==='edit' && $id) {
    $article = $pdo->prepare('SELECT * FROM news WHERE id=?');
    $article->execute([$id]);
    $article = $article->fetch();
}
require __DIR__.'/header.php';
?>
<?php if ($action==='add'): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Publish Article</span><a href="news.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" enctype="multipart/form-data">
    <input type="hidden" name="op" value="create"/>
    <div class="form-grid">
      <div class="form-group" style="grid-column:1/-1"><label>Headline *</label><input name="title" required/></div>
      <div class="form-group"><label>Category</label>
        <select name="category"><?php foreach($categories as $c): ?><option><?= $c ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Author</label><input name="author" value="NAYSA Admin"/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Cover Image</label>
        <input type="file" name="banner" accept="image/*"/>
        <small style="color:#8BA3B8">Shown as the article cover photo in the app.</small>
      </div>
      <div class="form-group" style="grid-column:1/-1"><label>Summary (shown in preview)</label><textarea name="summary" style="min-height:60px"></textarea></div>
      <div class="form-group" style="grid-column:1/-1"><label>Full Article Body</label><textarea name="body" style="min-height:160px"></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit"><span class="material-icons-round">publish</span>Publish</button>
      <a href="news.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<?php elseif ($action==='edit' && isset($article)): ?>
<div class="card">
  <div class="section-header"><span class="section-title">Edit Article</span><a href="news.php" class="btn btn-outline btn-sm">← Back</a></div>
  <form method="post" enctype="multipart/form-data">
    <input type="hidden" name="op" value="update"/>
    <input type="hidden" name="id" value="<?= e($article['id']) ?>"/>
    <input type="hidden" name="existingImageUrl" value="<?= e($article['imageUrl'] ?? '') ?>"/>
    <div class="form-grid">
      <div class="form-group" style="grid-column:1/-1"><label>Headline</label><input name="title" value="<?= e($article['title']) ?>"/></div>
      <div class="form-group"><label>Category</label>
        <select name="category"><?php foreach($categories as $c): ?><option <?= $article['category']===$c?'selected':'' ?>><?= $c ?></option><?php endforeach; ?></select>
      </div>
      <div class="form-group"><label>Author</label><input name="author" value="<?= e($article['author']) ?>"/></div>
      <div class="form-group" style="grid-column:1/-1"><label>Cover Image (Replace existing)</label>
        <input type="file" name="banner" accept="image/*"/>
        <?php if(!empty($article['imageUrl'])): ?>
          <div style="margin-top:8px">
            <img src="<?= e($article['imageUrl']) ?>" style="height:80px;border-radius:6px;object-fit:cover;">
            <small style="display:block;color:#4ade80;margin-top:4px">Current cover image</small>
          </div>
        <?php endif; ?>
      </div>
      <div class="form-group" style="grid-column:1/-1"><label>Summary</label><textarea name="summary"><?= e($article['summary']) ?></textarea></div>
      <div class="form-group" style="grid-column:1/-1"><label>Body</label><textarea name="body" style="min-height:160px"><?= e($article['body']) ?></textarea></div>
    </div>
    <div class="form-actions">
      <button class="btn btn-gold" type="submit">Update Article</button>
      <a href="news.php" class="btn btn-outline">Cancel</a>
    </div>
  </form>
</div>
<?php else: ?>
<div class="section-header">
  <span class="section-title">News & Announcements (<?= $pdo->query('SELECT COUNT(*) FROM news')->fetchColumn() ?>)</span>
  <a href="news.php?action=add" class="btn btn-gold"><span class="material-icons-round">add</span>Write Article</a>
</div>
<div class="card">
  <div class="table-wrap">
  <table>
    <thead><tr><th>Headline</th><th>Category</th><th>Author</th><th>Date</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach($pdo->query('SELECT * FROM news ORDER BY date DESC')->fetchAll() as $n): ?>
    <tr>
      <td>
        <?php if(!empty($n['imageUrl'])): ?>
          <img src="<?= e($n['imageUrl']) ?>" style="height:40px;width:60px;border-radius:4px;object-fit:cover;vertical-align:middle;margin-right:10px;">
        <?php endif; ?>
        <div style="display:inline-block;vertical-align:middle;">
          <strong style="color:#fff"><?= e($n['title']) ?></strong><br>
          <small style="color:#8BA3B8"><?= e(substr($n['summary']??'',0,80)) ?>...</small>
        </div>
      </td>
      <td><span class="badge badge-blue"><?= e($n['category']) ?></span></td>
      <td><?= e($n['author']) ?></td>
      <td style="color:#8BA3B8"><?= date('d M Y', strtotime($n['date'])) ?></td>
      <td>
        <a href="news.php?action=edit&id=<?= e($n['id']) ?>" class="btn btn-outline btn-sm"><span class="material-icons-round">edit</span></a>
        <form method="post" style="display:inline" onsubmit="return confirm('Delete article?')">
          <input type="hidden" name="op" value="delete"/>
          <input type="hidden" name="id" value="<?= e($n['id']) ?>"/>
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
