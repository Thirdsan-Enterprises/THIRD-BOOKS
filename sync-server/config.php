<?php
// ── ThirdBooks Sync Server Configuration ─────────────────────────────────────

define('API_KEY',    'tb-sync-magicbet-2026');   // app ↔ server shared secret
define('BACKUP_DIR', __DIR__ . '/backups/');
define('MAX_BACKUPS', 30);
define('APP_TAG',    'ThirdBooks');

// ── Dashboard users ───────────────────────────────────────────────────────────
// role 'admin'  → full access + download backup
// role 'viewer' → read-only (can see data, cannot download)
define('DASHBOARD_USERS', [
    'marion'  => ['password' => 'marion-admin-2026', 'role' => 'admin',  'name' => 'Marion'],
    'staff'   => ['password' => 'mb-staff-2026',     'role' => 'viewer', 'name' => 'Staff'],
]);
