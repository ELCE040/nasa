<?php
require_once __DIR__.'/config.php';
require_once __DIR__.'/migrate_officials.php';
require_once __DIR__.'/migrate_competitions.php';

function requireAuth(): void {
    if (empty($_SESSION['admin_logged_in'])) {
        header('Location: index.php'); exit;
    }
}

function requireSuperAdmin(): void {
    requireAuth();
    if (($_SESSION['admin_role'] ?? 'superadmin') !== 'superadmin') {
        flash('error', 'Access restricted to Superadmin only.');
        header('Location: matches.php'); exit;
    }
}

function isOfficial(): bool {
    return ($_SESSION['admin_role'] ?? '') === 'official';
}

function getOfficialLeagueId(): ?string {
    return $_SESSION['admin_league_id'] ?? null;
}

function getOfficialLeagueName(): ?string {
    return $_SESSION['admin_league_name'] ?? null;
}

function logout(): void {
    session_destroy();
    header('Location: index.php'); exit;
}
