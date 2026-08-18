<?php
// ============================================================
//  BearsNPRMP — Web Panel Built-in Server Router
// ============================================================

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if (str_starts_with($uri, '/api')) {
    require_once __DIR__ . '/api.php';
    exit;
}

if ($uri !== '/' && file_exists(__DIR__ . $uri)) {
    return false; // Serve static file as-is
}

require_once __DIR__ . '/index.php';
