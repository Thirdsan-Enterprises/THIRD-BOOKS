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

if (isset($_GET['list'])) {
    $out = [];
    foreach ($files as $f) {
        $json = json_decode(file_get_contents($f), true);
        $out[] = [
            'file'      => basename($f),
            'synced_at' => date('c', filemtime($f)),
            'size_kb'   => round(filesize($f) / 1024, 1),
            'journals'  => $json['counts']['journals'] ?? null,
            'customers' => $json['counts']['customers'] ?? null,
            'invoices'  => $json['counts']['invoices'] ?? null,
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
    'latest_file' => basename($latest),
    'synced_at'   => date('c', filemtime($latest)),
    'size_kb'     => round(filesize($latest) / 1024, 1),
    'counts'      => (json_decode(file_get_contents($latest), true) ?? [])['counts'] ?? null,
    'total_backups' => count($files),
], JSON_PRETTY_PRINT);
