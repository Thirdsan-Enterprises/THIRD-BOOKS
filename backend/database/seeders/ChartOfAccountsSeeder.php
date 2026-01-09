<?php

namespace Database\Seeders;

use App\Models\Accounting\Account;
use App\Models\Company;
use App\Models\Currency;
use Illuminate\Database\Seeder;

class ChartOfAccountsSeeder extends Seeder
{
    /**
     * Seed Chart of Accounts for a company
     *
     * @param Company $company
     * @param string $template 'retail' | 'hospitality' | 'services' | 'general'
     */
    public function run(Company $company, string $template = 'general'): void
    {
        $baseCurrency = Currency::where('code', $company->base_currency)->first();

        if (!$baseCurrency) {
            throw new \Exception("Base currency {$company->base_currency} not found");
        }

        $accounts = match ($template) {
            'retail' => $this->getRetailAccounts(),
            'hospitality' => $this->getHospitalityAccounts(),
            'services' => $this->getServicesAccounts(),
            default => $this->getGeneralAccounts(),
        };

        foreach ($accounts as $accountData) {
            Account::create([
                'company_id' => $company->id,
                'currency_id' => $baseCurrency->id,
                ...$accountData,
            ]);
        }
    }

    /**
     * General Chart of Accounts (suitable for most businesses)
     */
    private function getGeneralAccounts(): array
    {
        return [
            // ASSETS (1000-1999)
            ['code' => '1000', 'name' => 'Assets', 'type' => 'asset', 'category' => null, 'parent_id' => null, 'is_system' => true],

            // Current Assets (1000-1499)
            ['code' => '1010', 'name' => 'Cash and Cash Equivalents', 'type' => 'asset', 'category' => 'cash', 'parent_id' => null, 'is_system' => false],
            ['code' => '1011', 'name' => 'Petty Cash', 'type' => 'asset', 'category' => 'cash', 'parent_id' => null, 'is_system' => false],
            ['code' => '1020', 'name' => 'Bank Accounts', 'type' => 'asset', 'category' => 'bank', 'parent_id' => null, 'is_system' => false],
            ['code' => '1021', 'name' => 'Main Operating Account', 'type' => 'asset', 'category' => 'bank', 'parent_id' => null, 'is_system' => false],

            ['code' => '1100', 'name' => 'Accounts Receivable', 'type' => 'asset', 'category' => 'accounts_receivable', 'parent_id' => null, 'is_system' => true],
            ['code' => '1110', 'name' => 'Allowance for Doubtful Accounts', 'type' => 'asset', 'category' => 'accounts_receivable', 'parent_id' => null, 'is_system' => false],

            ['code' => '1150', 'name' => 'Prepaid Expenses', 'type' => 'asset', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '1151', 'name' => 'Prepaid Rent', 'type' => 'asset', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '1152', 'name' => 'Prepaid Insurance', 'type' => 'asset', 'category' => null, 'parent_id' => null, 'is_system' => false],

            ['code' => '1160', 'name' => 'Tax Receivable (VAT Input)', 'type' => 'asset', 'category' => null, 'parent_id' => null, 'is_system' => true],

            // Fixed Assets (1500-1899)
            ['code' => '1500', 'name' => 'Property, Plant & Equipment', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1510', 'name' => 'Land', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1520', 'name' => 'Buildings', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1530', 'name' => 'Furniture and Fixtures', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1540', 'name' => 'Equipment', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1550', 'name' => 'Vehicles', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1560', 'name' => 'Computer Equipment', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],

            ['code' => '1600', 'name' => 'Accumulated Depreciation', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1610', 'name' => 'Accumulated Depreciation - Buildings', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],
            ['code' => '1620', 'name' => 'Accumulated Depreciation - Equipment', 'type' => 'asset', 'category' => 'fixed_asset', 'parent_id' => null, 'is_system' => false],

            // LIABILITIES (2000-2999)
            ['code' => '2000', 'name' => 'Liabilities', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => true],

            // Current Liabilities (2000-2499)
            ['code' => '2100', 'name' => 'Accounts Payable', 'type' => 'liability', 'category' => 'accounts_payable', 'parent_id' => null, 'is_system' => true],
            ['code' => '2110', 'name' => 'Tax Payable (VAT Output)', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => true],
            ['code' => '2120', 'name' => 'Withholding Tax Payable', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '2130', 'name' => 'PAYE Payable', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '2140', 'name' => 'NSSF Payable', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],

            ['code' => '2200', 'name' => 'Accrued Expenses', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '2210', 'name' => 'Accrued Salaries', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '2220', 'name' => 'Accrued Utilities', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],

            ['code' => '2300', 'name' => 'Short-term Loans', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],
            ['code' => '2310', 'name' => 'Bank Overdraft', 'type' => 'liability', 'category' => null, 'parent_id' => null, 'is_system' => false],

            // Long-term Liabilities (2500-2899)
            ['code' => '2500', 'name' => 'Long-term Loans', 'type' => 'liability', 'category' => 'long_term_liability', 'parent_id' => null, 'is_system' => false],
            ['code' => '2510', 'name' => 'Mortgage Payable', 'type' => 'liability', 'category' => 'long_term_liability', 'parent_id' => null, 'is_system' => false],

            // EQUITY (3000-3999)
            ['code' => '3000', 'name' => 'Equity', 'type' => 'equity', 'category' => 'equity', 'parent_id' => null, 'is_system' => true],
            ['code' => '3010', 'name' => 'Owner\'s Capital', 'type' => 'equity', 'category' => 'equity', 'parent_id' => null, 'is_system' => true],
            ['code' => '3020', 'name' => 'Owner\'s Drawings', 'type' => 'equity', 'category' => 'equity', 'parent_id' => null, 'is_system' => false],
            ['code' => '3030', 'name' => 'Retained Earnings', 'type' => 'equity', 'category' => 'equity', 'parent_id' => null, 'is_system' => true],
            ['code' => '3040', 'name' => 'Current Year Earnings', 'type' => 'equity', 'category' => 'equity', 'parent_id' => null, 'is_system' => true],

            // INCOME (4000-4999)
            ['code' => '4000', 'name' => 'Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => true],
            ['code' => '4100', 'name' => 'Sales Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4200', 'name' => 'Service Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4300', 'name' => 'Other Income', 'type' => 'income', 'category' => 'other_income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4310', 'name' => 'Interest Income', 'type' => 'income', 'category' => 'other_income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4320', 'name' => 'Discount Received', 'type' => 'income', 'category' => 'other_income', 'parent_id' => null, 'is_system' => false],

            // EXPENSES (5000-9999)
            ['code' => '5000', 'name' => 'Cost of Goods Sold', 'type' => 'expense', 'category' => 'cost_of_goods_sold', 'parent_id' => null, 'is_system' => false],
            ['code' => '5100', 'name' => 'Purchases', 'type' => 'expense', 'category' => 'cost_of_goods_sold', 'parent_id' => null, 'is_system' => false],

            ['code' => '6000', 'name' => 'Operating Expenses', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6100', 'name' => 'Salaries and Wages', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6200', 'name' => 'Rent Expense', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6300', 'name' => 'Utilities Expense', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6310', 'name' => 'Electricity', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6320', 'name' => 'Water', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6330', 'name' => 'Internet & Phone', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6400', 'name' => 'Office Supplies', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6500', 'name' => 'Repairs and Maintenance', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6600', 'name' => 'Insurance Expense', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6700', 'name' => 'Marketing and Advertising', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6800', 'name' => 'Professional Fees', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6810', 'name' => 'Legal Fees', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6820', 'name' => 'Accounting Fees', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6900', 'name' => 'Depreciation Expense', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],

            ['code' => '7000', 'name' => 'Other Expenses', 'type' => 'expense', 'category' => 'other_expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '7100', 'name' => 'Bank Charges', 'type' => 'expense', 'category' => 'other_expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '7200', 'name' => 'Interest Expense', 'type' => 'expense', 'category' => 'other_expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '7300', 'name' => 'Discount Given', 'type' => 'expense', 'category' => 'other_expense', 'parent_id' => null, 'is_system' => false],
        ];
    }

    /**
     * Retail-specific Chart of Accounts
     */
    private function getRetailAccounts(): array
    {
        $general = $this->getGeneralAccounts();

        // Add retail-specific accounts
        $retailSpecific = [
            ['code' => '1200', 'name' => 'Inventory', 'type' => 'asset', 'category' => 'inventory', 'parent_id' => null, 'is_system' => true],
            ['code' => '1210', 'name' => 'Finished Goods', 'type' => 'asset', 'category' => 'inventory', 'parent_id' => null, 'is_system' => false],
            ['code' => '1220', 'name' => 'Inventory Write-offs', 'type' => 'asset', 'category' => 'inventory', 'parent_id' => null, 'is_system' => false],
            ['code' => '5200', 'name' => 'Freight and Shipping', 'type' => 'expense', 'category' => 'cost_of_goods_sold', 'parent_id' => null, 'is_system' => false],
        ];

        return array_merge($general, $retailSpecific);
    }

    /**
     * Hospitality-specific Chart of Accounts
     */
    private function getHospitalityAccounts(): array
    {
        $general = $this->getGeneralAccounts();

        // Add hospitality-specific accounts
        $hospitalitySpecific = [
            ['code' => '4110', 'name' => 'Room Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4120', 'name' => 'Food & Beverage Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4130', 'name' => 'Event Services Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '5300', 'name' => 'Food & Beverage Costs', 'type' => 'expense', 'category' => 'cost_of_goods_sold', 'parent_id' => null, 'is_system' => false],
            ['code' => '6350', 'name' => 'Laundry Expense', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
        ];

        return array_merge($general, $hospitalitySpecific);
    }

    /**
     * Services-specific Chart of Accounts
     */
    private function getServicesAccounts(): array
    {
        $general = $this->getGeneralAccounts();

        // Add services-specific accounts
        $servicesSpecific = [
            ['code' => '4210', 'name' => 'Consulting Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4220', 'name' => 'Project Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '4230', 'name' => 'Subscription Revenue', 'type' => 'income', 'category' => 'income', 'parent_id' => null, 'is_system' => false],
            ['code' => '6750', 'name' => 'Software Subscriptions', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
            ['code' => '6850', 'name' => 'Training and Development', 'type' => 'expense', 'category' => 'expense', 'parent_id' => null, 'is_system' => false],
        ];

        return array_merge($general, $servicesSpecific);
    }
}
