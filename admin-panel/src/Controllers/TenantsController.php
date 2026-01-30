<?php

namespace ThirdBooks\Admin\Controllers;

class TenantsController extends BaseController
{
    public function index(): void
    {
        $page = (int) ($_GET['page'] ?? 1);
        $search = $_GET['search'] ?? '';
        $status = $_GET['status'] ?? '';

        $query = ['page' => $page, 'per_page' => 15];
        if ($search) {
            $query['search'] = $search;
        }
        if ($status) {
            $query['status'] = $status;
        }

        $result = $this->apiGet('/admin/tenants', $query);

        if (isset($result['error'])) {
            $tenants = [];
            $pagination = ['total' => 0, 'current_page' => 1, 'last_page' => 1];
        } else {
            $tenants = $result['data'] ?? [];
            $pagination = $result['meta'] ?? ['total' => 0, 'current_page' => 1, 'last_page' => 1];
        }

        $this->view('tenants/index', [
            'title' => 'Tenants',
            'tenants' => $tenants,
            'pagination' => $pagination,
            'search' => $search,
            'status' => $status,
            'flash' => $this->getFlash(),
        ]);
    }

    public function create(): void
    {
        $this->view('tenants/create', [
            'title' => 'Create Tenant',
            'plans' => $this->getPlans(),
        ]);
    }

    public function store(): void
    {
        $data = [
            'company_name' => $_POST['company_name'] ?? '',
            'owner_name' => $_POST['owner_name'] ?? '',
            'owner_email' => $_POST['owner_email'] ?? '',
            'phone' => $_POST['phone'] ?? '',
            'plan' => $_POST['plan'] ?? 'basic',
            'address' => $_POST['address'] ?? '',
        ];

        $result = $this->apiPost('/admin/tenants', $data);

        if (isset($result['error'])) {
            $this->setFlash('error', 'Failed to create tenant: ' . $result['error']);
            $this->redirect('/tenants/create');
        }

        $this->setFlash('success', 'Tenant created successfully!');
        $this->redirect('/tenants');
    }

    public function show(string $id): void
    {
        $result = $this->apiGet("/admin/tenants/$id");

        if (isset($result['error'])) {
            $this->setFlash('error', 'Tenant not found.');
            $this->redirect('/tenants');
        }

        $tenant = $result['data'] ?? $result;

        // Get tenant statistics
        $stats = $this->apiGet("/admin/tenants/$id/stats");
        if (isset($stats['error'])) {
            $stats = [
                'users_count' => 0,
                'transactions_count' => 0,
                'storage_used' => 0,
                'last_activity' => null,
            ];
        }

        $this->view('tenants/show', [
            'title' => $tenant['company_name'] ?? 'Tenant Details',
            'tenant' => $tenant,
            'stats' => $stats,
            'flash' => $this->getFlash(),
        ]);
    }

    public function edit(string $id): void
    {
        $result = $this->apiGet("/admin/tenants/$id");

        if (isset($result['error'])) {
            $this->setFlash('error', 'Tenant not found.');
            $this->redirect('/tenants');
        }

        $this->view('tenants/edit', [
            'title' => 'Edit Tenant',
            'tenant' => $result['data'] ?? $result,
            'plans' => $this->getPlans(),
        ]);
    }

    public function update(string $id): void
    {
        $data = [
            'company_name' => $_POST['company_name'] ?? '',
            'owner_name' => $_POST['owner_name'] ?? '',
            'owner_email' => $_POST['owner_email'] ?? '',
            'phone' => $_POST['phone'] ?? '',
            'plan' => $_POST['plan'] ?? 'basic',
            'address' => $_POST['address'] ?? '',
            'status' => $_POST['status'] ?? 'active',
        ];

        $result = $this->apiPut("/admin/tenants/$id", $data);

        if (isset($result['error'])) {
            $this->setFlash('error', 'Failed to update tenant: ' . $result['error']);
            $this->redirect("/tenants/$id/edit");
        }

        $this->setFlash('success', 'Tenant updated successfully!');
        $this->redirect("/tenants/$id");
    }

    public function delete(string $id): void
    {
        $result = $this->apiDelete("/admin/tenants/$id");

        if (isset($result['error'])) {
            $this->setFlash('error', 'Failed to delete tenant: ' . $result['error']);
        } else {
            $this->setFlash('success', 'Tenant deleted successfully!');
        }

        $this->redirect('/tenants');
    }

    public function toggleStatus(string $id): void
    {
        $result = $this->apiPost("/admin/tenants/$id/toggle-status");

        if (isset($result['error'])) {
            $this->setFlash('error', 'Failed to update tenant status.');
        } else {
            $status = $result['status'] ?? 'updated';
            $this->setFlash('success', "Tenant status changed to $status.");
        }

        $this->redirect("/tenants/$id");
    }

    private function getPlans(): array
    {
        return [
            'basic' => [
                'name' => 'Basic',
                'price' => 50000,
                'users' => 2,
                'storage' => '1 GB',
            ],
            'professional' => [
                'name' => 'Professional',
                'price' => 150000,
                'users' => 10,
                'storage' => '10 GB',
            ],
            'enterprise' => [
                'name' => 'Enterprise',
                'price' => 500000,
                'users' => -1, // Unlimited
                'storage' => '100 GB',
            ],
        ];
    }
}
