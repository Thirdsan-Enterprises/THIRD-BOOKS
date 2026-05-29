<?php
// ── dashboard.php — admin view, open in any browser ──────────────────────────
require 'config.php';
session_start();

// ── Authentication ────────────────────────────────────────────────────────────
$authError = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['password'])) {
    if ($_POST['password'] === DASHBOARD_PASSWORD) {
        $_SESSION['tb_dashboard_auth'] = true;
    } else {
        $authError = 'Incorrect password.';
    }
}

if (empty($_SESSION['tb_dashboard_auth'])) {
    ?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ThirdBooks — Dashboard Login</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #f1f5f9; display: flex; align-items: center;
         justify-content: center; min-height: 100vh; }
  .card { background: #fff; border-radius: 12px; padding: 36px 40px;
          box-shadow: 0 4px 16px rgba(0,0,0,.10); width: 340px; }
  h1 { font-size: 20px; font-weight: 700; color: #1e293b; margin-bottom: 6px; }
  p  { font-size: 13px; color: #64748b; margin-bottom: 24px; }
  label { font-size: 13px; font-weight: 600; color: #475569; display: block; margin-bottom: 6px; }
  input[type=password] { width: 100%; padding: 10px 12px; border: 1px solid #cbd5e1;
                         border-radius: 8px; font-size: 14px; outline: none; }
  input[type=password]:focus { border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,.15); }
  button { width: 100%; padding: 11px; background: #1e40af; color: #fff;
           border: none; border-radius: 8px; font-size: 14px; font-weight: 600;
           cursor: pointer; margin-top: 16px; }
  button:hover { background: #1d4ed8; }
  .error { background: #fee2e2; color: #991b1b; padding: 10px 14px;
           border-radius: 8px; font-size: 13px; margin-top: 14px; }
</style>
</head>
<body>
<div class="card">
  <h1>ThirdBooks</h1>
  <p>Sync Dashboard — enter password to continue.</p>
  <form method="POST">
    <label for="pw">Password</label>
    <input type="password" id="pw" name="password" autofocus placeholder="Dashboard password">
    <button type="submit">Sign In</button>
    <?php if ($authError): ?><div class="error"><?= htmlspecialchars($authError) ?></div><?php endif; ?>
  </form>
</div>
</body>
</html>
<?php
    exit;
}

// ── Logout ─────────────────────────────────────────────────────────────────────
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: dashboard.php');
    exit;
}

// ── Data ──────────────────────────────────────────────────────────────────────
$files = glob(BACKUP_DIR . '*_backup.json');
rsort($files);
$latest     = $files ? $files[0] : null;
$lastSync   = $latest ? date('d M Y, H:i', filemtime($latest)) : null;
$size       = $latest ? round(filesize($latest) / 1024) . ' KB' : null;
$counts     = [];
$exportedAt = null;

if ($latest) {
    $raw = json_decode(file_get_contents($latest), true);
    $counts     = $raw['counts']      ?? [];
    $exportedAt = $raw['exported_at'] ?? null;
}

$syncedToday    = $latest && date('Y-m-d', filemtime($latest)) === date('Y-m-d');
$syncedThisWeek = $latest && (time() - filemtime($latest)) < 7 * 86400;
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ThirdBooks — Sync Dashboard</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #f1f5f9; color: #1e293b; min-height: 100vh; }
  header { background: #1e293b; color: #fff; padding: 18px 32px;
           display: flex; align-items: center; justify-content: space-between; }
  header h1 { font-size: 18px; font-weight: 600; }
  header span { font-size: 13px; opacity: .6; }
  .logout { font-size: 12px; color: #94a3b8; text-decoration: none; padding: 6px 12px;
            border: 1px solid #475569; border-radius: 6px; }
  .logout:hover { background: #334155; color: #fff; }
  .container { max-width: 860px; margin: 36px auto; padding: 0 24px; }
  .card { background: #fff; border-radius: 12px; padding: 24px;
          box-shadow: 0 1px 3px rgba(0,0,0,.08); margin-bottom: 20px; }
  .status-bar { border-radius: 10px; padding: 16px 20px;
                display: flex; align-items: center; gap: 14px; margin-bottom: 20px; }
  .status-bar.ok   { background: #dcfce7; color: #166534; }
  .status-bar.warn { background: #fef9c3; color: #854d0e; }
  .status-bar.bad  { background: #fee2e2; color: #991b1b; }
  .dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .ok .dot   { background: #16a34a; }
  .warn .dot { background: #ca8a04; }
  .bad .dot  { background: #dc2626; }
  .status-bar .label { font-weight: 600; font-size: 15px; }
  .status-bar .sub   { font-size: 13px; opacity: .75; margin-top: 2px; }
  h2 { font-size: 15px; font-weight: 600; margin-bottom: 14px; color: #475569; }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 12px; color: #94a3b8;
       font-weight: 600; text-transform: uppercase; letter-spacing: .05em;
       padding: 0 0 8px; border-bottom: 1px solid #e2e8f0; }
  td { padding: 10px 0; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
  .num { font-weight: 600; color: #0f172a; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
  .stat { background: #f8fafc; border-radius: 8px; padding: 16px; }
  .stat .val { font-size: 26px; font-weight: 700; color: #0f172a; }
  .stat .lbl { font-size: 12px; color: #94a3b8; margin-top: 2px; }
  .btn { display: inline-block; background: #1e40af; color: #fff;
         padding: 10px 20px; border-radius: 8px; text-decoration: none;
         font-size: 13px; font-weight: 600; margin-top: 4px; }
  .btn:hover { background: #1d4ed8; }
  .btn.danger { background: #dc2626; }
  .btn.danger:hover { background: #b91c1c; }
  .history-row td:first-child { color: #475569; }
  .badge { display:inline-block; padding: 2px 8px; border-radius: 99px;
           font-size: 11px; font-weight: 600; background: #dbeafe; color: #1e40af; }
  .none { color: #94a3b8; font-style: italic; font-size: 14px; margin-top: 8px; }
</style>
</head>
<body>
<header>
  <div>
    <h1>ThirdBooks — Sync Dashboard</h1>
    <span>Client backup monitor</span>
  </div>
  <a class="logout" href="?logout=1">Sign Out</a>
</header>

<div class="container">

  <?php if (!$latest): ?>
  <div class="status-bar bad">
    <div class="dot"></div>
    <div>
      <div class="label">No backup received yet</div>
      <div class="sub">The desktop app has not synced to this server.</div>
    </div>
  </div>

  <?php elseif ($syncedToday): ?>
  <div class="status-bar ok">
    <div class="dot"></div>
    <div>
      <div class="label">✓ Synced today — <?= htmlspecialchars($lastSync) ?></div>
      <div class="sub">Backup size: <?= htmlspecialchars($size) ?></div>
    </div>
  </div>

  <?php elseif ($syncedThisWeek): ?>
  <div class="status-bar warn">
    <div class="dot"></div>
    <div>
      <div class="label">⚠ Last sync: <?= htmlspecialchars($lastSync) ?></div>
      <div class="sub">App has not synced today — check the client machine.</div>
    </div>
  </div>

  <?php else: ?>
  <div class="status-bar bad">
    <div class="dot"></div>
    <div>
      <div class="label">✗ Last sync: <?= htmlspecialchars($lastSync) ?></div>
      <div class="sub">No sync in over a week — client machine may be offline or reinstalled.</div>
    </div>
  </div>
  <?php endif; ?>

  <?php if ($counts): ?>
  <div class="grid">
    <div class="stat">
      <div class="val"><?= number_format($counts['journals'] ?? 0) ?></div>
      <div class="lbl">Journal Entries</div>
    </div>
    <div class="stat">
      <div class="val"><?= number_format($counts['bills'] ?? 0) ?></div>
      <div class="lbl">Bills</div>
    </div>
    <div class="stat">
      <div class="val"><?= number_format($counts['outlet_revenues'] ?? 0) ?></div>
      <div class="lbl">Outlet Revenue Records</div>
    </div>
    <div class="stat">
      <div class="val"><?= number_format($counts['accounts'] ?? 0) ?></div>
      <div class="lbl">Chart of Accounts</div>
    </div>
  </div>
  <?php endif; ?>

  <?php if ($latest): ?>
  <div class="card">
    <h2>Latest Backup</h2>
    <table>
      <tr><th>Field</th><th>Value</th></tr>
      <tr><td>Synced at</td><td class="num"><?= htmlspecialchars($lastSync) ?></td></tr>
      <tr><td>Exported at (app time)</td><td><?= htmlspecialchars($exportedAt ?? '—') ?></td></tr>
      <tr><td>File size</td><td><?= htmlspecialchars($size) ?></td></tr>
    </table>
    <br>
    <a class="btn" href="download.php">⬇ Download for Restore</a>
  </div>

  <div class="card">
    <h2>Record Counts</h2>
    <table>
      <tr><th>Entity</th><th>Count</th></tr>
      <?php foreach ($counts as $key => $val): ?>
      <tr>
        <td><?= htmlspecialchars(ucwords(str_replace('_', ' ', $key))) ?></td>
        <td class="num"><?= number_format($val) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
  </div>

  <div class="card">
    <h2>Backup History (last <?= count($files) ?>)</h2>
    <?php if (count($files) === 0): ?>
      <div class="none">No backups yet.</div>
    <?php else: ?>
    <table>
      <tr><th>Date</th><th>Size</th><th></th></tr>
      <?php foreach (array_slice($files, 0, 15) as $i => $f): ?>
      <tr class="history-row">
        <td>
          <?= date('d M Y, H:i', filemtime($f)) ?>
          <?php if ($i === 0): ?><span class="badge">latest</span><?php endif; ?>
        </td>
        <td><?= round(filesize($f) / 1024) ?> KB</td>
        <td></td>
      </tr>
      <?php endforeach; ?>
    </table>
    <?php endif; ?>
  </div>
  <?php endif; ?>

</div>
</body>
</html>
