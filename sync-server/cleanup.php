<?php
// ── cleanup.php — one-off: remove test/junk backups that have no real
// chart-of-accounts data (i.e. not a genuine ThirdBooks backup), so
// "latest backup" on the dashboard points at real data again. Safe by
// design: only deletes files where data.accounts is missing or empty —
// every real backup always has actual accounts in it.
require 'config.php';
header('Content-Type: application/json');

if (($_SERVER['HTTP_X_API_KEY'] ?? '') !== API_KEY) {
    http_response_code(401);
    die(json_encode(['error' => 'Unauthorized']));
}

$deleted = [];
$kept = [];

foreach (glob(BACKUP_DIR . '*_backup.json') as $file) {
    $size = filesize($file);
    $isJunk = false;

    if ($size === false || $size < 2000) {
        // Too small to possibly contain a real chart of accounts.
        $isJunk = true;
    } else {
        // Cheap textual check on just the first chunk — avoids json_decode
        // on multi-MB files, which can exceed PHP's memory_limit.
        $head = file_get_contents($file, false, null, 0, 65536);
        if ($head === false || strpos($head, '"accounts":[{') === false) {
            $isJunk = true;
        }
    }

    if ($isJunk) {
        unlink($file);
        $deleted[] = basename($file);
    } else {
        $kept[] = basename($file);
    }
}

echo json_encode(['deleted' => $deleted, 'kept' => $kept], JSON_PRETTY_PRINT);
