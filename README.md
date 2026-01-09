# ThirdBooks - Modern Accounting Management System

[![Laravel](https://img.shields.io/badge/Laravel-11-FF2D20?logo=laravel)](https://laravel.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791?logo=postgresql)](https://postgresql.org)
[![License](https://img.shields.io/badge/License-Proprietary-red)](LICENSE)

A comprehensive, cloud-synchronized, offline-capable accounting system supporting double-entry bookkeeping, multi-currency accounting, and multi-tenancy for businesses in Uganda and East Africa.

## 🌟 Key Features

- **Double-Entry Bookkeeping** - GAAP-compliant accounting engine
- **Multi-Tenancy** - SaaS-ready architecture for multiple clients
- **Multi-Currency** - UGX base with USD, EUR, KES, TZS support
- **Offline-First** - Work without internet, sync when available
- **Mobile Admin** - Native iOS and Android monitoring apps
- **Industry Modules** - Retail, Hospitality, Services templates
- **Advanced Reporting** - P&L, Balance Sheet, Cash Flow, Aging Reports
- **Bank Reconciliation** - Automated transaction matching
- **Role-Based Access** - Granular permissions per user

## 🏗️ Architecture

```
thirdbooks/
├── backend/           # Laravel 11 API (Multi-tenant)
├── web-app/          # Inertia.js + Vue 3 Frontend
├── mobile-admin/     # Flutter Admin App
└── docs/             # Documentation
```

### Technology Stack

**Backend:**
- Laravel 11 + PHP 8.3
- PostgreSQL 15+
- Redis (Cache & Queues)
- Laravel Sanctum (Authentication)
- Stancl/Tenancy (Multi-tenancy)

**Web Frontend:**
- Inertia.js
- Vue 3 + TypeScript
- TailwindCSS + Shadcn Vue
- PWA with offline support

**Mobile:**
- Flutter 3.x
- Riverpod (State Management)
- Drift (Local SQLite)
- Dio (HTTP Client)

## 🚀 Quick Start

### Prerequisites

- PHP 8.3+
- Composer
- PostgreSQL 15+
- Redis
- Node.js 18+
- Flutter 3.x (for mobile)

### Backend Setup

```bash
cd backend

# Install dependencies
composer install

# Configure environment
cp .env.example .env
php artisan key:generate

# Setup database
php artisan migrate
php artisan db:seed

# Start development server
php artisan serve
```

### Web App Setup

```bash
cd web-app

# Install dependencies
npm install

# Start development server
npm run dev
```

### Mobile App Setup

```bash
cd mobile-admin

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run
```

## 📖 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Database Schema](docs/DATABASE.md)
- [API Documentation](docs/API.md)
- [Multi-Tenancy Guide](docs/MULTI_TENANCY.md)
- [Deployment Guide](docs/DEPLOYMENT.md)

## 🧪 Testing

```bash
# Backend tests
cd backend
php artisan test

# Frontend tests
cd web-app
npm run test

# Mobile tests
cd mobile-admin
flutter test
```

## 📋 Development Roadmap

- [x] Project structure setup
- [x] Multi-tenancy architecture
- [ ] Double-entry bookkeeping engine
- [ ] Chart of Accounts with templates
- [ ] Invoice & Bill management
- [ ] Financial reporting
- [ ] Offline synchronization
- [ ] Mobile admin app
- [ ] EFRIS integration (URA Uganda)

## 🔒 Security

- End-to-end encryption for sensitive data
- JWT authentication with refresh tokens
- Role-based access control (RBAC)
- Audit trail for all transactions
- SQL injection prevention
- XSS & CSRF protection
- Regular security audits

## 🌍 Uganda-Specific Features

- UGX as base currency (no decimals)
- VAT & Withholding Tax support
- EFRIS integration ready
- Mobile Money payment methods
- Local hosting support
- English & Luganda (planned)

## 📄 License

Proprietary - All rights reserved

## 🤝 Contributing

This is a private commercial project. Contact the development team for contribution guidelines.

## 📧 Support

For support, email: support@thirdbooks.com

---

**Built with ❤️ for African businesses**
