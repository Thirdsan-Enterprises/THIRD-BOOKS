<?php
// ── push.php — desktop app calls this on every launch ────────────────────────
// POST /push.php   Header: X-API-Key: <key>   Body: backup JSON

require 'config.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['error' => 'POST required']));
}

if (($key = $_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

$body = file_get_contents('php://input');
if (!$body) {
    http_response_code(400);
    die(json_encode(['error' => 'Empty body']));
}

$data = json_decode($body, true);
if (!$data || ($data['app'] ?? '') !== APP_TAG) {
    http_response_code(422);
    die(json_encode(['error' => 'Invalid ThirdBooks backup format']));
}

if (!is_dir(BACKUP_DIR)) mkdir(BACKUP_DIR, 0755, true);

$filename = BACKUP_DIR . date('Y-m-d_H-i-s') . '_backup.json';
file_put_contents($filename, $body);

// Prune oldest backups beyond MAX_BACKUPS
$files = glob(BACKUP_DIR . '*_backup.json');
if ($files && count($files) > MAX_BACKUPS) {
    sort($files);
    foreach (array_slice($files, 0, count($files) - MAX_BACKUPS) as $old) {
        unlink($old);
    }
}

echo json_encode([
    'status'    => 'ok',
    'saved_at'  => date('c'),
    'records'   => $data['counts'] ?? [],
]);
