<?php
/**
 * ThirdBooks Admin Panel - Settings
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

session_name(SESSION_NAME);
session_start();
requireAuth();

$user = getAuthUser();
$pdo = getDbConnection();

$message = '';
$messageType = '';

// System info
$phpVersion = phpversion();
$mysqlVersion = $pdo->query('SELECT VERSION()')->fetchColumn();

// Get some stats
$stats = [];
try {
    $stats['tenants'] = $pdo->query('SELECT COUNT(*) FROM tenants WHERE deleted_at IS NULL')->fetchColumn();
    $stats['users'] = $pdo->query('SELECT COUNT(*) FROM users WHERE deleted_at IS NULL')->fetchColumn();
    $stats['companies'] = $pdo->query('SELECT COUNT(*) FROM companies WHERE deleted_at IS NULL')->fetchColumn();
} catch (PDOException $e) {
    $stats = ['tenants' => 0, 'users' => 0, 'companies' => 0];
}

$pageTitle = 'Settings';
include __DIR__ . '/views/layouts/header.php';
?>

<?php if ($message): ?>
<div class="alert alert-<?= $messageType ?>"><?= e($message) ?></div>
<?php endif; ?>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 24px;">
    <!-- System Information -->
    <div class="card">
        <div class="card-header">
            <h2>System Information</h2>
        </div>
        <div class="card-body">
            <table class="table" style="margin: 0;">
                <tr>
                    <td><strong>Application</strong></td>
                    <td><?= APP_NAME ?> v<?= APP_VERSION ?></td>
                </tr>
                <tr>
                    <td><strong>Environment</strong></td>
                    <td><span class="badge badge-<?= APP_ENV === 'production' ? 'success' : 'warning' ?>"><?= ucfirst(APP_ENV) ?></span></td>
                </tr>
                <tr>
                    <td><strong>PHP Version</strong></td>
                    <td><?= $phpVersion ?></td>
                </tr>
                <tr>
                    <td><strong>MySQL Version</strong></td>
                    <td><?= $mysqlVersion ?></td>
                </tr>
                <tr>
                    <td><strong>Timezone</strong></td>
                    <td><?= TIMEZONE ?></td>
                </tr>
                <tr>
                    <td><strong>Server Time</strong></td>
                    <td><?= date('Y-m-d H:i:s') ?></td>
                </tr>
            </table>
        </div>
    </div>

    <!-- Database Statistics -->
    <div class="card">
        <div class="card-header">
            <h2>Database Statistics</h2>
        </div>
        <div class="card-body">
            <table class="table" style="margin: 0;">
                <tr>
                    <td><strong>Total Tenants</strong></td>
                    <td><?= number_format($stats['tenants']) ?></td>
                </tr>
                <tr>
                    <td><strong>Total Users</strong></td>
                    <td><?= number_format($stats['users']) ?></td>
                </tr>
                <tr>
                    <td><strong>Total Companies</strong></td>
                    <td><?= number_format($stats['companies']) ?></td>
                </tr>
                <tr>
                    <td><strong>Database Name</strong></td>
                    <td><?= DB_NAME ?></td>
                </tr>
            </table>
        </div>
    </div>

    <!-- API Configuration -->
    <div class="card">
        <div class="card-header">
            <h2>API Configuration</h2>
        </div>
        <div class="card-body">
            <table class="table" style="margin: 0;">
                <tr>
                    <td><strong>API URL</strong></td>
                    <td><a href="<?= API_URL ?>" target="_blank"><?= API_URL ?></a></td>
                </tr>
                <tr>
                    <td><strong>Admin URL</strong></td>
                    <td><a href="<?= BASE_URL ?>" target="_blank"><?= BASE_URL ?></a></td>
                </tr>
            </table>
        </div>
    </div>

    <!-- Quick Actions -->
    <div class="card">
        <div class="card-header">
            <h2>Maintenance</h2>
        </div>
        <div class="card-body">
            <p class="text-muted" style="margin-bottom: 16px;">Perform maintenance operations on the system.</p>
            <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                <a href="<?= API_URL ?>/health" target="_blank" class="btn btn-outline">Check API Health</a>
                <a href="audit-logs.php" class="btn btn-outline">View Audit Logs</a>
            </div>
        </div>
    </div>
</div>

<!-- Admin Account -->
<div class="card" style="margin-top: 24px;">
    <div class="card-header">
        <h2>Your Account</h2>
    </div>
    <div class="card-body">
        <table class="table" style="margin: 0; max-width: 500px;">
            <tr>
                <td><strong>Name</strong></td>
                <td><?= e($user['name']) ?></td>
            </tr>
            <tr>
                <td><strong>Email</strong></td>
                <td><?= e($user['email']) ?></td>
            </tr>
            <tr>
                <td><strong>Role</strong></td>
                <td><span class="badge badge-danger">Super Admin</span></td>
            </tr>
            <tr>
                <td><strong>Account Created</strong></td>
                <td><?= formatDateTime($user['created_at']) ?></td>
            </tr>
        </table>
    </div>
</div>

<?php include __DIR__ . '/views/layouts/footer.php'; ?>
