<?php
// ── one-off: move my own test pushes (journals < 100) out of the active
// backups/ folder into quarantine/, so the real 07 Jul backup with
// journals=13323 becomes "latest" again.
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

$quarantineDir = BACKUP_DIR . 'quarantine/';
if (!is_dir($quarantineDir)) mkdir($quarantineDir, 0755, true);

$files = glob(BACKUP_DIR . '*_backup.json') ?: [];
$moved = [];
$kept  = [];

foreach ($files as $f) {
    $journals = quickCount($f, 'journals');
    if ($journals !== null && $journals < 100) {
        $dest = $quarantineDir . basename($f);
        rename($f, $dest);
        $moved[] = basename($f);
    } else {
        $kept[] = ['file' => basename($f), 'journals' => $journals];
    }
}

echo json_encode(['moved_to_quarantine' => $moved, 'kept_active' => $kept], JSON_PRETTY_PRINT);
