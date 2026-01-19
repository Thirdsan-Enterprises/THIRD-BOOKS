<?php

namespace App\Http\Requests\Sales;

use Illuminate\Foundation\Http\FormRequest;

class StoreInvoiceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'company_id' => 'required|exists:companies,id',
            'customer_id' => 'required|exists:customers,id',
            'date' => 'required|date',
            'due_date' => 'nullable|date|after_or_equal:date',
            'reference' => 'nullable|string|max:255',
            'notes' => 'nullable|string',
            'terms' => 'nullable|string',
            'currency_id' => 'required|exists:currencies,id',
            'exchange_rate' => 'nullable|numeric|min:0',
            'lines' => 'required|array|min:1',
            'lines.*.account_id' => 'required|exists:accounts,id',
            'lines.*.description' => 'required|string|max:500',
            'lines.*.quantity' => 'required|numeric|min:0.01',
            'lines.*.unit_price' => 'required|numeric|min:0',
            'lines.*.discount_percent' => 'nullable|numeric|min:0|max:100',
            'lines.*.tax_rate' => 'nullable|numeric|min:0|max:100',
        ];
    }

    public function messages(): array
    {
        return [
            'company_id.required' => 'Company is required',
            'customer_id.required' => 'Customer is required',
            'customer_id.exists' => 'Selected customer does not exist',
            'date.required' => 'Invoice date is required',
            'lines.required' => 'Invoice must have at least one line item',
            'lines.*.account_id.required' => 'Account is required for each line',
            'lines.*.description.required' => 'Description is required for each line',
            'lines.*.quantity.required' => 'Quantity is required',
            'lines.*.unit_price.required' => 'Unit price is required',
        ];
    }
}
