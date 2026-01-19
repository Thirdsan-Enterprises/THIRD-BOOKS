<?php

namespace App\Http\Requests\Accounting;

use Illuminate\Foundation\Http\FormRequest;

class StoreJournalEntryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'company_id' => 'required|exists:companies,id',
            'date' => 'required|date',
            'reference' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'lines' => 'required|array|min:2',
            'lines.*.account_id' => 'required|exists:accounts,id',
            'lines.*.debit' => 'nullable|numeric|min:0',
            'lines.*.credit' => 'nullable|numeric|min:0',
            'lines.*.description' => 'nullable|string|max:500',
        ];
    }

    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            $lines = $this->input('lines', []);

            // Validate each line has either debit or credit, not both
            foreach ($lines as $index => $line) {
                $debit = $line['debit'] ?? 0;
                $credit = $line['credit'] ?? 0;

                if ($debit > 0 && $credit > 0) {
                    $validator->errors()->add(
                        "lines.{$index}",
                        'Line cannot have both debit and credit'
                    );
                }

                if ($debit == 0 && $credit == 0) {
                    $validator->errors()->add(
                        "lines.{$index}",
                        'Line must have either debit or credit'
                    );
                }
            }

            // Validate total debits equal total credits
            $totalDebits = array_sum(array_column($lines, 'debit'));
            $totalCredits = array_sum(array_column($lines, 'credit'));

            if (abs($totalDebits - $totalCredits) > 0.01) {
                $validator->errors()->add(
                    'lines',
                    "Journal entry must balance. Debits: {$totalDebits}, Credits: {$totalCredits}"
                );
            }
        });
    }

    public function messages(): array
    {
        return [
            'lines.required' => 'Journal entry must have at least 2 lines',
            'lines.min' => 'Journal entry must have at least 2 lines',
        ];
    }
}
