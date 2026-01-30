<?php ob_start(); ?>

<div class="reports-grid">
    <div class="card report-card">
        <div class="card-body">
            <div class="report-icon">📊</div>
            <h3>Tenant Growth</h3>
            <p>View tenant signup trends over time.</p>
            <a href="/reports/tenant-growth" class="btn btn-secondary">View Report</a>
        </div>
    </div>

    <div class="card report-card">
        <div class="card-body">
            <div class="report-icon">💰</div>
            <h3>Revenue Report</h3>
            <p>Monthly and yearly revenue breakdown.</p>
            <a href="/reports/revenue" class="btn btn-secondary">View Report</a>
        </div>
    </div>

    <div class="card report-card">
        <div class="card-body">
            <div class="report-icon">👥</div>
            <h3>User Activity</h3>
            <p>User engagement and activity metrics.</p>
            <a href="/reports/user-activity" class="btn btn-secondary">View Report</a>
        </div>
    </div>

    <div class="card report-card">
        <div class="card-body">
            <div class="report-icon">💾</div>
            <h3>Storage Usage</h3>
            <p>Storage utilization across tenants.</p>
            <a href="/reports/storage" class="btn btn-secondary">View Report</a>
        </div>
    </div>

    <div class="card report-card">
        <div class="card-body">
            <div class="report-icon">📈</div>
            <h3>Plan Distribution</h3>
            <p>Breakdown of tenants by subscription plan.</p>
            <a href="/reports/plans" class="btn btn-secondary">View Report</a>
        </div>
    </div>

    <div class="card report-card">
        <div class="card-body">
            <div class="report-icon">🔔</div>
            <h3>System Health</h3>
            <p>API performance and error logs.</p>
            <a href="/reports/health" class="btn btn-secondary">View Report</a>
        </div>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
