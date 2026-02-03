-- =====================================================
-- THIRDBOOKS DATABASE SCHEMA
-- Version: 1.0.0
-- Generated for: MySQL 8.0+ / MariaDB 10.4+
-- =====================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

-- =====================================================
-- CENTRAL DATABASE TABLES
-- These tables manage tenants and central authentication
-- =====================================================

-- -----------------------------------------------------
-- Table: tenants
-- Stores all tenant (organization) information
-- -----------------------------------------------------
DROP TABLE IF EXISTS `tenants`;
CREATE TABLE `tenants` (
    `id` CHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `company_name` VARCHAR(255) NULL,
    `email` VARCHAR(255) NOT NULL,
    `phone` VARCHAR(50) NULL,
    `address` TEXT NULL,
    `country` VARCHAR(100) DEFAULT 'Uganda',
    `base_currency` VARCHAR(3) DEFAULT 'UGX',
    `fiscal_year_start` TINYINT UNSIGNED DEFAULT 1 COMMENT 'Month 1-12',
    `plan` ENUM('free', 'starter', 'professional', 'enterprise') DEFAULT 'free',
    `trial_ends_at` TIMESTAMP NULL,
    `subscription_ends_at` TIMESTAMP NULL,
    `status` ENUM('active', 'suspended', 'cancelled', 'pending') DEFAULT 'active',
    `settings` JSON NULL,
    `data` JSON NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_tenants_email` (`email`),
    INDEX `idx_tenants_status` (`status`),
    INDEX `idx_tenants_plan` (`plan`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: domains
-- Custom domains for each tenant
-- -----------------------------------------------------
DROP TABLE IF EXISTS `domains`;
CREATE TABLE `domains` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tenant_id` CHAR(36) NOT NULL,
    `domain` VARCHAR(255) NOT NULL,
    `is_primary` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_domains_domain` (`domain`),
    INDEX `idx_domains_tenant_primary` (`tenant_id`, `is_primary`),
    CONSTRAINT `fk_domains_tenant` FOREIGN KEY (`tenant_id`)
        REFERENCES `tenants` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: users
-- Central user authentication and profiles
-- -----------------------------------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tenant_id` CHAR(36) NULL COMMENT 'NULL for super admins',
    `name` VARCHAR(255) NOT NULL,
    `email` VARCHAR(255) NOT NULL,
    `password` VARCHAR(255) NOT NULL,
    `phone` VARCHAR(50) NULL,
    `role` ENUM('super_admin', 'admin', 'accountant', 'manager', 'user', 'viewer') DEFAULT 'user',
    `is_active` TINYINT(1) DEFAULT 1,
    `email_verified_at` TIMESTAMP NULL,
    `remember_token` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_users_tenant_email` (`tenant_id`, `email`),
    INDEX `idx_users_email` (`email`),
    INDEX `idx_users_role` (`tenant_id`, `role`),
    CONSTRAINT `fk_users_tenant` FOREIGN KEY (`tenant_id`)
        REFERENCES `tenants` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: password_reset_tokens
-- -----------------------------------------------------
DROP TABLE IF EXISTS `password_reset_tokens`;
CREATE TABLE `password_reset_tokens` (
    `email` VARCHAR(255) NOT NULL,
    `token` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: personal_access_tokens (Laravel Sanctum)
-- -----------------------------------------------------
DROP TABLE IF EXISTS `personal_access_tokens`;
CREATE TABLE `personal_access_tokens` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tokenable_type` VARCHAR(255) NOT NULL,
    `tokenable_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `token` VARCHAR(64) NOT NULL,
    `abilities` TEXT NULL,
    `last_used_at` TIMESTAMP NULL,
    `expires_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_personal_access_tokens_token` (`token`),
    INDEX `idx_personal_access_tokens_tokenable` (`tokenable_type`, `tokenable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: sessions
-- -----------------------------------------------------
DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
    `id` VARCHAR(255) NOT NULL,
    `user_id` BIGINT UNSIGNED NULL,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` TEXT NULL,
    `payload` LONGTEXT NOT NULL,
    `last_activity` INT NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_sessions_user` (`user_id`),
    INDEX `idx_sessions_last_activity` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: failed_jobs
-- -----------------------------------------------------
DROP TABLE IF EXISTS `failed_jobs`;
CREATE TABLE `failed_jobs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `uuid` VARCHAR(255) NOT NULL,
    `connection` TEXT NOT NULL,
    `queue` TEXT NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `exception` LONGTEXT NOT NULL,
    `failed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_failed_jobs_uuid` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: jobs
-- -----------------------------------------------------
DROP TABLE IF EXISTS `jobs`;
CREATE TABLE `jobs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `queue` VARCHAR(255) NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `attempts` TINYINT UNSIGNED NOT NULL,
    `reserved_at` INT UNSIGNED NULL,
    `available_at` INT UNSIGNED NOT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_jobs_queue` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: cache
-- -----------------------------------------------------
DROP TABLE IF EXISTS `cache`;
CREATE TABLE `cache` (
    `key` VARCHAR(255) NOT NULL,
    `value` MEDIUMTEXT NOT NULL,
    `expiration` INT NOT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `cache_locks`;
CREATE TABLE `cache_locks` (
    `key` VARCHAR(255) NOT NULL,
    `owner` VARCHAR(255) NOT NULL,
    `expiration` INT NOT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TENANT DATABASE TABLES
-- These tables are created for each tenant
-- For single-tenant mode, they exist in the same database
-- =====================================================

-- -----------------------------------------------------
-- Table: companies
-- Business entities within a tenant
-- -----------------------------------------------------
DROP TABLE IF EXISTS `companies`;
CREATE TABLE `companies` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `legal_name` VARCHAR(255) NULL,
    `tax_id` VARCHAR(50) NULL COMMENT 'TIN for Uganda',
    `registration_number` VARCHAR(100) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(50) NULL,
    `address` TEXT NULL,
    `city` VARCHAR(100) NULL,
    `state` VARCHAR(100) NULL,
    `postal_code` VARCHAR(20) NULL,
    `country` VARCHAR(100) DEFAULT 'Uganda',
    `base_currency` VARCHAR(3) DEFAULT 'UGX',
    `fiscal_year_start` DATE NULL,
    `fiscal_year_end` DATE NULL,
    `logo_url` VARCHAR(500) NULL,
    `settings` JSON NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: currencies
-- Supported currencies
-- -----------------------------------------------------
DROP TABLE IF EXISTS `currencies`;
CREATE TABLE `currencies` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(3) NOT NULL COMMENT 'ISO 4217',
    `name` VARCHAR(100) NOT NULL,
    `symbol` VARCHAR(10) NOT NULL,
    `decimal_places` TINYINT UNSIGNED DEFAULT 2,
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_currencies_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: exchange_rates
-- Historical exchange rates
-- -----------------------------------------------------
DROP TABLE IF EXISTS `exchange_rates`;
CREATE TABLE `exchange_rates` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `currency_id` BIGINT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `rate` DECIMAL(20,10) NOT NULL COMMENT 'Rate against base currency',
    `source` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_exchange_rates_currency_date` (`currency_id`, `date`),
    CONSTRAINT `fk_exchange_rates_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: accounts
-- Chart of Accounts (Hierarchical)
-- -----------------------------------------------------
DROP TABLE IF EXISTS `accounts`;
CREATE TABLE `accounts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `parent_id` BIGINT UNSIGNED NULL COMMENT 'For sub-accounts',
    `code` VARCHAR(20) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `type` ENUM('asset', 'liability', 'equity', 'income', 'expense') NOT NULL,
    `subtype` VARCHAR(100) NULL,
    `category` ENUM(
        'bank', 'cash', 'accounts_receivable', 'inventory', 'fixed_asset',
        'accounts_payable', 'credit_card', 'long_term_liability',
        'equity', 'income', 'cost_of_goods_sold', 'expense',
        'other_income', 'other_expense'
    ) NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `opening_balance` DECIMAL(18,4) DEFAULT 0,
    `current_balance` DECIMAL(18,4) DEFAULT 0,
    `is_active` TINYINT(1) DEFAULT 1,
    `is_system` TINYINT(1) DEFAULT 0 COMMENT 'System accounts cannot be deleted',
    `order` INT DEFAULT 0,
    `settings` JSON NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_accounts_code` (`code`),
    INDEX `idx_accounts_company_type` (`company_id`, `type`),
    INDEX `idx_accounts_company_category` (`company_id`, `category`),
    INDEX `idx_accounts_active` (`is_active`),
    CONSTRAINT `fk_accounts_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_accounts_parent` FOREIGN KEY (`parent_id`)
        REFERENCES `accounts` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_accounts_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: journal_entries
-- Double-entry bookkeeping core
-- -----------------------------------------------------
DROP TABLE IF EXISTS `journal_entries`;
CREATE TABLE `journal_entries` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `entry_number` VARCHAR(50) NOT NULL,
    `date` DATE NOT NULL,
    `reference` VARCHAR(100) NULL,
    `description` TEXT NULL,
    `status` ENUM('draft', 'posted') DEFAULT 'draft',
    `type` ENUM('manual', 'automatic') DEFAULT 'manual',
    `source` VARCHAR(50) NULL COMMENT 'e.g., invoice, bill, payment',
    `source_id` BIGINT UNSIGNED NULL,
    `created_by` BIGINT UNSIGNED NULL,
    `posted_by` BIGINT UNSIGNED NULL,
    `posted_at` TIMESTAMP NULL,
    `is_locked` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_journal_entries_number` (`entry_number`),
    INDEX `idx_journal_entries_company_date` (`company_id`, `date`),
    INDEX `idx_journal_entries_company_status` (`company_id`, `status`),
    INDEX `idx_journal_entries_source` (`source`, `source_id`),
    CONSTRAINT `fk_journal_entries_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_journal_entries_created_by` FOREIGN KEY (`created_by`)
        REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_journal_entries_posted_by` FOREIGN KEY (`posted_by`)
        REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: journal_lines
-- Individual debit/credit lines for journal entries
-- -----------------------------------------------------
DROP TABLE IF EXISTS `journal_lines`;
CREATE TABLE `journal_lines` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `journal_entry_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `description` VARCHAR(500) NULL,
    `debit` DECIMAL(18,4) DEFAULT 0,
    `credit` DECIMAL(18,4) DEFAULT 0,
    `currency_id` BIGINT UNSIGNED NULL,
    `exchange_rate` DECIMAL(20,10) DEFAULT 1,
    `debit_foreign` DECIMAL(18,4) DEFAULT 0,
    `credit_foreign` DECIMAL(18,4) DEFAULT 0,
    `order` INT DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_journal_lines_entry_account` (`journal_entry_id`, `account_id`),
    INDEX `idx_journal_lines_account` (`account_id`),
    CONSTRAINT `fk_journal_lines_entry` FOREIGN KEY (`journal_entry_id`)
        REFERENCES `journal_entries` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_journal_lines_account` FOREIGN KEY (`account_id`)
        REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_journal_lines_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: general_ledger
-- Denormalized ledger for performance
-- -----------------------------------------------------
DROP TABLE IF EXISTS `general_ledger`;
CREATE TABLE `general_ledger` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NOT NULL,
    `journal_line_id` BIGINT UNSIGNED NOT NULL,
    `journal_entry_id` BIGINT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `entry_number` VARCHAR(50) NOT NULL,
    `description` TEXT NULL,
    `debit` DECIMAL(18,4) DEFAULT 0,
    `credit` DECIMAL(18,4) DEFAULT 0,
    `balance` DECIMAL(18,4) DEFAULT 0 COMMENT 'Running balance',
    `currency_id` BIGINT UNSIGNED NULL,
    `exchange_rate` DECIMAL(20,10) DEFAULT 1,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_general_ledger_company_account_date` (`company_id`, `account_id`, `date`),
    INDEX `idx_general_ledger_account_date` (`account_id`, `date`),
    INDEX `idx_general_ledger_date` (`date`),
    INDEX `idx_general_ledger_entry` (`journal_entry_id`),
    CONSTRAINT `fk_general_ledger_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_general_ledger_account` FOREIGN KEY (`account_id`)
        REFERENCES `accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_general_ledger_line` FOREIGN KEY (`journal_line_id`)
        REFERENCES `journal_lines` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_general_ledger_entry` FOREIGN KEY (`journal_entry_id`)
        REFERENCES `journal_entries` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_general_ledger_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: customers
-- Customer/client records
-- -----------------------------------------------------
DROP TABLE IF EXISTS `customers`;
CREATE TABLE `customers` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `customer_number` VARCHAR(50) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `company_name` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(50) NULL,
    `mobile` VARCHAR(50) NULL,
    `billing_address` TEXT NULL,
    `shipping_address` TEXT NULL,
    `city` VARCHAR(100) NULL,
    `state` VARCHAR(100) NULL,
    `postal_code` VARCHAR(20) NULL,
    `country` VARCHAR(100) DEFAULT 'Uganda',
    `tax_id` VARCHAR(50) NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `credit_limit` DECIMAL(18,4) DEFAULT 0,
    `payment_terms_days` INT DEFAULT 30,
    `status` ENUM('active', 'inactive') DEFAULT 'active',
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_customers_number` (`customer_number`),
    INDEX `idx_customers_company_status` (`company_id`, `status`),
    INDEX `idx_customers_email` (`email`),
    CONSTRAINT `fk_customers_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_customers_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: invoices
-- Sales invoices
-- -----------------------------------------------------
DROP TABLE IF EXISTS `invoices`;
CREATE TABLE `invoices` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `customer_id` BIGINT UNSIGNED NOT NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `invoice_number` VARCHAR(50) NOT NULL,
    `date` DATE NOT NULL,
    `due_date` DATE NOT NULL,
    `reference` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `terms` TEXT NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `exchange_rate` DECIMAL(20,10) DEFAULT 1,
    `subtotal` DECIMAL(18,4) DEFAULT 0,
    `tax_amount` DECIMAL(18,4) DEFAULT 0,
    `discount_amount` DECIMAL(18,4) DEFAULT 0,
    `total` DECIMAL(18,4) DEFAULT 0,
    `paid_amount` DECIMAL(18,4) DEFAULT 0,
    `balance` DECIMAL(18,4) DEFAULT 0,
    `status` ENUM('draft', 'sent', 'viewed', 'partial', 'paid', 'overdue', 'cancelled') DEFAULT 'draft',
    `sent_at` TIMESTAMP NULL,
    `viewed_at` TIMESTAMP NULL,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_invoices_number` (`invoice_number`),
    INDEX `idx_invoices_company_customer` (`company_id`, `customer_id`),
    INDEX `idx_invoices_company_status` (`company_id`, `status`),
    INDEX `idx_invoices_company_date` (`company_id`, `date`),
    INDEX `idx_invoices_due_date` (`due_date`),
    CONSTRAINT `fk_invoices_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invoices_customer` FOREIGN KEY (`customer_id`)
        REFERENCES `customers` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_invoices_journal_entry` FOREIGN KEY (`journal_entry_id`)
        REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_invoices_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: invoice_lines
-- Line items for invoices
-- -----------------------------------------------------
DROP TABLE IF EXISTS `invoice_lines`;
CREATE TABLE `invoice_lines` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `invoice_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NULL COMMENT 'Income account',
    `description` TEXT NOT NULL,
    `quantity` DECIMAL(18,4) DEFAULT 1,
    `unit_price` DECIMAL(18,4) DEFAULT 0,
    `discount_percent` DECIMAL(5,2) DEFAULT 0,
    `discount_amount` DECIMAL(18,4) DEFAULT 0,
    `tax_rate` DECIMAL(5,2) DEFAULT 0,
    `tax_amount` DECIMAL(18,4) DEFAULT 0,
    `amount` DECIMAL(18,4) DEFAULT 0,
    `order` INT DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_invoice_lines_invoice` (`invoice_id`),
    CONSTRAINT `fk_invoice_lines_invoice` FOREIGN KEY (`invoice_id`)
        REFERENCES `invoices` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invoice_lines_account` FOREIGN KEY (`account_id`)
        REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: payments
-- Customer payments received
-- -----------------------------------------------------
DROP TABLE IF EXISTS `payments`;
CREATE TABLE `payments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `customer_id` BIGINT UNSIGNED NULL,
    `invoice_id` BIGINT UNSIGNED NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `deposit_account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Bank/cash account',
    `payment_number` VARCHAR(50) NOT NULL,
    `date` DATE NOT NULL,
    `amount` DECIMAL(18,4) NOT NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `exchange_rate` DECIMAL(20,10) DEFAULT 1,
    `method` ENUM('cash', 'bank_transfer', 'cheque', 'mobile_money', 'credit_card', 'other') DEFAULT 'bank_transfer',
    `reference` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `status` ENUM('pending', 'cleared', 'bounced', 'cancelled') DEFAULT 'cleared',
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_payments_number` (`payment_number`),
    INDEX `idx_payments_company_customer` (`company_id`, `customer_id`),
    INDEX `idx_payments_company_date` (`company_id`, `date`),
    CONSTRAINT `fk_payments_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_payments_customer` FOREIGN KEY (`customer_id`)
        REFERENCES `customers` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_payments_invoice` FOREIGN KEY (`invoice_id`)
        REFERENCES `invoices` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_payments_journal_entry` FOREIGN KEY (`journal_entry_id`)
        REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_payments_deposit_account` FOREIGN KEY (`deposit_account_id`)
        REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_payments_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: vendors
-- Supplier/vendor records
-- -----------------------------------------------------
DROP TABLE IF EXISTS `vendors`;
CREATE TABLE `vendors` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `vendor_number` VARCHAR(50) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `company_name` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    `phone` VARCHAR(50) NULL,
    `mobile` VARCHAR(50) NULL,
    `address` TEXT NULL,
    `city` VARCHAR(100) NULL,
    `state` VARCHAR(100) NULL,
    `postal_code` VARCHAR(20) NULL,
    `country` VARCHAR(100) DEFAULT 'Uganda',
    `tax_id` VARCHAR(50) NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `payment_terms_days` INT DEFAULT 30,
    `status` ENUM('active', 'inactive') DEFAULT 'active',
    `notes` TEXT NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_vendors_number` (`vendor_number`),
    INDEX `idx_vendors_company_status` (`company_id`, `status`),
    INDEX `idx_vendors_email` (`email`),
    CONSTRAINT `fk_vendors_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_vendors_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: bills
-- Purchase bills from vendors
-- -----------------------------------------------------
DROP TABLE IF EXISTS `bills`;
CREATE TABLE `bills` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `vendor_id` BIGINT UNSIGNED NOT NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `bill_number` VARCHAR(50) NOT NULL,
    `vendor_invoice_number` VARCHAR(100) NULL,
    `date` DATE NOT NULL,
    `due_date` DATE NOT NULL,
    `reference` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `exchange_rate` DECIMAL(20,10) DEFAULT 1,
    `subtotal` DECIMAL(18,4) DEFAULT 0,
    `tax_amount` DECIMAL(18,4) DEFAULT 0,
    `discount_amount` DECIMAL(18,4) DEFAULT 0,
    `total` DECIMAL(18,4) DEFAULT 0,
    `paid_amount` DECIMAL(18,4) DEFAULT 0,
    `balance` DECIMAL(18,4) DEFAULT 0,
    `status` ENUM('draft', 'approved', 'partial', 'paid', 'overdue', 'cancelled') DEFAULT 'draft',
    `approved_at` TIMESTAMP NULL,
    `approved_by` BIGINT UNSIGNED NULL,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bills_number` (`bill_number`),
    INDEX `idx_bills_company_vendor` (`company_id`, `vendor_id`),
    INDEX `idx_bills_company_status` (`company_id`, `status`),
    INDEX `idx_bills_company_date` (`company_id`, `date`),
    INDEX `idx_bills_due_date` (`due_date`),
    CONSTRAINT `fk_bills_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_bills_vendor` FOREIGN KEY (`vendor_id`)
        REFERENCES `vendors` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_bills_journal_entry` FOREIGN KEY (`journal_entry_id`)
        REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bills_approved_by` FOREIGN KEY (`approved_by`)
        REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bills_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: bill_lines
-- Line items for bills
-- -----------------------------------------------------
DROP TABLE IF EXISTS `bill_lines`;
CREATE TABLE `bill_lines` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `bill_id` BIGINT UNSIGNED NOT NULL,
    `account_id` BIGINT UNSIGNED NULL COMMENT 'Expense account',
    `description` TEXT NOT NULL,
    `quantity` DECIMAL(18,4) DEFAULT 1,
    `unit_price` DECIMAL(18,4) DEFAULT 0,
    `discount_percent` DECIMAL(5,2) DEFAULT 0,
    `discount_amount` DECIMAL(18,4) DEFAULT 0,
    `tax_rate` DECIMAL(5,2) DEFAULT 0,
    `tax_amount` DECIMAL(18,4) DEFAULT 0,
    `amount` DECIMAL(18,4) DEFAULT 0,
    `order` INT DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_bill_lines_bill` (`bill_id`),
    CONSTRAINT `fk_bill_lines_bill` FOREIGN KEY (`bill_id`)
        REFERENCES `bills` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_bill_lines_account` FOREIGN KEY (`account_id`)
        REFERENCES `accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: bill_payments
-- Payments made to vendors
-- -----------------------------------------------------
DROP TABLE IF EXISTS `bill_payments`;
CREATE TABLE `bill_payments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NOT NULL,
    `vendor_id` BIGINT UNSIGNED NULL,
    `bill_id` BIGINT UNSIGNED NULL,
    `journal_entry_id` BIGINT UNSIGNED NULL,
    `payment_account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Bank/cash account',
    `payment_number` VARCHAR(50) NOT NULL,
    `date` DATE NOT NULL,
    `amount` DECIMAL(18,4) NOT NULL,
    `currency_id` BIGINT UNSIGNED NULL,
    `exchange_rate` DECIMAL(20,10) DEFAULT 1,
    `method` ENUM('cash', 'bank_transfer', 'cheque', 'mobile_money', 'credit_card', 'other') DEFAULT 'bank_transfer',
    `reference` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `status` ENUM('pending', 'cleared', 'bounced', 'cancelled') DEFAULT 'cleared',
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_bill_payments_number` (`payment_number`),
    INDEX `idx_bill_payments_company_vendor` (`company_id`, `vendor_id`),
    INDEX `idx_bill_payments_company_date` (`company_id`, `date`),
    CONSTRAINT `fk_bill_payments_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_bill_payments_vendor` FOREIGN KEY (`vendor_id`)
        REFERENCES `vendors` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bill_payments_bill` FOREIGN KEY (`bill_id`)
        REFERENCES `bills` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bill_payments_journal_entry` FOREIGN KEY (`journal_entry_id`)
        REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bill_payments_payment_account` FOREIGN KEY (`payment_account_id`)
        REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_bill_payments_currency` FOREIGN KEY (`currency_id`)
        REFERENCES `currencies` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: audit_logs
-- Comprehensive audit trail
-- -----------------------------------------------------
DROP TABLE IF EXISTS `audit_logs`;
CREATE TABLE `audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NULL,
    `user_id` BIGINT UNSIGNED NULL,
    `action` VARCHAR(50) NOT NULL COMMENT 'create, update, delete, login, etc.',
    `model_type` VARCHAR(255) NULL,
    `model_id` BIGINT UNSIGNED NULL,
    `description` TEXT NULL,
    `old_values` JSON NULL,
    `new_values` JSON NULL,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_audit_logs_company_date` (`company_id`, `created_at`),
    INDEX `idx_audit_logs_model` (`model_type`, `model_id`),
    INDEX `idx_audit_logs_user` (`user_id`),
    CONSTRAINT `fk_audit_logs_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_audit_logs_user` FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: sync_logs
-- Sync status tracking for offline support
-- -----------------------------------------------------
DROP TABLE IF EXISTS `sync_logs`;
CREATE TABLE `sync_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` BIGINT UNSIGNED NULL,
    `user_id` BIGINT UNSIGNED NULL,
    `entity_type` VARCHAR(100) NOT NULL,
    `entity_id` BIGINT UNSIGNED NOT NULL,
    `action` ENUM('create', 'update', 'delete') NOT NULL,
    `sync_status` ENUM('pending', 'synced', 'conflict', 'failed') DEFAULT 'pending',
    `data` JSON NULL,
    `conflict_data` JSON NULL,
    `error_message` TEXT NULL,
    `synced_at` TIMESTAMP NULL,
    `retry_count` INT DEFAULT 0,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_sync_logs_company_status` (`company_id`, `sync_status`),
    INDEX `idx_sync_logs_entity` (`entity_type`, `entity_id`),
    INDEX `idx_sync_logs_user` (`user_id`),
    CONSTRAINT `fk_sync_logs_company` FOREIGN KEY (`company_id`)
        REFERENCES `companies` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sync_logs_user` FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: events
-- Event store for event sourcing
-- -----------------------------------------------------
DROP TABLE IF EXISTS `events`;
CREATE TABLE `events` (
    `id` CHAR(36) NOT NULL,
    `tenant_id` CHAR(36) NOT NULL,
    `aggregate_type` VARCHAR(100) NOT NULL,
    `aggregate_id` CHAR(36) NOT NULL,
    `event_type` VARCHAR(100) NOT NULL,
    `event_data` JSON NOT NULL,
    `metadata` JSON NULL,
    `sequence_number` BIGINT UNSIGNED NOT NULL,
    `device_id` VARCHAR(100) NULL,
    `user_id` CHAR(36) NULL,
    `occurred_at` TIMESTAMP NOT NULL,
    `synced_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_events_tenant_sequence` (`tenant_id`, `sequence_number`),
    INDEX `idx_events_aggregate` (`aggregate_type`, `aggregate_id`),
    INDEX `idx_events_device` (`device_id`, `synced_at`),
    CONSTRAINT `fk_events_tenant` FOREIGN KEY (`tenant_id`)
        REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: sync_queue
-- Queue for pending sync operations
-- -----------------------------------------------------
DROP TABLE IF EXISTS `sync_queue`;
CREATE TABLE `sync_queue` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tenant_id` CHAR(36) NOT NULL,
    `event_id` CHAR(36) NOT NULL,
    `device_id` VARCHAR(100) NOT NULL,
    `status` ENUM('pending', 'syncing', 'synced', 'failed') DEFAULT 'pending',
    `error_message` TEXT NULL,
    `attempts` INT DEFAULT 0,
    `last_attempt_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_sync_queue_tenant_status` (`tenant_id`, `status`),
    INDEX `idx_sync_queue_device` (`device_id`, `status`),
    CONSTRAINT `fk_sync_queue_tenant` FOREIGN KEY (`tenant_id`)
        REFERENCES `tenants` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sync_queue_event` FOREIGN KEY (`event_id`)
        REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: device_sync_state
-- Track sync state per device
-- -----------------------------------------------------
DROP TABLE IF EXISTS `device_sync_state`;
CREATE TABLE `device_sync_state` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tenant_id` CHAR(36) NOT NULL,
    `device_id` VARCHAR(100) NOT NULL,
    `device_name` VARCHAR(255) NULL,
    `device_type` ENUM('mobile', 'web', 'desktop') DEFAULT 'desktop',
    `last_synced_sequence` BIGINT UNSIGNED DEFAULT 0,
    `last_sync_at` TIMESTAMP NULL,
    `sync_metadata` JSON NULL,
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_device_sync_state_tenant_device` (`tenant_id`, `device_id`),
    CONSTRAINT `fk_device_sync_state_tenant` FOREIGN KEY (`tenant_id`)
        REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: conflicts
-- Conflict detection and resolution
-- -----------------------------------------------------
DROP TABLE IF EXISTS `conflicts`;
CREATE TABLE `conflicts` (
    `id` CHAR(36) NOT NULL,
    `tenant_id` CHAR(36) NOT NULL,
    `server_event_id` CHAR(36) NULL,
    `client_event_id` CHAR(36) NULL,
    `aggregate_type` VARCHAR(100) NOT NULL,
    `aggregate_id` CHAR(36) NOT NULL,
    `conflict_type` VARCHAR(50) NOT NULL,
    `server_data` JSON NULL,
    `client_data` JSON NULL,
    `conflict_fields` JSON NULL,
    `resolution_strategy` VARCHAR(50) NULL,
    `resolved_data` JSON NULL,
    `resolved_by` CHAR(36) NULL,
    `resolved_at` TIMESTAMP NULL,
    `server_device_id` VARCHAR(100) NULL,
    `client_device_id` VARCHAR(100) NULL,
    `status` VARCHAR(20) DEFAULT 'pending',
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_conflicts_tenant_status` (`tenant_id`, `status`),
    INDEX `idx_conflicts_aggregate` (`aggregate_type`, `aggregate_id`),
    CONSTRAINT `fk_conflicts_tenant` FOREIGN KEY (`tenant_id`)
        REFERENCES `tenants` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_conflicts_server_event` FOREIGN KEY (`server_event_id`)
        REFERENCES `events` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_conflicts_client_event` FOREIGN KEY (`client_event_id`)
        REFERENCES `events` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- SEED DATA
-- =====================================================

-- -----------------------------------------------------
-- Insert default currencies
-- -----------------------------------------------------
INSERT INTO `currencies` (`code`, `name`, `symbol`, `decimal_places`, `is_active`) VALUES
('UGX', 'Ugandan Shilling', 'UGX', 0, 1),
('USD', 'US Dollar', '$', 2, 1),
('EUR', 'Euro', '€', 2, 1),
('GBP', 'British Pound', '£', 2, 1),
('KES', 'Kenyan Shilling', 'KES', 2, 1),
('TZS', 'Tanzanian Shilling', 'TZS', 0, 1),
('RWF', 'Rwandan Franc', 'RWF', 0, 1);

-- -----------------------------------------------------
-- Insert super admin user (password: Admin@123)
-- Password hash for 'Admin@123' using bcrypt
-- -----------------------------------------------------
INSERT INTO `users` (`id`, `tenant_id`, `name`, `email`, `password`, `role`, `is_active`, `email_verified_at`, `created_at`) VALUES
(1, NULL, 'System Administrator', 'admin@thirdbooks.digital', '$2y$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4OVmwuRTXveaIpi2', 'super_admin', 1, NOW(), NOW());

-- -----------------------------------------------------
-- Insert demo tenant
-- -----------------------------------------------------
INSERT INTO `tenants` (`id`, `name`, `company_name`, `email`, `phone`, `country`, `base_currency`, `plan`, `status`, `created_at`) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'Demo Company', 'Demo Company Ltd', 'demo@thirdbooks.digital', '+256 700 123456', 'Uganda', 'UGX', 'professional', 'active', NOW());

-- -----------------------------------------------------
-- Insert demo tenant domain
-- -----------------------------------------------------
INSERT INTO `domains` (`tenant_id`, `domain`, `is_primary`, `created_at`) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'demo.thirdbooks.digital', 1, NOW());

-- -----------------------------------------------------
-- Insert demo tenant user (password: Demo@123)
-- -----------------------------------------------------
INSERT INTO `users` (`id`, `tenant_id`, `name`, `email`, `password`, `role`, `is_active`, `email_verified_at`, `created_at`) VALUES
(2, '550e8400-e29b-41d4-a716-446655440000', 'Demo User', 'demo@thirdbooks.digital', '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 1, NOW(), NOW());

-- -----------------------------------------------------
-- Insert demo company
-- -----------------------------------------------------
INSERT INTO `companies` (`id`, `name`, `legal_name`, `tax_id`, `email`, `phone`, `address`, `city`, `country`, `base_currency`, `fiscal_year_start`, `fiscal_year_end`, `created_at`) VALUES
(1, 'Demo Company', 'Demo Company Limited', 'TIN123456789', 'info@democompany.ug', '+256 414 123456', 'Plot 1, Demo Street', 'Kampala', 'Uganda', 'UGX', '2024-01-01', '2024-12-31', NOW());

-- -----------------------------------------------------
-- Insert Chart of Accounts (Standard Uganda)
-- -----------------------------------------------------
INSERT INTO `accounts` (`company_id`, `code`, `name`, `type`, `subtype`, `category`, `is_active`, `is_system`, `order`) VALUES
-- Assets (1000-1999)
(1, '1000', 'Assets', 'asset', 'Current Assets', NULL, 1, 1, 1),
(1, '1010', 'Cash on Hand', 'asset', 'Current Assets', 'cash', 1, 1, 2),
(1, '1020', 'Petty Cash', 'asset', 'Current Assets', 'cash', 1, 0, 3),
(1, '1100', 'Bank Accounts', 'asset', 'Current Assets', 'bank', 1, 1, 4),
(1, '1110', 'Main Operating Account', 'asset', 'Current Assets', 'bank', 1, 0, 5),
(1, '1120', 'Savings Account', 'asset', 'Current Assets', 'bank', 1, 0, 6),
(1, '1130', 'Mobile Money Account', 'asset', 'Current Assets', 'bank', 1, 0, 7),
(1, '1200', 'Accounts Receivable', 'asset', 'Current Assets', 'accounts_receivable', 1, 1, 8),
(1, '1300', 'Inventory', 'asset', 'Current Assets', 'inventory', 1, 0, 9),
(1, '1400', 'Prepaid Expenses', 'asset', 'Current Assets', NULL, 1, 0, 10),
(1, '1500', 'Fixed Assets', 'asset', 'Non-Current Assets', 'fixed_asset', 1, 1, 11),
(1, '1510', 'Furniture & Equipment', 'asset', 'Non-Current Assets', 'fixed_asset', 1, 0, 12),
(1, '1520', 'Vehicles', 'asset', 'Non-Current Assets', 'fixed_asset', 1, 0, 13),
(1, '1530', 'Computer Equipment', 'asset', 'Non-Current Assets', 'fixed_asset', 1, 0, 14),
(1, '1600', 'Accumulated Depreciation', 'asset', 'Non-Current Assets', 'fixed_asset', 1, 1, 15),

-- Liabilities (2000-2999)
(1, '2000', 'Liabilities', 'liability', 'Current Liabilities', NULL, 1, 1, 20),
(1, '2100', 'Accounts Payable', 'liability', 'Current Liabilities', 'accounts_payable', 1, 1, 21),
(1, '2200', 'Credit Cards', 'liability', 'Current Liabilities', 'credit_card', 1, 0, 22),
(1, '2300', 'Accrued Expenses', 'liability', 'Current Liabilities', NULL, 1, 0, 23),
(1, '2400', 'VAT Payable', 'liability', 'Current Liabilities', NULL, 1, 1, 24),
(1, '2410', 'Output VAT', 'liability', 'Current Liabilities', NULL, 1, 0, 25),
(1, '2420', 'Input VAT', 'liability', 'Current Liabilities', NULL, 1, 0, 26),
(1, '2500', 'PAYE Payable', 'liability', 'Current Liabilities', NULL, 1, 0, 27),
(1, '2600', 'NSSF Payable', 'liability', 'Current Liabilities', NULL, 1, 0, 28),
(1, '2700', 'Short-term Loans', 'liability', 'Current Liabilities', NULL, 1, 0, 29),
(1, '2800', 'Long-term Loans', 'liability', 'Non-Current Liabilities', 'long_term_liability', 1, 0, 30),

-- Equity (3000-3999)
(1, '3000', 'Equity', 'equity', 'Owners Equity', 'equity', 1, 1, 40),
(1, '3100', 'Share Capital', 'equity', 'Owners Equity', 'equity', 1, 0, 41),
(1, '3200', 'Retained Earnings', 'equity', 'Owners Equity', 'equity', 1, 1, 42),
(1, '3300', 'Current Year Earnings', 'equity', 'Owners Equity', 'equity', 1, 1, 43),
(1, '3400', 'Dividends', 'equity', 'Owners Equity', 'equity', 1, 0, 44),

-- Income (4000-4999)
(1, '4000', 'Income', 'income', 'Operating Income', 'income', 1, 1, 50),
(1, '4100', 'Sales Revenue', 'income', 'Operating Income', 'income', 1, 1, 51),
(1, '4200', 'Service Revenue', 'income', 'Operating Income', 'income', 1, 0, 52),
(1, '4300', 'Consulting Income', 'income', 'Operating Income', 'income', 1, 0, 53),
(1, '4800', 'Other Income', 'income', 'Other Income', 'other_income', 1, 0, 54),
(1, '4900', 'Interest Income', 'income', 'Other Income', 'other_income', 1, 0, 55),

-- Cost of Goods Sold (5000-5999)
(1, '5000', 'Cost of Goods Sold', 'expense', 'Direct Costs', 'cost_of_goods_sold', 1, 1, 60),
(1, '5100', 'Cost of Goods Sold - Products', 'expense', 'Direct Costs', 'cost_of_goods_sold', 1, 0, 61),
(1, '5200', 'Direct Labor', 'expense', 'Direct Costs', 'cost_of_goods_sold', 1, 0, 62),

-- Expenses (6000-6999)
(1, '6000', 'Operating Expenses', 'expense', 'Operating Expenses', 'expense', 1, 1, 70),
(1, '6100', 'Salaries & Wages', 'expense', 'Personnel', 'expense', 1, 0, 71),
(1, '6110', 'Employee Benefits', 'expense', 'Personnel', 'expense', 1, 0, 72),
(1, '6120', 'NSSF Employer Contribution', 'expense', 'Personnel', 'expense', 1, 0, 73),
(1, '6200', 'Rent Expense', 'expense', 'Facilities', 'expense', 1, 0, 74),
(1, '6210', 'Utilities', 'expense', 'Facilities', 'expense', 1, 0, 75),
(1, '6220', 'Internet & Communication', 'expense', 'Facilities', 'expense', 1, 0, 76),
(1, '6300', 'Office Supplies', 'expense', 'Administrative', 'expense', 1, 0, 77),
(1, '6310', 'Printing & Stationery', 'expense', 'Administrative', 'expense', 1, 0, 78),
(1, '6400', 'Insurance', 'expense', 'Administrative', 'expense', 1, 0, 79),
(1, '6500', 'Professional Fees', 'expense', 'Administrative', 'expense', 1, 0, 80),
(1, '6510', 'Legal Fees', 'expense', 'Administrative', 'expense', 1, 0, 81),
(1, '6520', 'Accounting Fees', 'expense', 'Administrative', 'expense', 1, 0, 82),
(1, '6600', 'Marketing & Advertising', 'expense', 'Sales & Marketing', 'expense', 1, 0, 83),
(1, '6700', 'Travel & Transport', 'expense', 'Operations', 'expense', 1, 0, 84),
(1, '6710', 'Fuel & Oil', 'expense', 'Operations', 'expense', 1, 0, 85),
(1, '6720', 'Vehicle Maintenance', 'expense', 'Operations', 'expense', 1, 0, 86),
(1, '6800', 'Depreciation Expense', 'expense', 'Non-Cash', 'expense', 1, 1, 87),
(1, '6900', 'Bank Charges', 'expense', 'Financial', 'expense', 1, 0, 88),
(1, '6910', 'Interest Expense', 'expense', 'Financial', 'expense', 1, 0, 89),
(1, '6990', 'Miscellaneous Expenses', 'expense', 'Other', 'other_expense', 1, 0, 90);

-- Update parent_id for hierarchical structure
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '1000') AS t) WHERE code IN ('1010', '1020', '1100', '1200', '1300', '1400', '1500', '1600');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '1100') AS t) WHERE code IN ('1110', '1120', '1130');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '1500') AS t) WHERE code IN ('1510', '1520', '1530');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '2000') AS t) WHERE code IN ('2100', '2200', '2300', '2400', '2500', '2600', '2700', '2800');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '2400') AS t) WHERE code IN ('2410', '2420');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '3000') AS t) WHERE code IN ('3100', '3200', '3300', '3400');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '4000') AS t) WHERE code IN ('4100', '4200', '4300', '4800', '4900');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '5000') AS t) WHERE code IN ('5100', '5200');
UPDATE `accounts` SET `parent_id` = (SELECT id FROM (SELECT id FROM `accounts` WHERE code = '6000') AS t) WHERE code IN ('6100', '6110', '6120', '6200', '6210', '6220', '6300', '6310', '6400', '6500', '6510', '6520', '6600', '6700', '6710', '6720', '6800', '6900', '6910', '6990');

-- Set currency_id for all accounts (UGX = 1)
UPDATE `accounts` SET `currency_id` = 1 WHERE `currency_id` IS NULL;


SET FOREIGN_KEY_CHECKS = 1;
COMMIT;

-- =====================================================
-- END OF SCHEMA
-- =====================================================
