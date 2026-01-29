<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class SuperAdminMiddleware
{
    /**
     * Handle an incoming request.
     *
     * Ensures the authenticated user has super_admin role.
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (!Auth::check()) {
            return redirect()->route('admin.login');
        }

        if (Auth::user()->role !== 'super_admin') {
            Auth::logout();
            return redirect()
                ->route('admin.login')
                ->with('error', 'You do not have admin access.');
        }

        return $next($request);
    }
}
