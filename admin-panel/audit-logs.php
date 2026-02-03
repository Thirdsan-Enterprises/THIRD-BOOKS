<?php
/**
 * ThirdBooks Admin Panel - Audit Logs
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

session_name(SESSION_NAME);
session_start();
requireAuth();

$user = getAuthUser();
$pdo = getDbConnection();

// Filters
$action = $_GET['action'] ?? '';
$search = $_GET['search'] ?? '';
$page = max(1, intval($_GET['page'] ?? 1));
$perPage = 50;
$offset = ($page - 1) * $perPage;

$where = ['1=1'];
$params = [];

if ($action) {
    $where[] = 'a.action = ?';
    $params[] = $action;
}

if ($search) {
    $where[] = '(a.description LIKE ? OR u.name LIKE ? OR u.email LIKE ?)';
    $params[] = "%{$search}%";
    $params[] = "%{$search}%";
    $params[] = "%{$search}%";
}

$whereClause = implode(' AND ', $where);

try {
    $countStmt = $pdo->prepare("SELECT COUNT(*) as count FROM audit_logs a LEFT JOIN users u ON a.user_id = u.id WHERE {$whereClause}");
    $countStmt->execute($params);
    $totalCount = $countStmt->fetch()['count'];
    $totalPages = ceil($totalCount / $perPage);

    $stmt = $pdo->prepare("
        SELECT a.*, u.name as user_name, u.email as user_email
        FROM audit_logs a
        LEFT JOIN users u ON a.user_id = u.id
        WHERE {$whereClause}
        ORDER BY a.created_at DESC
        LIMIT {$perPage} OFFSET {$offset}
    ");
    $stmt->execute($params);
    $logs = $stmt->fetchAll();

    // Get unique actions for filter
    $actionsStmt = $pdo->query("SELECT DISTINCT action FROM audit_logs ORDER BY action");
    $actions = $actionsStmt->fetchAll(PDO::FETCH_COLUMN);

} catch (PDOException $e) {
    $logs = [];
    $actions = [];
    $totalCount = 0;
    $totalPages = 0;
}

$pageTitle = 'Audit Logs';
include __DIR__ . '/views/layouts/header.php';
?>

<div class="card">
    <div class="card-body">
        <form method="GET" style="display: flex; gap: 16px; flex-wrap: wrap; align-items: flex-end;">
            <div class="form-group" style="margin-bottom: 0; flex: 1; min-width: 200px;">
                <label>Search</label>
                <input type="text" name="search" class="form-control" placeholder="Search description, user..." value="<?= e($search) ?>">
            </div>
            <div class="form-group" style="margin-bottom: 0; width: 180px;">
                <label>Action</label>
                <select name="action" class="form-control">
                    <option value="">All Actions</option>
                    <?php foreach ($actions as $a): ?>
                    <option value="<?= e($a) ?>" <?= $action === $a ? 'selected' : '' ?>><?= ucfirst($a) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <button type="submit" class="btn btn-primary">Filter</button>
            <?php if ($search || $action): ?>
            <a href="audit-logs.php" class="btn btn-outline">Clear</a>
            <?php endif; ?>
        </form>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <h2>Audit Logs (<?= number_format($totalCount) ?>)</h2>
    </div>
    <div class="card-body" style="padding: 0;">
        <?php if (empty($logs)): ?>
        <p style="padding: 24px;" class="text-muted">No audit logs found.</p>
        <?php else: ?>
        <table class="table">
            <thead>
                <tr>
                    <th>Time</th>
                    <th>User</th>
                    <th>Action</th>
                    <th>Description</th>
                    <th>IP Address</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($logs as $log): ?>
                <tr>
                    <td style="white-space: nowrap;">
                        <?= formatDateTime($log['created_at'], 'M d, H:i') ?>
                    </td>
                    <td>
                        <?php if ($log['user_name']): ?>
                        <?= e($log['user_name']) ?><br>
                        <small class="text-muted"><?= e($log['user_email']) ?></small>
                        <?php else: ?>
                        <span class="text-muted">System</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <span class="badge badge-<?= in_array($log['action'], ['create', 'login']) ? 'success' : (in_array($log['action'], ['delete', 'logout']) ? 'danger' : 'secondary') ?>">
                            <?= ucfirst($log['action']) ?>
                        </span>
                    </td>
                    <td>
                        <?= e($log['description'] ?? '-') ?>
                        <?php if ($log['model_type']): ?>
                        <br><small class="text-muted"><?= e($log['model_type']) ?> #<?= $log['model_id'] ?></small>
                        <?php endif; ?>
                    </td>
                    <td><code style="font-size: 12px;"><?= e($log['ip_address'] ?? '-') ?></code></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

        <?php if ($totalPages > 1): ?>
        <div style="padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border);">
            <div class="text-muted">
                Page <?= $page ?> of <?= $totalPages ?>
            </div>
            <div style="display: flex; gap: 8px;">
                <?php if ($page > 1): ?>
                <a href="?<?= http_build_query(array_merge($_GET, ['page' => $page - 1])) ?>" class="btn btn-sm btn-outline">&laquo; Previous</a>
                <?php endif; ?>
                <?php if ($page < $totalPages): ?>
                <a href="?<?= http_build_query(array_merge($_GET, ['page' => $page + 1])) ?>" class="btn btn-sm btn-outline">Next &raquo;</a>
                <?php endif; ?>
            </div>
        </div>
        <?php endif; ?>
        <?php endif; ?>
    </div>
</div>

<?php include __DIR__ . '/views/layouts/footer.php'; ?>
