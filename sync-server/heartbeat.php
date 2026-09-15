<?php
// ── heartbeat.php — lightweight ping from the desktop app ────────────────────
require 'config.php';
header('Content-Type: application/json');

if (($_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

$body = json_decode(file_get_contents('php://input'), true) ?? [];

$data = [
    'at'   => date('c'),
    'ts'   => time(),
    'user' => substr(strip_tags($body['user'] ?? 'unknown'), 0, 64),
    'ip'   => $_SERVER['REMOTE_ADDR'],
];

if (!is_dir(BACKUP_DIR)) mkdir(BACKUP_DIR, 0755, true);
file_put_contents(BACKUP_DIR . 'heartbeat.json', json_encode($data));

// An admin clicked "Request Sync Now" on the dashboard since this app last
// pushed — tell it to push right away instead of waiting for its normal
// 20-minute timer. push.php clears this flag once a fresh backup lands.
$forcePush = file_exists(BACKUP_DIR . 'force_sync.json');

echo json_encode(['status' => 'ok', 'at' => $data['at'], 'force_push' => $forcePush]);
