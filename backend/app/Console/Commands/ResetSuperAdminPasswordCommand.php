<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

class ResetSuperAdminPasswordCommand extends Command
{
    protected $signature = 'admin:reset-superadmin-password
                            {--email= : Super admin email (defaults to admin@thirdbooks.digital)}
                            {--password= : New password (will prompt if not provided)}';

    protected $description = 'Reset the super admin password and revoke all existing sessions';

    public function handle(): int
    {
        $this->info('ThirdBooks — Super Admin Password Reset');
        $this->newLine();

        $email = $this->option('email') ?? 'admin@thirdbooks.digital';

        $superAdmin = User::where('role', User::ROLE_SUPER_ADMIN)
            ->where('email', $email)
            ->first();

        if (! $superAdmin) {
            $superAdmin = User::where('role', User::ROLE_SUPER_ADMIN)->first();
        }

        if (! $superAdmin) {
            $this->error('No super admin user found in the database.');
            return self::FAILURE;
        }

        $this->line("Found: <info>{$superAdmin->name}</info> <comment><{$superAdmin->email}></comment>");
        $this->newLine();

        if ($this->option('password')) {
            $password = $this->option('password');
        } else {
            $password = $this->secret('New password (min 8 characters)');
            $confirm  = $this->secret('Confirm new password');

            if ($password !== $confirm) {
                $this->error('Passwords do not match.');
                return self::FAILURE;
            }
        }

        if (strlen($password) < 8) {
            $this->error('Password must be at least 8 characters long.');
            return self::FAILURE;
        }

        try {
            // The 'hashed' cast on the User model hashes plain-text assignments automatically.
            $superAdmin->password  = $password;
            $superAdmin->is_active = true;
            $superAdmin->save();

            // Revoke all Sanctum tokens so existing sessions cannot be reused.
            $superAdmin->tokens()->delete();

            $this->newLine();
            $this->info('Password reset successfully. All existing sessions have been revoked.');
            $this->newLine();
            $this->table(
                ['Field', 'Value'],
                [
                    ['ID',      $superAdmin->id],
                    ['Name',    $superAdmin->name],
                    ['Email',   $superAdmin->email],
                    ['Role',    $superAdmin->role],
                    ['Updated', now()->format('Y-m-d H:i:s')],
                ]
            );
            $this->newLine();
            $this->info('You can now log in at: /admin');

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error('Failed to reset password: ' . $e->getMessage());
            return self::FAILURE;
        }
    }
}
