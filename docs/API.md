# ThirdBooks API Documentation

Complete REST API documentation for ThirdBooks accounting system.

**Base URL:** `http://localhost:8000/api`

**Authentication:** Bearer Token (Laravel Sanctum)

---

## Authentication

### Register New Tenant

Creates a new tenant (company) and admin user.

```http
POST /auth/register
Content-Type: application/json

{
  "company_name": "Acme Ltd",
  "name": "John Doe",
  "email": "john@acme.com",
  "password": "password123",
  "password_confirmation": "password123",
  "phone": "+256700123456",
  "country": "UG",
  "base_currency": "UGX"
}
```

**Response:**
```json
{
  "message": "Registration successful",
  "token": "1|abc123...",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@acme.com",
    "role": "admin",
    "tenant_id": "uuid"
  },
  "tenant": {
    "id": "uuid",
    "name": "Acme Ltd",
    "domain": "acme-ltd.thirdbooks.test",
    "plan": "trial",
    "trial_ends_at": "2024-02-09T..."
  }
}
```

### Login

```http
POST /auth/login
Content-Type: application/json

{
  "email": "john@acme.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "token": "2|def456...",
  "user": {...},
  "tenant": {...}
}
```

### Logout

```http
POST /auth/logout
Authorization: Bearer {token}
```

### Get Current User

```http
GET /auth/user
Authorization: Bearer {token}
```

---

## Chart of Accounts

All requests require:
- **Authorization:** `Bearer {token}`
- **X-Tenant-ID:** `{tenant_uuid}` (header)

### List Accounts

```http
GET /accounts?type=asset&is_active=true&parents_only=true
```

**Query Parameters:**
- `type` - Filter by type (asset, liability, equity, income, expense)
- `category` - Filter by category
- `is_active` - Filter active/inactive accounts
- `parents_only` - Show only parent accounts (no children)

**Response:**
```json
{
  "accounts": [
    {
      "id": 1,
      "code": "1000",
      "name": "Assets",
      "type": "asset",
      "category": null,
      "currency_id": 1,
      "current_balance": 0,
      "is_active": true,
      "is_system": true,
      "parent_id": null
    }
  ]
}
```

### Get Single Account

```http
GET /accounts/{id}
```

### Create Account

```http
POST /accounts
Content-Type: application/json

{
  "company_id": 1,
  "code": "1050",
  "name": "Savings Account",
  "type": "asset",
  "category": "bank",
  "currency_id": 1,
  "parent_id": null,
  "opening_balance": 10000,
  "is_active": true
}
```

### Update Account

```http
PUT /accounts/{id}
Content-Type: application/json

{
  "name": "Updated Account Name",
  "is_active": false
}
```

### Delete Account

```http
DELETE /accounts/{id}
```

**Note:** System accounts and accounts with transactions cannot be deleted.

### Get Account Balance

```http
GET /accounts/{id}/balance?date=2024-01-09
```

**Response:**
```json
{
  "account_id": 1,
  "account_code": "1020",
  "account_name": "Bank Account",
  "balance": 50000,
  "date": "2024-01-09",
  "currency": "UGX"
}
```

### Get Account Ledger

```http
GET /accounts/{id}/ledger?start_date=2024-01-01&end_date=2024-01-31
```

**Response:**
```json
{
  "account": {
    "id": 1,
    "code": "1020",
    "name": "Bank Account",
    "type": "asset"
  },
  "entries": [
    {
      "date": "2024-01-05",
      "entry_number": "JE-2024-000001",
      "description": "Payment received",
      "debit": 10000,
      "credit": 0,
      "balance": 10000
    }
  ],
  "opening_balance": 0,
  "closing_balance": 10000
}
```

### Bulk Create Accounts

