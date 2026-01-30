<?php ob_start(); ?>

<div class="card">
    <div class="card-header">
        <h2 class="card-title">Edit Tenant</h2>
    </div>
    <div class="card-body">
        <form method="POST" action="/tenants/<?= $tenant['id'] ?>" class="form">
            <div class="form-row">
                <div class="form-group">
                    <label for="company_name">Company Name *</label>
                    <input type="text" id="company_name" name="company_name" required
                           value="<?= htmlspecialchars($tenant['company_name']) ?>">
                </div>
                <div class="form-group">
                    <label for="plan">Subscription Plan *</label>
                    <select id="plan" name="plan" required>
                        <?php foreach ($plans as $key => $plan): ?>
                            <option value="<?= $key ?>" <?= ($tenant['plan'] ?? 'basic') === $key ? 'selected' : '' ?>>
                                <?= $plan['name'] ?> - UGX <?= number_format($plan['price']) ?>/month
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="owner_name">Owner Name *</label>
                    <input type="text" id="owner_name" name="owner_name" required
                           value="<?= htmlspecialchars($tenant['owner_name'] ?? '') ?>">
                </div>
                <div class="form-group">
                    <label for="owner_email">Owner Email *</label>
                    <input type="email" id="owner_email" name="owner_email" required
                           value="<?= htmlspecialchars($tenant['owner_email'] ?? '') ?>">
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="phone">Phone Number</label>
                    <input type="tel" id="phone" name="phone"
                           value="<?= htmlspecialchars($tenant['phone'] ?? '') ?>">
                </div>
                <div class="form-group">
                    <label for="status">Status</label>
                    <select id="status" name="status">
                        <option value="active" <?= ($tenant['status'] ?? 'active') === 'active' ? 'selected' : '' ?>>Active</option>
                        <option value="suspended" <?= ($tenant['status'] ?? '') === 'suspended' ? 'selected' : '' ?>>Suspended</option>
                        <option value="inactive" <?= ($tenant['status'] ?? '') === 'inactive' ? 'selected' : '' ?>>Inactive</option>
                    </select>
                </div>
            </div>

            <div class="form-group">
                <label for="address">Address</label>
                <textarea id="address" name="address" rows="3"><?= htmlspecialchars($tenant['address'] ?? '') ?></textarea>
            </div>

            <div class="form-actions">
                <a href="/tenants/<?= $tenant['id'] ?>" class="btn btn-secondary">Cancel</a>
                <button type="submit" class="btn btn-primary">Update Tenant</button>
            </div>
        </form>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
