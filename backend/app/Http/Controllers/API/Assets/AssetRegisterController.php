<?php

namespace App\Http\Controllers\API\Assets;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
use App\Models\Accounting\JournalEntry;
use App\Models\Assets\AssetRegister;
use App\Models\Assets\DepreciationEntry;
use App\Services\Accounting\DoubleEntryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class AssetRegisterController extends Controller
{
    public function __construct(private readonly DoubleEntryService $des) {}

    // ── List ─────────────────────────────────────────────────────────────────

    /**
     * GET /assets
     * Query: ?status=active &category=Software &asset_nature=intangible &coa_account_id=12
     */
    public function index(Request $request)
    {
        $query = AssetRegister::with(['coaAccount', 'bill', 'creator'])
            ->withCount('depreciationEntries')
            ->withCount('amortizationEntries')
            ->orderByDesc('acquisition_date');

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }
        if ($request->filled('asset_nature')) {
            $query->where('asset_nature', $request->asset_nature);
        }
        if ($request->filled('coa_account_id')) {
            $query->where('coa_account_id', $request->coa_account_id);
        }

        $perPage = $request->input('per_page', 50);
        return response()->json($query->paginate($perPage));
    }

    // ── Show ─────────────────────────────────────────────────────────────────

    public function show($id)
    {
        $asset = AssetRegister::with([
            'coaAccount',
            'bill.vendor',
            'creator',
            'depreciationEntries.journalEntry',
            'amortizationEntries.journalEntry',
        ])->findOrFail($id);

        $appends = ['accumulated_depreciation', 'is_fully_depreciated'];
        if ($asset->isIntangible()) {
            $appends = ['accumulated_amortization', 'is_fully_amortized'];
        }
        $asset->append($appends);

        return response()->json(['asset' => $asset]);
    }

    // ── Create ───────────────────────────────────────────────────────────────

    /**
     * POST /assets
     * Handles both tangible (PP&E) and intangible (software, patents) assets.
     *
     * Intangible rules (IAS 38):
     *  - asset_nature = 'intangible'
     *  - Straight-line only (no declining-balance)
     *  - No salvage value (residual assumed zero)
     *  - useful_life_years is required
     */
    public function store(Request $request)
    {
        $allCategories = implode(',', AssetRegister::CATEGORIES);

        $validator = Validator::make($request->all(), [
            'coa_account_id'          => 'required|exists:accounts,id',
            'name'                    => 'required|string|max:255',
            'asset_nature'            => 'nullable|in:tangible,intangible',
            'category'                => 'required|in:' . $allCategories,
            'cost'                    => 'required|numeric|min:0.01',
            'acquisition_date'        => 'required|date',
            'salvage_value'           => 'nullable|numeric|min:0',
            'description'             => 'nullable|string',
            'asset_code'              => 'nullable|string|max:50',
            'location'                => 'nullable|string|max:255',
            'responsible_person'      => 'nullable|string|max:255',
            'depreciation_method'     => 'nullable|in:straight_line,declining_balance',
            'depreciation_rate'       => 'nullable|numeric|min:0.01|max:100',
            'depreciation_period'     => 'nullable|in:monthly,yearly',
            'useful_life_years'       => 'nullable|numeric|min:0.25',
            'depreciation_start_date' => 'nullable|date',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        // Determine nature: explicit input wins; otherwise infer from CoA account name
        $nature = $request->input('asset_nature');
        if (!$nature) {
            $account = Account::find($request->coa_account_id);
            $nature  = $account
                ? AssetRegister::inferNatureFromAccountName($account->name)
                : AssetRegister::NATURE_TANGIBLE;
        }

        $isIntangible = $nature === AssetRegister::NATURE_INTANGIBLE;
        $cost         = (float) $request->cost;

        // Intangibles: IAS 38 — residual value = 0, method = straight_line
        $salvage  = $isIntangible ? 0.0 : (float) ($request->salvage_value ?? 0);
        $method   = $isIntangible ? AssetRegister::METHOD_STRAIGHT_LINE : $request->depreciation_method;

        // For intangibles, the "rate" is derived from useful life; store null for rate
        $rate     = $isIntangible ? null : $request->depreciation_rate;

        $companyId = $request->user()->company_id ?? $request->input('company_id');

        $asset = AssetRegister::create([
            'company_id'              => $companyId,
            'coa_account_id'          => $request->coa_account_id,
            'asset_code'              => $request->asset_code,
            'name'                    => $request->name,
            'category'                => $request->category,
            'description'             => $request->description,
            'asset_nature'            => $nature,
            'cost'                    => $cost,
            'salvage_value'           => $salvage,
            'current_book_value'      => $cost,
            'currency_code'           => $request->currency_code ?? 'UGX',
            'acquisition_date'        => $request->acquisition_date,
            'status'                  => AssetRegister::STATUS_ACTIVE,
            'location'                => $request->location,
            'responsible_person'      => $request->responsible_person,
            'depreciation_method'     => $method,
            'depreciation_rate'       => $rate,
            'depreciation_period'     => $request->depreciation_period,
            'useful_life_years'       => $request->useful_life_years,
            'depreciation_start_date' => $request->depreciation_start_date,
            'created_by'              => $request->user()?->id,
        ]);

        return response()->json(['message' => 'Asset created', 'asset' => $asset->fresh('coaAccount')], 201);
    }

    // ── Update ───────────────────────────────────────────────────────────────

    public function update(Request $request, $id)
    {
        $asset = AssetRegister::findOrFail($id);

        $allowed = [
            'name', 'category', 'description', 'asset_code',
            'salvage_value', 'location', 'responsible_person',
            'depreciation_method', 'depreciation_rate',
            'depreciation_period', 'useful_life_years',
            'depreciation_start_date',
        ];

        // Enforce IAS 38 for intangibles: salvage stays 0, method stays straight_line
        $data = $request->only($allowed);
        if ($asset->isIntangible()) {
            $data['salvage_value']       = 0;
            $data['depreciation_method'] = AssetRegister::METHOD_STRAIGHT_LINE;
            $data['depreciation_rate']   = null;
        }

        $asset->update($data);

        return response()->json(['message' => 'Asset updated', 'asset' => $asset->fresh('coaAccount')]);
    }

    // ── Dispose ──────────────────────────────────────────────────────────────

    /**
     * POST /assets/{asset}/dispose
     *
     * Tangible (PP&E):
     *   DR Accumulated Depreciation / DR Proceeds / DR Loss
     *   CR Fixed Asset (CoA) / CR Gain
     *
     * Intangible (IAS 38.112):
     *   DR Accumulated Amortization
     *   CR Intangible Asset (CoA)
     *   DR/CR Gain or Loss on derecognition
     */
    public function dispose(Request $request, $id)
    {
        $asset = AssetRegister::findOrFail($id);

        if ($asset->status !== AssetRegister::STATUS_ACTIVE) {
            return response()->json(['message' => 'Only active assets can be disposed'], 422);
        }

        $validator = Validator::make($request->all(), [
            'disposal_date'       => 'required|date',
            'proceeds'            => 'nullable|numeric|min:0',
            'proceeds_account_id' => 'nullable|exists:accounts,id',
            'notes'               => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        try {
            DB::beginTransaction();

            $proceeds    = (float) ($request->proceeds ?? 0);
            $bookValue   = (float) $asset->current_book_value;
            $company     = $asset->company;
            $lines       = [];

            if ($asset->isIntangible()) {
                // ── Intangible disposal (IAS 38 derecognition) ───────────────
                $accumulated = (float) $asset->accumulated_amortization;

                $accumAmortAcct = Account::where('company_id', $company->id)
                    ->where('name', 'like', '%Accumulated Amortization%')
                    ->first();

                if ($accumAmortAcct && $accumulated > 0) {
                    $lines[] = [
                        'account_id'  => $accumAmortAcct->id,
                        'debit'       => $accumulated,
                        'credit'      => 0,
                        'description' => "Clear accumulated amortization — {$asset->name}",
                    ];
                }

                // CR Intangible Asset at cost
                $lines[] = [
                    'account_id'  => $asset->coa_account_id,
                    'debit'       => 0,
                    'credit'      => (float) $asset->cost,
                    'description' => "Derecognise intangible asset — {$asset->name}",
                ];
            } else {
                // ── Tangible disposal (IAS 16 derecognition) ─────────────────
                $accumulated = (float) $asset->accumulated_depreciation;

                $accumDeprAcct = Account::where('company_id', $company->id)
                    ->where('name', 'like', '%Accumulated Depreciation%')
                    ->first();

                if ($accumDeprAcct && $accumulated > 0) {
                    $lines[] = [
                        'account_id'  => $accumDeprAcct->id,
                        'debit'       => $accumulated,
                        'credit'      => 0,
                        'description' => "Clear accumulated depreciation — {$asset->name}",
                    ];
                }

                // CR Fixed Asset at cost
                $lines[] = [
                    'account_id'  => $asset->coa_account_id,
                    'debit'       => 0,
                    'credit'      => (float) $asset->cost,
                    'description' => "Disposal of asset — {$asset->name}",
                ];
            }

            // Proceeds (applies to both tangible and intangible)
            if ($proceeds > 0 && $request->proceeds_account_id) {
                $lines[] = [
                    'account_id'  => $request->proceeds_account_id,
                    'debit'       => $proceeds,
                    'credit'      => 0,
                    'description' => "Disposal proceeds — {$asset->name}",
                ];
            }

            // Gain / Loss on disposal / derecognition
            $gainLoss = $proceeds - $bookValue;
            if ($gainLoss > 0) {
                $gainAcct = Account::where('company_id', $company->id)
                    ->whereIn('name', ['Gain on Disposal', 'Other Income'])
                    ->first();
                if ($gainAcct) {
                    $lines[] = [
                        'account_id'  => $gainAcct->id,
                        'debit'       => 0,
                        'credit'      => $gainLoss,
                        'description' => "Gain on disposal of {$asset->name}",
                    ];
                }
            } elseif ($gainLoss < 0) {
                $lossAcct = Account::where('company_id', $company->id)
                    ->whereIn('name', ['Loss on Disposal', 'Other Expense'])
                    ->first();
                if ($lossAcct) {
                    $lines[] = [
                        'account_id'  => $lossAcct->id,
                        'debit'       => abs($gainLoss),
                        'credit'      => 0,
                        'description' => "Loss on disposal of {$asset->name}",
                    ];
                }
            }

            if (!empty($lines)) {
                $isIntangible = $asset->isIntangible();
                $this->des->createJournalEntry(
                    $company,
                    [
                        'date'        => $request->disposal_date,
                        'reference'   => ($isIntangible ? 'DERECOG-' : 'DISP-') . $asset->id,
                        'description' => ($isIntangible ? 'Intangible asset derecognition' : 'Asset disposal')
                                         . " — {$asset->name}",
                        'type'        => JournalEntry::TYPE_AUTOMATIC,
                        'source'      => $isIntangible ? 'intangible_derecognition' : 'asset_disposal',
                        'source_id'   => $asset->id,
                        'lines'       => $lines,
                    ],
                    $request->user(),
                    true
                );
            }

            $asset->update([
                'status'        => AssetRegister::STATUS_DISPOSED,
                'disposal_date' => $request->disposal_date,
            ]);

            DB::commit();

            $verb = $asset->isIntangible() ? 'derecognised' : 'disposed';
            return response()->json(['message' => "Asset {$verb} successfully", 'asset' => $asset->fresh()]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Disposal failed', 'error' => $e->getMessage()], 400);
        }
    }

    // ── Post Depreciation (tangible) ─────────────────────────────────────────

    /**
     * POST /assets/{asset}/depreciate
     * Posts one depreciation period for a tangible (PP&E) asset.
     * JE: DR Depreciation Expense / CR Accumulated Depreciation
     */
    public function postDepreciation(Request $request, $id)
    {
        $asset = AssetRegister::with('company')->findOrFail($id);

        if ($asset->status !== AssetRegister::STATUS_ACTIVE) {
            return response()->json(['message' => 'Only active assets can be depreciated'], 422);
        }
        if ($asset->isIntangible()) {
            return response()->json([
                'message' => 'This is an intangible asset. Use POST /assets/{id}/amortize instead.',
            ], 422);
        }
        if (!$asset->depreciation_method || !$asset->depreciation_rate) {
            return response()->json(['message' => 'Asset has no depreciation schedule configured'], 422);
        }

        $amount = $asset->calculateNextDepreciation();
        if ($amount <= 0) {
            return response()->json(['message' => 'Asset is fully depreciated to salvage value'], 422);
        }

        $validator = Validator::make($request->all(), [
            'period_date'                 => 'required|date',
            'depreciation_account_id'     => 'required|exists:accounts,id',
            'accumulated_depr_account_id' => 'required|exists:accounts,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        try {
            DB::beginTransaction();

            $company     = $asset->company;
            $periodDate  = $request->period_date;
            $periodLabel = \Carbon\Carbon::parse($periodDate)
                ->format($asset->depreciation_period === 'monthly' ? 'M Y' : 'Y');

            $je = $this->des->createJournalEntry(
                $company,
                [
                    'date'        => $periodDate,
                    'reference'   => "DEP-{$asset->id}-{$periodLabel}",
                    'description' => "Depreciation — {$asset->name} ({$periodLabel})",
                    'type'        => JournalEntry::TYPE_AUTOMATIC,
                    'source'      => 'depreciation',
                    'source_id'   => $asset->id,
                    'lines'       => [
                        [
                            'account_id'  => $request->depreciation_account_id,
                            'debit'       => $amount,
                            'credit'      => 0,
                            'description' => "Depreciation expense — {$asset->name}",
                        ],
                        [
                            'account_id'  => $request->accumulated_depr_account_id,
                            'debit'       => 0,
                            'credit'      => $amount,
                            'description' => "Accumulated depreciation — {$asset->name}",
                        ],
                    ],
                ],
                $request->user(),
                true
            );

            $newBookValue   = (float) $asset->current_book_value - $amount;
            $newAccumulated = (float) $asset->accumulated_depreciation + $amount;

            DepreciationEntry::create([
                'company_id'               => $company->id,
                'asset_register_id'        => $asset->id,
                'journal_entry_id'         => $je->id,
                'period_date'              => $periodDate,
                'period_label'             => $periodLabel,
                'depreciation_amount'      => $amount,
                'accumulated_depreciation' => $newAccumulated,
                'book_value_after'         => $newBookValue,
                'method'                   => $asset->depreciation_method,
                'rate_used'                => $asset->depreciation_rate,
                'status'                   => DepreciationEntry::STATUS_POSTED,
                'entry_type'               => 'depreciation',
                'created_by'               => $request->user()?->id,
            ]);

            $asset->update([
                'current_book_value'     => $newBookValue,
                'last_depreciation_date' => $periodDate,
            ]);

            DB::commit();

            return response()->json([
                'message'          => 'Depreciation posted successfully',
                'amount'           => $amount,
                'new_book_value'   => $newBookValue,
                'journal_entry_id' => $je->id,
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Depreciation failed', 'error' => $e->getMessage()], 400);
        }
    }

    // ── Post Amortization (intangible) ────────────────────────────────────────

    /**
     * POST /assets/{asset}/amortize
     * Posts one amortization period for an intangible asset (IAS 38).
     *
     * JE: DR Amortization Expense (6910)
     *     CR Accumulated Amortization (1800 / 1810)
     */
    public function postAmortization(Request $request, $id)
    {
        $asset = AssetRegister::with('company')->findOrFail($id);

        if ($asset->status !== AssetRegister::STATUS_ACTIVE) {
            return response()->json(['message' => 'Only active assets can be amortized'], 422);
        }
        if ($asset->isTangible()) {
            return response()->json([
                'message' => 'This is a tangible asset. Use POST /assets/{id}/depreciate instead.',
            ], 422);
        }
        if (!$asset->useful_life_years || !$asset->depreciation_period) {
            return response()->json(['message' => 'Asset has no amortization schedule configured (useful_life_years and depreciation_period are required)'], 422);
        }

        $amount = $asset->calculateNextAmortization();
        if ($amount <= 0) {
            return response()->json(['message' => 'Asset is fully amortized'], 422);
        }

        $validator = Validator::make($request->all(), [
            'period_date'                     => 'required|date',
            'amortization_account_id'         => 'required|exists:accounts,id',
            'accumulated_amort_account_id'    => 'required|exists:accounts,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        try {
            DB::beginTransaction();

            $company     = $asset->company;
            $periodDate  = $request->period_date;
            $periodLabel = \Carbon\Carbon::parse($periodDate)
                ->format($asset->depreciation_period === 'monthly' ? 'M Y' : 'Y');

            // JE: DR Amortization Expense / CR Accumulated Amortization
            $je = $this->des->createJournalEntry(
                $company,
                [
                    'date'        => $periodDate,
                    'reference'   => "AMORT-{$asset->id}-{$periodLabel}",
                    'description' => "Amortization — {$asset->name} ({$periodLabel})",
                    'type'        => JournalEntry::TYPE_AUTOMATIC,
                    'source'      => 'amortization',
                    'source_id'   => $asset->id,
                    'lines'       => [
                        [
                            'account_id'  => $request->amortization_account_id,
                            'debit'       => $amount,
                            'credit'      => 0,
                            'description' => "Amortization expense — {$asset->name}",
                        ],
                        [
                            'account_id'  => $request->accumulated_amort_account_id,
                            'debit'       => 0,
                            'credit'      => $amount,
                            'description' => "Accumulated amortization — {$asset->name}",
                        ],
                    ],
                ],
                $request->user(),
                true
            );

            $newBookValue   = (float) $asset->current_book_value - $amount;
            $newAccumulated = (float) $asset->accumulated_amortization + $amount;

            // Reuse DepreciationEntry table — entry_type = 'amortization' distinguishes it
            DepreciationEntry::create([
                'company_id'               => $company->id,
                'asset_register_id'        => $asset->id,
                'journal_entry_id'         => $je->id,
                'period_date'              => $periodDate,
                'period_label'             => $periodLabel,
                'depreciation_amount'      => $amount,
                'accumulated_depreciation' => $newAccumulated,
                'book_value_after'         => $newBookValue,
                'method'                   => AssetRegister::METHOD_STRAIGHT_LINE,
                'rate_used'                => null,
                'status'                   => DepreciationEntry::STATUS_POSTED,
                'entry_type'               => 'amortization',
                'created_by'               => $request->user()?->id,
            ]);

            $asset->update([
                'current_book_value'     => $newBookValue,
                'last_depreciation_date' => $periodDate,
            ]);

            DB::commit();

            return response()->json([
                'message'          => 'Amortization posted successfully',
                'amount'           => $amount,
                'new_book_value'   => $newBookValue,
                'journal_entry_id' => $je->id,
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Amortization failed', 'error' => $e->getMessage()], 400);
        }
    }

    // ── Bulk depreciation (tangible) ─────────────────────────────────────────

    /**
     * POST /assets/depreciate-all
     * Posts depreciation for ALL depreciable tangible assets.
     */
    public function depreciateAll(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'period_date'                  => 'required|date',
            'depreciation_account_id'      => 'required|exists:accounts,id',
            'accumulated_depr_account_id'  => 'required|exists:accounts,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $companyId = $request->user()->company_id ?? $request->input('company_id');

        $assets  = AssetRegister::depreciable()->where('company_id', $companyId)->get();
        $posted  = 0;
        $skipped = 0;
        $errors  = [];

        foreach ($assets as $asset) {
            try {
                $this->postDepreciation($request, $asset->id);
                $posted++;
            } catch (\Exception $e) {
                $skipped++;
                $errors[] = "Asset {$asset->name}: {$e->getMessage()}";
            }
        }

        return response()->json([
            'message' => "Depreciation run complete. Posted: $posted, Skipped: $skipped.",
            'posted'  => $posted,
            'skipped' => $skipped,
            'errors'  => $errors,
        ]);
    }

    // ── Bulk amortization (intangible) ────────────────────────────────────────

    /**
     * POST /assets/amortize-all
     * Posts amortization for ALL amortizable intangible assets.
     */
    public function amortizeAll(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'period_date'                  => 'required|date',
            'amortization_account_id'      => 'required|exists:accounts,id',
            'accumulated_amort_account_id' => 'required|exists:accounts,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $companyId = $request->user()->company_id ?? $request->input('company_id');

        $assets  = AssetRegister::amortizable()->where('company_id', $companyId)->get();
        $posted  = 0;
        $skipped = 0;
        $errors  = [];

        foreach ($assets as $asset) {
            try {
                $this->postAmortization($request, $asset->id);
                $posted++;
            } catch (\Exception $e) {
                $skipped++;
                $errors[] = "Asset {$asset->name}: {$e->getMessage()}";
            }
        }

        return response()->json([
            'message' => "Amortization run complete. Posted: $posted, Skipped: $skipped.",
            'posted'  => $posted,
            'skipped' => $skipped,
            'errors'  => $errors,
        ]);
    }

    // ── Depreciation schedule preview (tangible) ──────────────────────────────

    /**
     * GET /assets/{asset}/depreciation-schedule
     * Returns a preview of future depreciation periods without posting.
     */
    public function depreciationSchedule($id)
    {
        $asset = AssetRegister::findOrFail($id);

        if ($asset->isIntangible()) {
            return response()->json([
                'message'  => 'This is an intangible asset. Use GET /assets/{id}/amortization-schedule instead.',
                'schedule' => [],
            ]);
        }

        if (!$asset->depreciation_method || !$asset->depreciation_rate) {
            return response()->json(['schedule' => [], 'message' => 'No depreciation configured']);
        }

        $schedule    = [];
        $bookValue   = (float) $asset->current_book_value;
        $salvage     = (float) $asset->salvage_value;
        $annualRate  = (float) $asset->depreciation_rate / 100;
        $isMonthly   = $asset->depreciation_period === 'monthly';
        $periodFactor = $isMonthly ? 1 / 12 : 1;
        $periodRate  = $annualRate * $periodFactor;
        $maxPeriods  = $isMonthly ? 120 : 20;

        $date        = $asset->depreciation_start_date
            ? \Carbon\Carbon::parse($asset->depreciation_start_date)
            : \Carbon\Carbon::now();
        $accumulated = (float) $asset->accumulated_depreciation;

        for ($i = 0; $i < $maxPeriods && $bookValue > $salvage; $i++) {
            if ($asset->depreciation_method === AssetRegister::METHOD_DECLINING_BALANCE) {
                $amount = $bookValue * $periodRate;
            } else {
                $usefulLifeYears = (float) ($asset->useful_life_years ?? 5);
                $totalPeriods    = $isMonthly ? $usefulLifeYears * 12 : $usefulLifeYears;
                $amount          = ((float) $asset->cost - $salvage) / $totalPeriods;
            }
            $amount      = min($amount, $bookValue - $salvage);
            $amount      = max(0, round($amount, 4));
            $bookValue  -= $amount;
            $accumulated += $amount;

            $schedule[] = [
                'period'      => $date->format($isMonthly ? 'M Y' : 'Y'),
                'date'        => $date->toDateString(),
                'amount'      => $amount,
                'accumulated' => round($accumulated, 4),
                'book_value'  => round(max($bookValue, $salvage), 4),
            ];

            $date = $isMonthly ? $date->copy()->addMonth() : $date->copy()->addYear();
            if ($bookValue <= $salvage) break;
        }

        return response()->json([
            'asset'    => $asset->only(['id', 'name', 'cost', 'salvage_value', 'current_book_value']),
            'schedule' => $schedule,
        ]);
    }

    // ── Amortization schedule preview (intangible) ────────────────────────────

    /**
     * GET /assets/{asset}/amortization-schedule
     * Returns a full straight-line amortization schedule (IAS 38) without posting.
     *
     * Example response row:
     *   { "period": "May 2026", "date": "2026-05-01", "amount": 1389,
     *     "accumulated": 1389, "book_value": 48611 }
     */
    public function amortizationSchedule($id)
    {
        $asset = AssetRegister::findOrFail($id);

        if ($asset->isTangible()) {
            return response()->json([
                'message'  => 'This is a tangible asset. Use GET /assets/{id}/depreciation-schedule instead.',
                'schedule' => [],
            ]);
        }

        if (!$asset->useful_life_years || !$asset->depreciation_period) {
            return response()->json(['schedule' => [], 'message' => 'No amortization schedule configured']);
        }

        $isMonthly       = $asset->depreciation_period === 'monthly';
        $usefulLifeYears = (float) $asset->useful_life_years;
        $totalPeriods    = $isMonthly ? (int) ($usefulLifeYears * 12) : (int) $usefulLifeYears;
        $cost            = (float) $asset->cost;
        $amountPerPeriod = round($cost / $totalPeriods, 4);
        $bookValue       = (float) $asset->current_book_value;
        $accumulated     = (float) $asset->accumulated_amortization;

        $date = $asset->depreciation_start_date
            ? \Carbon\Carbon::parse($asset->depreciation_start_date)
            : \Carbon\Carbon::now();

        $schedule = [];

        for ($i = 0; $i < $totalPeriods && $bookValue > 0; $i++) {
            $amount      = min($amountPerPeriod, $bookValue);
            $amount      = max(0, round($amount, 4));
            $bookValue  -= $amount;
            $accumulated += $amount;

            $schedule[] = [
                'period'      => $date->format($isMonthly ? 'M Y' : 'Y'),
                'date'        => $date->toDateString(),
                'amount'      => $amount,
                'accumulated' => round($accumulated, 4),
                'book_value'  => round(max($bookValue, 0), 4),
            ];

            $date = $isMonthly ? $date->copy()->addMonth() : $date->copy()->addYear();
            if ($bookValue <= 0) break;
        }

        return response()->json([
            'asset' => $asset->only([
                'id', 'name', 'cost', 'useful_life_years',
                'depreciation_period', 'current_book_value',
            ]),
            'total_periods'     => $totalPeriods,
            'amount_per_period' => $amountPerPeriod,
            'schedule'          => $schedule,
        ]);
    }
}
