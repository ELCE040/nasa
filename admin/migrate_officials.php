<?php
require_once __DIR__.'/config.php';

function initAdminUsersTable(): void {
    $pdo = db();
    try {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS admin_users (
                id VARCHAR(50) PRIMARY KEY,
                username VARCHAR(100) NOT NULL UNIQUE,
                password VARCHAR(255) NOT NULL,
                name VARCHAR(255) NOT NULL,
                role ENUM('superadmin', 'official') DEFAULT 'official',
                leagueId VARCHAR(50) DEFAULT NULL,
                leagueName VARCHAR(255) DEFAULT NULL,
                createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        ");

        // Seed default superadmin if empty
        $count = (int)$pdo->query("SELECT COUNT(*) FROM admin_users")->fetchColumn();
        if ($count === 0) {
            $defaultPass = password_hash(ADMIN_PASS, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare("INSERT INTO admin_users (id, username, password, name, role) VALUES (?, ?, ?, ?, ?)");
            $stmt->execute(['u_admin_master', ADMIN_USER, $defaultPass, 'Super Admin', 'superadmin']);
        }
    } catch (PDOException $e) {
        // Table created or error handled
    }
}

initAdminUsersTable();
