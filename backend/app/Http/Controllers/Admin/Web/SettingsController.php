<?php

namespace App\Http\Controllers\Admin\Web;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;

class SettingsController extends Controller
{
    public function index()
    {
        return view('admin.settings');
    }

    public function clearCache()
    {
        Artisan::call('cache:clear');

        return redirect()
            ->back()
            ->with('success', 'Cache cleared successfully.');
    }

    public function clearConfig()
    {
        Artisan::call('config:clear');

        return redirect()
            ->back()
            ->with('success', 'Configuration cache cleared successfully.');
    }
}
