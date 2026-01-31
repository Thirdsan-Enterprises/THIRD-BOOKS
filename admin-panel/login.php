<?php
/**
 * ThirdBooks Admin Panel - Login
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

// Start session
session_name(SESSION_NAME);
session_start();

// Redirect if already logged in
if (isAuthenticated() && getAuthUser()) {
    redirect(BASE_URL . '/index.php');
}

$error = '';

// Handle login form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    // Basic validation
    if (empty($email) || empty($password)) {
        $error = 'Please enter both email and password.';
    } else {
        try {
            $pdo = getDbConnection();

            // Find user by email (must be super_admin)
            $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ? AND role = ? AND is_active = 1 AND deleted_at IS NULL');
            $stmt->execute([$email, 'super_admin']);
            $user = $stmt->fetch();

            if ($user && password_verify($password, $user['password'])) {
                // Login successful
                $_SESSION['admin_user_id'] = $user['id'];
                $_SESSION['admin_user_name'] = $user['name'];
                $_SESSION['admin_user_email'] = $user['email'];
                $_SESSION['login_time'] = time();

                // Regenerate session ID for security
                session_regenerate_id(true);

                // Log the login
                logMessage('info', 'Admin login successful', ['user_id' => $user['id'], 'email' => $email]);

                redirect(BASE_URL . '/index.php');
            } else {
                $error = 'Invalid email or password.';
                logMessage('warning', 'Failed admin login attempt', ['email' => $email, 'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown']);
            }
        } catch (PDOException $e) {
            $error = 'A database error occurred. Please try again later.';
            logMessage('error', 'Login database error', ['error' => $e->getMessage()]);
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - ThirdBooks Admin</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #1E3A5F 0%, #0D9488 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .login-container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            width: 100%;
            max-width: 420px;
            overflow: hidden;
        }

        .login-header {
            background: #1E3A5F;
            padding: 40px 30px;
            text-align: center;
        }

        .login-header h1 {
            color: white;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 8px;
        }

        .login-header p {
            color: rgba(255, 255, 255, 0.7);
            font-size: 14px;
        }

        .logo {
            width: 60px;
            height: 60px;
            background: #0D9488;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
        }

        .logo svg {
            width: 36px;
            height: 36px;
            color: white;
        }

        .login-form {
            padding: 40px 30px;
        }

        .form-group {
            margin-bottom: 24px;
        }

        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #374151;
            font-size: 14px;
        }

        .form-group input {
            width: 100%;
            padding: 14px 16px;
            border: 2px solid #E5E7EB;
            border-radius: 10px;
            font-size: 15px;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        .form-group input:focus {
            outline: none;
            border-color: #0D9488;
            box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.1);
        }

        .btn {
            width: 100%;
            padding: 14px 24px;
            background: #1E3A5F;
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s, transform 0.1s;
        }

        .btn:hover {
            background: #2E5077;
        }

        .btn:active {
            transform: scale(0.98);
        }

        .error-message {
            background: #FEE2E2;
            color: #DC2626;
            padding: 12px 16px;
            border-radius: 8px;
            margin-bottom: 24px;
            font-size: 14px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .error-message svg {
            flex-shrink: 0;
        }

        .login-footer {
            text-align: center;
            padding: 20px 30px 30px;
            border-top: 1px solid #E5E7EB;
        }

        .login-footer p {
            color: #6B7280;
            font-size: 13px;
        }

        .login-footer a {
            color: #0D9488;
            text-decoration: none;
        }

        .login-footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-header">
            <div class="logo">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M3 21h18M3 10h18M3 7l9-4 9 4M4 10h16v11H4z"/>
                </svg>
            </div>
            <h1>ThirdBooks</h1>
            <p>Admin Panel</p>
        </div>

        <form class="login-form" method="POST" action="">
            <?php if ($error): ?>
            <div class="error-message">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="8" x2="12" y2="12"/>
                    <line x1="12" y1="16" x2="12.01" y2="16"/>
                </svg>
                <?= e($error) ?>
            </div>
            <?php endif; ?>

            <div class="form-group">
                <label for="email">Email Address</label>
                <input type="email" id="email" name="email" value="<?= e($_POST['email'] ?? '') ?>" placeholder="admin@thirdbooks.digital" required autofocus>
            </div>

            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" placeholder="Enter your password" required>
            </div>

            <button type="submit" class="btn">Sign In</button>
        </form>

        <div class="login-footer">
            <p>&copy; <?= date('Y') ?> ThirdBooks. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
