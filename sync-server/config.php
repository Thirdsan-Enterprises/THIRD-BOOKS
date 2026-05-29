<?php
// ── ThirdBooks Sync Server Configuration ─────────────────────────────────────
// Deploy these 4 files to any PHP host (shared hosting works fine).
// Set your own API_KEY — paste the same value into the app's Settings > Server Backup.

define('API_KEY',            'tb-sync-magicbet-2026');   // app ↔ server auth key
define('DASHBOARD_PASSWORD', 'magicbet-admin-2026');      // dashboard login password
define('BACKUP_DIR',         __DIR__ . '/backups/');
define('MAX_BACKUPS',        30);                          // keep last 30 syncs
define('APP_TAG',            'ThirdBooks');
