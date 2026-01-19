<?php

namespace App\Http\Controllers\API\Reporting;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
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

        // Revenue (current month)
        $revenue = Account::where('company_id', $companyId)
            ->where('type', 'income')
            ->sum('current_balance');

        // Expenses (current month)
        $expenses = Account::where('company_id', $companyId)
            ->where('type', 'expense')
            ->sum('current_balance');

        // Profit
        $profit = $revenue - $expenses;

        // Cash position
        $cash = Account::where('company_id', $companyId)
            ->whereIn('category', ['cash', 'bank'])
            ->sum('current_balance');

        // Receivables
        $receivables = Invoice::unpaid()->sum('balance');

        // Payables
        $payables = Bill::unpaid()->sum('balance');

        // Overdue invoices count
        $overdueInvoices = Invoice::overdue()->count();

        // Overdue bills count
        $overdueBills = Bill::overdue()->count();

        return response()->json([
            'revenue' => $revenue,
            'expenses' => $expenses,
            'profit' => $profit,
            'profit_margin' => $revenue > 0 ? ($profit / $revenue) * 100 : 0,
            'cash_position' => $cash,
            'accounts_receivable' => $receivables,
            'accounts_payable' => $payables,
            'overdue_invoices_count' => $overdueInvoices,
            'overdue_bills_count' => $overdueBills,
        ]);
    }

    /**
     * Trial Balance
     */
    public function trialBalance(Request $request)
    {
        $date = $request->input('date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->orderBy('code')
            ->get();

        $trialBalance = [];
        $totalDebits = 0;
        $totalCredits = 0;

        foreach ($accounts as $account) {
            $balance = $account->getBalance(new \DateTime($date));

            if ($balance == 0) {
                continue;
            }

            $debit = 0;
            $credit = 0;

            // Assets and Expenses have debit balances
            if (in_array($account->type, ['asset', 'expense'])) {
                $debit = $balance;
                $totalDebits += $balance;
            }
            // Liabilities, Equity, and Income have credit balances
            else {
                $credit = $balance;
                $totalCredits += $balance;
            }

            $trialBalance[] = [
                'code' => $account->code,
                'name' => $account->name,
                'type' => $account->type,
                'debit' => $debit,
                'credit' => $credit,
            ];
        }

        return response()->json([
            'date' => $date,
            'accounts' => $trialBalance,
            'total_debits' => $totalDebits,
            'total_credits' => $totalCredits,
            'is_balanced' => abs($totalDebits - $totalCredits) < 0.01,
        ]);
    }

    /**
     * Balance Sheet
     */
    public function balanceSheet(Request $request)
    {
        $date = $request->input('date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->whereIn('type', ['asset', 'liability', 'equity'])
            ->orderBy('code')
            ->get();

        $assets = [];
        $liabilities = [];
        $equity = [];

        $totalAssets = 0;
        $totalLiabilities = 0;
        $totalEquity = 0;

        foreach ($accounts as $account) {
            $balance = $account->getBalance(new \DateTime($date));

            if ($balance == 0) {
                continue;
            }

            $accountData = [
                'code' => $account->code,
                'name' => $account->name,
                'balance' => $balance,
            ];

            if ($account->type === 'asset') {
                $assets[] = $accountData;
                $totalAssets += $balance;
            } elseif ($account->type === 'liability') {
                $liabilities[] = $accountData;
                $totalLiabilities += $balance;
            } else {
                $equity[] = $accountData;
                $totalEquity += $balance;
            }
        }

        return response()->json([
            'date' => $date,
            'assets' => [
                'accounts' => $assets,
                'total' => $totalAssets,
            ],
            'liabilities' => [
                'accounts' => $liabilities,
                'total' => $totalLiabilities,
            ],
            'equity' => [
                'accounts' => $equity,
                'total' => $totalEquity,
            ],
            'total_liabilities_and_equity' => $totalLiabilities + $totalEquity,
            'is_balanced' => abs($totalAssets - ($totalLiabilities + $totalEquity)) < 0.01,
        ]);
    }

    /**
     * Profit & Loss Statement
     */
    public function profitLoss(Request $request)
    {
        $startDate = $request->input('start_date', now()->startOfMonth()->format('Y-m-d'));
        $endDate = $request->input('end_date', now()->format('Y-m-d'));
        $companyId = $request->header('X-Company-ID');

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->whereIn('type', ['income', 'expense'])
            ->orderBy('code')
            ->get();

        $income = [];
        $expenses = [];

        $totalIncome = 0;
        $totalExpenses = 0;

        foreach ($accounts as $account) {
            $entries = $account->getLedgerEntries(
                new \DateTime($startDate),
                new \DateTime($endDate)
            );

            if ($entries->isEmpty()) {
                continue;
            }

            $balance = $entries->last()->balance ?? 0;

            if ($balance == 0) {
                continue;
            }

            $accountData = [
                'code' => $account->code,
                'name' => $account->name,
                'balance' => $balance,
            ];

            if ($account->type === 'income') {
                $income[] = $accountData;
                $totalIncome += $balance;
            } else {
                $expenses[] = $accountData;
                $totalExpenses += $balance;
            }
        }

        $netProfit = $totalIncome - $totalExpenses;

        return response()->json([
            'period' => [
                'start_date' => $startDate,
                'end_date' => $endDate,
            ],
            'income' => [
                'accounts' => $income,
                'total' => $totalIncome,
            ],
            'expenses' => [
                'accounts' => $expenses,
                'total' => $totalExpenses,
            ],
            'gross_profit' => $totalIncome,
            'net_profit' => $netProfit,
            'profit_margin' => $totalIncome > 0 ? ($netProfit / $totalIncome) * 100 : 0,
        ]);
    }

    /**
     * Aged Receivables Report
     */
    public function agedReceivables(Request $request)
    {
        $customers = Customer::with('invoices')->get();

        $report = [];
        $totals = [
            'current' => 0,
            '30_days' => 0,
            '60_days' => 0,
            '90_plus_days' => 0,
            'total' => 0,
        ];

        foreach ($customers as $customer) {
            $invoices = $customer->invoices()
                ->whereIn('status', ['sent', 'viewed', 'partial', 'overdue'])
                ->get();

            if ($invoices->isEmpty()) {
                continue;
            }

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
                    'id' => $customer->id,
                    'name' => $customer->name,
                    'customer_number' => $customer->customer_number,
                ],
                'aging' => $aging,
                'total' => $customerTotal,
            ];

            $totals['current'] += $aging['current'];
            $totals['30_days'] += $aging['30_days'];
            $totals['60_days'] += $aging['60_days'];
            $totals['90_plus_days'] += $aging['90_plus_days'];
            $totals['total'] += $customerTotal;
        }

        return response()->json([
            'report' => $report,
            'totals' => $totals,
        ]);
    }

    /**
     * Aged Payables Report
     */
    public function agedPayables(Request $request)
    {
        $vendors = Vendor::with('bills')->get();

        $report = [];
        $totals = [
            'current' => 0,
            '30_days' => 0,
            '60_days' => 0,
            '90_plus_days' => 0,
            'total' => 0,
        ];

        foreach ($vendors as $vendor) {
            $bills = $vendor->bills()
                ->whereIn('status', ['approved', 'partial', 'overdue'])
                ->get();

            if ($bills->isEmpty()) {
                continue;
            }

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
                    'id' => $vendor->id,
                    'name' => $vendor->name,
                    'vendor_number' => $vendor->vendor_number,
                ],
                'aging' => $aging,
                'total' => $vendorTotal,
            ];

            $totals['current'] += $aging['current'];
            $totals['30_days'] += $aging['30_days'];
            $totals['60_days'] += $aging['60_days'];
            $totals['90_plus_days'] += $aging['90_plus_days'];
            $totals['total'] += $vendorTotal;
        }

        return response()->json([
            'report' => $report,
            'totals' => $totals,
        ]);
    }
}
