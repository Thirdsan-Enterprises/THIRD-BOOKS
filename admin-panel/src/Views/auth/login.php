<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - ThirdBooks Admin</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body class="login-page">
    <div class="login-container">
        <div class="login-card">
            <div class="login-header">
                <div class="login-logo">
                    <span class="logo-icon">📚</span>
                    <h1>ThirdBooks</h1>
                </div>
                <p class="login-subtitle">Admin Panel</p>
            </div>

            <?php if (isset($error) && $error): ?>
                <div class="alert alert-error">
                    <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>

            <form method="POST" action="/login" class="login-form">
                <div class="form-group">
                    <label for="email">Email Address</label>
                    <input type="email" id="email" name="email" required autofocus
                           placeholder="admin@thirdbooks.com">
                </div>

                <div class="form-group">
                    <label for="password">Password</label>
                    <input type="password" id="password" name="password" required
                           placeholder="••••••••">
                </div>

                <button type="submit" class="btn btn-primary btn-block">
                    Sign In
                </button>
            </form>

            <div class="login-footer">
                <p>ThirdBooks Admin Panel &copy; <?= date('Y') ?></p>
            </div>
        </div>
    </div>
</body>
</html>
