<?php
// ── download.php — admin-only backup download ─────────────────────────────────
require 'config.php';
session_start();

if (empty($_SESSION['tb_user']) || $_SESSION['tb_role'] !== 'admin') {
    http_response_code(403);
    die('Forbidden — administrator access required.');
}

$files = glob(BACKUP_DIR . '*_backup.json');
if (!$files) {
    http_response_code(404);
    die('No backup found on server.');
}

rsort($files);
$latest = $files[0];
$name   = 'thirdbooks_backup_' . date('Y-m-d', filemtime($latest)) . '.json';

header('Content-Type: application/octet-stream');
header('Content-Disposition: attachment; filename="' . $name . '"');
header('Content-Length: ' . filesize($latest));
header('X-Backup-Date: ' . date('c', filemtime($latest)));
readfile($latest);
