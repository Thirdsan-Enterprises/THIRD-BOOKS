<?php

namespace App\Observers;

use App\Models\Sales\Customer;
use App\Services\Sync\EventSourceService;

class CustomerObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Handle the Customer "created" event.
     */
    public function created(Customer $customer): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'customer',
            aggregateId: $customer->id,
            eventType: 'customer.created',
            eventData: [
                'name' => $customer->name,
                'email' => $customer->email,
                'phone' => $customer->phone,
                'address' => $customer->address,
                'city' => $customer->city,
                'state' => $customer->state,
                'postal_code' => $customer->postal_code,
                'country' => $customer->country,
                'tax_number' => $customer->tax_number,
                'currency' => $customer->currency,
                'payment_terms' => $customer->payment_terms,
                'credit_limit' => $customer->credit_limit,
                'notes' => $customer->notes,
            ]
        );
    }

    /**
     * Handle the Customer "updated" event.
     */
    public function updated(Customer $customer): void
    {
        $changes = $customer->getDirty();

        if (empty($changes)) {
            return;
        }

        $this->eventSourceService->createEvent(
            aggregateType: 'customer',
            aggregateId: $customer->id,
            eventType: 'customer.updated',
            eventData: array_merge(
                ['changes' => $changes],
                $customer->only([
                    'name',
                    'email',
                    'phone',
                    'address',
                ])
            )
        );
    }

    /**
     * Handle the Customer "deleted" event.
     */
    public function deleted(Customer $customer): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'customer',
            aggregateId: $customer->id,
            eventType: 'customer.deleted',
            eventData: [
                'name' => $customer->name,
                'deleted_at' => now()->toIso8601String(),
            ]
        );
    }
}
