<?php
/**
 * ThirdBooks API Diagnostic Script
 *
 * Access: https://api.thirdbooks.digital/diagnostic.php
 * Protect with token:  ?token=YOUR_DEPLOY_HOOK_SECRET
 *
 * Shows exactly what is failing without needing Laravel to boot.
 * DELETE this file after the server is confirmed healthy.
 */

// ── Simple token protection ────────────────────────────────────────────────
$token = $_GET['token'] ?? '';
if (empty($token) || strlen($token) < 8) {
    http_response_code(403);
    die(json_encode(['error' => 'Token required. Add ?token=YOUR_DEPLOY_HOOK_SECRET']));
}

header('Content-Type: application/json');

$results = [];

// ── 1. PHP version ─────────────────────────────────────────────────────────
$results['php_version']      = PHP_VERSION;
$results['php_version_ok']   = version_compare(PHP_VERSION, '8.1.0', '>=');

// ── 2. Key files present ───────────────────────────────────────────────────
$base = __DIR__;
$results['files'] = [
    'vendor/autoload.php' => file_exists("$base/vendor/autoload.php"),
    'bootstrap/app.php'   => file_exists("$base/bootstrap/app.php"),
    '.env'                => file_exists("$base/.env"),
    'artisan'             => file_exists("$base/artisan"),
    'routes/api.php'      => file_exists("$base/routes/api.php"),
    'config/tenancy.php'  => file_exists("$base/config/tenancy.php"),
];

// ── 3. Read .env (safe keys only) ─────────────────────────────────────────
$envPath = "$base/.env";
$results['env'] = [];
if (file_exists($envPath)) {
    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    $safe  = ['APP_ENV', 'APP_DEBUG', 'APP_URL', 'DB_CONNECTION', 'DB_HOST',
              'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'CACHE_DRIVER',
              'QUEUE_CONNECTION', 'SESSION_DRIVER', 'TENANCY_MODE'];
    foreach ($lines as $line) {
        if (str_starts_with(trim($line), '#')) continue;
        [$key] = explode('=', $line, 2);
        $key = trim($key);
        if (in_array($key, $safe)) {
            $results['env'][$key] = trim(explode('=', $line, 2)[1] ?? '');
        }
        if ($key === 'APP_KEY') {
            $results['env']['APP_KEY'] = strlen(trim(explode('=', $line, 2)[1] ?? '')) > 10
                ? 'SET (length ' . strlen(trim(explode('=', $line, 2)[1])) . ')'
                : 'MISSING OR EMPTY';
        }
    }
} else {
    $results['env']['error'] = '.env file NOT found — this alone causes HTTP 500';
}

// ── 4. Database connectivity ───────────────────────────────────────────────
$results['database'] = [];
if (file_exists($envPath)) {
    $env = [];
    foreach (file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (str_starts_with(trim($line), '#')) continue;
        [$k, $v] = array_pad(explode('=', $line, 2), 2, '');
        $env[trim($k)] = trim($v);
    }

    $host   = $env['DB_HOST']     ?? '127.0.0.1';
    $port   = $env['DB_PORT']     ?? '3306';
    $db     = $env['DB_DATABASE'] ?? '';
    $user   = $env['DB_USERNAME'] ?? '';
    $pass   = $env['DB_PASSWORD'] ?? '';

    try {
        $pdo = new PDO(
            "mysql:host=$host;port=$port;dbname=$db;charset=utf8mb4",
            $user, $pass,
            [PDO::ATTR_TIMEOUT => 5, PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $results['database']['connected'] = true;

        // Check which tables exist
        $tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
        $results['database']['tables'] = $tables;

        $required = ['tenants', 'users', 'personal_access_tokens', 'jobs', 'companies', 'domains'];
        $missing  = array_diff($required, $tables);
        $results['database']['missing_required_tables'] = array_values($missing);
        $results['database']['migrations_needed'] = !empty($missing);

    } catch (PDOException $e) {
        $results['database']['connected'] = false;
        $results['database']['error']     = $e->getMessage();
    }
}

// ── 5. Writable directories ────────────────────────────────────────────────
$dirs = [
    'storage/logs'             => "$base/storage/logs",
    'storage/framework/cache'  => "$base/storage/framework/cache",
    'storage/framework/sessions' => "$base/storage/framework/sessions",
    'storage/framework/views'  => "$base/storage/framework/views",
    'bootstrap/cache'          => "$base/bootstrap/cache",
];
$results['writable'] = [];
foreach ($dirs as $label => $path) {
    $results['writable'][$label] = [
        'exists'   => is_dir($path),
        'writable' => is_writable($path),
    ];
}

// ── 6. PHP extensions ─────────────────────────────────────────────────────
$results['extensions'] = [];
foreach (['pdo', 'pdo_mysql', 'mbstring', 'json', 'openssl', 'tokenizer', 'xml', 'ctype', 'bcmath', 'zip'] as $ext) {
    $results['extensions'][$ext] = extension_loaded($ext);
}

// ── 7. Autoloader test ─────────────────────────────────────────────────────
if (file_exists("$base/vendor/autoload.php")) {
    try {
        require_once "$base/vendor/autoload.php";
        $results['autoloader'] = 'OK — vendor/autoload.php loaded successfully';
    } catch (Throwable $e) {
        $results['autoloader'] = 'FAILED: ' . $e->getMessage();
    }
} else {
    $results['autoloader'] = 'MISSING — composer install has not been run';
}

// ── Summary ────────────────────────────────────────────────────────────────
$critical = [];
if (!$results['files']['vendor/autoload.php'])    $critical[] = 'vendor/ missing — run composer install';
if (!$results['files']['.env'])                   $critical[] = '.env missing — create from .env.example';
if (isset($results['env']['APP_KEY']) && str_contains($results['env']['APP_KEY'], 'MISSING')) $critical[] = 'APP_KEY not set — run php artisan key:generate';
if (!($results['database']['connected'] ?? false)) $critical[] = 'Database not connected — check DB_* credentials in .env';
if (!empty($results['database']['missing_required_tables'] ?? [])) {
    $critical[] = 'Missing DB tables: ' . implode(', ', $results['database']['missing_required_tables']) . ' — run php artisan migrate';
}

$results['critical_issues'] = $critical;
$results['healthy']         = empty($critical);
$results['timestamp']       = date('Y-m-d H:i:s T');

echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
