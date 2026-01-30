<?php
/**
 * ThirdBooks Admin Panel
 * Entry point for the admin panel application
 */

declare(strict_types=1);

// Autoload
require_once __DIR__ . '/../vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->safeLoad();

// Load configuration
$config = require __DIR__ . '/../config/app.php';

// Start session
session_start();

// Simple router
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];

// Check authentication for protected routes
$publicRoutes = ['/login', '/assets'];
$isPublicRoute = false;
foreach ($publicRoutes as $route) {
    if (str_starts_with($uri, $route)) {
        $isPublicRoute = true;
        break;
    }
}

if (!$isPublicRoute && !isset($_SESSION['admin_user'])) {
    header('Location: /login');
    exit;
}

// Route handling
$routes = [
    'GET' => [
        '/' => 'DashboardController@index',
        '/login' => 'AuthController@showLogin',
        '/logout' => 'AuthController@logout',
        '/tenants' => 'TenantsController@index',
        '/tenants/create' => 'TenantsController@create',
        '/tenants/(\d+)' => 'TenantsController@show',
        '/tenants/(\d+)/edit' => 'TenantsController@edit',
        '/users' => 'UsersController@index',
        '/settings' => 'SettingsController@index',
        '/reports' => 'ReportsController@index',
    ],
    'POST' => [
        '/login' => 'AuthController@login',
        '/tenants' => 'TenantsController@store',
        '/tenants/(\d+)' => 'TenantsController@update',
        '/tenants/(\d+)/delete' => 'TenantsController@delete',
        '/tenants/(\d+)/toggle-status' => 'TenantsController@toggleStatus',
    ],
];

// Find matching route
$handler = null;
$params = [];

foreach ($routes[$method] ?? [] as $pattern => $controllerAction) {
    $pattern = '#^' . $pattern . '$#';
    if (preg_match($pattern, $uri, $matches)) {
        $handler = $controllerAction;
        $params = array_slice($matches, 1);
        break;
    }
}

// Handle static assets
if (str_starts_with($uri, '/assets/')) {
    $file = __DIR__ . $uri;
    if (file_exists($file)) {
        $ext = pathinfo($file, PATHINFO_EXTENSION);
        $contentTypes = [
            'css' => 'text/css',
            'js' => 'application/javascript',
            'png' => 'image/png',
            'jpg' => 'image/jpeg',
            'svg' => 'image/svg+xml',
        ];
        header('Content-Type: ' . ($contentTypes[$ext] ?? 'application/octet-stream'));
        readfile($file);
        exit;
    }
}

// Execute controller action
if ($handler) {
    [$controllerName, $action] = explode('@', $handler);
    $controllerClass = "ThirdBooks\\Admin\\Controllers\\$controllerName";

    if (class_exists($controllerClass)) {
        $controller = new $controllerClass($config);
        if (method_exists($controller, $action)) {
            call_user_func_array([$controller, $action], $params);
            exit;
        }
    }
}

// 404 Not Found
http_response_code(404);
include __DIR__ . '/../src/Views/errors/404.php';
