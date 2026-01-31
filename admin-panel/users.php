<?php
/**
 * ThirdBooks Admin Panel - User Management
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

// Handle actions
if ($_SERVER['REQUEST_METHOD'] === 'POST' && validateCsrfToken($_POST['_token'] ?? '')) {
    $action = $_POST['action'] ?? '';
    $userId = $_POST['user_id'] ?? '';

    try {
        switch ($action) {
            case 'deactivate':
                $stmt = $pdo->prepare("UPDATE users SET is_active = 0, updated_at = NOW() WHERE id = ? AND id != ?");
                $stmt->execute([$userId, $user['id']]);
                $message = 'User deactivated successfully.';
                $messageType = 'success';
                break;

            case 'activate':
                $stmt = $pdo->prepare("UPDATE users SET is_active = 1, updated_at = NOW() WHERE id = ?");
                $stmt->execute([$userId]);
                $message = 'User activated successfully.';
                $messageType = 'success';
                break;

            case 'reset_password':
                $newPassword = password_hash('TempPass123!', PASSWORD_BCRYPT);
                $stmt = $pdo->prepare("UPDATE users SET password = ?, updated_at = NOW() WHERE id = ?");
                $stmt->execute([$newPassword, $userId]);
                $message = 'Password reset to: TempPass123!';
                $messageType = 'warning';
                break;
        }
    } catch (PDOException $e) {
        $message = 'An error occurred.';
        $messageType = 'danger';
    }
}

// Filters
$role = $_GET['role'] ?? '';
$status = $_GET['status'] ?? '';
$search = $_GET['search'] ?? '';
$page = max(1, intval($_GET['page'] ?? 1));
$perPage = ITEMS_PER_PAGE;
$offset = ($page - 1) * $perPage;

$where = ['deleted_at IS NULL'];
$params = [];

if ($role) {
    $where[] = 'role = ?';
    $params[] = $role;
}

if ($status !== '') {
    $where[] = 'is_active = ?';
    $params[] = $status;
}

if ($search) {
    $where[] = '(name LIKE ? OR email LIKE ?)';
    $params[] = "%{$search}%";
    $params[] = "%{$search}%";
}

$whereClause = implode(' AND ', $where);

$countStmt = $pdo->prepare("SELECT COUNT(*) as count FROM users WHERE {$whereClause}");
$countStmt->execute($params);
$totalCount = $countStmt->fetch()['count'];
$totalPages = ceil($totalCount / $perPage);

$stmt = $pdo->prepare("
    SELECT u.*, t.company_name as tenant_name
    FROM users u
    LEFT JOIN tenants t ON u.tenant_id = t.id
    WHERE u.deleted_at IS NULL " . ($role ? "AND u.role = ?" : "") . " " . ($status !== '' ? "AND u.is_active = ?" : "") . " " . ($search ? "AND (u.name LIKE ? OR u.email LIKE ?)" : "") . "
    ORDER BY u.created_at DESC
    LIMIT {$perPage} OFFSET {$offset}
");
$stmt->execute($params);
$users = $stmt->fetchAll();

$pageTitle = 'Users';
include __DIR__ . '/views/layouts/header.php';
?>

<?php if ($message): ?>
<div class="alert alert-<?= $messageType ?>"><?= e($message) ?></div>
<?php endif; ?>

<div class="card">
    <div class="card-body">
        <form method="GET" style="display: flex; gap: 16px; flex-wrap: wrap; align-items: flex-end;">
            <div class="form-group" style="margin-bottom: 0; flex: 1; min-width: 200px;">
                <label>Search</label>
                <input type="text" name="search" class="form-control" placeholder="Name or email..." value="<?= e($search) ?>">
            </div>
            <div class="form-group" style="margin-bottom: 0; width: 150px;">
                <label>Role</label>
                <select name="role" class="form-control">
                    <option value="">All Roles</option>
                    <option value="super_admin" <?= $role === 'super_admin' ? 'selected' : '' ?>>Super Admin</option>
                    <option value="admin" <?= $role === 'admin' ? 'selected' : '' ?>>Admin</option>
                    <option value="accountant" <?= $role === 'accountant' ? 'selected' : '' ?>>Accountant</option>
                    <option value="user" <?= $role === 'user' ? 'selected' : '' ?>>User</option>
                </select>
            </div>
            <div class="form-group" style="margin-bottom: 0; width: 150px;">
                <label>Status</label>
                <select name="status" class="form-control">
                    <option value="">All</option>
                    <option value="1" <?= $status === '1' ? 'selected' : '' ?>>Active</option>
                    <option value="0" <?= $status === '0' ? 'selected' : '' ?>>Inactive</option>
                </select>
            </div>
            <button type="submit" class="btn btn-primary">Filter</button>
        </form>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <h2>Users (<?= number_format($totalCount) ?>)</h2>
    </div>
    <div class="card-body" style="padding: 0;">
        <table class="table">
            <thead>
                <tr>
                    <th>User</th>
                    <th>Tenant</th>
                    <th>Role</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($users as $u): ?>
                <tr>
                    <td>
                        <strong><?= e($u['name']) ?></strong><br>
                        <small class="text-muted"><?= e($u['email']) ?></small>
                    </td>
                    <td><?= $u['tenant_name'] ? e($u['tenant_name']) : '<span class="text-muted">System</span>' ?></td>
                    <td><span class="badge badge-<?= $u['role'] === 'super_admin' ? 'danger' : 'secondary' ?>"><?= ucfirst(str_replace('_', ' ', $u['role'])) ?></span></td>
                    <td><span class="badge badge-<?= $u['is_active'] ? 'success' : 'warning' ?>"><?= $u['is_active'] ? 'Active' : 'Inactive' ?></span></td>
                    <td><?= formatDate($u['created_at']) ?></td>
                    <td>
                        <?php if ($u['id'] != $user['id']): ?>
                        <form method="POST" style="display: inline;">
                            <input type="hidden" name="_token" value="<?= generateCsrfToken() ?>">
                            <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                            <?php if ($u['is_active']): ?>
                            <button type="submit" name="action" value="deactivate" class="btn btn-sm btn-outline">Deactivate</button>
                            <?php else: ?>
                            <button type="submit" name="action" value="activate" class="btn btn-sm btn-secondary">Activate</button>
                            <?php endif; ?>
                            <button type="submit" name="action" value="reset_password" class="btn btn-sm btn-outline" data-confirm="Reset password to TempPass123!?">Reset Password</button>
                        </form>
                        <?php else: ?>
                        <span class="text-muted">Current user</span>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?php include __DIR__ . '/views/layouts/footer.php'; ?>
