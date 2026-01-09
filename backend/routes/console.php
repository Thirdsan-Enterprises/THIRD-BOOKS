<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

/*
|--------------------------------------------------------------------------
| Console Routes
|--------------------------------------------------------------------------
*/

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

/*
|--------------------------------------------------------------------------
| Scheduled Tasks
|--------------------------------------------------------------------------
*/

// Update exchange rates daily at 6 AM
Schedule::command('thirdbooks:update-exchange-rates')
    ->dailyAt('06:00')
    ->timezone('Africa/Kampala');

// Generate automatic backups daily at 2 AM
Schedule::command('backup:run')
    ->dailyAt('02:00')
    ->timezone('Africa/Kampala');

// Clean old activity logs (keep 90 days)
Schedule::command('activitylog:clean')
    ->daily()
    ->timezone('Africa/Kampala');

// Send overdue invoice reminders at 9 AM
Schedule::command('thirdbooks:send-invoice-reminders')
    ->dailyAt('09:00')
    ->timezone('Africa/Kampala');

// Clean temporary files weekly
Schedule::command('thirdbooks:cleanup-temp-files')
    ->weekly()
    ->timezone('Africa/Kampala');
