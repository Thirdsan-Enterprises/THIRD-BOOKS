<?php
// ── pull.php — any authorised machine downloads the latest backup ─────────────
// GET /pull.php   Header: X-API-Key: <key>

require 'config.php';

header('Content-Type: application/json');

if (($key = $_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

$files = glob(BACKUP_DIR . '*_backup.json');
if (!$files) {
    http_response_code(404);
    die(json_encode(['error' => 'No backup found on server']));
}

rsort($files);
$latest = $files[0];

header('Content-Type: application/json');
header('X-Backup-Date: ' . date('c', filemtime($latest)));
header('X-Backup-Size: ' . filesize($latest));
readfile($latest);
