# ThirdBooks - Quick Start Guide

Get ThirdBooks up and running in under 10 minutes!

## 🚀 Prerequisites

Before starting, ensure you have:

- ✅ **PHP 8.3+** installed
- ✅ **Composer** installed
- ✅ **PostgreSQL 15+** running
- ✅ **Redis** running (optional but recommended)
- ✅ **Node.js 18+** and npm installed

---

## 📦 Backend Setup (5 minutes)

### Step 1: Install Dependencies

```bash
cd backend
composer install
```

### Step 2: Configure Environment

```bash
cp .env.example .env
php artisan key:generate
```

Edit `.env` and set your database credentials:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=thirdbooks_central
DB_USERNAME=postgres
DB_PASSWORD=your_password

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
```

### Step 3: Create Database

```bash
# In PostgreSQL
createdb thirdbooks_central
```

Or using psql:
```sql
CREATE DATABASE thirdbooks_central;
```

### Step 4: Run Migrations & Seeders

```bash
# Run central migrations (tenant management)
php artisan migrate --path=database/migrations/central

# Seed currencies
php artisan db:seed
```

### Step 5: Start Backend Server

```bash
php artisan serve
```

✅ Backend running at: **http://localhost:8000**

---

## 🎨 Frontend Setup (3 minutes)

### Step 1: Install Dependencies

```bash
cd web-app
npm install
```

### Step 2: Configure Environment

```bash
cp .env.example .env
```

The default configuration works out of the box:
```env
VITE_API_URL=http://localhost:8000
VITE_APP_NAME=ThirdBooks
```

### Step 3: Start Development Server

```bash
npm run dev
```

✅ Frontend running at: **http://localhost:3000**

---

## 🎯 First Steps

### 1. Register Your First Tenant

```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "company_name": "My Company",
    "name": "Admin User",
    "email": "admin@mycompany.com",
    "password": "password123",
    "password_confirmation": "password123",
    "country": "UG",
    "base_currency": "UGX"
  }'
```

**Save the response!** You'll need:
- `token` - For authentication
- `tenant.id` - Your tenant UUID
- `user.id` - Your user ID

### 2. Create Your First Company

The registration creates a tenant, but you need to set up the company database:

```bash
# Run tenant migrations
php artisan tenants:migrate --tenants=YOUR_TENANT_UUID

# Seed Chart of Accounts
php artisan tenants:seed --tenants=YOUR_TENANT_UUID
```

### 3. Test the API

```bash
# Get trial balance (should be empty initially)
curl http://localhost:8000/api/reports/trial-balance \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_UUID"

# List accounts (should show 82 accounts)
curl http://localhost:8000/api/accounts \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_UUID"
```

---

## 🧪 Create Sample Data

### Create a Customer

```bash
curl -X POST http://localhost:8000/api/customers \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_UUID" \
  -H "Content-Type: application/json" \
  -d '{
    "company_id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+256700123456",
    "currency_id": 1,
    "credit_limit": 1000000,
    "payment_terms_days": 30
  }'
```

### Create an Invoice

```bash
curl -X POST http://localhost:8000/api/invoices \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_UUID" \
  -H "Content-Type: application/json" \
  -d '{
    "company_id": 1,
    "customer_id": 1,
    "date": "2024-01-09",
    "currency_id": 1,
    "create_journal_entry": true,
    "auto_post": false,
    "lines": [{
      "account_id": 20,
      "description": "Consulting Services",
      "quantity": 10,
      "unit_price": 10000,
      "tax_rate": 18
    }]
  }'
```

### View Financial Reports

```bash
# Dashboard overview
curl http://localhost:8000/api/dashboard/overview \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_UUID"

# Trial Balance
curl http://localhost:8000/api/reports/trial-balance \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_UUID"
```

---

## 📱 Access the Web Dashboard

1. Open browser to **http://localhost:3000**
2. You'll see the dashboard with:
   - Revenue, Expenses, Profit, Cash Position cards
   - Recent invoices list
   - Recent bills list

**Note:** The dashboard currently shows placeholder data. To connect it to the API:
- Implement authentication flow
- Add API integration with Axios
- Create invoice and bill list pages

---

## 🔧 Common Commands

### Backend

```bash
# Run migrations
php artisan migrate

