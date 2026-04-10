<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\Auth\AuthController;
use App\Http\Controllers\API\Accounting\AccountController;
use App\Http\Controllers\API\Accounting\JournalEntryController;
use App\Http\Controllers\API\Sales\InvoiceController;
use App\Http\Controllers\API\Sales\CustomerController;
use App\Http\Controllers\API\Purchases\BillController;
use App\Http\Controllers\API\Purchases\VendorController;
use App\Http\Controllers\API\Reporting\ReportController;
use App\Http\Controllers\SyncController;
use App\Http\Controllers\ConflictController;
use App\Http\Controllers\API\AccountDataController;
use App\Http\Controllers\API\Outlets\OutletRevenueController;
use App\Http\Controllers\API\AttachmentController;
use App\Http\Controllers\API\Banking\BankStatementController;
use App\Http\Controllers\API\Banking\BankReconciliationController;
use App\Http\Controllers\API\UserController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Public routes
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/auth/reset-password', [AuthController::class, 'resetPassword']);

// Protected routes (requires authentication)
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/user', [AuthController::class, 'user']);

    // Account / self-service data management
    Route::delete('/me/data', [AccountDataController::class, 'deleteAllData']);

    // Tenant-specific routes
    Route::middleware('tenant')->group(function () {

        // Tenant User Management (admin-only write, all users can list)
        Route::get('/users', [UserController::class, 'index']);
        Route::post('/users', [UserController::class, 'store']);
        Route::put('/users/{user}', [UserController::class, 'update']);
        Route::delete('/users/{user}', [UserController::class, 'destroy']);

        // Dashboard
        Route::get('/dashboard/overview', [ReportController::class, 'dashboardOverview']);

        // Chart of Accounts
        Route::apiResource('accounts', AccountController::class);
        Route::post('/accounts/bulk', [AccountController::class, 'bulkCreate']);
        Route::get('/accounts/{account}/balance', [AccountController::class, 'balance']);
        Route::get('/accounts/{account}/ledger', [AccountController::class, 'ledger']);

        // Journal Entries (Double-Entry Core)
        Route::apiResource('journal-entries', JournalEntryController::class);
        Route::post('/journal-entries/{journalEntry}/post', [JournalEntryController::class, 'post']);
        Route::post('/journal-entries/{journalEntry}/unpost', [JournalEntryController::class, 'unpost']);
        Route::get('/journal-entries/{journalEntry}/preview', [JournalEntryController::class, 'preview']);

        // Sales & Receivables
        Route::apiResource('customers', CustomerController::class);
        Route::get('/customers/{customer}/statement', [CustomerController::class, 'statement']);
        Route::get('/customers/{customer}/aging', [CustomerController::class, 'aging']);

        Route::apiResource('invoices', InvoiceController::class);
        Route::post('/invoices/{invoice}/send', [InvoiceController::class, 'send']);
        Route::post('/invoices/{invoice}/payment', [InvoiceController::class, 'recordPayment']);
        Route::get('/invoices/{invoice}/pdf', [InvoiceController::class, 'downloadPdf']);

        // Purchases & Payables
        Route::apiResource('vendors', VendorController::class);
        Route::get('/vendors/{vendor}/statement', [VendorController::class, 'statement']);
        Route::get('/vendors/{vendor}/aging', [VendorController::class, 'aging']);

        Route::apiResource('bills', BillController::class);
        Route::post('/bills/{bill}/payment', [BillController::class, 'recordPayment']);
        Route::get('/bills/{bill}/pdf', [BillController::class, 'downloadPdf']);

        // ── Attachments (polymorphic — bills, invoices, journal entries, payments) ─
        Route::get('/attachments', [AttachmentController::class, 'index']);       // Global list / filter by type
        Route::post('/attachments', [AttachmentController::class, 'store']);      // Upload one or more files
        Route::get('/attachments/{attachment}', [AttachmentController::class, 'show']);
        Route::delete('/attachments/{attachment}', [AttachmentController::class, 'destroy']);

        // ── Banking — Uploaded Statements ────────────────────────────────────────
        Route::prefix('banking')->group(function () {
            // Tab: all uploaded statements
            Route::get('/statements', [BankStatementController::class, 'index']);
            Route::post('/statements', [BankStatementController::class, 'store']);      // Upload CSV or JSON rows
            Route::get('/statements/{statement}', [BankStatementController::class, 'show']);
            Route::delete('/statements/{statement}', [BankStatementController::class, 'destroy']); // Delete when errors found

            // Reconciliation
            Route::get('/reconciliation/accounts', [BankReconciliationController::class, 'accounts']); // All CoA types incl. loans
            Route::get('/reconciliation/items', [BankReconciliationController::class, 'availableItems']); // Open bills / invoices
            Route::post('/statements/{statement}/lines/{line}/reconcile', [BankReconciliationController::class, 'reconcile']); // 1 line → many bills
            Route::delete('/reconciliation-items/{item}', [BankReconciliationController::class, 'unreconcile']); // Reverse
        });

        // Outlet Revenue — posts DR Petty Cash / DR Payouts / CR Stakes JEs
        Route::prefix('outlet-revenues')->group(function () {
            Route::post('/', [OutletRevenueController::class, 'store']);
            Route::post('/commission', [OutletRevenueController::class, 'storeCommission']);
        });

        // Financial Reports
        Route::prefix('reports')->group(function () {
            Route::get('/trial-balance', [ReportController::class, 'trialBalance']);
            Route::get('/balance-sheet', [ReportController::class, 'balanceSheet']);
            Route::get('/profit-loss', [ReportController::class, 'profitLoss']);
            Route::get('/cash-flow', [ReportController::class, 'cashFlow']);
            Route::get('/general-ledger', [ReportController::class, 'generalLedger']);
            Route::get('/aged-receivables', [ReportController::class, 'agedReceivables']);
            Route::get('/aged-payables', [ReportController::class, 'agedPayables']);

            // Export reports
            Route::get('/export/{type}', [ReportController::class, 'export']);
        });

        // Currencies
        Route::get('/currencies', function() {
            return response()->json(\App\Models\Currency::active()->get());
        });

        // Companies
        Route::get('/companies', function() {
            return response()->json(\App\Models\Company::all());
        });

        // Sync (Event Sourcing & Offline Support)
        Route::prefix('sync')->group(function () {
            Route::post('/', [SyncController::class, 'sync']); // Full bi-directional sync
            Route::post('/push', [SyncController::class, 'push']); // Upload events
            Route::get('/pull', [SyncController::class, 'pull']); // Download events
            Route::get('/status', [SyncController::class, 'status']); // Get sync status
            Route::post('/device', [SyncController::class, 'updateDevice']); // Update device state
            Route::get('/replay/{aggregateType}/{aggregateId}', [SyncController::class, 'replay']); // Replay events
        });

        // Conflict Resolution
        Route::prefix('conflicts')->group(function () {
            Route::get('/', [ConflictController::class, 'index']); // List all conflicts
            Route::get('/statistics', [ConflictController::class, 'statistics']); // Get conflict stats
            Route::get('/{id}', [ConflictController::class, 'show']); // Get conflict details
            Route::post('/{id}/resolve/server', [ConflictController::class, 'resolveWithServer']); // Resolve with server data
            Route::post('/{id}/resolve/client', [ConflictController::class, 'resolveWithClient']); // Resolve with client data
            Route::post('/{id}/resolve/merge', [ConflictController::class, 'resolveWithMerge']); // Resolve with merged data
            Route::post('/{id}/ignore', [ConflictController::class, 'ignore']); // Ignore conflict
            Route::post('/bulk-resolve', [ConflictController::class, 'bulkResolve']); // Bulk resolve conflicts
        });
    });
});

// Health check
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toIso8601String(),
    ]);
});
