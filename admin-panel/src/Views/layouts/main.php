<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($title ?? 'Admin Panel') ?> - <?= htmlspecialchars($config['name']) ?></title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
    <div class="app-container">
        <!-- Sidebar -->
        <aside class="sidebar">
            <div class="sidebar-header">
                <div class="logo">
                    <span class="logo-icon">📚</span>
                    <span class="logo-text">ThirdBooks</span>
                </div>
                <span class="logo-subtitle">Admin Panel</span>
            </div>

            <nav class="sidebar-nav">
                <a href="/" class="nav-item <?= ($title ?? '') === 'Dashboard' ? 'active' : '' ?>">
                    <span class="nav-icon">📊</span>
                    <span class="nav-text">Dashboard</span>
                </a>
                <a href="/tenants" class="nav-item <?= str_contains($title ?? '', 'Tenant') ? 'active' : '' ?>">
                    <span class="nav-icon">🏢</span>
                    <span class="nav-text">Tenants</span>
                </a>
                <a href="/users" class="nav-item <?= ($title ?? '') === 'Users' ? 'active' : '' ?>">
                    <span class="nav-icon">👥</span>
                    <span class="nav-text">Users</span>
                </a>
                <a href="/reports" class="nav-item <?= ($title ?? '') === 'Reports' ? 'active' : '' ?>">
                    <span class="nav-icon">📈</span>
                    <span class="nav-text">Reports</span>
                </a>
                <a href="/settings" class="nav-item <?= ($title ?? '') === 'Settings' ? 'active' : '' ?>">
                    <span class="nav-icon">⚙️</span>
                    <span class="nav-text">Settings</span>
                </a>
            </nav>

            <div class="sidebar-footer">
                <div class="user-info">
                    <div class="user-avatar"><?= substr($user['name'] ?? 'A', 0, 1) ?></div>
                    <div class="user-details">
                        <div class="user-name"><?= htmlspecialchars($user['name'] ?? 'Admin') ?></div>
                        <div class="user-role"><?= htmlspecialchars(ucfirst(str_replace('_', ' ', $user['role'] ?? 'admin'))) ?></div>
                    </div>
                </div>
                <a href="/logout" class="logout-btn">Logout</a>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="main-content">
            <header class="content-header">
                <h1 class="page-title"><?= htmlspecialchars($title ?? 'Dashboard') ?></h1>
                <div class="header-actions">
                    <?php if (isset($headerActions)): ?>
                        <?= $headerActions ?>
                    <?php endif; ?>
                </div>
            </header>

            <?php if (isset($flash) && $flash): ?>
                <div class="alert alert-<?= $flash['type'] ?>">
                    <?= htmlspecialchars($flash['message']) ?>
                </div>
            <?php endif; ?>

            <div class="content-body">
                <?= $content ?? '' ?>
            </div>
        </main>
    </div>

    <script src="/assets/js/app.js"></script>
</body>
</html>
