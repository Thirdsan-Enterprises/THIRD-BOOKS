<?php
/**
 * ThirdBooks Admin Panel - Tenant Management
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

// Start session
session_name(SESSION_NAME);
session_start();

// Require authentication
requireAuth();

$user = getAuthUser();
$pdo = getDbConnection();

$message = '';
$messageType = '';

// Handle actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    $tenantId = $_POST['tenant_id'] ?? '';

    if (!validateCsrfToken($_POST['_token'] ?? '')) {
        $message = 'Invalid security token. Please try again.';
        $messageType = 'danger';
    } else {
        try {
            switch ($action) {
                case 'suspend':
                    $stmt = $pdo->prepare("UPDATE tenants SET status = 'suspended', updated_at = NOW() WHERE id = ?");
                    $stmt->execute([$tenantId]);
                    $message = 'Tenant suspended successfully.';
                    $messageType = 'success';
                    break;

                case 'activate':
                    $stmt = $pdo->prepare("UPDATE tenants SET status = 'active', updated_at = NOW() WHERE id = ?");
                    $stmt->execute([$tenantId]);
                    $message = 'Tenant activated successfully.';
                    $messageType = 'success';
                    break;

                case 'delete':
                    $stmt = $pdo->prepare("UPDATE tenants SET deleted_at = NOW() WHERE id = ?");
                    $stmt->execute([$tenantId]);
                    $message = 'Tenant deleted successfully.';
                    $messageType = 'success';
                    break;
            }

            logMessage('info', "Tenant action: {$action}", ['tenant_id' => $tenantId, 'admin_id' => $user['id']]);

        } catch (PDOException $e) {
            $message = 'An error occurred. Please try again.';
            $messageType = 'danger';
            logMessage('error', 'Tenant action failed', ['error' => $e->getMessage()]);
        }
    }
}

// Filters
$status = $_GET['status'] ?? '';
$plan = $_GET['plan'] ?? '';
$search = $_GET['search'] ?? '';
$page = max(1, intval($_GET['page'] ?? 1));
$perPage = ITEMS_PER_PAGE;
$offset = ($page - 1) * $perPage;

// Build query
$where = ['deleted_at IS NULL'];
$params = [];

if ($status) {
    $where[] = 'status = ?';
    $params[] = $status;
}

if ($plan) {
    $where[] = 'plan = ?';
    $params[] = $plan;
}

if ($search) {
    $where[] = '(name LIKE ? OR company_name LIKE ? OR email LIKE ?)';
    $searchTerm = "%{$search}%";
    $params[] = $searchTerm;
    $params[] = $searchTerm;
    $params[] = $searchTerm;
}

$whereClause = implode(' AND ', $where);

// Get total count
$countStmt = $pdo->prepare("SELECT COUNT(*) as count FROM tenants WHERE {$whereClause}");
$countStmt->execute($params);
$totalCount = $countStmt->fetch()['count'];
$totalPages = ceil($totalCount / $perPage);

// Get tenants
$stmt = $pdo->prepare("SELECT * FROM tenants WHERE {$whereClause} ORDER BY created_at DESC LIMIT {$perPage} OFFSET {$offset}");
$stmt->execute($params);
$tenants = $stmt->fetchAll();

$pageTitle = 'Tenants';
include __DIR__ . '/views/layouts/header.php';
?>

<?php if ($message): ?>
<div class="alert alert-<?= $messageType ?>">
    <?= e($message) ?>
</div>
<?php endif; ?>

<!-- Filters -->
<div class="card">
    <div class="card-body">
        <form method="GET" action="" class="filter-form" style="display: flex; gap: 16px; flex-wrap: wrap; align-items: flex-end;">
            <div class="form-group" style="margin-bottom: 0; flex: 1; min-width: 200px;">
                <label>Search</label>
                <input type="text" name="search" class="form-control" placeholder="Search by name, company, email..." value="<?= e($search) ?>">
            </div>
            <div class="form-group" style="margin-bottom: 0; width: 150px;">
                <label>Status</label>
                <select name="status" class="form-control">
                    <option value="">All Statuses</option>
                    <option value="active" <?= $status === 'active' ? 'selected' : '' ?>>Active</option>
                    <option value="suspended" <?= $status === 'suspended' ? 'selected' : '' ?>>Suspended</option>
                    <option value="pending" <?= $status === 'pending' ? 'selected' : '' ?>>Pending</option>
                    <option value="cancelled" <?= $status === 'cancelled' ? 'selected' : '' ?>>Cancelled</option>
                </select>
            </div>
            <div class="form-group" style="margin-bottom: 0; width: 150px;">
                <label>Plan</label>
                <select name="plan" class="form-control">
                    <option value="">All Plans</option>
                    <option value="free" <?= $plan === 'free' ? 'selected' : '' ?>>Free</option>
                    <option value="starter" <?= $plan === 'starter' ? 'selected' : '' ?>>Starter</option>
                    <option value="professional" <?= $plan === 'professional' ? 'selected' : '' ?>>Professional</option>
                    <option value="enterprise" <?= $plan === 'enterprise' ? 'selected' : '' ?>>Enterprise</option>
                </select>
            </div>
            <button type="submit" class="btn btn-primary">Filter</button>
            <?php if ($search || $status || $plan): ?>
            <a href="tenants.php" class="btn btn-outline">Clear</a>
            <?php endif; ?>
        </form>
    </div>
</div>

<!-- Tenants Table -->
<div class="card">
    <div class="card-header">
        <h2>Tenants (<?= number_format($totalCount) ?>)</h2>
    </div>
    <div class="card-body" style="padding: 0;">
        <?php if (empty($tenants)): ?>
        <p style="padding: 24px;" class="text-muted">No tenants found.</p>
        <?php else: ?>
        <table class="table">
            <thead>
                <tr>
                    <th>Tenant</th>
                    <th>Contact</th>
                    <th>Plan</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($tenants as $tenant): ?>
                <tr>
                    <td>
                        <strong><?= e($tenant['company_name'] ?: $tenant['name']) ?></strong>
                        <br>
                        <small class="text-muted"><?= e(substr($tenant['id'], 0, 8)) ?>...</small>
                    </td>
                    <td>
                        <?= e($tenant['email']) ?>
                        <?php if ($tenant['phone']): ?>
                        <br><small class="text-muted"><?= e($tenant['phone']) ?></small>
                        <?php endif; ?>
                    </td>
                    <td>
                        <span class="badge badge-<?= $tenant['plan'] === 'enterprise' ? 'primary' : ($tenant['plan'] === 'professional' ? 'info' : ($tenant['plan'] === 'starter' ? 'success' : 'secondary')) ?>">
                            <?= ucfirst($tenant['plan']) ?>
                        </span>
                    </td>
                    <td>
                        <span class="badge badge-<?= $tenant['status'] === 'active' ? 'success' : ($tenant['status'] === 'suspended' ? 'danger' : 'warning') ?>">
                            <?= ucfirst($tenant['status']) ?>
                        </span>
                    </td>
                    <td><?= formatDate($tenant['created_at']) ?></td>
                    <td>
                        <div style="display: flex; gap: 8px;">
                            <?php if ($tenant['status'] === 'active'): ?>
                            <form method="POST" action="" style="display: inline;">
                                <input type="hidden" name="_token" value="<?= generateCsrfToken() ?>">
                                <input type="hidden" name="action" value="suspend">
                                <input type="hidden" name="tenant_id" value="<?= e($tenant['id']) ?>">
                                <button type="submit" class="btn btn-sm btn-outline" data-confirm="Are you sure you want to suspend this tenant?">Suspend</button>
                            </form>
                            <?php else: ?>
                            <form method="POST" action="" style="display: inline;">
                                <input type="hidden" name="_token" value="<?= generateCsrfToken() ?>">
                                <input type="hidden" name="action" value="activate">
                                <input type="hidden" name="tenant_id" value="<?= e($tenant['id']) ?>">
                                <button type="submit" class="btn btn-sm btn-secondary">Activate</button>
                            </form>
                            <?php endif; ?>
                            <form method="POST" action="" style="display: inline;">
                                <input type="hidden" name="_token" value="<?= generateCsrfToken() ?>">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="tenant_id" value="<?= e($tenant['id']) ?>">
                                <button type="submit" class="btn btn-sm btn-danger" data-confirm="Are you sure you want to delete this tenant? This action cannot be undone.">Delete</button>
                            </form>
                        </div>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

        <!-- Pagination -->
        <?php if ($totalPages > 1): ?>
        <div style="padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border);">
            <div class="text-muted">
                Showing <?= $offset + 1 ?> - <?= min($offset + $perPage, $totalCount) ?> of <?= $totalCount ?>
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
