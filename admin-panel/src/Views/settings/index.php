<?php ob_start(); ?>

<div class="card">
    <div class="card-header">
        <h2 class="card-title">System Settings</h2>
    </div>
    <div class="card-body">
        <form method="POST" action="/settings" class="form">
            <div class="form-group">
                <label for="site_name">Site Name</label>
                <input type="text" id="site_name" name="site_name"
                       value="<?= htmlspecialchars($settings['site_name'] ?? 'ThirdBooks') ?>">
            </div>

            <div class="form-group">
                <label for="support_email">Support Email</label>
                <input type="email" id="support_email" name="support_email"
                       value="<?= htmlspecialchars($settings['support_email'] ?? '') ?>">
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="max_tenants">Maximum Tenants</label>
                    <input type="number" id="max_tenants" name="max_tenants"
                           value="<?= $settings['max_tenants'] ?? 1000 ?>">
                </div>
                <div class="form-group">
                    <label for="default_plan">Default Plan</label>
                    <select id="default_plan" name="default_plan">
                        <option value="basic" <?= ($settings['default_plan'] ?? 'basic') === 'basic' ? 'selected' : '' ?>>Basic</option>
                        <option value="professional" <?= ($settings['default_plan'] ?? '') === 'professional' ? 'selected' : '' ?>>Professional</option>
                        <option value="enterprise" <?= ($settings['default_plan'] ?? '') === 'enterprise' ? 'selected' : '' ?>>Enterprise</option>
                    </select>
                </div>
            </div>

            <div class="form-group">
                <label class="checkbox-label">
                    <input type="checkbox" name="maintenance_mode" <?= ($settings['maintenance_mode'] ?? false) ? 'checked' : '' ?>>
                    Enable Maintenance Mode
                </label>
                <small>When enabled, only admins can access the system.</small>
            </div>

            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save Settings</button>
            </div>
        </form>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
