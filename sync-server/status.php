<?php
// ── status.php — read-only latest-backup summary, API-key protected.
// Lets us verify backup health without a browser session.
require 'config.php';
header('Content-Type: application/json');

if (($_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

$files = glob(BACKUP_DIR . '*_backup.json') ?: [];
rsort($files);

// Cheap textual extraction from just the "counts" header block near the
// top of the file — avoids json_decode()'ing multi-MB backups, which can
// exceed PHP's memory_limit (same lesson as cleanup.php earlier).
function quickCount($file, $key) {
    $head = file_get_contents($file, false, null, 0, 8192);
    if ($head === false) return null;
    if (preg_match('/"' . preg_quote($key, '/') . '"\s*:\s*(\d+)/', $head, $m)) {
        return (int) $m[1];
    }
    return null;
}

if (isset($_GET['list'])) {
    $out = [];
    foreach ($files as $f) {
        $out[] = [
            'file'      => basename($f),
            'synced_at' => date('c', filemtime($f)),
            'size_kb'   => round(filesize($f) / 1024, 1),
            'journals'  => quickCount($f, 'journals'),
            'customers' => quickCount($f, 'customers'),
            'invoices'  => quickCount($f, 'invoices'),
        ];
    }
    echo json_encode($out, JSON_PRETTY_PRINT);
    exit;
}

$latest = $files[0] ?? null;

if (!$latest) {
    echo json_encode(['latest' => null]);
    exit;
}

echo json_encode([
    'latest_file'   => basename($latest),
    'synced_at'     => date('c', filemtime($latest)),
    'size_kb'       => round(filesize($latest) / 1024, 1),
    'journals'      => quickCount($latest, 'journals'),
    'customers'     => quickCount($latest, 'customers'),
    'invoices'      => quickCount($latest, 'invoices'),
    'total_backups' => count($files),
], JSON_PRETTY_PRINT);
