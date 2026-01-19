<?php

namespace App\Jobs;

use App\Models\Currency;
use App\Models\ExchangeRate;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class UpdateExchangeRates implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(): void
    {
        $apiKey = config('services.exchange_rate.api_key');
        $apiUrl = config('services.exchange_rate.url', 'https://api.exchangerate-api.com/v4/latest/UGX');

        try {
            $response = Http::get($apiUrl);

            if ($response->successful()) {
                $data = $response->json();
                $rates = $data['rates'] ?? [];

                foreach ($rates as $code => $rate) {
                    $currency = Currency::where('code', $code)->first();

                    if ($currency) {
                        ExchangeRate::updateOrCreate(
                            [
                                'currency_id' => $currency->id,
                                'date' => now()->toDateString(),
                            ],
                            [
                                'rate' => $rate,
                                'source' => 'API',
                            ]
                        );
                    }
                }

                Log::info('Exchange rates updated successfully');
            }
        } catch (\Exception $e) {
            Log::error('Failed to update exchange rates: ' . $e->getMessage());
            throw $e;
        }
    }
}
