<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class CreateSuperAdminCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'admin:create-super
                            {--email= : The super admin email address}
                            {--name= : The super admin name}
                            {--password= : The super admin password}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Create a new super admin user';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('🔧 ThirdBooks Super Admin Creation');
        $this->newLine();

        // Get email
        $email = $this->option('email') ?? $this->ask('Email address', 'admin@thirdbooks.digital');

        // Validate email
        $validator = Validator::make(['email' => $email], [
            'email' => 'required|email|unique:users,email',
        ]);

        if ($validator->fails()) {
            $this->error('❌ ' . $validator->errors()->first('email'));
            return self::FAILURE;
        }

        // Get name
        $name = $this->option('name') ?? $this->ask('Full name', 'Super Administrator');

        // Get password
        if ($this->option('password')) {
            $password = $this->option('password');
        } else {
            $password = $this->secret('Password (min 8 characters)');
            $passwordConfirm = $this->secret('Confirm password');

            if ($password !== $passwordConfirm) {
                $this->error('❌ Passwords do not match!');
                return self::FAILURE;
            }
        }

        // Validate password length
        if (strlen($password) < 8) {
            $this->error('❌ Password must be at least 8 characters long!');
            return self::FAILURE;
        }

        // Create super admin
        try {
            $superAdmin = User::create([
                'tenant_id' => null, // Super admin doesn't belong to any tenant
                'name' => $name,
                'email' => $email,
                'password' => Hash::make($password),
                'phone' => null,
                'role' => User::ROLE_SUPER_ADMIN,
                'is_active' => true,
                'email_verified_at' => now(),
            ]);

            $this->newLine();
            $this->info('✅ Super admin created successfully!');
            $this->newLine();
            $this->table(
                ['Field', 'Value'],
                [
                    ['ID', $superAdmin->id],
                    ['Name', $superAdmin->name],
                    ['Email', $superAdmin->email],
                    ['Role', $superAdmin->role],
                    ['Created', $superAdmin->created_at->format('Y-m-d H:i:s')],
                ]
            );
            $this->newLine();
            $this->info('🔐 You can now login at: /admin');

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error('❌ Failed to create super admin: ' . $e->getMessage());
            return self::FAILURE;
        }
    }
}
