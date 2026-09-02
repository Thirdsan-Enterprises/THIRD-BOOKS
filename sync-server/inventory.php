<?php
// ── inventory.php — temporary, read-only listing of all backups with
// cheap journal-count extraction (no full json_decode on large files).
require 'config.php';
header('Content-Type: application/json');

if (($_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

function quickCount($file, $key) {
    $head = file_get_contents($file, false, null, 0, 8192);
    if ($head === false) return null;
    if (preg_match('/"' . preg_quote($key, '/') . '"\s*:\s*(\d+)/', $head, $m)) {
        return (int) $m[1];
    }
    return null;
}

$files = glob(BACKUP_DIR . '*_backup.json') ?: [];
rsort($files);
$out = [];
foreach ($files as $f) {
    $out[] = [
        'file'      => basename($f),
        'synced_at' => date('c', filemtime($f)),
        'size_kb'   => round(filesize($f) / 1024, 1),
        'journals'  => quickCount($f, 'journals'),
    ];
}

$quarantineDir = BACKUP_DIR . 'quarantine/';
$qFiles = is_dir($quarantineDir) ? (glob($quarantineDir . '*_backup.json') ?: []) : [];
$qOut = [];
foreach ($qFiles as $f) {
    $qOut[] = [
        'file'      => basename($f),
        'synced_at' => date('c', filemtime($f)),
        'journals'  => quickCount($f, 'journals'),
    ];
}

echo json_encode(['active' => $out, 'quarantined' => $qOut], JSON_PRETTY_PRINT);