```http
POST /accounts/bulk
Content-Type: application/json

{
  "company_id": 1,
  "accounts": [
    {
      "code": "1030",
      "name": "Cash",
      "type": "asset",
      "currency_id": 1
    },
    {
      "code": "1040",
      "name": "Petty Cash",
      "type": "asset",
      "currency_id": 1
    }
  ]
}
```

---

## Journal Entries

### List Journal Entries

```http
GET /journal-entries?status=posted&start_date=2024-01-01&per_page=20
```

**Query Parameters:**
- `status` - draft or posted
- `type` - manual or automatic
- `start_date` / `end_date` - Date range
- `per_page` - Pagination (default: 20)

### Get Single Journal Entry

```http
GET /journal-entries/{id}
```

**Response:**
```json
{
  "journal_entry": {
    "id": 1,
    "entry_number": "JE-2024-000001",
    "date": "2024-01-09",
    "description": "Payment received",
    "status": "posted",
    "type": "automatic",
    "lines": [
      {
        "id": 1,
        "account_id": 1,
        "account": {
          "code": "1020",
          "name": "Bank Account"
        },
        "debit": 10000,
        "credit": 0,
        "description": "Payment via mobile money"
      },
      {
        "id": 2,
        "account_id": 2,
        "account": {
          "code": "1100",
          "name": "Accounts Receivable"
        },
        "debit": 0,
        "credit": 10000,
        "description": "Payment for invoice INV-2024-000001"
      }
    ]
  },
  "is_balanced": true,
  "total_debits": 10000,
  "total_credits": 10000
}
```

### Create Journal Entry

```http
POST /journal-entries
Content-Type: application/json

{
  "company_id": 1,
  "date": "2024-01-09",
  "reference": "REF-001",
  "description": "Manual journal entry",
  "auto_post": false,
  "lines": [
    {
      "account_id": 1,
      "debit": 5000,
      "credit": 0,
      "description": "Debit entry"
    },
    {
      "account_id": 2,
      "debit": 0,
      "credit": 5000,
      "description": "Credit entry"
    }
  ]
}
```

**Note:** Lines must balance (total debits = total credits)

### Update Journal Entry

```http
PUT /journal-entries/{id}
Content-Type: application/json

{
  "date": "2024-01-10",
  "description": "Updated description"
}
```

**Note:** Only draft entries can be updated.

### Delete Journal Entry

```http
DELETE /journal-entries/{id}
```

**Note:** Only draft entries can be deleted.

### Post Journal Entry

```http
POST /journal-entries/{id}/post
```

Posts a draft journal entry to the general ledger. Requires accountant permissions.

### Unpost Journal Entry

```http
POST /journal-entries/{id}/unpost
```

Unposts a journal entry. Requires accountant permissions. Deletes GL entries and recalculates balances.

### Preview Journal Entry

```http
GET /journal-entries/{id}/preview
```

Shows preview before posting with validation status.

---

## Customers

### List Customers

```http
GET /customers?status=active&search=john&per_page=20
```

### Get Customer

```http
GET /customers/{id}
```

**Response:**
```json
{
  "customer": {
    "id": 1,
    "customer_number": "CUST-000001",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+256700123456",
    "credit_limit": 1000000,
    "payment_terms_days": 30,
    "status": "active"
  },
  "outstanding_balance": 50000,
  "has_exceeded_credit_limit": false
}
```

### Create Customer

```http
POST /customers
Content-Type: application/json

{
  "company_id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+256700123456",
  "currency_id": 1,
  "credit_limit": 1000000,
  "payment_terms_days": 30,
  "billing_address": "Kampala, Uganda",
  "status": "active"
}
```

### Update Customer

```http
PUT /customers/{id}
```

### Delete Customer

```http
DELETE /customers/{id}
```

**Note:** Cannot delete customers with invoices.

### Customer Statement

```http
GET /customers/{id}/statement?start_date=2024-01-01&end_date=2024-01-31
```

**Response:**
```json
{
  "customer": {...},
  "period": {
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
  },
  "invoices": [...],
  "payments": [...],
  "outstanding_balance": 50000
}
```

