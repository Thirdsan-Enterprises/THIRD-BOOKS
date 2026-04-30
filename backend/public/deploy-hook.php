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

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');

$token = $_GET['secret']
    ?? $_SERVER['HTTP_X_DEPLOY_TOKEN']
    ?? '';

$tokenFile = __DIR__ . '/.deploy-token';
$expectedToken = '';
if (file_exists($tokenFile)) {
    $expectedToken = trim(file_get_contents($tokenFile));
}
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

$lockFile = sys_get_temp_dir() . '/thirdbooks_deploy.lock';
if (file_exists($lockFile) && (time() - filemtime($lockFile)) < 60) {
    http_response_code(429);
    echo json_encode(['error' => 'Deploy in progress, try again later']);
    exit;
}
touch($lockFile);

$projectRoot = file_exists(__DIR__ . '/artisan')
    ? __DIR__
    : dirname(__DIR__);
$php = PHP_BINARY ?: 'php';
$artisan = $projectRoot . '/artisan';

if (!file_exists($artisan)) {
    http_response_code(500);
    echo json_encode(['error' => 'Artisan not found at project root']);
    exit;
}

$results = [];
$allSuccess = true;

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
        'command'   => "artisan {$command}",
        'exit_code' => $exitCode,
        'output'    => implode("\n", $output),
        'success'   => $exitCode === 0,
    ];
}

$body = json_decode(file_get_contents('php://input'), true) ?? [];
$runMigrate = $body['migrate'] ?? true;
$runSeed    = $body['seed']    ?? false;
$runCache   = $body['cache']   ?? true;

// 1. Set directory permissions
$storageDir = $projectRoot . '/storage';
$cacheDir   = $projectRoot . '/bootstrap/cache';
foreach ([$storageDir, $cacheDir] as $dir) {
    if (is_dir($dir)) {
        chmod($dir, 0775);
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($dir, RecursiveDirectoryIterator::SKIP_DOTS),
            RecursiveIteratorIterator::SELF_FIRST
        );
        foreach ($iterator as $item) {
            if ($item->isDir())  chmod($item->getPathname(), 0775);
            elseif ($item->isFile()) chmod($item->getPathname(), 0664);
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

// 5. Seed MagicBet outlets for all tenants (idempotent — uses updateOrCreate)
$result = runArtisan('magicbet:seed-outlets --all', $projectRoot, $php, $artisan);
$results[] = $result;

// 6. Storage link (idempotent)
$results[] = runArtisan('storage:link --force', $projectRoot, $php, $artisan);

// 6. System diagnostic — output appears in GitHub Actions log after every deploy
$results[] = runArtisan('diagnose', $projectRoot, $php, $artisan);

@unlink($lockFile);

http_response_code($allSuccess ? 200 : 500);
echo json_encode([
    'status'    => $allSuccess ? 'success' : 'partial_failure',
    'timestamp' => date('c'),
    'results'   => $results,
], JSON_PRETTY_PRINT);
