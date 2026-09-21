<?php
require_once __DIR__.'/config.php';
$pdo = db();

$sql = "
CREATE TABLE IF NOT EXISTS team_registrations (
  id VARCHAR(64) PRIMARY KEY,
  teamName VARCHAR(255) NOT NULL,
  wardName VARCHAR(255) NOT NULL,
  coachName VARCHAR(255) NOT NULL,
  paymentReceiptRef VARCHAR(255),
  status ENUM('pending','approved','rejected') DEFAULT 'pending',
  requestDate DATETIME DEFAULT NOW()
);
";

try {
    $pdo->exec($sql);
    echo '<h2 style="color:green">✅ team_registrations table created successfully!</h2>';
    echo '<p>You can now delete this file.</p>';
} catch (PDOException $e) {
    echo '<h2 style="color:red">❌ Error: ' . htmlspecialchars($e->getMessage()) . '</h2>';
}
?>
