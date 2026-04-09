<?php

namespace App\Http\Controllers\API\Banking;

use App\Http\Controllers\Controller;
use App\Models\Banking\BankStatement;
use App\Models\Banking\BankStatementLine;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class BankStatementController extends Controller
{
    /**
     * List all uploaded bank statements for the company.
     *
     * GET /banking/statements
     * Optional: ?bank_account_id=5  ?status=pending|in_progress|reconciled
     */
    public function index(Request $request)
    {
        $query = BankStatement::with(['bankAccount', 'uploader'])
            ->withCount('lines')
            ->orderByDesc('to_date');

        if ($request->has('bank_account_id')) {
            $query->where('bank_account_id', $request->bank_account_id);
        }

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        $perPage = $request->input('per_page', 20);

        return response()->json($query->paginate($perPage));
    }

    /**
     * Show a single statement with its lines.
     *
     * GET /banking/statements/{id}
     */
    public function show($id)
    {
        $statement = BankStatement::with([
            'bankAccount',
            'uploader',
            'lines.reconciliationItems.reconcilable',
        ])->findOrFail($id);

        // Append per-line remaining amounts
        $statement->lines->each(function ($line) {
            $line->append(['transaction_amount', 'remaining_amount', 'net_amount']);
        });

        return response()->json(['statement' => $statement]);
    }

    /**
     * Upload a new bank statement (CSV or plain JSON rows).
     *
     * POST /banking/statements
     * Multipart form:
     *   - bank_account_id    required
     *   - from_date          required  YYYY-MM-DD
     *   - to_date            required  YYYY-MM-DD
     *   - opening_balance    optional
     *   - closing_balance    optional
     *   - reference_number   optional
     *   - notes              optional
     *   - file               optional  CSV upload
     *   - rows               optional  JSON array (when posting from mobile/desktop)
     *     rows[*].date, rows[*].description, rows[*].debit, rows[*].credit, rows[*].balance, rows[*].reference
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'bank_account_id'  => 'required|exists:accounts,id',
            'from_date'        => 'required|date',
            'to_date'          => 'required|date|after_or_equal:from_date',
            'opening_balance'  => 'nullable|numeric',
            'closing_balance'  => 'nullable|numeric',
            'reference_number' => 'nullable|string|max:100',
            'notes'            => 'nullable|string',
            'file'             => 'nullable|file|max:10240|mimes:csv,txt,xlsx',
            'rows'             => 'nullable|array|min:1',
            'rows.*.date'      => 'required_with:rows|date',
            'rows.*.description' => 'required_with:rows|string',
            'rows.*.debit'     => 'nullable|numeric|min:0',
            'rows.*.credit'    => 'nullable|numeric|min:0',
            'rows.*.balance'   => 'nullable|numeric',
            'rows.*.reference' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        if (!$request->hasFile('file') && !$request->has('rows')) {
            return response()->json(['message' => 'Either a CSV file or rows array must be provided'], 422);
        }

        try {
            DB::beginTransaction();

            $disk     = config('filesystems.default', 'local');
            $filePath = null;
            $fileName = null;

            if ($request->hasFile('file')) {
                $file      = $request->file('file');
                $fileName  = $file->getClientOriginalName();
                $filePath  = 'bank-statements/' . date('Y/m') . '/' . Str::uuid() . '.' . $file->getClientOriginalExtension();
                $file->storeAs(dirname($filePath), basename($filePath), ['disk' => $disk]);
            }

            $companyId = $request->user()->company_id ?? $request->input('company_id');

            $statement = BankStatement::create([
                'company_id'       => $companyId,
                'bank_account_id'  => $request->bank_account_id,
                'reference_number' => $request->reference_number,
                'from_date'        => $request->from_date,
                'to_date'          => $request->to_date,
                'opening_balance'  => $request->opening_balance ?? 0,
                'closing_balance'  => $request->closing_balance ?? 0,
                'file_name'        => $fileName,
                'file_path'        => $filePath,
                'disk'             => $disk,
                'notes'            => $request->notes,
                'uploaded_by'      => $request->user()?->id,
            ]);

            // Parse rows — from JSON payload or CSV file
            $rows = $request->has('rows')
                ? $request->rows
                : $this->parseCsvFile($request->file('file'));

            foreach ($rows as $row) {
                BankStatementLine::create([
                    'bank_statement_id' => $statement->id,
                    'date'              => $row['date'],
                    'description'       => $row['description'],
                    'reference'         => $row['reference'] ?? null,
                    'debit'             => (float) ($row['debit'] ?? 0),
                    'credit'            => (float) ($row['credit'] ?? 0),
                    'balance'           => isset($row['balance']) ? (float) $row['balance'] : null,
                ]);
            }

            DB::commit();

            return response()->json([
                'message'   => 'Bank statement uploaded successfully with ' . count($rows) . ' lines',
                'statement' => $statement->fresh(['bankAccount', 'lines']),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Failed to upload statement', 'error' => $e->getMessage()], 400);
        }
    }

    /**
     * Delete a bank statement and all its lines/reconciliations.
     *
     * Allowed only when status = pending or in_progress (not fully reconciled).
     *
     * DELETE /banking/statements/{id}
     */
    public function destroy($id)
    {
        $statement = BankStatement::findOrFail($id);

        if ($statement->status === BankStatement::STATUS_RECONCILED) {
            return response()->json([
                'message' => 'A fully reconciled statement cannot be deleted. Reverse reconciliations first.',
            ], 403);
        }

        try {
            DB::beginTransaction();

            // Delete reconciliation items that belong to this statement's lines
            foreach ($statement->lines as $line) {
                $line->reconciliationItems()->delete();
            }

            // Delete lines
            $statement->lines()->delete();

            // Delete physical file
            if ($statement->file_path) {
                Storage::disk($statement->disk)->delete($statement->file_path);
            }

            $statement->delete();

            DB::commit();

            return response()->json(['message' => 'Bank statement deleted successfully']);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Failed to delete statement', 'error' => $e->getMessage()], 400);
        }
    }

    /**
     * Parse a CSV file into an array of row arrays.
     * Expected columns (case-insensitive): Date, Description, Debit, Credit, Balance, Reference
     */
    private function parseCsvFile($file): array
    {
        $path = $file->getRealPath();
        $handle = fopen($path, 'r');
        $rows = [];

        $headers = null;
        while (($data = fgetcsv($handle)) !== false) {
            if ($headers === null) {
                $headers = array_map(fn($h) => strtolower(trim($h)), $data);
                continue;
            }

            $row = array_combine($headers, $data);

            $rows[] = [
                'date'        => $this->parseDate($row['date'] ?? ''),
                'description' => $row['description'] ?? $row['narration'] ?? $row['details'] ?? '',
                'reference'   => $row['reference'] ?? $row['ref'] ?? $row['cheque'] ?? null,
                'debit'       => $this->parseAmount($row['debit'] ?? $row['dr'] ?? '0'),
                'credit'      => $this->parseAmount($row['credit'] ?? $row['cr'] ?? '0'),
                'balance'     => $this->parseAmount($row['balance'] ?? $row['running balance'] ?? '0'),
            ];
        }

        fclose($handle);

        return array_filter($rows, fn($r) => !empty($r['date']) && !empty($r['description']));
    }

    private function parseAmount(string $value): float
    {
        // Strip currency symbols, commas, spaces
        $clean = preg_replace('/[^\d.\-]/', '', $value);
        return (float) ($clean ?: 0);
    }

    private function parseDate(string $value): string
    {
        if (empty($value)) {
            return now()->format('Y-m-d');
        }

        try {
            return \Carbon\Carbon::parse($value)->format('Y-m-d');
        } catch (\Exception $e) {
            return now()->format('Y-m-d');
        }
    }
}