### Customer Aging

```http
GET /customers/{id}/aging
```

**Response:**
```json
{
  "customer": {...},
  "aging": {
    "current": 10000,
    "30_days": 5000,
    "60_days": 3000,
    "90_plus_days": 2000
  },
  "total_outstanding": 20000,
  "overdue_invoices": [...]
}
```

---

## Invoices

### List Invoices

```http
GET /invoices?status=unpaid&customer_id=1&unpaid_only=true&per_page=20
```

### Get Invoice

```http
GET /invoices/{id}
```

**Response:**
```json
{
  "invoice": {
    "id": 1,
    "invoice_number": "INV-2024-000001",
    "customer_id": 1,
    "customer": {
      "name": "John Doe"
    },
    "date": "2024-01-09",
    "due_date": "2024-02-08",
    "subtotal": 100000,
    "tax_amount": 18000,
    "total": 118000,
    "paid_amount": 0,
    "balance": 118000,
    "status": "sent",
    "lines": [
      {
        "description": "Consulting services",
        "quantity": 10,
        "unit_price": 10000,
        "tax_rate": 18,
        "amount": 118000
      }
    ]
  }
}
```

### Create Invoice

```http
POST /invoices
Content-Type: application/json

{
  "company_id": 1,
  "customer_id": 1,
  "date": "2024-01-09",
  "due_date": "2024-02-08",
  "currency_id": 1,
  "reference": "PO-123",
  "notes": "Payment terms: Net 30",
  "create_journal_entry": true,
  "auto_post": false,
  "lines": [
    {
      "account_id": 10,
      "description": "Consulting services",
      "quantity": 10,
      "unit_price": 10000,
      "tax_rate": 18
    }
  ]
}
```

### Update Invoice

```http
PUT /invoices/{id}
```

**Note:** Only draft invoices can be updated.

### Delete Invoice

```http
DELETE /invoices/{id}
```

### Send Invoice

```http
POST /invoices/{id}/send
```

Marks invoice as sent and creates journal entry.

### Record Payment

```http
POST /invoices/{id}/payment
Content-Type: application/json

{
  "amount": 118000,
  "date": "2024-01-15",
  "method": "mobile_money",
  "deposit_account_id": 1,
  "reference": "M-PESA123456",
  "notes": "Full payment"
}
```

### Download PDF

```http
GET /invoices/{id}/pdf
```

---

## Vendors & Bills

Similar structure to Customers & Invoices:

- `GET /vendors` - List vendors
- `POST /vendors` - Create vendor
- `GET /vendors/{id}/statement` - Vendor statement
- `GET /vendors/{id}/aging` - AP aging

- `GET /bills` - List bills
- `POST /bills` - Create bill
- `POST /bills/{id}/payment` - Record payment
- `GET /bills/{id}/pdf` - Download PDF

---

## Reports

### Dashboard Overview

```http
GET /dashboard/overview
```

**Response:**
```json
{
  "revenue": 1000000,
  "expenses": 600000,
  "profit": 400000,
  "profit_margin": 40,
  "cash_position": 500000,
  "accounts_receivable": 200000,
  "accounts_payable": 150000,
  "overdue_invoices_count": 5,
  "overdue_bills_count": 3
}
```

### Trial Balance

```http
GET /reports/trial-balance?date=2024-01-31
```

**Response:**
```json
{
  "date": "2024-01-31",
  "accounts": [
    {
      "code": "1020",
      "name": "Bank Account",
      "type": "asset",
      "debit": 100000,
      "credit": 0
    },
    {
      "code": "3010",
      "name": "Owner's Capital",
      "type": "equity",
      "debit": 0,
      "credit": 100000
    }
  ],
  "total_debits": 100000,
  "total_credits": 100000,
  "is_balanced": true
}
```

### Balance Sheet

