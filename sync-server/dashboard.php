<?php
// ── dashboard.php — ThirdBooks Sync Dashboard ────────────────────────────────
require 'config.php';
session_start();

// ── Logout ────────────────────────────────────────────────────────────────────
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: dashboard.php');
    exit;
}

// ── Login ─────────────────────────────────────────────────────────────────────
$authError = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['username'], $_POST['password'])) {
    $u = strtolower(trim($_POST['username']));
    $p = $_POST['password'];
    $users = DASHBOARD_USERS;
    if (isset($users[$u]) && $users[$u]['password'] === $p) {
        $_SESSION['tb_user']  = $u;
        $_SESSION['tb_role']  = $users[$u]['role'];
        $_SESSION['tb_name']  = $users[$u]['name'];
    } else {
        $authError = 'Incorrect username or password.';
    }
}

// ── Show login if not authenticated ──────────────────────────────────────────
if (empty($_SESSION['tb_user'])) {
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ThirdBooks — Dashboard</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 60%, #0f172a 100%);
    min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
  }
  .login-wrap {
    width: 100%; max-width: 420px; padding: 24px;
  }
  .brand {
    text-align: center; margin-bottom: 32px;
  }
  .brand-icon {
    width: 60px; height: 60px; border-radius: 16px;
    background: linear-gradient(135deg, #3b82f6, #1d4ed8);
    display: inline-flex; align-items: center; justify-content: center;
    margin-bottom: 14px;
    box-shadow: 0 8px 24px rgba(59,130,246,.35);
  }
  .brand-icon svg { width: 30px; height: 30px; }
  .brand h1 { color: #fff; font-size: 22px; font-weight: 700; letter-spacing: -.3px; }
  .brand p  { color: #94a3b8; font-size: 13px; margin-top: 4px; }
  .card {
    background: rgba(255,255,255,.05);
    border: 1px solid rgba(255,255,255,.10);
    backdrop-filter: blur(12px);
    border-radius: 16px;
    padding: 32px 36px;
  }
  .field { margin-bottom: 18px; }
  label { display: block; font-size: 12px; font-weight: 600;
          color: #94a3b8; letter-spacing: .05em; text-transform: uppercase; margin-bottom: 7px; }
  input[type=text], input[type=password] {
    width: 100%; padding: 11px 14px;
    background: rgba(255,255,255,.07);
    border: 1px solid rgba(255,255,255,.12);
    border-radius: 9px; font-size: 14px; color: #f1f5f9; outline: none;
  }
  input::placeholder { color: #475569; }
  input:focus { border-color: #3b82f6; background: rgba(59,130,246,.08); }
  .btn-login {
    width: 100%; padding: 12px;
    background: linear-gradient(135deg, #3b82f6, #1d4ed8);
    color: #fff; border: none; border-radius: 9px;
    font-size: 14px; font-weight: 700; cursor: pointer; margin-top: 4px;
    letter-spacing: .02em;
    box-shadow: 0 4px 14px rgba(59,130,246,.30);
    transition: opacity .15s;
  }
  .btn-login:hover { opacity: .9; }
  .error {
    background: rgba(239,68,68,.15); border: 1px solid rgba(239,68,68,.3);
    color: #fca5a5; padding: 10px 14px; border-radius: 8px;
    font-size: 13px; margin-top: 14px; text-align: center;
  }
  .footer { text-align: center; color: #475569; font-size: 12px; margin-top: 20px; }
</style>
</head>
<body>
<div class="login-wrap">
  <div class="brand">
    <div class="brand-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/>
      </svg>
    </div>
    <h1>ThirdBooks</h1>
    <p>MagicBet — Sync Dashboard</p>
  </div>
  <div class="card">
    <form method="POST">
      <div class="field">
        <label>Username</label>
        <input type="text" name="username" autocomplete="username" placeholder="Enter username" autofocus
               value="<?= htmlspecialchars($_POST['username'] ?? '') ?>">
      </div>
      <div class="field">
        <label>Password</label>
        <input type="password" name="password" autocomplete="current-password" placeholder="Enter password">
      </div>
      <button class="btn-login" type="submit">Sign In</button>
      <?php if ($authError): ?>
        <div class="error"><?= htmlspecialchars($authError) ?></div>
      <?php endif; ?>
    </form>
  </div>
  <div class="footer">© 2026 MagicBet Ltd · ThirdBooks Accounting</div>
</div>
</body>
</html>
<?php
    exit;
}

// ── Authenticated — load data ─────────────────────────────────────────────────
$isAdmin  = $_SESSION['tb_role'] === 'admin';
$userName = $_SESSION['tb_name'] ?? 'User';

$files      = glob(BACKUP_DIR . '*_backup.json') ?: [];
rsort($files);
$latest     = $files ? $files[0] : null;
$lastSync   = $latest ? date('d M Y, H:i', filemtime($latest)) : null;
$size       = $latest ? round(filesize($latest) / 1024, 1) . ' KB' : null;
$counts     = [];
$exportedAt = null;

if ($latest) {
    $raw        = json_decode(file_get_contents($latest), true);
    $counts     = $raw['counts']      ?? [];
    $exportedAt = $raw['exported_at'] ?? null;
}

$syncedToday    = $latest && date('Y-m-d', filemtime($latest)) === date('Y-m-d');
$syncedThisWeek = $latest && (time() - filemtime($latest)) < 7 * 86400;

if      ($syncedToday)    { $statusClass = 'ok';   $statusIcon = '✓'; $statusText = 'Synced today'; $statusSub = 'Last backup: ' . $lastSync; }
elseif  ($syncedThisWeek) { $statusClass = 'warn'; $statusIcon = '⚠'; $statusText = 'Last sync: ' . $lastSync; $statusSub = 'No sync today — check the client machine.'; }
elseif  ($latest)         { $statusClass = 'bad';  $statusIcon = '✗'; $statusText = 'Last sync: ' . $lastSync; $statusSub = 'No sync in over a week.'; }
else                      { $statusClass = 'bad';  $statusIcon = '✗'; $statusText = 'No backup received yet'; $statusSub = 'The desktop app has not synced to this server.'; }
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ThirdBooks — Sync Dashboard</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f0f4f9; color: #1e293b; min-height: 100vh;
  }

  /* ── Top bar ── */
  .topbar {
    background: linear-gradient(135deg, #0f172a, #1e3a5f);
    height: 58px; padding: 0 28px;
    display: flex; align-items: center; justify-content: space-between;
    box-shadow: 0 2px 12px rgba(0,0,0,.25);
  }
  .topbar-left { display: flex; align-items: center; gap: 12px; }
  .topbar-icon {
    width: 34px; height: 34px; border-radius: 9px;
    background: linear-gradient(135deg, #3b82f6, #1d4ed8);
    display: flex; align-items: center; justify-content: center;
  }
  .topbar-icon svg { width: 17px; height: 17px; }
  .topbar-title { color: #fff; font-size: 16px; font-weight: 700; letter-spacing: -.2px; }
  .topbar-sub   { color: #64748b; font-size: 12px; margin-left: 4px; }
  .topbar-right { display: flex; align-items: center; gap: 14px; }
  .user-chip {
    display: flex; align-items: center; gap: 8px;
    background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.10);
    border-radius: 8px; padding: 5px 12px;
  }
  .user-avatar {
    width: 26px; height: 26px; border-radius: 50%;
    background: linear-gradient(135deg, #3b82f6, #7c3aed);
    display: flex; align-items: center; justify-content: center;
    font-size: 11px; font-weight: 700; color: #fff;
  }
  .user-name  { color: #e2e8f0; font-size: 13px; font-weight: 600; }
  .user-role  { color: #64748b; font-size: 11px; }
  .btn-logout {
    color: #94a3b8; font-size: 12px; text-decoration: none;
    padding: 6px 12px; border: 1px solid rgba(255,255,255,.12);
    border-radius: 7px; transition: all .15s;
  }
  .btn-logout:hover { background: rgba(239,68,68,.15); color: #fca5a5; border-color: rgba(239,68,68,.3); }

  /* ── Layout ── */
  .page { max-width: 940px; margin: 32px auto; padding: 0 20px; }

  /* ── Status bar ── */
  .status-bar {
    border-radius: 12px; padding: 18px 22px;
    display: flex; align-items: center; gap: 16px; margin-bottom: 24px;
    border: 1px solid transparent;
  }
  .status-bar.ok   { background: #dcfce7; border-color: #bbf7d0; color: #166534; }
  .status-bar.warn { background: #fef9c3; border-color: #fde68a; color: #854d0e; }
  .status-bar.bad  { background: #fee2e2; border-color: #fecaca; color: #991b1b; }
  .status-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }
  .ok   .status-dot { background: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.2); }
  .warn .status-dot { background: #ca8a04; box-shadow: 0 0 0 3px rgba(202,138,4,.2); }
  .bad  .status-dot { background: #dc2626; box-shadow: 0 0 0 3px rgba(220,38,38,.2); }
  .status-text .title { font-weight: 700; font-size: 15px; }
  .status-text .sub   { font-size: 13px; opacity: .75; margin-top: 2px; }

  /* ── Stat grid ── */
  .stat-grid {
    display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px;
  }
  @media(max-width:680px) { .stat-grid { grid-template-columns: 1fr 1fr; } }
  .stat-card {
    background: #fff; border-radius: 12px; padding: 20px;
    box-shadow: 0 1px 4px rgba(0,0,0,.07); border: 1px solid #e2e8f0;
  }
  .stat-card .icon {
    width: 38px; height: 38px; border-radius: 9px;
    display: flex; align-items: center; justify-content: center; margin-bottom: 12px;
  }
  .stat-card .icon svg { width: 18px; height: 18px; }
  .stat-card .val  { font-size: 28px; font-weight: 800; color: #0f172a; line-height: 1; }
  .stat-card .lbl  { font-size: 12px; color: #64748b; margin-top: 4px; font-weight: 500; }
  .icon-blue   { background: #dbeafe; color: #1d4ed8; }
  .icon-purple { background: #ede9fe; color: #7c3aed; }
  .icon-green  { background: #dcfce7; color: #16a34a; }
  .icon-orange { background: #ffedd5; color: #ea580c; }

  /* ── Cards ── */
  .card {
    background: #fff; border-radius: 12px; padding: 24px;
    box-shadow: 0 1px 4px rgba(0,0,0,.07); border: 1px solid #e2e8f0;
    margin-bottom: 20px;
  }
  .card-header {
    display: flex; align-items: center; justify-content: space-between; margin-bottom: 18px;
  }
  .card-title { font-size: 14px; font-weight: 700; color: #374151; text-transform: uppercase;
                letter-spacing: .06em; }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 11px; color: #94a3b8; font-weight: 700;
       text-transform: uppercase; letter-spacing: .07em; padding: 0 0 10px; border-bottom: 1px solid #e2e8f0; }
  td { padding: 11px 0; border-bottom: 1px solid #f8fafc; font-size: 14px; color: #374151; }
  tr:last-child td { border-bottom: none; }
  td.val { font-weight: 700; color: #0f172a; }
  .badge-latest {
    display: inline-block; padding: 2px 8px; border-radius: 99px;
    font-size: 11px; font-weight: 700; background: #dbeafe; color: #1e40af; margin-left: 6px;
  }

  /* ── Download btn ── */
  .btn-download {
    display: inline-flex; align-items: center; gap: 7px;
    background: linear-gradient(135deg, #1e40af, #1d4ed8);
    color: #fff; padding: 10px 20px; border-radius: 9px;
    text-decoration: none; font-size: 13px; font-weight: 700;
    box-shadow: 0 3px 10px rgba(29,78,216,.25); transition: opacity .15s;
  }
  .btn-download:hover { opacity: .88; }
  .btn-download svg { width: 15px; height: 15px; }
  .admin-only { display: <?= $isAdmin ? 'block' : 'none' ?>; }

  /* ── Viewer notice ── */
  .viewer-notice {
    display: <?= $isAdmin ? 'none' : 'flex' ?>;
    align-items: center; gap: 10px;
    background: #f0f9ff; border: 1px solid #bae6fd; border-radius: 8px;
    padding: 10px 14px; font-size: 13px; color: #0369a1; margin-top: 12px;
  }

  .none { color: #94a3b8; font-style: italic; font-size: 14px; }
</style>
</head>
<body>

<div class="topbar">
  <div class="topbar-left">
    <div class="topbar-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/>
      </svg>
    </div>
    <span class="topbar-title">ThirdBooks</span>
    <span class="topbar-sub">/ Sync Dashboard</span>
  </div>
  <div class="topbar-right">
    <div class="user-chip">
      <div class="user-avatar"><?= strtoupper(substr($userName, 0, 1)) ?></div>
      <div>
        <div class="user-name"><?= htmlspecialchars($userName) ?></div>
        <div class="user-role"><?= $isAdmin ? 'Administrator' : 'Viewer' ?></div>
      </div>
    </div>
    <a class="btn-logout" href="?logout=1">Sign Out</a>
  </div>
</div>

<div class="page">

  <!-- Status -->
  <div class="status-bar <?= $statusClass ?>">
    <div class="status-dot"></div>
    <div class="status-text">
      <div class="title"><?= $statusIcon ?> <?= htmlspecialchars($statusText) ?></div>
      <div class="sub"><?= htmlspecialchars($statusSub) ?></div>
    </div>
  </div>

  <!-- Stats -->
  <?php if ($counts): ?>
  <div class="stat-grid">
    <div class="stat-card">
      <div class="icon icon-blue">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/>
        </svg>
      </div>
      <div class="val"><?= number_format($counts['journals'] ?? 0) ?></div>
      <div class="lbl">Journal Entries</div>
    </div>
    <div class="stat-card">
      <div class="icon icon-purple">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/>
        </svg>
      </div>
      <div class="val"><?= number_format($counts['bills'] ?? 0) ?></div>
      <div class="lbl">Bills</div>
    </div>
    <div class="stat-card">
      <div class="icon icon-green">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/>
        </svg>
      </div>
      <div class="val"><?= number_format($counts['outlet_revenues'] ?? 0) ?></div>
      <div class="lbl">Revenue Records</div>
    </div>
    <div class="stat-card">
      <div class="icon icon-orange">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
        </svg>
      </div>
      <div class="val"><?= number_format($counts['accounts'] ?? 0) ?></div>
      <div class="lbl">Chart of Accounts</div>
    </div>
  </div>
  <?php endif; ?>

  <!-- Backup details -->
  <?php if ($latest): ?>
  <div class="card">
    <div class="card-header">
      <div class="card-title">Latest Backup</div>
      <div class="admin-only">
        <a class="btn-download" href="download.php">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
          </svg>
          Download for Restore
        </a>
      </div>
    </div>
    <table>
      <tr><th>Field</th><th>Value</th></tr>
      <tr><td>Synced at</td><td class="val"><?= htmlspecialchars($lastSync) ?></td></tr>
      <tr><td>Exported by app</td><td><?= htmlspecialchars($exportedAt ?? '—') ?></td></tr>
      <tr><td>Backup size</td><td><?= htmlspecialchars($size) ?></td></tr>
      <tr><td>Total backups kept</td><td><?= count($files) ?> of <?= MAX_BACKUPS ?></td></tr>
    </table>
    <div class="viewer-notice">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
      Backup download is restricted to administrators only.
    </div>
  </div>

  <!-- Record counts -->
  <?php if ($counts): ?>
  <div class="card">
    <div class="card-header"><div class="card-title">Record Counts</div></div>
    <table>
      <tr><th>Entity</th><th>Count</th></tr>
      <?php foreach ($counts as $key => $val): ?>
      <tr>
        <td><?= htmlspecialchars(ucwords(str_replace('_', ' ', $key))) ?></td>
        <td class="val"><?= number_format($val) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
  </div>
  <?php endif; ?>

  <!-- Backup history -->
  <div class="card">
    <div class="card-header">
      <div class="card-title">Backup History</div>
      <span style="font-size:12px;color:#94a3b8;"><?= count($files) ?> backups stored</span>
    </div>
    <?php if (!$files): ?>
      <div class="none">No backups yet.</div>
    <?php else: ?>
    <table>
      <tr><th>Date &amp; Time</th><th>Size</th></tr>
      <?php foreach (array_slice($files, 0, 20) as $i => $f): ?>
      <tr>
        <td>
          <?= date('d M Y, H:i', filemtime($f)) ?>
          <?php if ($i === 0): ?><span class="badge-latest">latest</span><?php endif; ?>
        </td>
        <td><?= round(filesize($f) / 1024, 1) ?> KB</td>
      </tr>
      <?php endforeach; ?>
    </table>
    <?php endif; ?>
  </div>

  <?php endif; // end $latest ?>

</div><!-- /page -->
</body>
</html>
