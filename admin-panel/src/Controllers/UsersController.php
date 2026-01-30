<?php

namespace ThirdBooks\Admin\Controllers;

class UsersController extends BaseController
{
    public function index(): void
    {
        $page = (int) ($_GET['page'] ?? 1);
        $search = $_GET['search'] ?? '';

        $query = ['page' => $page, 'per_page' => 20];
        if ($search) {
            $query['search'] = $search;
        }

        $result = $this->apiGet('/admin/users', $query);

        if (isset($result['error'])) {
            $users = [];
            $pagination = ['total' => 0, 'current_page' => 1, 'last_page' => 1];
        } else {
            $users = $result['data'] ?? [];
            $pagination = $result['meta'] ?? ['total' => 0, 'current_page' => 1, 'last_page' => 1];
        }

        $this->view('users/index', [
            'title' => 'Users',
            'users' => $users,
            'pagination' => $pagination,
            'search' => $search,
            'flash' => $this->getFlash(),
        ]);
    }
}
