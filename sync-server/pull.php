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

// Lightweight preview: record counts only, without downloading the full
// (potentially many-MB) backup — lets the app show "this is what you're
// about to restore" before committing to an irreversible overwrite.
if (isset($_GET['preview'])) {
    // Read just enough of the file to get the 'counts' block near the top,
    // rather than json_decode()'ing the whole thing (can be 20MB+).
    $head = file_get_contents($latest, false, null, 0, 8192);
    $counts = null;
    if ($head !== false && preg_match('/"counts"\s*:\s*(\{[^}]*\})/', $head, $m)) {
        $counts = json_decode($m[1], true);
    }
    echo json_encode([
        'synced_at' => date('c', filemtime($latest)),
        'size_kb'   => round(filesize($latest) / 1024, 1),
        'counts'    => $counts,
    ]);
    exit;
}

header('Content-Type: application/json');
header('X-Backup-Date: ' . date('c', filemtime($latest)));
header('X-Backup-Size: ' . filesize($latest));
readfile($latest);
