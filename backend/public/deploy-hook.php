<?php
/**
 * ThirdBooks Post-Deployment Hook
 *
 * Triggered by GitHub Actions after FTP upload to run artisan commands.
 * Secured with a shared secret token stored in GitHub Secrets.
 *
 * Usage: POST https://api.thirdbooks.digital/deploy-hook.php
 * Header: X-Deploy-Token: <DEPLOY_HOOK_SECRET>
 */

// Strict error handling
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');

// Accept GET or POST (GitHub Actions uses GET with ?secret=)
$token = $_GET['secret']
    ?? $_SERVER['HTTP_X_DEPLOY_TOKEN']
    ?? '';

// Read expected token from .deploy-token or .env
$tokenFile = __DIR__ . '/.deploy-token';
$expectedToken = '';
if (file_exists($tokenFile)) {
    $expectedToken = trim(file_get_contents($tokenFile));
}
// Fallback: read DEPLOY_HOOK_SECRET from .env
if (empty($expectedToken) && file_exists(__DIR__ . '/.env')) {
    foreach (file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (str_starts_with($line, 'DEPLOY_HOOK_SECRET=')) {
            $expectedToken = trim(substr($line, strlen('DEPLOY_HOOK_SECRET=')));
            break;
        }
    }
}

if (empty($token) || empty($expectedToken) || !hash_equals($expectedToken, $token)) {
    http_response_code(403);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Rate limit: only allow one deploy per 60 seconds
$lockFile = sys_get_temp_dir() . '/thirdbooks_deploy.lock';
if (file_exists($lockFile) && (time() - filemtime($lockFile)) < 60) {
    http_response_code(429);
    echo json_encode(['error' => 'Deploy in progress, try again later']);
    exit;
}
touch($lockFile);

// After flattened DirectAdmin deployment, public_html/ IS the project root.
// Both development (backend/) and production (public_html/) resolve correctly:
//   dev:  __DIR__ = backend/public/  → dirname = backend/  ✓
//   prod: __DIR__ = public_html/     → dirname would go UP, wrong!
// So use __DIR__ directly and check if artisan is here or one level up.
$projectRoot = file_exists(__DIR__ . '/artisan')
    ? __DIR__           // production (flattened)
    : dirname(__DIR__); // development (standard Laravel structure)
$php = PHP_BINARY ?: 'php';
$artisan = $projectRoot . '/artisan';

if (!file_exists($artisan)) {
    http_response_code(500);
    echo json_encode(['error' => 'Artisan not found at project root']);
    exit;
}

$results = [];
$allSuccess = true;

/**
 * Run an artisan command and capture output
 */
function runArtisan(string $command, string $projectRoot, string $php, string $artisan): array {
    $fullCommand = sprintf(
        'cd %s && %s %s %s 2>&1',
        escapeshellarg($projectRoot),
        escapeshellarg($php),
        escapeshellarg($artisan),
        $command
    );

    $output = [];
    $exitCode = 0;
    exec($fullCommand, $output, $exitCode);

    return [
        'command' => "artisan {$command}",
        'exit_code' => $exitCode,
        'output' => implode("\n", $output),
        'success' => $exitCode === 0,
    ];
}

// Determine which commands to run
$body = json_decode(file_get_contents('php://input'), true) ?? [];
$runMigrate = $body['migrate'] ?? true;
$runSeed = $body['seed'] ?? false;  // Only on first deploy
$runCache = $body['cache'] ?? true;

// 1. Set directory permissions
$storageDir = $projectRoot . '/storage';
$cacheDir = $projectRoot . '/bootstrap/cache';

foreach ([$storageDir, $cacheDir] as $dir) {
    if (is_dir($dir)) {
        chmod($dir, 0775);
        // Recursively set permissions on subdirectories
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($dir, RecursiveDirectoryIterator::SKIP_DOTS),
            RecursiveIteratorIterator::SELF_FIRST
        );
        foreach ($iterator as $item) {
            if ($item->isDir()) {
                chmod($item->getPathname(), 0775);
            } elseif ($item->isFile()) {
                chmod($item->getPathname(), 0664);
            }
        }
    }
}
$results[] = ['command' => 'chmod storage & cache', 'success' => true, 'output' => 'Permissions set'];

// 2. Run migrations
if ($runMigrate) {
    $result = runArtisan('migrate --force', $projectRoot, $php, $artisan);
    $results[] = $result;
    if (!$result['success']) $allSuccess = false;
}

// 3. Seed database (first deploy only)
if ($runSeed) {
    $result = runArtisan('db:seed --force', $projectRoot, $php, $artisan);
    $results[] = $result;
    if (!$result['success']) $allSuccess = false;
}

// 4. Cache configuration
if ($runCache) {
    foreach (['config:cache', 'route:cache', 'view:cache'] as $cmd) {
        $result = runArtisan($cmd, $projectRoot, $php, $artisan);
        $results[] = $result;
        if (!$result['success']) $allSuccess = false;
    }
}

// 5. Storage link (idempotent)
$result = runArtisan('storage:link --force', $projectRoot, $php, $artisan);
$results[] = $result;

// Clean up lock file
@unlink($lockFile);

$statusCode = $allSuccess ? 200 : 500;
http_response_code($statusCode);

echo json_encode([
    'status' => $allSuccess ? 'success' : 'partial_failure',
    'timestamp' => date('c'),
    'results' => $results,
], JSON_PRETTY_PRINT);
