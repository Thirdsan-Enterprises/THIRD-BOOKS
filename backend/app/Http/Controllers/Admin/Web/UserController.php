<?php

namespace App\Http\Controllers\Admin\Web;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Spatie\Activitylog\Models\Activity;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $query = User::with('tenant');

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($request->filled('role')) {
            $query->where('role', $request->role);
        }

        if ($request->filled('status')) {
            $query->where('is_active', $request->status === 'active');
        }

        $users = $query->orderBy('created_at', 'desc')->paginate(15);

        return view('admin.users.index', compact('users'));
    }

    public function show(User $user)
    {
        $user->load('tenant');

        $activities = Activity::causedBy($user)
            ->orderBy('created_at', 'desc')
            ->limit(20)
            ->get();

        return view('admin.users.show', compact('user', 'activities'));
    }

    public function deactivate(User $user)
    {
        if ($user->role === 'super_admin') {
            return redirect()
                ->back()
                ->with('error', 'Cannot deactivate super admin.');
        }

        $user->update(['is_active' => false]);
        $user->tokens()->delete();

        return redirect()
            ->back()
            ->with('success', 'User deactivated successfully.');
    }

    public function activate(User $user)
    {
        $user->update(['is_active' => true]);

        return redirect()
            ->back()
            ->with('success', 'User activated successfully.');
    }

    public function resetPassword(User $user)
    {
        Password::sendResetLink(['email' => $user->email]);

        return redirect()
            ->back()
            ->with('success', 'Password reset email sent.');
    }
}