# Seed database
php artisan db:seed

# Clear cache
php artisan cache:clear
php artisan config:clear
php artisan route:clear

# Run queue worker
php artisan queue:work

# Run scheduler (for cron jobs)
php artisan schedule:work
```

### Frontend

```bash
# Development
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Type check
npm run type-check
```

---

## 📊 Understanding the Structure

### Chart of Accounts (Default Template)

After seeding, you'll have:

**Assets (1000-1999)**
- Cash & Bank accounts
- Accounts Receivable
- Prepaid Expenses
- Fixed Assets

**Liabilities (2000-2999)**
- Accounts Payable
- Tax Payables (VAT, WHT, PAYE, NSSF)
- Short & Long-term Loans

**Equity (3000-3999)**
- Owner's Capital
- Retained Earnings

**Income (4000-4999)**
- Sales Revenue
- Service Revenue
- Other Income

**Expenses (5000-9999)**
- Cost of Goods Sold
- Operating Expenses
- Other Expenses

### API Endpoints Summary

**Authentication:**
- POST `/api/auth/register` - Register tenant
- POST `/api/auth/login` - Login
- POST `/api/auth/logout` - Logout
- GET `/api/auth/user` - Get current user

**Accounting:**
- GET/POST `/api/accounts` - Chart of Accounts
- GET/POST `/api/journal-entries` - Journal entries
- POST `/api/journal-entries/{id}/post` - Post entry

**Sales:**
- GET/POST `/api/customers` - Customers
- GET/POST `/api/invoices` - Invoices
- POST `/api/invoices/{id}/payment` - Record payment

**Purchases:**
- GET/POST `/api/vendors` - Vendors
- GET/POST `/api/bills` - Bills
- POST `/api/bills/{id}/payment` - Record payment

**Reports:**
- GET `/api/reports/trial-balance` - Trial Balance
- GET `/api/reports/balance-sheet` - Balance Sheet
- GET `/api/reports/profit-loss` - P&L Statement
- GET `/api/reports/aged-receivables` - AR Aging
- GET `/api/reports/aged-payables` - AP Aging

---

## 🐛 Troubleshooting

### "Connection refused" errors

**Problem:** Can't connect to PostgreSQL or Redis

**Solution:**
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check Redis is running
sudo systemctl status redis

# Start services if needed
sudo systemctl start postgresql
sudo systemctl start redis
```

### "Class not found" errors

**Problem:** Composer autoload issues

**Solution:**
```bash
cd backend
composer dump-autoload
```

### Migration errors

**Problem:** Database already exists

**Solution:**
```bash
# Fresh migration
php artisan migrate:fresh

# Or drop and recreate database
dropdb thirdbooks_central
createdb thirdbooks_central
php artisan migrate --path=database/migrations/central
```

### Frontend not loading

**Problem:** Module not found errors

**Solution:**
```bash
cd web-app
rm -rf node_modules package-lock.json
npm install
```

---

## 📚 Next Steps

1. **Read the Full Documentation:**
   - `docs/ARCHITECTURE.md` - System design
   - `docs/API.md` - Complete API reference
   - `docs/SETUP_GUIDE.md` - Production deployment

2. **Explore the Code:**
   - Check `backend/app/Models` for business logic
   - Review `backend/app/Services` for core services
   - Examine `backend/database/seeders` for sample data

3. **Build Features:**
   - Create invoice management UI
   - Add authentication pages
   - Implement reports dashboard
   - Build settings pages

4. **Test Everything:**
   - Write PHPUnit tests
   - Test API endpoints
   - Validate accounting logic

---

## 🎉 You're Ready!

ThirdBooks is now running! You have:

✅ Complete backend API with 50+ endpoints
✅ Double-entry bookkeeping engine
✅ Multi-tenant architecture
✅ Modern Vue 3 frontend
✅ PostgreSQL database with migrations
✅ 82 pre-configured accounts
✅ 8 currencies ready to use

**Need Help?**
- Check `docs/` folder for detailed guides
- Review code comments
- Open an issue on GitHub

**Happy Accounting! 🚀**
