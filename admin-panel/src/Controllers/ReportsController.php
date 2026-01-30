<?php

namespace ThirdBooks\Admin\Controllers;

class ReportsController extends BaseController
{
    public function index(): void
    {
        $this->view('reports/index', [
            'title' => 'Reports',
            'flash' => $this->getFlash(),
        ]);
    }
}
