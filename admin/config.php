<?php
define('DB_HOST', 'localhost');
define('DB_USER', 'nayshzoc_naysa_user');
define('DB_PASS', 'Naysa2026!');
define('DB_NAME', 'nayshzoc_nasa_db');

define('ADMIN_USER', 'admin');
define('ADMIN_PASS', 'NaysaAdmin2026!'); // Change this!

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
            DB_USER, DB_PASS,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
             PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
        );
    }
    return $pdo;
}

function uid(): string {
    return uniqid('', true);
}

function flash(string $key, string $msg = ''): string {
    if ($msg) { $_SESSION['flash'][$key] = $msg; return ''; }
    $v = $_SESSION['flash'][$key] ?? '';
    unset($_SESSION['flash'][$key]);
    return $v;
}

function e(mixed $v): string {
    return htmlspecialchars((string)($v ?? ''), ENT_QUOTES);
}

session_start();
