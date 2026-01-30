<?php ob_start(); ?>

<div class="card">
    <div class="card-header">
        <h2 class="card-title">Create New Tenant</h2>
    </div>
    <div class="card-body">
        <form method="POST" action="/tenants" class="form">
            <div class="form-row">
                <div class="form-group">
                    <label for="company_name">Company Name *</label>
                    <input type="text" id="company_name" name="company_name" required
                           placeholder="Enter company name">
                </div>
                <div class="form-group">
                    <label for="plan">Subscription Plan *</label>
                    <select id="plan" name="plan" required>
                        <?php foreach ($plans as $key => $plan): ?>
                            <option value="<?= $key ?>">
                                <?= $plan['name'] ?> - UGX <?= number_format($plan['price']) ?>/month
                                (<?= $plan['users'] === -1 ? 'Unlimited' : $plan['users'] ?> users, <?= $plan['storage'] ?>)
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="owner_name">Owner Name *</label>
                    <input type="text" id="owner_name" name="owner_name" required
                           placeholder="Enter owner full name">
                </div>
                <div class="form-group">
                    <label for="owner_email">Owner Email *</label>
                    <input type="email" id="owner_email" name="owner_email" required
                           placeholder="owner@example.com">
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="phone">Phone Number</label>
                    <input type="tel" id="phone" name="phone"
                           placeholder="+256 700 123456">
                </div>
            </div>

            <div class="form-group">
                <label for="address">Address</label>
                <textarea id="address" name="address" rows="3"
                          placeholder="Company address"></textarea>
            </div>

            <div class="form-actions">
                <a href="/tenants" class="btn btn-secondary">Cancel</a>
                <button type="submit" class="btn btn-primary">Create Tenant</button>
            </div>
        </form>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
