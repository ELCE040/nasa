<?php
require_once __DIR__.'/config.php';
$pdo = db();

try {
    $id = 'ptest' . time();
    $name = 'Test Player';
    $age = 20;
    $position = 'Striker';
    $teamId = 't123';
    $teamName = 'Test Team';
    $wardName = 'Test Ward';
    $jerseyNumber = 10;
    $preferredFoot = 'Right';
    $heightM = 1.75;
    $bio = 'Test bio';
    $imageUrl = null;

    $stmt = $pdo->prepare("INSERT INTO players (id, name, age, position, teamId, teamName, wardName, jerseyNumber, preferredFoot, heightM, bio, imageUrl) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");
    
    $stmt->execute([
        $id, $name, $age, $position, $teamId, $teamName, $wardName, $jerseyNumber, $preferredFoot, $heightM, $bio, $imageUrl
    ]);

    echo "<h2 style='color:green'>✅ Insert successful!</h2>";
    
    // Clean up
    $pdo->exec("DELETE FROM players WHERE id = '$id'");
    
} catch (PDOException $e) {
    echo "<h2 style='color:red'>❌ Insert failed: " . htmlspecialchars($e->getMessage()) . "</h2>";
} catch (Exception $e) {
    echo "<h2 style='color:red'>❌ Error: " . htmlspecialchars($e->getMessage()) . "</h2>";
}
?>
