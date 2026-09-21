<?php
require_once __DIR__.'/config.php';
$pdo = db();

try {
    $pdo->exec("ALTER TABLE match_events ADD COLUMN assistName VARCHAR(255) DEFAULT NULL, ADD COLUMN isPenalty TINYINT(1) DEFAULT 0");
    echo "match_events table updated successfully.<br>";
} catch (PDOException $e) {
    echo "match_events update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("ALTER TABLE matches ADD COLUMN phase VARCHAR(50) DEFAULT 'First Half'");
    echo "matches table updated successfully.<br>";
} catch (PDOException $e) {
    echo "matches update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("ALTER TABLE leagues ADD COLUMN format VARCHAR(50) DEFAULT 'league'");
    echo "leagues table updated with format.<br>";
} catch (PDOException $e) {
    echo "leagues format update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("ALTER TABLE matches ADD COLUMN stage VARCHAR(50) DEFAULT 'League Match', ADD COLUMN groupName VARCHAR(50) DEFAULT NULL");
    echo "matches table updated with stage and groupName.<br>";
} catch (PDOException $e) {
    echo "matches stage/groupName update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("ALTER TABLE teams ADD COLUMN groupName VARCHAR(50) DEFAULT NULL");
    echo "teams table updated with groupName.<br>";
} catch (PDOException $e) {
    echo "teams groupName update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("ALTER TABLE teams ADD COLUMN isExternal TINYINT(1) NOT NULL DEFAULT 0");
    echo "teams table updated with isExternal.<br>";
} catch (PDOException $e) {
    echo "teams isExternal update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("ALTER TABLE matches ADD COLUMN isPrivate TINYINT(1) NOT NULL DEFAULT 0");
    echo "matches table updated with isPrivate.<br>";
} catch (PDOException $e) {
    echo "matches isPrivate update skipped or failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS app_active_sessions (
      deviceId VARCHAR(100) PRIMARY KEY,
      role VARCHAR(50) DEFAULT 'viewer',
      platform VARCHAR(50) DEFAULT 'mobile',
      appVersion VARCHAR(50) DEFAULT '1.0.0',
      firstSeen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      lastPing DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_lastPing (lastPing)
    )");
    echo "app_active_sessions table created/verified successfully.<br>";
} catch (PDOException $e) {
    echo "app_active_sessions creation failed: " . htmlspecialchars($e->getMessage()) . "<br>";
}

echo "<br><b>Migration complete!</b>";

