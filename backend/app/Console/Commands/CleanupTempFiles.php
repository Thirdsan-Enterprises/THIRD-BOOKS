<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

class CleanupTempFiles extends Command
{
    protected $signature = 'thirdbooks:cleanup-temp-files';
    protected $description = 'Clean up old temporary files';

    public function handle()
    {
        $this->info('Cleaning up temporary files...');

        $paths = [
            storage_path('app/temp'),
            storage_path('framework/cache/data'),
        ];

        $deletedCount = 0;

        foreach ($paths as $path) {
            if (File::exists($path)) {
                $files = File::files($path);

                foreach ($files as $file) {
                    // Delete files older than 24 hours
                    if (filemtime($file) < now()->subDay()->timestamp) {
                        File::delete($file);
                        $deletedCount++;
                    }
                }
            }
        }

        $this->info("Deleted {$deletedCount} temporary files.");

        return Command::SUCCESS;
    }
}
