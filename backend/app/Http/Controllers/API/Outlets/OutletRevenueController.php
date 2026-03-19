<?php

namespace App\Http\Controllers\API\Outlets;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Services\Accounting\DoubleEntryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Outlet Revenue Controller
 *
 * Accepts outlet revenue data (Total In / Total Out / Total GGR) uploaded
 * from the desktop app and immediately posts the corresponding double-entry
 * journal entries to the general ledger:
 *
 *   DR  150 Accounts Receivable = Total GGR   (outlet owes MagicBet the net)
 *   DR  107 Payouts             = Total Out   (winnings paid to customers)
 *   CR  103 Stakes              = Total In    (gross revenue recognised)
 *
 * Weekly commission (DR 178 / CR 150 AR) JEs are created by the separate
 * commission endpoint, reducing the receivable balance.
 * Gaming-tax JEs are posted manually by the accountant.
 */
class OutletRevenueController extends Controller
{
    public function __construct(
        protected DoubleEntryService $doubleEntry
    ) {}

    /**
     * POST /api/outlet-revenues
     *
     * Accept one or many outlet revenue records and post JEs for each.
     *
     * Request body (array of records):
     * [
     *   {
     *     "outlet_code": "3000",
     *     "outlet_name": "MAGIC BET YUMBE",
     *     "date": "2026-01-01",
     *     "stake_amount": 1500000,
     *     "payout_amount": 750000,
     *     "net_amount": 750000,
     *     "reference": "CSV-3000-20260101"
     *   }, ...
     * ]
     */
    public function store(Request $request)
    {
        $request->validate([
            '*.outlet_code'    => 'required|string',
            '*.date'           => 'required|date',
            '*.stake_amount'   => 'required|numeric|min:0',
            '*.payout_amount'  => 'required|numeric|min:0',
            '*.net_amount'     => 'required|numeric',
        ]);

        $user    = $request->user();
        $company = $this->resolveCompany($request);

        $created = 0;
        $skipped = 0;
        $errors  = [];

        DB::beginTransaction();
        try {
            foreach ($request->all() as $index => $row) {
                $ref = $row['reference'] ?? sprintf(
                    'REV-%s-%s',
                    $row['outlet_code'],
                    date('Ymd', strtotime($row['date']))
                );

                // Idempotency: skip if a JE with this reference already exists
                $exists = \App\Models\Accounting\JournalEntry::where('company_id', $company->id)
                    ->where('reference', $ref)
                    ->exists();

                if ($exists) {
                    $skipped++;
                    continue;
                }

                // Build a lightweight DTO for DoubleEntryService
                $revenueDto = (object) [
                    'id'             => Str::uuid()->toString(),
                    'outlet'         => (object) [
                        'name'        => $row['outlet_name'] ?? $row['outlet_code'],
                        'outlet_code' => $row['outlet_code'],
                    ],
                    'date'           => $row['date'],
                    'stake_amount'   => (float) $row['stake_amount'],
                    'payout_amount'  => (float) $row['payout_amount'],
                    'net_amount'     => (float) $row['net_amount'],
                ];

                $this->doubleEntry->createOutletRevenueJournalEntry(
                    $revenueDto,
                    $company,
                    $user,
                    true // auto-post
                );

                $created++;
            }

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'message' => 'Failed to post outlet revenue journal entries.',
                'error'   => $e->getMessage(),
            ], 422);
        }

        return response()->json([
            'message' => 'Outlet revenue processed.',
            'created' => $created,
            'skipped' => $skipped,
            'errors'  => $errors,
        ]);
    }

    /**
     * POST /api/outlet-revenues/commission
     *
     * Post a weekly commission JE for an outlet.
     *
     * {
     *   "outlet_id": "uuid",
     *   "outlet_name": "MAGIC BET YUMBE",
     *   "outlet_code": "3000",
     *   "commission_amount": 300000,
     *   "week_end": "2026-01-05",
     *   "week_ref": "JE-COMM-3000-2026-W01"
     * }
     */
    public function storeCommission(Request $request)
    {
        $request->validate([
            'outlet_code'       => 'required|string',
            'commission_amount' => 'required|numeric|min:0',
            'week_end'          => 'required|date',
            'week_ref'          => 'required|string',
        ]);

        $user    = $request->user();
        $company = $this->resolveCompany($request);

        // Idempotency check
        $exists = \App\Models\Accounting\JournalEntry::where('company_id', $company->id)
            ->where('reference', $request->week_ref)
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Commission JE already exists.', 'skipped' => true]);
        }

        $outletDto = (object) [
            'id'          => $request->input('outlet_id', Str::uuid()->toString()),
            'name'        => $request->input('outlet_name', $request->outlet_code),
            'outlet_code' => $request->outlet_code,
        ];

        try {
            $this->doubleEntry->createOutletCommissionJournalEntry(
                $outletDto,
                $company,
                $user,
                (float) $request->commission_amount,
                new \DateTime($request->week_end),
                $request->week_ref,
                true
            );
        } catch (\Throwable $e) {
            return response()->json([
                'message' => 'Failed to post commission journal entry.',
                'error'   => $e->getMessage(),
            ], 422);
        }

        return response()->json(['message' => 'Commission JE posted.']);
    }

    // -------------------------------------------------------------------------

    private function resolveCompany(Request $request): Company
    {
        return Company::firstOrFail();
    }
}
