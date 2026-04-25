<?php

namespace Tests;

use App\Models\Company;
use App\Models\Tenant\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

abstract class TestCase extends BaseTestCase
{
    /**
     * Create a fully provisioned tenant + user + company for testing.
     * Returns ['tenant', 'user', 'company', 'token'].
     */
    protected function createTenantWithUser(array $overrides = []): array
    {
        $tenantId = Str::uuid()->toString();

        $tenant = Tenant::create(array_merge([
            'id'                   => $tenantId,
            'name'                 => 'Test Company',
            'company_name'         => 'Test Company Ltd',
            'email'                => 'test@testcompany.com',
            'country'              => 'UG',
            'base_currency'        => 'UGX',
            'plan'                 => 'trial',
            'trial_ends_at'        => now()->addDays(30),
            'status'               => 'active',
        ], $overrides['tenant'] ?? []));

        $user = User::create(array_merge([
            'tenant_id'         => $tenantId,
            'name'              => 'Test Admin',
            'email'             => 'admin@testcompany.com',
            'password'          => Hash::make('password123'),
            'role'              => 'admin',
            'is_active'         => true,
            'email_verified_at' => now(),
        ], $overrides['user'] ?? []));

        $company = Company::create(array_merge([
            'tenant_id'          => $tenantId,
            'name'               => 'Test Company Ltd',
            'legal_name'         => 'Test Company Ltd',
            'email'              => 'test@testcompany.com',
            'country'            => 'UG',
            'base_currency'      => 'UGX',
            'fiscal_year_start'  => '01-01',
            'fiscal_year_end'    => '12-31',
        ], $overrides['company'] ?? []));

        $token = $user->createToken('test-device')->plainTextToken;

        return compact('tenant', 'user', 'company', 'token');
    }

    /**
     * Return auth + tenant headers for API requests.
     */
    protected function tenantHeaders(string $token, string $tenantId): array
    {
        return [
            'Authorization' => "Bearer $token",
            'X-Tenant-ID'   => $tenantId,
            'Accept'        => 'application/json',
        ];
    }
}
