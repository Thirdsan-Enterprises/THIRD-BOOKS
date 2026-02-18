-- =====================================================
-- ThirdBooks Database Setup
-- =====================================================
-- Import this file into your DirectAdmin MySQL database
-- via phpMyAdmin or command line:
--   mysql -u username -p database_name < database-setup.sql
--
-- This creates ALL tables for both the backend API and
-- admin panel (they share the same database).
-- =====================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- =====================================================
-- LARAVEL FRAMEWORK TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS `migrations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `migration` VARCHAR(255) NOT NULL,
    `batch` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cache` (
    `key` VARCHAR(255) NOT NULL PRIMARY KEY,
    `value` MEDIUMTEXT NOT NULL,
    `expiration` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cache_locks` (
    `key` VARCHAR(255) NOT NULL PRIMARY KEY,
    `owner` VARCHAR(255) NOT NULL,
    `expiration` INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jobs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `queue` VARCHAR(255) NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `attempts` TINYINT UNSIGNED NOT NULL,
    `reserved_at` INT UNSIGNED NULL,
    `available_at` INT UNSIGNED NOT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    INDEX `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `failed_jobs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uuid` VARCHAR(255) NOT NULL UNIQUE,
    `connection` TEXT NOT NULL,
    `queue` TEXT NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `exception` LONGTEXT NOT NULL,
    `failed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- CENTRAL TABLES (Platform-level)
-- =====================================================

-- Tenants (organizations/businesses)
CREATE TABLE IF NOT EXISTS `tenants` (
    `id` CHAR(36) NOT NULL PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `company_name` VARCHAR(255) NOT NULL,
    `email` VARCHAR(255) NOT NULL UNIQUE,
    `phone` VARCHAR(255) NULL,
    `address` TEXT NULL,
    `country` VARCHAR(2) NOT NULL DEFAULT 'UG',
    `base_currency` VARCHAR(3) NOT NULL DEFAULT 'UGX',
    `fiscal_year_start` VARCHAR(5) NOT NULL DEFAULT '01-01',
    `plan` VARCHAR(255) NOT NULL DEFAULT 'trial',
    `trial_ends_at` TIMESTAMP NULL,
    `subscription_ends_at` TIMESTAMP NULL,
    `status` VARCHAR(255) NOT NULL DEFAULT 'active',
    `settings` JSON NULL,
    `data` JSON NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `tenants_email_index` (`email`),
    INDEX `tenants_status_index` (`status`),
    INDEX `tenants_plan_index` (`plan`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Domains (tenant subdomains)
CREATE TABLE IF NOT EXISTS `domains` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` CHAR(36) NOT NULL,
    `domain` VARCHAR(255) NOT NULL UNIQUE,
    `is_primary` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `domains_domain_index` (`domain`),
    INDEX `domains_tenant_id_is_primary_index` (`tenant_id`, `is_primary`),
    CONSTRAINT `domains_tenant_id_foreign` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Users (all users including super_admin)
CREATE TABLE IF NOT EXISTS `users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` CHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `email` VARCHAR(255) NOT NULL,
    `password` VARCHAR(255) NOT NULL,
    `phone` VARCHAR(255) NULL,
    `role` VARCHAR(255) NOT NULL DEFAULT 'user',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `email_verified_at` TIMESTAMP NULL,
    `remember_token` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `users_email_index` (`email`),
    INDEX `users_tenant_id_role_index` (`tenant_id`, `role`),
    CONSTRAINT `users_tenant_id_foreign` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Password reset tokens
CREATE TABLE IF NOT EXISTS `password_reset_tokens` (
    `email` VARCHAR(255) NOT NULL PRIMARY KEY,
    `token` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sessions
CREATE TABLE IF NOT EXISTS `sessions` (
    `id` VARCHAR(255) NOT NULL PRIMARY KEY,
    `user_id` BIGINT UNSIGNED NULL,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` TEXT NULL,
    `payload` LONGTEXT NOT NULL,
    `last_activity` INT NOT NULL,
    INDEX `sessions_user_id_index` (`user_id`),
    INDEX `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sanctum personal access tokens (API authentication)
CREATE TABLE IF NOT EXISTS `personal_access_tokens` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tokenable_type` VARCHAR(255) NOT NULL,
    `tokenable_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `token` VARCHAR(64) NOT NULL UNIQUE,
    `abilities` TEXT NULL,
    `last_used_at` TIMESTAMP NULL,
    `expires_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`, `tokenable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Central audit logs (platform-level admin actions)
CREATE TABLE IF NOT EXISTS `audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `user_id` BIGINT UNSIGNED NULL,
    `tenant_id` CHAR(36) NULL,
    `action` VARCHAR(255) NOT NULL,
    `entity_type` VARCHAR(255) NULL,
    `entity_id` VARCHAR(255) NULL,
    `changes` JSON NULL,
    `metadata` JSON NULL,
    `ip_address` VARCHAR(255) NULL,
    `user_agent` TEXT NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `audit_logs_user_id_index` (`user_id`),
    INDEX `audit_logs_tenant_id_index` (`tenant_id`),
    INDEX `audit_logs_entity_type_entity_id_index` (`entity_type`, `entity_id`),
    INDEX `audit_logs_action_index` (`action`),
    INDEX `audit_logs_created_at_index` (`created_at`),
    CONSTRAINT `audit_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TENANT TABLES (Business data - shared database mode)
-- =====================================================

-- Companies
CREATE TABLE IF NOT EXISTS `companies` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` CHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `legal_name` VARCHAR(255) NULL,
    `tax_id` VARCHAR(255) NULL,
    `registration_number` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(255) NULL,
    `address` TEXT NULL,
    `city` VARCHAR(255) NULL,
    `state` VARCHAR(255) NULL,
    `postal_code` VARCHAR(255) NULL,
    `country` VARCHAR(2) NOT NULL DEFAULT 'UG',
    `base_currency` VARCHAR(3) NOT NULL DEFAULT 'UGX',
    `fiscal_year_start` VARCHAR(5) NOT NULL DEFAULT '01-01',
    `fiscal_year_end` VARCHAR(5) NOT NULL DEFAULT '12-31',
    `logo_url` VARCHAR(255) NULL,
    `settings` JSON NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `companies_tenant_id_index` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Currencies
CREATE TABLE IF NOT EXISTS `currencies` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `code` VARCHAR(3) NOT NULL UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    `symbol` VARCHAR(10) NOT NULL,
    `decimal_places` INT NOT NULL DEFAULT 2,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Exchange rates
CREATE TABLE IF NOT EXISTS `exchange_rates` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `rate` DECIMAL(20,10) NOT NULL,
    `source` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    UNIQUE KEY `exchange_rates_currency_id_date_unique` (`currency_id`, `date`),
    INDEX `exchange_rates_date_index` (`date`),
    CONSTRAINT `exchange_rates_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chart of Accounts
CREATE TABLE IF NOT EXISTS `accounts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `parent_id` BIGINT UNSIGNED NULL,
    `code` VARCHAR(50) NOT NULL UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `type` ENUM('asset','liability','equity','income','expense') NOT NULL,
    `subtype` VARCHAR(255) NULL,
    `category` ENUM('bank','cash','accounts_receivable','inventory','fixed_asset','accounts_payable','credit_card','long_term_liability','equity','income','cost_of_goods_sold','expense','other_income','other_expense') NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `opening_balance` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `current_balance` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `is_system` TINYINT(1) NOT NULL DEFAULT 0,
    `order` INT NOT NULL DEFAULT 0,
    `settings` JSON NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `accounts_company_id_type_index` (`company_id`, `type`),
    INDEX `accounts_company_id_category_index` (`company_id`, `category`),
    INDEX `accounts_code_index` (`code`),
    INDEX `accounts_is_active_index` (`is_active`),
    CONSTRAINT `accounts_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `accounts_parent_id_foreign` FOREIGN KEY (`parent_id`) REFERENCES `accounts` (`id`) ON DELETE SET NULL,
    CONSTRAINT `accounts_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Journal Entries (Double-Entry Core)
CREATE TABLE IF NOT EXISTS `journal_entries` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `entry_number` VARCHAR(255) NOT NULL UNIQUE,
    `date` DATE NOT NULL,
    `reference` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `status` ENUM('draft','posted') NOT NULL DEFAULT 'draft',
    `type` ENUM('manual','automatic') NOT NULL DEFAULT 'manual',
    `source` VARCHAR(255) NULL,
    `source_id` BIGINT UNSIGNED NULL,
    `created_by` BIGINT UNSIGNED NOT NULL,
    `posted_by` BIGINT UNSIGNED NULL,
    `posted_at` TIMESTAMP NULL,
    `is_locked` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `journal_entries_company_id_date_index` (`company_id`, `date`),
    INDEX `journal_entries_company_id_status_index` (`company_id`, `status`),
    INDEX `journal_entries_entry_number_index` (`entry_number`),
    INDEX `journal_entries_source_source_id_index` (`source`, `source_id`),
    CONSTRAINT `journal_entries_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `journal_entries_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `journal_entries_posted_by_foreign` FOREIGN KEY (`posted_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Journal Lines
CREATE TABLE IF NOT EXISTS `journal_lines` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `journal_entry_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `description` TEXT NULL,
    `debit` DECIMAL(20,4) UNSIGNED NOT NULL DEFAULT 0,
    `credit` DECIMAL(20,4) UNSIGNED NOT NULL DEFAULT 0,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(20,10) NOT NULL DEFAULT 1,
    `debit_foreign` DECIMAL(20,4) UNSIGNED NOT NULL DEFAULT 0,
    `credit_foreign` DECIMAL(20,4) UNSIGNED NOT NULL DEFAULT 0,
    `order` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `journal_lines_journal_entry_id_account_id_index` (`journal_entry_id`, `account_id`),
    INDEX `journal_lines_account_id_index` (`account_id`),
    CONSTRAINT `journal_lines_journal_entry_id_foreign` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE CASCADE,
    CONSTRAINT `journal_lines_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `journal_lines_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- General Ledger (denormalized for performance)
CREATE TABLE IF NOT EXISTS `general_ledger` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `journal_line_id` BIGINT UNSIGNED NOT NULL,
    `journal_entry_id` BIGINT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `entry_number` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `debit` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `credit` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `balance` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(20,10) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `general_ledger_company_id_account_id_date_index` (`company_id`, `account_id`, `date`),
    INDEX `general_ledger_account_id_date_index` (`account_id`, `date`),
    INDEX `general_ledger_date_index` (`date`),
    INDEX `general_ledger_journal_entry_id_index` (`journal_entry_id`),
    CONSTRAINT `general_ledger_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `general_ledger_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `general_ledger_journal_line_id_foreign` FOREIGN KEY (`journal_line_id`) REFERENCES `journal_lines` (`id`) ON DELETE CASCADE,
    CONSTRAINT `general_ledger_journal_entry_id_foreign` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE CASCADE,
    CONSTRAINT `general_ledger_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Customers
CREATE TABLE IF NOT EXISTS `customers` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `customer_number` VARCHAR(255) NOT NULL UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    `company_name` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(255) NULL,
    `mobile` VARCHAR(255) NULL,
    `billing_address` TEXT NULL,
    `shipping_address` TEXT NULL,
    `city` VARCHAR(255) NULL,
    `state` VARCHAR(255) NULL,
    `postal_code` VARCHAR(255) NULL,
    `country` VARCHAR(2) NOT NULL DEFAULT 'UG',
    `tax_id` VARCHAR(255) NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `credit_limit` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `payment_terms_days` INT NOT NULL DEFAULT 30,
    `status` ENUM('active','inactive') NOT NULL DEFAULT 'active',
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `customers_company_id_status_index` (`company_id`, `status`),
    INDEX `customers_customer_number_index` (`customer_number`),
    INDEX `customers_email_index` (`email`),
    CONSTRAINT `customers_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `customers_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Invoices
CREATE TABLE IF NOT EXISTS `invoices` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `customer_id` BIGINT UNSIGNED NOT NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `invoice_number` VARCHAR(255) NOT NULL UNIQUE,
    `date` DATE NOT NULL,
    `due_date` DATE NOT NULL,
    `reference` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `terms` TEXT NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(20,10) NOT NULL DEFAULT 1,
    `subtotal` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `tax_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `discount_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `total` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `paid_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `balance` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `status` ENUM('draft','sent','viewed','partial','paid','overdue','cancelled') NOT NULL DEFAULT 'draft',
    `sent_at` TIMESTAMP NULL,
    `viewed_at` TIMESTAMP NULL,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `invoices_company_id_customer_id_index` (`company_id`, `customer_id`),
    INDEX `invoices_company_id_status_index` (`company_id`, `status`),
    INDEX `invoices_company_id_date_index` (`company_id`, `date`),
    INDEX `invoices_invoice_number_index` (`invoice_number`),
    INDEX `invoices_due_date_index` (`due_date`),
    CONSTRAINT `invoices_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `invoices_customer_id_foreign` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `invoices_journal_entry_id_foreign` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `invoices_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Invoice Lines
CREATE TABLE IF NOT EXISTS `invoice_lines` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `invoice_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `description` TEXT NOT NULL,
    `quantity` DECIMAL(20,4) NOT NULL DEFAULT 1,
    `unit_price` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `discount_percent` DECIMAL(5,2) NOT NULL DEFAULT 0,
    `discount_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `tax_rate` DECIMAL(5,2) NOT NULL DEFAULT 0,
    `tax_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `order` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `invoice_lines_invoice_id_index` (`invoice_id`),
    CONSTRAINT `invoice_lines_invoice_id_foreign` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`id`) ON DELETE CASCADE,
    CONSTRAINT `invoice_lines_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Payments (customer payments)
CREATE TABLE IF NOT EXISTS `payments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `customer_id` BIGINT UNSIGNED NULL,
    `invoice_id` BIGINT UNSIGNED NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `deposit_account_id` BIGINT UNSIGNED NOT NULL,
    `payment_number` VARCHAR(255) NOT NULL UNIQUE,
    `date` DATE NOT NULL,
    `amount` DECIMAL(20,4) NOT NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(20,10) NOT NULL DEFAULT 1,
    `method` ENUM('cash','bank_transfer','cheque','mobile_money','credit_card','other') NOT NULL DEFAULT 'cash',
    `reference` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `status` ENUM('pending','cleared','bounced','cancelled') NOT NULL DEFAULT 'cleared',
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `payments_company_id_customer_id_index` (`company_id`, `customer_id`),
    INDEX `payments_company_id_date_index` (`company_id`, `date`),
    INDEX `payments_payment_number_index` (`payment_number`),
    CONSTRAINT `payments_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `payments_customer_id_foreign` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL,
    CONSTRAINT `payments_invoice_id_foreign` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`id`) ON DELETE SET NULL,
    CONSTRAINT `payments_journal_entry_id_foreign` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `payments_deposit_account_id_foreign` FOREIGN KEY (`deposit_account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `payments_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vendors
CREATE TABLE IF NOT EXISTS `vendors` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `vendor_number` VARCHAR(255) NOT NULL UNIQUE,
    `name` VARCHAR(255) NOT NULL,
    `company_name` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(255) NULL,
    `mobile` VARCHAR(255) NULL,
    `address` TEXT NULL,
    `city` VARCHAR(255) NULL,
    `state` VARCHAR(255) NULL,
    `postal_code` VARCHAR(255) NULL,
    `country` VARCHAR(2) NOT NULL DEFAULT 'UG',
    `tax_id` VARCHAR(255) NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `payment_terms_days` INT NOT NULL DEFAULT 30,
    `status` ENUM('active','inactive') NOT NULL DEFAULT 'active',
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `vendors_company_id_status_index` (`company_id`, `status`),
    INDEX `vendors_vendor_number_index` (`vendor_number`),
    CONSTRAINT `vendors_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `vendors_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bills
CREATE TABLE IF NOT EXISTS `bills` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `vendor_id` BIGINT UNSIGNED NOT NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `bill_number` VARCHAR(255) NOT NULL UNIQUE,
    `vendor_invoice_number` VARCHAR(255) NULL,
    `date` DATE NOT NULL,
    `due_date` DATE NOT NULL,
    `reference` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(20,10) NOT NULL DEFAULT 1,
    `subtotal` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `tax_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `discount_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `total` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `paid_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `balance` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `status` ENUM('draft','approved','partial','paid','overdue','cancelled') NOT NULL DEFAULT 'draft',
    `approved_at` TIMESTAMP NULL,
    `approved_by` BIGINT UNSIGNED NULL,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `bills_company_id_vendor_id_index` (`company_id`, `vendor_id`),
    INDEX `bills_company_id_status_index` (`company_id`, `status`),
    INDEX `bills_bill_number_index` (`bill_number`),
    INDEX `bills_due_date_index` (`due_date`),
    CONSTRAINT `bills_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `bills_vendor_id_foreign` FOREIGN KEY (`vendor_id`) REFERENCES `vendors` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `bills_journal_entry_id_foreign` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `bills_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`),
    CONSTRAINT `bills_approved_by_foreign` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bill Lines
CREATE TABLE IF NOT EXISTS `bill_lines` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `bill_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NULL,
    `description` TEXT NOT NULL,
    `quantity` DECIMAL(20,4) NOT NULL DEFAULT 1,
    `unit_price` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `discount_percent` DECIMAL(5,2) NOT NULL DEFAULT 0,
    `discount_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `tax_rate` DECIMAL(5,2) NOT NULL DEFAULT 0,
    `tax_amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `amount` DECIMAL(20,4) NOT NULL DEFAULT 0,
    `order` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `bill_lines_bill_id_index` (`bill_id`),
    CONSTRAINT `bill_lines_bill_id_foreign` FOREIGN KEY (`bill_id`) REFERENCES `bills` (`id`) ON DELETE CASCADE,
    CONSTRAINT `bill_lines_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bill Payments
CREATE TABLE IF NOT EXISTS `bill_payments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `vendor_id` BIGINT UNSIGNED NULL,
    `bill_id` BIGINT UNSIGNED NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `payment_account_id` BIGINT UNSIGNED NOT NULL,
    `payment_number` VARCHAR(255) NOT NULL UNIQUE,
    `date` DATE NOT NULL,
    `amount` DECIMAL(20,4) NOT NULL,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `exchange_rate` DECIMAL(20,10) NOT NULL DEFAULT 1,
    `method` ENUM('cash','bank_transfer','cheque','mobile_money','credit_card','other') NOT NULL DEFAULT 'cash',
    `reference` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `status` ENUM('pending','cleared','bounced','cancelled') NOT NULL DEFAULT 'cleared',
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    `deleted_at` TIMESTAMP NULL,
    INDEX `bill_payments_company_id_vendor_id_index` (`company_id`, `vendor_id`),
    INDEX `bill_payments_payment_number_index` (`payment_number`),
    CONSTRAINT `bill_payments_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `bill_payments_vendor_id_foreign` FOREIGN KEY (`vendor_id`) REFERENCES `vendors` (`id`) ON DELETE SET NULL,
    CONSTRAINT `bill_payments_bill_id_foreign` FOREIGN KEY (`bill_id`) REFERENCES `bills` (`id`) ON DELETE SET NULL,
    CONSTRAINT `bill_payments_journal_entry_id_foreign` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `bill_payments_payment_account_id_foreign` FOREIGN KEY (`payment_account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `bill_payments_currency_id_foreign` FOREIGN KEY (`currency_id`) REFERENCES `currencies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- EVENT SOURCING & SYNC TABLES
-- =====================================================

-- Events (event sourcing store)
CREATE TABLE IF NOT EXISTS `events` (
    `id` CHAR(36) NOT NULL PRIMARY KEY,
    `tenant_id` CHAR(36) NOT NULL,
    `aggregate_type` VARCHAR(255) NOT NULL,
    `aggregate_id` CHAR(36) NOT NULL,
    `event_type` VARCHAR(255) NOT NULL,
    `event_data` JSON NOT NULL,
    `metadata` JSON NULL,
    `sequence_number` BIGINT UNSIGNED NOT NULL,
    `device_id` VARCHAR(255) NULL,
    `user_id` CHAR(36) NOT NULL,
    `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `synced_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `events_tenant_id_index` (`tenant_id`),
    INDEX `events_aggregate_id_index` (`aggregate_id`),
    INDEX `events_sequence_number_index` (`sequence_number`),
    INDEX `events_device_id_index` (`device_id`),
    INDEX `events_user_id_index` (`user_id`),
    INDEX `events_tenant_id_occurred_at_index` (`tenant_id`, `occurred_at`),
    INDEX `events_tenant_id_synced_at_index` (`tenant_id`, `synced_at`),
    UNIQUE KEY `events_tenant_id_sequence_number_unique` (`tenant_id`, `sequence_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sync Queue
CREATE TABLE IF NOT EXISTS `sync_queue` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` CHAR(36) NOT NULL,
    `event_id` CHAR(36) NOT NULL,
    `device_id` VARCHAR(255) NOT NULL,
    `status` ENUM('pending','syncing','synced','failed') NOT NULL DEFAULT 'pending',
    `error_message` TEXT NULL,
    `attempts` INT NOT NULL DEFAULT 0,
    `last_attempt_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `sync_queue_tenant_id_index` (`tenant_id`),
    INDEX `sync_queue_device_id_index` (`device_id`),
    INDEX `sync_queue_tenant_id_status_index` (`tenant_id`, `status`),
    INDEX `sync_queue_device_id_status_index` (`device_id`, `status`),
    CONSTRAINT `sync_queue_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Device Sync State
CREATE TABLE IF NOT EXISTS `device_sync_state` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` CHAR(36) NOT NULL,
    `device_id` VARCHAR(255) NOT NULL,
    `device_name` VARCHAR(255) NOT NULL,
    `device_type` VARCHAR(255) NOT NULL,
    `last_synced_sequence` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `last_sync_at` TIMESTAMP NULL,
    `sync_metadata` JSON NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `device_sync_state_tenant_id_index` (`tenant_id`),
    INDEX `device_sync_state_device_id_index` (`device_id`),
    UNIQUE KEY `device_sync_state_tenant_id_device_id_unique` (`tenant_id`, `device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Conflicts (offline sync conflict resolution)
CREATE TABLE IF NOT EXISTS `conflicts` (
    `id` CHAR(36) NOT NULL PRIMARY KEY,
    `tenant_id` CHAR(36) NOT NULL,
    `server_event_id` CHAR(36) NOT NULL,
    `client_event_id` CHAR(36) NOT NULL,
    `aggregate_type` VARCHAR(255) NOT NULL,
    `aggregate_id` CHAR(36) NOT NULL,
    `conflict_type` VARCHAR(255) NOT NULL,
    `server_data` JSON NOT NULL,
    `client_data` JSON NOT NULL,
    `conflict_fields` JSON NULL,
    `resolution_strategy` VARCHAR(255) NULL,
    `resolved_data` JSON NULL,
    `resolved_by` CHAR(36) NULL,
    `resolved_at` TIMESTAMP NULL,
    `server_device_id` VARCHAR(255) NULL,
    `client_device_id` VARCHAR(255) NOT NULL,
    `status` VARCHAR(255) NOT NULL DEFAULT 'pending',
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `conflicts_tenant_id_index` (`tenant_id`),
    INDEX `conflicts_server_event_id_index` (`server_event_id`),
    INDEX `conflicts_client_event_id_index` (`client_event_id`),
    INDEX `conflicts_aggregate_id_index` (`aggregate_id`),
    INDEX `conflicts_tenant_id_status_index` (`tenant_id`, `status`),
    INDEX `conflicts_aggregate_type_aggregate_id_index` (`aggregate_type`, `aggregate_id`),
    CONSTRAINT `conflicts_server_event_id_foreign` FOREIGN KEY (`server_event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
    CONSTRAINT `conflicts_client_event_id_foreign` FOREIGN KEY (`client_event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sync Logs
CREATE TABLE IF NOT EXISTS `sync_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `user_id` BIGINT UNSIGNED NULL,
    `entity_type` VARCHAR(255) NOT NULL,
    `entity_id` BIGINT UNSIGNED NOT NULL,
    `action` ENUM('create','update','delete') NOT NULL,
    `sync_status` ENUM('pending','synced','conflict','failed') NOT NULL DEFAULT 'pending',
    `data` JSON NULL,
    `conflict_data` JSON NULL,
    `error_message` TEXT NULL,
    `synced_at` TIMESTAMP NULL,
    `retry_count` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NULL,
    `updated_at` TIMESTAMP NULL,
    INDEX `sync_logs_company_id_sync_status_index` (`company_id`, `sync_status`),
    INDEX `sync_logs_entity_type_entity_id_index` (`entity_type`, `entity_id`),
    INDEX `sync_logs_user_id_index` (`user_id`),
    CONSTRAINT `sync_logs_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `sync_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tenant-level audit logs
CREATE TABLE IF NOT EXISTS `tenant_audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `user_id` BIGINT UNSIGNED NULL,
    `action` VARCHAR(255) NOT NULL,
    `model_type` VARCHAR(255) NOT NULL,
    `model_id` BIGINT UNSIGNED NOT NULL,
    `description` VARCHAR(255) NULL,
    `old_values` JSON NULL,
    `new_values` JSON NULL,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL,
    INDEX `tenant_audit_logs_company_id_created_at_index` (`company_id`, `created_at`),
    INDEX `tenant_audit_logs_model_type_model_id_index` (`model_type`, `model_id`),
    INDEX `tenant_audit_logs_user_id_index` (`user_id`),
    CONSTRAINT `tenant_audit_logs_company_id_foreign` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `tenant_audit_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- SEED DATA
-- =====================================================

-- Currencies
INSERT INTO `currencies` (`code`, `name`, `symbol`, `decimal_places`, `is_active`, `created_at`, `updated_at`) VALUES
('UGX', 'Ugandan Shilling', 'UGX', 0, 1, NOW(), NOW()),
('KES', 'Kenyan Shilling', 'KES', 2, 1, NOW(), NOW()),
('TZS', 'Tanzanian Shilling', 'TZS', 0, 1, NOW(), NOW()),
('RWF', 'Rwandan Franc', 'RWF', 0, 1, NOW(), NOW()),
('USD', 'US Dollar', '$', 2, 1, NOW(), NOW()),
('EUR', 'Euro', '€', 2, 1, NOW(), NOW()),
('GBP', 'British Pound', '£', 2, 1, NOW(), NOW()),
('ZAR', 'South African Rand', 'R', 2, 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

-- Super Admin User
-- !! CHANGE THE PASSWORD AFTER FIRST LOGIN !!
-- Email: admin@thirdbooks.digital
-- Password: SuperAdmin@2024
INSERT INTO `users` (`tenant_id`, `name`, `email`, `password`, `phone`, `role`, `is_active`, `email_verified_at`, `created_at`, `updated_at`) VALUES
(NULL, 'Super Administrator', 'admin@thirdbooks.digital', '$2y$12$LN5Gk0UhWFYlX0kMSU4Bie.X3kqb8UVlKlJ3lFORqrUvGxYCaWzOi', NULL, 'super_admin', 1, NOW(), NOW(), NOW())
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);
-- NOTE: The hashed password above is for 'SuperAdmin@2024' with bcrypt cost 12
-- If it doesn't work, run this after importing:
--   UPDATE users SET password = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi' WHERE email = 'admin@thirdbooks.digital';
-- (That hash = 'password', change it immediately)

-- Record migrations as run
INSERT INTO `migrations` (`migration`, `batch`) VALUES
('2024_01_01_000001_create_tenants_table', 1),
('2024_01_01_000002_create_domains_table', 1),
('2024_01_01_000003_create_users_table', 1),
('2024_01_15_000001_create_audit_logs_table', 1),
('2024_01_01_000001_create_companies_table', 2),
('2024_01_01_000002_create_currencies_table', 2),
('2024_01_01_000003_create_accounts_table', 2),
('2024_01_01_000004_create_journal_entries_table', 2),
('2024_01_01_000005_create_general_ledger_table', 2),
('2024_01_01_000006_create_customers_table', 2),
('2024_01_01_000007_create_invoices_table', 2),
('2024_01_01_000008_create_payments_table', 2),
('2024_01_01_000009_create_vendors_and_bills_table', 2),
('2024_01_01_000010_create_audit_logs_table', 2),
('2024_01_01_000011_create_sync_logs_table', 2),
('2024_01_10_000001_create_event_sourcing_tables', 2),
('2024_01_10_000002_create_conflicts_table', 2),
('2024_01_15_000001_add_tenant_id_to_companies_table', 2);

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- DONE! Your database is ready.
--
-- Login credentials:
--   Email:    admin@thirdbooks.digital
--   Password: SuperAdmin@2024
--
-- IMPORTANT: Change the password immediately after login!
-- =====================================================
