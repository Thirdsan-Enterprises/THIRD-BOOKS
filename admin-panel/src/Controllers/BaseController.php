<?php

namespace ThirdBooks\Admin\Controllers;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

abstract class BaseController
{
    protected array $config;
    protected Client $apiClient;

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->apiClient = new Client([
            'base_uri' => $config['api']['base_url'],
            'timeout' => $config['api']['timeout'],
            'headers' => [
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ],
        ]);
    }

    protected function view(string $template, array $data = []): void
    {
        $data['config'] = $this->config;
        $data['user'] = $_SESSION['admin_user'] ?? null;

        extract($data);

        include __DIR__ . "/../Views/{$template}.php";
    }

    protected function redirect(string $url): void
    {
        header("Location: $url");
        exit;
    }

    protected function json(array $data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json');
        echo json_encode($data);
        exit;
    }

    protected function apiGet(string $endpoint, array $query = []): array
    {
        try {
            $options = ['headers' => $this->getApiHeaders()];
            if (!empty($query)) {
                $options['query'] = $query;
            }

            $response = $this->apiClient->get($endpoint, $options);
            return json_decode($response->getBody()->getContents(), true);
        } catch (GuzzleException $e) {
            return ['error' => $e->getMessage()];
        }
    }

    protected function apiPost(string $endpoint, array $data = []): array
    {
        try {
            $response = $this->apiClient->post($endpoint, [
                'headers' => $this->getApiHeaders(),
                'json' => $data,
            ]);
            return json_decode($response->getBody()->getContents(), true);
        } catch (GuzzleException $e) {
            return ['error' => $e->getMessage()];
        }
    }

    protected function apiPut(string $endpoint, array $data = []): array
    {
        try {
            $response = $this->apiClient->put($endpoint, [
                'headers' => $this->getApiHeaders(),
                'json' => $data,
            ]);
            return json_decode($response->getBody()->getContents(), true);
        } catch (GuzzleException $e) {
            return ['error' => $e->getMessage()];
        }
    }

    protected function apiDelete(string $endpoint): array
    {
        try {
            $response = $this->apiClient->delete($endpoint, [
                'headers' => $this->getApiHeaders(),
            ]);
            return json_decode($response->getBody()->getContents(), true);
        } catch (GuzzleException $e) {
            return ['error' => $e->getMessage()];
        }
    }

    protected function getApiHeaders(): array
    {
        $headers = [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ];

        if (isset($_SESSION['api_token'])) {
            $headers['Authorization'] = 'Bearer ' . $_SESSION['api_token'];
        }

        return $headers;
    }

    protected function setFlash(string $type, string $message): void
    {
        $_SESSION['flash'] = [
            'type' => $type,
            'message' => $message,
        ];
    }

    protected function getFlash(): ?array
    {
        $flash = $_SESSION['flash'] ?? null;
        unset($_SESSION['flash']);
        return $flash;
    }
}
