<?php
/**
 * ThirdBooks Admin Panel Configuration
 *
 * IMPORTANT: Update these settings with your actual database credentials
 * before deploying to thirdbooks.digital
 */

// Prevent direct access
if (!defined('ADMIN_PANEL')) {
    die('Direct access not permitted');
}

// =====================================================
// ENVIRONMENT
// =====================================================
define('APP_ENV', 'production'); // 'development' or 'production'
define('APP_DEBUG', false);      // Set to true for debugging (disable in production!)
define('APP_NAME', 'ThirdBooks Admin');
define('APP_VERSION', '1.0.0');

// =====================================================
// URL CONFIGURATION
// =====================================================
define('BASE_URL', 'https://thirdbooks.digital');
define('API_URL', 'https://api.thirdbooks.digital');
define('ASSETS_URL', BASE_URL . '/assets');

// =====================================================
// DATABASE CONFIGURATION
// Update with your DirectAdmin MySQL credentials
// =====================================================
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'your_database_name');      // Same as API database
define('DB_USER', 'your_database_user');
define('DB_PASS', 'your_database_password');
define('DB_CHARSET', 'utf8mb4');

// =====================================================
// SESSION CONFIGURATION
// =====================================================
define('SESSION_NAME', 'thirdbooks_admin');
define('SESSION_LIFETIME', 7200); // 2 hours
define('SESSION_PATH', '/');
define('SESSION_DOMAIN', '.thirdbooks.digital');
define('SESSION_SECURE', true);   // Requires HTTPS
define('SESSION_HTTPONLY', true);

// =====================================================
// SECURITY
// =====================================================
define('CSRF_TOKEN_NAME', '_token');
define('PASSWORD_ALGO', PASSWORD_BCRYPT);
define('PASSWORD_COST', 12);

// Allowed admin emails (add your admin emails here)
define('ALLOWED_ADMIN_EMAILS', serialize([
    'admin@thirdbooks.digital',
    // Add more admin emails as needed
]));

// =====================================================
// TIMEZONE
// =====================================================
define('TIMEZONE', 'Africa/Kampala');
date_default_timezone_set(TIMEZONE);

// =====================================================
// FILE PATHS
// =====================================================
define('ROOT_PATH', dirname(__DIR__));
define('CONFIG_PATH', ROOT_PATH . '/config');
define('VIEWS_PATH', ROOT_PATH . '/views');
define('CONTROLLERS_PATH', ROOT_PATH . '/controllers');
define('ASSETS_PATH', ROOT_PATH . '/assets');
define('LOGS_PATH', ROOT_PATH . '/logs');
define('UPLOADS_PATH', ROOT_PATH . '/uploads');

// =====================================================
// LOGGING
// =====================================================
define('LOG_ENABLED', true);
define('LOG_FILE', LOGS_PATH . '/admin_' . date('Y-m-d') . '.log');
define('LOG_LEVEL', 'error'); // 'debug', 'info', 'warning', 'error'

// =====================================================
// PAGINATION
// =====================================================
define('ITEMS_PER_PAGE', 25);

// =====================================================
// ERROR HANDLING
// =====================================================
if (APP_DEBUG) {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
} else {
    error_reporting(0);
    ini_set('display_errors', 0);
}

// =====================================================
// HELPER FUNCTIONS
// =====================================================

/**
 * Get database connection
 */
function getDbConnection(): PDO {
    static $pdo = null;

    if ($pdo === null) {
        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=%s',
            DB_HOST,
            DB_PORT,
            DB_NAME,
            DB_CHARSET
        );

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci"
        ];

        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            if (APP_DEBUG) {
                die('Database connection failed: ' . $e->getMessage());
            }
            die('Database connection failed. Please check your configuration.');
        }
    }

    return $pdo;
}

/**
 * Log message to file
 */
function logMessage(string $level, string $message, array $context = []): void {
    if (!LOG_ENABLED) return;

    $levels = ['debug' => 0, 'info' => 1, 'warning' => 2, 'error' => 3];
    if ($levels[$level] < $levels[LOG_LEVEL]) return;

    $logDir = dirname(LOG_FILE);
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }

    $timestamp = date('Y-m-d H:i:s');
    $contextStr = !empty($context) ? ' ' . json_encode($context) : '';
    $logEntry = "[{$timestamp}] [{$level}] {$message}{$contextStr}" . PHP_EOL;

    file_put_contents(LOG_FILE, $logEntry, FILE_APPEND | LOCK_EX);
}

/**
 * Generate CSRF token
 */
function generateCsrfToken(): string {
    if (empty($_SESSION[CSRF_TOKEN_NAME])) {
        $_SESSION[CSRF_TOKEN_NAME] = bin2hex(random_bytes(32));
    }
    return $_SESSION[CSRF_TOKEN_NAME];
}

/**
 * Validate CSRF token
 */
function validateCsrfToken(string $token): bool {
    return isset($_SESSION[CSRF_TOKEN_NAME]) && hash_equals($_SESSION[CSRF_TOKEN_NAME], $token);
}

/**
 * Redirect to URL
 */
function redirect(string $url): void {
    header('Location: ' . $url);
    exit;
}

/**
 * Check if user is authenticated
 */
function isAuthenticated(): bool {
    return isset($_SESSION['admin_user_id']) && !empty($_SESSION['admin_user_id']);
}

/**
 * Get authenticated user
 */
function getAuthUser(): ?array {
    if (!isAuthenticated()) return null;

    static $user = null;

    if ($user === null) {
        $pdo = getDbConnection();
        $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ? AND role = ? AND is_active = 1');
        $stmt->execute([$_SESSION['admin_user_id'], 'super_admin']);
        $user = $stmt->fetch();
    }

    return $user ?: null;
}

/**
 * Require authentication
 */
function requireAuth(): void {
    if (!isAuthenticated() || !getAuthUser()) {
        redirect(BASE_URL . '/login.php');
    }
}

/**
 * Sanitize output
 */
function e(string $string): string {
    return htmlspecialchars($string, ENT_QUOTES, 'UTF-8');
}

/**
 * Format currency
 */
function formatCurrency(float $amount, string $currency = 'UGX'): string {
    if ($currency === 'UGX') {
        return 'UGX ' . number_format($amount, 0);
    }
    return $currency . ' ' . number_format($amount, 2);
}

/**
 * Format date
 */
function formatDate(?string $date, string $format = 'd M Y'): string {
    if (empty($date)) return '-';
    return date($format, strtotime($date));
}

/**
 * Format datetime
 */
function formatDateTime(?string $datetime, string $format = 'd M Y H:i'): string {
    if (empty($datetime)) return '-';
    return date($format, strtotime($datetime));
}
