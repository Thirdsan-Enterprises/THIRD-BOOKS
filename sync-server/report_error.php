<?php
// ── report_error.php — desktop app reports a notable local error ────────────
// POST /report_error.php   Header: X-API-Key: <key>   Body: {kind, message, context?}
//
// Lets whoever has server access see what's going wrong on a remote machine
// without waiting on a screenshot or a WhatsApp message — the app calls this
// itself, right where it already knows something failed (a sync error, a
// corrupted local file, etc). Never blocks or affects the app if it fails;
// same "fire and forget" spirit as heartbeat.php.

require 'config.php';
header('Content-Type: application/json');

if (($_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['error' => 'POST required']));
}

$body = json_decode(file_get_contents('php://input'), true) ?? [];

$entry = [
    'at'      => date('c'),
    'ts'      => time(),
    'kind'    => substr(strip_tags((string)($body['kind'] ?? 'unknown')), 0, 64),
    'message' => substr(strip_tags((string)($body['message'] ?? '')), 0, 1000),
    'user'    => substr(strip_tags((string)($body['user'] ?? 'unknown')), 0, 64),
    'context' => is_array($body['context'] ?? null) ? $body['context'] : null,
];

if (!is_dir(BACKUP_DIR)) mkdir(BACKUP_DIR, 0755, true);
$logFile = BACKUP_DIR . 'client_errors.jsonl';

// Append this entry, then keep only the most recent MAX_ERROR_LOG_LINES —
// a client that's erroring in a loop should never be able to grow this file
// without bound on a shared host.
const MAX_ERROR_LOG_LINES = 300;
$lines = [];
if (file_exists($logFile)) {
    $lines = file($logFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
}
$lines[] = json_encode($entry);
if (count($lines) > MAX_ERROR_LOG_LINES) {
    $lines = array_slice($lines, -MAX_ERROR_LOG_LINES);
}
file_put_contents($logFile, implode("\n", $lines) . "\n");

echo json_encode(['status' => 'ok']);
