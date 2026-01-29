# ThirdBooks Mobile & Desktop App

A comprehensive multi-platform accounting application built with Flutter. This app provides full offline-first accounting functionality for businesses in Uganda/East Africa.

## Features

### Core Accounting
- **Chart of Accounts** - Manage your complete chart of accounts with support for Assets, Liabilities, Equity, Revenue, and Expense accounts
- **Journal Entries** - Create and post double-entry journal entries with automatic balance validation
- **General Ledger** - View all posted transactions by account

### Sales
- **Customers** - Manage customer information, contact details, and credit limits
- **Invoices** - Create professional invoices with line items, taxes, and discounts
- **Payments Received** - Record customer payments and allocate to invoices

### Purchases
- **Vendors** - Manage supplier information and payment terms
- **Bills** - Record vendor bills with expense allocation
- **Payments Made** - Record payments to vendors

### Reports
- **Trial Balance** - Verify debits equal credits
- **Income Statement** - Revenue and expenses for a period
- **Balance Sheet** - Assets, liabilities, and equity at a point in time
- **AR Aging** - Accounts receivable aging by customer
- **AP Aging** - Accounts payable aging by vendor

### Offline-First Architecture
- **Local SQLite Database** - All data stored locally using Drift ORM
- **Event Sourcing** - Track all changes for reliable synchronization
- **Bidirectional Sync** - Push local changes and pull server updates
- **Conflict Resolution** - Handle sync conflicts with user control

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio (for Android) or Xcode (for iOS/macOS)

### Installation

1. **Clone the repository**
   ```bash
   cd /path/to/THIRD-BOOKS/mobile-admin
   ```

2. **Enable desktop platforms** (if not already enabled)
   ```bash
   flutter create . --platforms=linux,macos,windows
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Generate code** (Drift database, Freezed models)
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Run the app**
   ```bash
   # For mobile
   flutter run

   # For desktop
   flutter run -d linux
   flutter run -d macos
   flutter run -d windows
   ```

## Project Structure

```
mobile-admin/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── core/
│   │   ├── api/
│   │   │   └── api_client.dart   # HTTP client with Dio
│   │   ├── auth/
│   │   │   └── auth_provider.dart # Authentication state
│   │   ├── database/
│   │   │   └── app_database.dart  # Drift SQLite database
│   │   ├── providers/
│   │   │   ├── accounts_provider.dart
│   │   │   ├── customers_provider.dart
│   │   │   ├── vendors_provider.dart
│   │   │   ├── invoices_provider.dart
│   │   │   ├── bills_provider.dart
│   │   │   ├── journal_entries_provider.dart
│   │   │   └── reports_provider.dart
│   │   ├── router/
│   │   │   └── app_router.dart    # GoRouter configuration
│   │   ├── sync/
│   │   │   └── sync_service.dart  # Sync with server
│   │   └── theme/
│   │       └── app_theme.dart     # App theming
│   └── features/
│       ├── accounts/
│       │   └── accounts_list_screen.dart
│       ├── auth/
│       │   └── login_screen.dart
│       ├── bills/
│       │   └── bills_list_screen.dart
│       ├── conflicts/
│       │   └── conflicts_screen.dart
│       ├── customers/
│       │   └── customers_list_screen.dart
│       ├── dashboard/
│       │   └── dashboard_screen.dart
│       ├── invoices/
│       │   └── invoices_list_screen.dart
│       ├── journals/
│       │   └── journal_entries_screen.dart
│       ├── reports/
│       │   └── reports_screen.dart
│       ├── settings/
│       │   └── settings_screen.dart
│       ├── sync/
│       │   └── sync_status_screen.dart
│       └── vendors/
│           └── vendors_list_screen.dart
└── pubspec.yaml
```

## Architecture

### State Management
- **Riverpod** - Type-safe provider-based state management
- **StateNotifier** - Immutable state updates with reactive rebuilds

### Database
- **Drift (SQLite)** - Type-safe local database ORM
- **20+ tables** for complete accounting functionality
- **Auto-seeding** of account types, currencies, and tax rates

### Navigation
- **GoRouter** - Declarative routing with deep linking support
- **ShellRoute** - Bottom navigation with persistent navigation bar

### Synchronization
- **Event Sourcing** - Every change is captured as an event
- **Optimistic Updates** - UI updates immediately, syncs in background
- **Conflict Detection** - Server and client conflicts are tracked
- **Resolution UI** - Users can choose to keep server or client data

## Database Schema

### Core Tables
- `accounts` - Chart of accounts
- `account_types` - Asset, Liability, Equity, Revenue, Expense
- `journal_entries` - Transaction headers
- `journal_entry_lines` - Transaction details
- `general_ledger` - Posted transactions

### Business Partners
- `customers` - Customer master data
- `vendors` - Vendor/supplier master data

### Transactions
- `invoices` - Sales invoices
- `invoice_items` - Invoice line items
- `bills` - Vendor bills
- `bill_items` - Bill line items
- `payments` - Received and made payments
- `payment_allocations` - Payment to invoice/bill links

### Reference Data
- `currencies` - UGX, USD, EUR, KES with exchange rates
- `tax_rates` - VAT 18%, WHT 6%, etc.
- `fiscal_years` - Accounting periods

## Configuration

### Environment Variables
Set the API base URL in the app:
```dart
// In api_client.dart
const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);
```

Run with custom URL:
```bash
flutter run --dart-define=API_BASE_URL=https://your-api.com/api
```

## Building for Production

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Desktop
```bash
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

## License

Proprietary - All rights reserved.

## Support

For support, please contact the development team.
