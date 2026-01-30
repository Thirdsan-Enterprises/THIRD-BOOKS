<?php

namespace ThirdBooks\Admin\Controllers;

class AuthController extends BaseController
{
    public function showLogin(): void
    {
        if (isset($_SESSION['admin_user'])) {
            $this->redirect('/');
        }

        $this->view('auth/login', [
            'error' => $_SESSION['login_error'] ?? null,
        ]);
        unset($_SESSION['login_error']);
    }

    public function login(): void
    {
        $email = $_POST['email'] ?? '';
        $password = $_POST['password'] ?? '';

        if (empty($email) || empty($password)) {
            $_SESSION['login_error'] = 'Please enter both email and password.';
            $this->redirect('/login');
        }

        // Try to authenticate with the API
        $result = $this->apiPost('/admin/auth/login', [
            'email' => $email,
            'password' => $password,
        ]);

        if (isset($result['error'])) {
            // Fallback to local admin credentials for development
            $adminEmail = $_ENV['ADMIN_EMAIL'] ?? 'admin@thirdbooks.com';
            $adminPassword = $_ENV['ADMIN_PASSWORD'] ?? 'admin123';

            if ($email === $adminEmail && $password === $adminPassword) {
                $_SESSION['admin_user'] = [
                    'id' => 1,
                    'name' => 'System Administrator',
                    'email' => $adminEmail,
                    'role' => 'super_admin',
                ];
                $_SESSION['api_token'] = 'local_development_token';

                $this->setFlash('success', 'Welcome back, Administrator!');
                $this->redirect('/');
            }

            $_SESSION['login_error'] = 'Invalid credentials. Please try again.';
            $this->redirect('/login');
        }

        // Store user data and token
        $_SESSION['admin_user'] = $result['user'];
        $_SESSION['api_token'] = $result['token'];

        $this->setFlash('success', 'Welcome back, ' . $result['user']['name'] . '!');
        $this->redirect('/');
    }

    public function logout(): void
    {
        // Clear API session if available
        if (isset($_SESSION['api_token'])) {
            $this->apiPost('/admin/auth/logout');
        }

        // Destroy local session
        session_destroy();

        // Start new session for flash message
        session_start();
        $this->setFlash('success', 'You have been logged out successfully.');

        $this->redirect('/login');
    }
}
