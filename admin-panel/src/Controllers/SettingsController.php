<?php

namespace ThirdBooks\Admin\Controllers;

class SettingsController extends BaseController
{
    public function index(): void
    {
        $settings = $this->apiGet('/admin/settings');

        if (isset($settings['error'])) {
            $settings = [
                'site_name' => 'ThirdBooks',
                'support_email' => 'support@thirdbooks.com',
                'max_tenants' => 1000,
                'default_plan' => 'basic',
                'maintenance_mode' => false,
            ];
        }

        $this->view('settings/index', [
            'title' => 'Settings',
            'settings' => $settings,
            'flash' => $this->getFlash(),
        ]);
    }
}
