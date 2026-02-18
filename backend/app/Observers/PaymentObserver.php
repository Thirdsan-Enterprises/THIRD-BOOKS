<?php

namespace App\Observers;

use App\Models\Sales\Payment;
use App\Services\Sync\EventSourceService;

class PaymentObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Handle the Payment "created" event.
     */
    public function created(Payment $payment): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'payment',
            aggregateId: $payment->id,
            eventType: 'payment.recorded',
            eventData: [
                'paymentable_type' => $payment->paymentable_type,
                'paymentable_id' => $payment->paymentable_id,
                'payment_date' => $payment->payment_date,
                'amount' => $payment->amount,
                'payment_method' => $payment->payment_method,
                'reference_number' => $payment->reference_number,
                'notes' => $payment->notes,
                'account_id' => $payment->account_id,
            ]
        );
    }

    /**
     * Handle the Payment "updated" event.
     */
    public function updated(Payment $payment): void
    {
        $changes = $payment->getDirty();

        if (empty($changes)) {
            return;
        }

        $this->eventSourceService->createEvent(
            aggregateType: 'payment',
            aggregateId: $payment->id,
            eventType: 'payment.updated',
            eventData: array_merge(
                ['changes' => $changes],
                $payment->only([
                    'payment_date',
                    'amount',
                    'payment_method',
                    'reference_number',
                ])
            )
        );
    }

    /**
     * Handle the Payment "deleted" event.
     */
    public function deleted(Payment $payment): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'payment',
            aggregateId: $payment->id,
            eventType: 'payment.voided',
            eventData: [
                'amount' => $payment->amount,
                'reference_number' => $payment->reference_number,
                'deleted_at' => now()->toIso8601String(),
            ]
        );
    }
}
