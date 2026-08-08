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
    $raw = file_get_contents($file);
    $json = json_decode($raw, true);

    $isJunk = false;
    if ($json === null) {
        $isJunk = true;
    } elseif (
        !isset($json['data']['accounts']) ||
        !is_array($json['data']['accounts']) ||
        count($json['data']['accounts']) === 0
    ) {
        $isJunk = true;
    }

    if ($isJunk) {
        unlink($file);
        $deleted[] = basename($file);
    } else {
        $kept[] = basename($file);
    }
}

echo json_encode(['deleted' => $deleted, 'kept' => $kept], JSON_PRETTY_PRINT);
