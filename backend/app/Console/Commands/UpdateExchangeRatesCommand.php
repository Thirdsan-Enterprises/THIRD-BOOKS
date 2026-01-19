<?php

namespace App\Console\Commands;

use App\Jobs\UpdateExchangeRates;
use Illuminate\Console\Command;

class UpdateExchangeRatesCommand extends Command
{
    protected $signature = 'thirdbooks:update-exchange-rates';
    protected $description = 'Update currency exchange rates from external API';

    public function handle()
    {
        $this->info('Updating exchange rates...');

        UpdateExchangeRates::dispatch();

        $this->info('Exchange rates update job dispatched successfully!');

        return Command::SUCCESS;
    }
}
