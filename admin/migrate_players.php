<?php
require_once __DIR__.'/config.php';
$pdo = db();

// 1. Create uploads directory if it doesn't exist
$uploadDir = dirname(__DIR__) . '/naysa_backend/uploads';
// Try alternate common paths
$paths = [
    '/home/nayshzoc/naysa_backend/uploads',
    dirname(__DIR__) . '/uploads',
    __DIR__ . '/../uploads',
];

$madeDir = false;
foreach ($paths as $p) {
    if (is_dir($p)) { echo "<p style='color:green'>✅ uploads dir exists: $p</p>"; $madeDir = true; break; }
    if (@mkdir($p, 0755, true)) { echo "<p style='color:green'>✅ Created uploads dir: $p</p>"; $madeDir = true; break; }
}
if (!$madeDir) echo "<p style='color:orange'>⚠️ Could not auto-create uploads dir. Create it manually at: /home/nayshzoc/naysa_backend/uploads</p>";

// 2. Fix players table - add missing columns using SHOW COLUMNS (MySQL compatible)
$neededCols = [
    'imageUrl'      => 'TEXT DEFAULT NULL',
    'parentPhone'   => 'VARCHAR(50) DEFAULT NULL',
    'bio'           => 'TEXT DEFAULT NULL',
    'heightM'       => 'DECIMAL(4,2) DEFAULT NULL',
    'preferredFoot' => "VARCHAR(20) DEFAULT 'Right'",
    'jerseyNumber'  => 'INT DEFAULT 0',
];

$existingCols = $pdo->query("SHOW COLUMNS FROM players")->fetchAll(PDO::FETCH_COLUMN);

foreach ($neededCols as $col => $def) {
    if (!in_array($col, $existingCols)) {
        try {
            $pdo->exec("ALTER TABLE players ADD COLUMN `$col` $def");
            echo "<p style='color:green'>✅ Added column: $col</p>";
        } catch (PDOException $e) {
            echo "<p style='color:red'>❌ Failed to add $col: " . htmlspecialchars($e->getMessage()) . "</p>";
        }
    } else {
        echo "<p style='color:#aaa'>— Column already exists: $col</p>";
    }
}

echo '<h2 style="color:green;margin-top:20px">✅ Done! Delete this file now.</h2>';
?>
