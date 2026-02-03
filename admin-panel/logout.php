<?php
/**
 * ThirdBooks Admin Panel - Logout
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

// Start session
session_name(SESSION_NAME);
session_start();

// Log the logout
if (isset($_SESSION['admin_user_id'])) {
    logMessage('info', 'Admin logout', ['user_id' => $_SESSION['admin_user_id']]);
}

// Destroy session
$_SESSION = [];

if (ini_get('session.use_cookies')) {
    $params = session_get_cookie_params();
    setcookie(
        session_name(),
        '',
        time() - 42000,
        $params['path'],
        $params['domain'],
        $params['secure'],
        $params['httponly']
    );
}

session_destroy();

// Redirect to login
redirect(BASE_URL . '/login.php');
