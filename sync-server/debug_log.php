<?php
// ── debug_log.php — one-shot cleanup for the temporary push.php diagnostic.
//
// This file used to serve debug_log.txt while the sync 500 was being traced.
// That investigation is finished (cause: json_decode() on the full backup
// exhausting memory_limit — see push.php), and the logging has been removed,
// but debug_log.txt is already sitting in the web root on the live host and
// nothing else can reach in to remove it. Hitting this once deletes the log
// and then this file itself, leaving no diagnostic residue on the server.
header('Content-Type: text/plain');

if (($_GET['token'] ?? '') !== 'tmp-debug-2026-09-09') {
    http_response_code(403);
    die('forbidden');
}

$log = __DIR__ . '/debug_log.txt';
echo file_exists($log)
    ? (@unlink($log) ? "debug_log.txt deleted\n" : "FAILED to delete debug_log.txt\n")
    : "debug_log.txt already gone\n";

echo @unlink(__FILE__) ? "debug_log.php deleted\n" : "FAILED to delete debug_log.php\n";
