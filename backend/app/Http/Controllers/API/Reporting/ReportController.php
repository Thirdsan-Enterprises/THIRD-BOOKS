<?php

namespace App\Http\Controllers\API\Reporting;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
use App\Models\Assets\DepreciationEntry;
use App\Models\Sales\Invoice;
use App\Models\Sales\Customer;
use App\Models\Purchases\Bill;
use App\Models\Purchases\Vendor;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    /**
     * Dashboard overview
     */
    public function dashboardOverview(Request $request)
    {
        $companyId = $request->header('X-Company-ID');

        $revenue  = Account::where('company_id', $companyId)->where('type', 'income')->sum('current_balance');
        $expenses = Account::where('company_id', $companyId)->where('type', 'expense')->sum('current_balance');
        $profit   = $revenue - $expenses;
        $cash     = Account::where('company_id', $companyId)->whereIn('category', ['cash', 'bank'])->sum('current_balance');

        $receivables   = Invoice::unpaid()->sum('balance');
        $payables      = Bill::unpaid()->sum('balance');
        $overdueInvoices = Invoice::overdue()->count();
        $overdueBills    = Bill::overdue()->count();

        return response()->json([
            'revenue'               => $revenue,
            'expenses'              => $expenses,
            'profit'                => $profit,
            'profit_margin'         => $revenue > 0 ? ($profit / $revenue) * 100 : 0,
            'cash_position'         => $cash,
            'accounts_receivable'   => $receivables,
            'accounts_payable'      => $payables,
            'overdue_invoices_count' => $overdueInvoices,
            'overdue_bills_count'    => $overdueBills,
        ]);
    }

    /**
     * Trial Balance
     */
    public function trialBalance(Request $request)
    {
        $date      = $request->input('date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->orderBy('code')
            ->get();

        $trialBalance  = [];
        $totalDebits   = 0;
        $totalCredits  = 0;

        foreach ($accounts as $account) {
            $balance = $account->getBalance(new \DateTime($date));
            if ($balance == 0) continue;

            $debit  = 0;
            $credit = 0;

            if (in_array($account->type, ['asset', 'expense'])) {
                $debit        = $balance;
                $totalDebits += $balance;
            } else {
                $credit        = $balance;
                $totalCredits += $balance;
            }

            $trialBalance[] = [
                'code'   => $account->code,
                'name'   => $account->name,
                'type'   => $account->type,
                'category' => $account->category,
                'debit'  => $debit,
                'credit' => $credit,
            ];
        }

        return response()->json([
            'date'          => $date,
            'accounts'      => $trialBalance,
            'total_debits'  => $totalDebits,
            'total_credits' => $totalCredits,
            'is_balanced'   => abs($totalDebits - $totalCredits) < 0.01,
        ]);
    }

    /**
     * Balance Sheet
     *
     * Assets are grouped into three sections per industry standard:
     *   1. Current Assets
     *   2. Fixed Assets (PP&E) — tangible, with accumulated depreciation
     *   3. Intangible Assets (IAS 38) — software, patents, with accumulated amortization
     */
    public function balanceSheet(Request $request)
    {
        $date      = $request->input('date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->whereIn('type', ['asset', 'liability', 'equity'])
            ->orderBy('code')
            ->get();

        // ── Asset sub-sections ────────────────────────────────────────────────
        $currentAssets    = [];
        $fixedAssets      = [];   // PP&E — tangible (1500–1699)
        $intangibleAssets = [];   // IAS 38 — intangible (1700–1899)
        $otherAssets      = [];

        $totalCurrentAssets    = 0;
        $totalFixedAssets      = 0;
        $totalIntangibleAssets = 0;
        $totalOtherAssets      = 0;

        $liabilities = [];
        $equity      = [];

        $totalLiabilities = 0;
        $totalEquity      = 0;

        foreach ($accounts as $account) {
            $balance = $account->getBalance(new \DateTime($date));
            if ($balance == 0) continue;

            $row = [
                'code'     => $account->code,
                'name'     => $account->name,
                'category' => $account->category,
                'balance'  => $balance,
            ];

            if ($account->type === 'asset') {
                $code = (int) $account->code;

                if ($account->category === 'intangible_asset') {
                    // 1700–1899 — Intangible Assets and Accumulated Amortization
                    $intangibleAssets[]     = $row;
                    $totalIntangibleAssets += $balance;
                } elseif ($account->category === 'fixed_asset' || ($code >= 1500 && $code < 1700)) {
                    // 1500–1699 — PP&E and Accumulated Depreciation
                    $fixedAssets[]      = $row;
                    $totalFixedAssets  += $balance;
                } elseif (in_array($account->category, ['cash', 'bank', 'accounts_receivable', 'inventory']) ||
                          ($code >= 1000 && $code < 1500)) {
                    $currentAssets[]       = $row;
                    $totalCurrentAssets   += $balance;
                } else {
                    $otherAssets[]      = $row;
                    $totalOtherAssets  += $balance;
                }
            } elseif ($account->type === 'liability') {
                $liabilities[]     = $row;
                $totalLiabilities += $balance;
            } else {
                $equity[]      = $row;
                $totalEquity  += $balance;
            }
        }

        $totalAssets = $totalCurrentAssets + $totalFixedAssets + $totalIntangibleAssets + $totalOtherAssets;

        return response()->json([
            'date'   => $date,
            'assets' => [
                'current_assets' => [
                    'accounts' => $currentAssets,
                    'total'    => $totalCurrentAssets,
                ],
                'fixed_assets' => [
                    'accounts' => $fixedAssets,
                    'total'    => $totalFixedAssets,
                    'label'    => 'Property, Plant & Equipment (PP&E)',
                ],
                'intangible_assets' => [
                    'accounts' => $intangibleAssets,
                    'total'    => $totalIntangibleAssets,
                    'label'    => 'Intangible Assets',
                ],
                'other_assets' => [
                    'accounts' => $otherAssets,
                    'total'    => $totalOtherAssets,
                ],
                'total' => $totalAssets,
            ],
            'liabilities' => [
                'accounts' => $liabilities,
                'total'    => $totalLiabilities,
            ],
            'equity' => [
                'accounts' => $equity,
                'total'    => $totalEquity,
            ],
            'total_liabilities_and_equity' => $totalLiabilities + $totalEquity,
            'is_balanced' => abs($totalAssets - ($totalLiabilities + $totalEquity)) < 0.01,
        ]);
    }

    /**
     * Profit & Loss Statement
     *
     * Both Depreciation Expense (6900) and Amortization Expense (6910) are
     * standard expense accounts and appear automatically in the expenses section.
     */
    public function profitLoss(Request $request)
    {
        $startDate = $request->input('start_date', now()->startOfMonth()->format('Y-m-d'));
        $endDate   = $request->input('end_date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->whereIn('type', ['income', 'expense'])
            ->orderBy('code')
            ->get();

        $income   = [];
        $expenses = [];

        $totalIncome   = 0;
        $totalExpenses = 0;

        foreach ($accounts as $account) {
            $entries = $account->getLedgerEntries(
                new \DateTime($startDate),
                new \DateTime($endDate)
            );

            if ($entries->isEmpty()) continue;

            $balance = $entries->last()->balance ?? 0;
            if ($balance == 0) continue;

            $row = [
                'code'    => $account->code,
                'name'    => $account->name,
                'balance' => $balance,
            ];

            if ($account->type === 'income') {
                $income[]       = $row;
                $totalIncome   += $balance;
            } else {
                $expenses[]     = $row;
                $totalExpenses += $balance;
            }
        }

        $netProfit = $totalIncome - $totalExpenses;

        return response()->json([
            'period' => [
                'start_date' => $startDate,
                'end_date'   => $endDate,
            ],
            'income' => [
                'accounts' => $income,
                'total'    => $totalIncome,
            ],
            'expenses' => [
                'accounts' => $expenses,
                'total'    => $totalExpenses,
            ],
            'gross_profit'   => $totalIncome,
            'net_profit'     => $netProfit,
            'profit_margin'  => $totalIncome > 0 ? ($netProfit / $totalIncome) * 100 : 0,
        ]);
    }

    /**
     * Cash Flow Statement (indirect method)
     *
     * Both depreciation and amortization are non-cash charges added back
     * under Operating Activities (IAS 7 indirect method).
     */
    public function cashFlow(Request $request)
    {
        $startDate = $request->input('start_date', now()->startOfMonth()->format('Y-m-d'));
        $endDate   = $request->input('end_date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        // ── Closing cash & bank balance ───────────────────────────────────────
        $cashAccounts = Account::where('company_id', $companyId)
            ->whereIn('category', ['cash', 'bank'])
            ->get();
        $closingCash = $cashAccounts->sum('current_balance');

        // ── Non-cash add-backs: depreciation (tangible) ───────────────────────
        $depreciationAddBack = DepreciationEntry::where('company_id', $companyId)
            ->where('status', 'posted')
            ->where('entry_type', 'depreciation')
            ->whereBetween('period_date', [$startDate, $endDate])
            ->sum('depreciation_amount');

        // ── Non-cash add-backs: amortization (intangible, IAS 38) ────────────
        $amortizationAddBack = DepreciationEntry::where('company_id', $companyId)
            ->where('status', 'posted')
            ->where('entry_type', 'amortization')
            ->whereBetween('period_date', [$startDate, $endDate])
            ->sum('depreciation_amount');

        // ── Working capital movements ─────────────────────────────────────────
        $arBalance = Account::where('company_id', $companyId)
            ->where('category', 'accounts_receivable')
            ->sum('current_balance');
        $apBalance = Account::where('company_id', $companyId)
            ->where('category', 'accounts_payable')
            ->sum('current_balance');

        $receivablesImpact = -$arBalance;
        $payablesImpact    = -$apBalance;

        // ── Operating profit from P&L ─────────────────────────────────────────
        $income   = Account::where('company_id', $companyId)->where('type', 'income')->sum('current_balance');
        $expenses = Account::where('company_id', $companyId)->where('type', 'expense')->sum('current_balance');
        $operatingProfit = $income - $expenses;

        $totalNonCashAddBack = $depreciationAddBack + $amortizationAddBack;

        $netOperating = $operatingProfit + $totalNonCashAddBack + $receivablesImpact + $payablesImpact;

        // ── Investing: PP&E acquisitions ──────────────────────────────────────
        $fixedAssetBalance = Account::where('company_id', $companyId)
            ->where('category', 'fixed_asset')
            ->where('name', 'not like', '%Depreciation%')
            ->sum('current_balance');

        // Investing: intangible asset acquisitions (software, patents — capital outflows)
        $intangibleBalance = Account::where('company_id', $companyId)
            ->where('category', 'intangible_asset')
            ->where('name', 'not like', '%Amortization%')
            ->sum('current_balance');

        $netInvesting = -($fixedAssetBalance + $intangibleBalance);

        // ── Financing ─────────────────────────────────────────────────────────
        $loanBalance   = Account::where('company_id', $companyId)
            ->where('category', 'long_term_liability')
            ->sum('current_balance');
        $loanProceeds  = $loanBalance < 0 ? abs($loanBalance) : 0;
        $loanRepayment = $loanBalance > 0 ? $loanBalance : 0;
        $netFinancing  = $loanProceeds - $loanRepayment;

        $netIncrease = $netOperating + $netInvesting + $netFinancing;
        $openingCash = $closingCash - $netIncrease;

        return response()->json([
            'period' => ['start_date' => $startDate, 'end_date' => $endDate],
            'operating' => [
                'operating_profit'        => round($operatingProfit, 2),
                'depreciation_add_back'   => round($depreciationAddBack, 2),
                'amortization_add_back'   => round($amortizationAddBack, 2),
                'total_non_cash_add_back' => round($totalNonCashAddBack, 2),
                'receivables_impact'      => round($receivablesImpact, 2),
                'payables_impact'         => round($payablesImpact, 2),
                'net_operating'           => round($netOperating, 2),
            ],
            'investing' => [
                'fixed_asset_acquisitions'     => round($fixedAssetBalance, 2),
                'intangible_asset_acquisitions' => round($intangibleBalance, 2),
                'net_investing'                => round($netInvesting, 2),
            ],
            'financing' => [
                'loan_proceeds'  => round($loanProceeds, 2),
                'loan_repayment' => round($loanRepayment, 2),
                'net_financing'  => round($netFinancing, 2),
            ],
            'summary' => [
                'opening_cash' => round($openingCash, 2),
                'net_increase' => round($netIncrease, 2),
                'closing_cash' => round($closingCash, 2),
            ],
        ]);
    }

    /**
     * Aged Receivables Report
     */
    public function agedReceivables(Request $request)
    {
        $customers = Customer::with('invoices')->get();

        $report = [];
        $totals = ['current' => 0, '30_days' => 0, '60_days' => 0, '90_plus_days' => 0, 'total' => 0];

        foreach ($customers as $customer) {
            $invoices = $customer->invoices()
                ->whereIn('status', ['sent', 'viewed', 'partial', 'overdue'])
                ->get();

            if ($invoices->isEmpty()) continue;

            $aging = ['current' => 0, '30_days' => 0, '60_days' => 0, '90_plus_days' => 0];

            foreach ($invoices as $invoice) {
                $daysOverdue = now()->diffInDays($invoice->due_date, false);
                if ($daysOverdue <= 0) {
                    $aging['current'] += $invoice->balance;
                } elseif ($daysOverdue <= 30) {
                    $aging['30_days'] += $invoice->balance;
                } elseif ($daysOverdue <= 60) {
                    $aging['60_days'] += $invoice->balance;
                } else {
                    $aging['90_plus_days'] += $invoice->balance;
                }
            }

            $customerTotal = array_sum($aging);
            $report[] = [
                'customer' => [
                    'id'              => $customer->id,
                    'name'            => $customer->name,
                    'customer_number' => $customer->customer_number,
                ],
                'aging' => $aging,
                'total' => $customerTotal,
            ];

            foreach ($aging as $bucket => $val) {
                $totals[$bucket] += $val;
            }
            $totals['total'] += $customerTotal;
        }

        return response()->json(['report' => $report, 'totals' => $totals]);
    }

    /**
     * Aged Payables Report
     */
    public function agedPayables(Request $request)
    {
        $vendors = Vendor::with('bills')->get();

        $report = [];
        $totals = ['current' => 0, '30_days' => 0, '60_days' => 0, '90_plus_days' => 0, 'total' => 0];

        foreach ($vendors as $vendor) {
            $bills = $vendor->bills()
                ->whereIn('status', ['approved', 'partial', 'overdue'])
                ->get();

            if ($bills->isEmpty()) continue;

            $aging = ['current' => 0, '30_days' => 0, '60_days' => 0, '90_plus_days' => 0];

            foreach ($bills as $bill) {
                $daysOverdue = now()->diffInDays($bill->due_date, false);
                if ($daysOverdue <= 0) {
                    $aging['current'] += $bill->balance;
                } elseif ($daysOverdue <= 30) {
                    $aging['30_days'] += $bill->balance;
                } elseif ($daysOverdue <= 60) {
                    $aging['60_days'] += $bill->balance;
                } else {
                    $aging['90_plus_days'] += $bill->balance;
                }
            }

            $vendorTotal = array_sum($aging);
            $report[] = [
                'vendor' => [
                    'id'            => $vendor->id,
                    'name'          => $vendor->name,
                    'vendor_number' => $vendor->vendor_number,
                ],
                'aging' => $aging,
                'total' => $vendorTotal,
            ];

            foreach ($aging as $bucket => $val) {
                $totals[$bucket] += $val;
            }
            $totals['total'] += $vendorTotal;
        }

        return response()->json(['report' => $report, 'totals' => $totals]);
    }
}
