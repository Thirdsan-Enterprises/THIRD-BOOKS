<?php
// ── request_sync.php — admin dashboard action: "pull her data now" ──────────
// POST only, requires an authenticated admin dashboard session (not the app's
// API key — this is triggered by a person in the browser, not the app).
//
// Writes a small flag file the desktop app's regular heartbeat checks (see
// heartbeat.php). The app is a local-first desktop client with no inbound
// connection — the server can't reach out to it directly — so this is a
// request the app picks up on its own next check-in (every ~10 minutes, or
// immediately on next launch), not an instant push. push.php clears the flag
// once a fresh backup actually arrives.

require 'config.php';
session_start();
header('Content-Type: application/json');

if (empty($_SESSION['tb_user']) || ($_SESSION['tb_role'] ?? '') !== 'admin') {
    http_response_code(403);
    die(json_encode(['error' => 'Admin login required']));
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['error' => 'POST required']));
}

if (!is_dir(BACKUP_DIR)) mkdir(BACKUP_DIR, 0755, true);
file_put_contents(BACKUP_DIR . 'force_sync.json', json_encode([
    'requested_at' => date('c'),
    'requested_by' => $_SESSION['tb_name'] ?? $_SESSION['tb_user'],
]));

echo json_encode(['status' => 'ok']);
