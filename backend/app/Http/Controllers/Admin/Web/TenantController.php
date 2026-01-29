<?php

namespace App\Http\Controllers\Admin\Web;

use App\Http\Controllers\Controller;
use App\Models\Tenant\Tenant;
use App\Models\User;
use Illuminate\Http\Request;

class TenantController extends Controller
{
    public function index(Request $request)
    {
        $query = Tenant::query();

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('company_name', 'like', "%{$search}%");
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('plan')) {
            $query->where('plan', $request->plan);
        }

        $tenants = $query->orderBy('created_at', 'desc')->paginate(15);

        return view('admin.tenants.index', compact('tenants'));
    }

    public function show(Tenant $tenant)
    {
        $users = User::where('tenant_id', $tenant->id)->get();

        return view('admin.tenants.show', compact('tenant', 'users'));
    }

    public function edit(Tenant $tenant)
    {
        return view('admin.tenants.edit', compact('tenant'));
    }

    public function update(Request $request, Tenant $tenant)
    {
        $validated = $request->validate([
            'company_name' => 'required|string|max:255',
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255',
            'phone' => 'nullable|string|max:50',
            'address' => 'nullable|string|max:500',
            'country' => 'required|string|size:2',
            'plan' => 'required|in:trial,basic,premium,enterprise',
            'status' => 'required|in:active,suspended,cancelled',
            'trial_ends_at' => 'nullable|date',
            'subscription_ends_at' => 'nullable|date',
        ]);

        $tenant->update($validated);

        return redirect()
            ->route('admin.tenants.show', $tenant)
            ->with('success', 'Tenant updated successfully.');
    }

    public function suspend(Tenant $tenant)
    {
        $tenant->update(['status' => 'suspended']);

        return redirect()
            ->back()
            ->with('success', 'Tenant suspended successfully.');
    }

    public function activate(Tenant $tenant)
    {
        $tenant->update(['status' => 'active']);

        return redirect()
            ->back()
            ->with('success', 'Tenant activated successfully.');
    }

    public function destroy(Tenant $tenant)
    {
        $tenant->delete();

        return redirect()
            ->route('admin.tenants.index')
            ->with('success', 'Tenant deleted successfully.');
    }
}
