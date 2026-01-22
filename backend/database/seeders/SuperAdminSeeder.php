<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class SuperAdminSeeder extends Seeder
{
    /**
     * Seed the super admin user.
     *
     * This creates a super admin account that has cross-tenant access
     * and can manage all tenants, users, and system settings.
     */
    public function run(): void
    {
        // Check if super admin already exists
        $existingSuperAdmin = User::where('role', User::ROLE_SUPER_ADMIN)->first();

        if ($existingSuperAdmin) {
            $this->command->info('Super admin user already exists: ' . $existingSuperAdmin->email);
            return;
        }

        // Create super admin user
        $superAdmin = User::create([
            'tenant_id' => null, // Super admin doesn't belong to any tenant
            'name' => 'Super Administrator',
            'email' => 'admin@thirdbooks.digital',
            'password' => Hash::make('SuperAdmin@2024'), // Change this password immediately after first login!
            'phone' => null,
            'role' => User::ROLE_SUPER_ADMIN,
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $this->command->info('✅ Super admin created successfully!');
        $this->command->newLine();
        $this->command->warn('🔐 IMPORTANT SECURITY NOTICE:');
        $this->command->warn('================================================');
        $this->command->info('Email: ' . $superAdmin->email);
        $this->command->error('Password: SuperAdmin@2024');
        $this->command->warn('================================================');
        $this->command->warn('⚠️  CHANGE THIS PASSWORD IMMEDIATELY AFTER FIRST LOGIN!');
        $this->command->newLine();
    }
}