```http
GET /reports/balance-sheet?date=2024-01-31
```

**Response:**
```json
{
  "date": "2024-01-31",
  "assets": {
    "accounts": [...],
    "total": 500000
  },
  "liabilities": {
    "accounts": [...],
    "total": 200000
  },
  "equity": {
    "accounts": [...],
    "total": 300000
  },
  "total_liabilities_and_equity": 500000,
  "is_balanced": true
}
```

### Profit & Loss

```http
GET /reports/profit-loss?start_date=2024-01-01&end_date=2024-01-31
```

**Response:**
```json
{
  "period": {
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
  },
  "income": {
    "accounts": [...],
    "total": 1000000
  },
  "expenses": {
    "accounts": [...],
    "total": 600000
  },
  "gross_profit": 1000000,
  "net_profit": 400000,
  "profit_margin": 40
}
```

### Aged Receivables

```http
GET /reports/aged-receivables
```

**Response:**
```json
{
  "report": [
    {
      "customer": {
        "id": 1,
        "name": "John Doe",
        "customer_number": "CUST-000001"
      },
      "aging": {
        "current": 10000,
        "30_days": 5000,
        "60_days": 3000,
        "90_plus_days": 2000
      },
      "total": 20000
    }
  ],
  "totals": {
    "current": 50000,
    "30_days": 25000,
    "60_days": 15000,
    "90_plus_days": 10000,
    "total": 100000
  }
}
```

### Aged Payables

```http
GET /reports/aged-payables
```

Similar structure to Aged Receivables.

---

## Error Responses

All endpoints return consistent error responses:

**Validation Error (422):**
```json
{
  "message": "Validation failed",
  "errors": {
    "email": ["The email field is required."],
    "password": ["The password must be at least 8 characters."]
  }
}
```

**Unauthorized (401):**
```json
{
  "message": "Unauthenticated."
}
```

**Forbidden (403):**
```json
{
  "message": "You do not have permission to perform this action."
}
```

**Not Found (404):**
```json
{
  "message": "Resource not found."
}
```

**Server Error (500):**
```json
{
  "message": "An error occurred",
  "error": "Detailed error message"
}
```

---

## Rate Limiting

- **Default:** 60 requests per minute per user
- **Header:** `X-RateLimit-Limit`, `X-RateLimit-Remaining`

---

## Pagination

List endpoints support pagination:

**Request:**
```http
GET /invoices?per_page=20&page=2
```

**Response:**
```json
{
  "current_page": 2,
  "data": [...],
  "first_page_url": "http://localhost:8000/api/invoices?page=1",
  "from": 21,
  "last_page": 5,
  "last_page_url": "http://localhost:8000/api/invoices?page=5",
  "next_page_url": "http://localhost:8000/api/invoices?page=3",
  "path": "http://localhost:8000/api/invoices",
  "per_page": 20,
  "prev_page_url": "http://localhost:8000/api/invoices?page=1",
  "to": 40,
  "total": 100
}
```

---

## Testing with cURL

### Complete Workflow Example

```bash
# 1. Register
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "company_name": "Test Company",
    "name": "Admin User",
    "email": "admin@test.com",
    "password": "password123",
    "password_confirmation": "password123"
  }'

# Save the token from response

# 2. Create a customer
curl -X POST http://localhost:8000/api/customers \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "company_id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "currency_id": 1
  }'

# 3. Create an invoice
curl -X POST http://localhost:8000/api/invoices \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "company_id": 1,
    "customer_id": 1,
    "date": "2024-01-09",
    "currency_id": 1,
    "lines": [{
      "account_id": 10,
      "description": "Services",
      "quantity": 1,
      "unit_price": 100000,
      "tax_rate": 18
    }]
  }'

# 4. Get trial balance
curl http://localhost:8000/api/reports/trial-balance \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_ID"
```

---

**Last Updated:** January 2026
**API Version:** 1.0.0
