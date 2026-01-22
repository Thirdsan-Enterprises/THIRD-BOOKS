# ThirdBooks Super Admin Portal Guide

## Overview

The Super Admin Portal provides comprehensive system administration capabilities for managing your entire ThirdBooks multi-tenant accounting platform. This guide covers setup, features, and best practices.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Creating Super Admin Users](#creating-super-admin-users)
3. [Admin Portal Features](#admin-portal-features)
4. [Security Best Practices](#security-best-practices)
5. [API Reference](#api-reference)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Create Your First Super Admin

**Option A: Using Database Seeder (Recommended for initial setup)**

```bash
cd backend
php artisan db:seed --class=SuperAdminSeeder
```

This creates a super admin with:
- **Email:** `admin@thirdbooks.digital`
- **Password:** `SuperAdmin@2024`

⚠️ **IMPORTANT:** Change this password immediately after first login!

**Option B: Using Artisan Command (Interactive)**

```bash
cd backend
php artisan admin:create-super
```

This will prompt you for:
- Email address
- Full name
- Password (with confirmation)

**Option C: Using Artisan Command (Non-interactive)**

```bash
cd backend
php artisan admin:create-super \
  --email="your.email@example.com" \
  --name="Your Name" \
  --password="YourSecurePassword123!"
```

### 2. Login to Admin Portal

1. Navigate to: `https://thirdbooks.digital/admin`
2. Login with your super admin credentials
3. You'll be redirected to the admin dashboard

### 3. Verify Access

After login, you should see:
- 🔴 Red-themed admin interface (distinct from tenant blue theme)
- Navigation: Dashboard, Tenants, Users, Audit Logs
- "Super Admin" badge in the header
- Link to return to tenant dashboard (if you also have a tenant account)

---

## Creating Super Admin Users

### Who Should Be a Super Admin?

Super admins have **unlimited system access**, including:
- View and modify all tenant data
- Suspend/activate any tenant
- Impersonate any user (login as them)
- View complete audit trail
- Access system analytics and revenue data

**Best Practices:**
- ✅ Limit super admin accounts to 2-3 trusted individuals
- ✅ Use strong, unique passwords
- ✅ Enable 2FA when available
- ✅ Regularly review super admin activity in audit logs
- ❌ Never share super admin credentials
- ❌ Don't use super admin for daily operations

### Manual Database Creation (If Needed)

If you need to manually create a super admin directly in the database:

```sql
INSERT INTO users (
    id,
    tenant_id,
    name,
    email,
    password,
    role,
    is_active,
    email_verified_at,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    NULL, -- Super admins don't belong to any tenant
    'Your Name',
    'your.email@example.com',
    '$2y$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5KQBdLcVGPVY6', -- "password" - CHANGE THIS!
    'super_admin',
    true,
    NOW(),
    NOW(),
    NOW()
);
```

**To hash a new password:**

```bash
php artisan tinker
>>> bcrypt('YourNewPassword')
```

---

## Admin Portal Features

### 1. Dashboard (`/admin`)

**System Overview:**
- Total tenants (active, suspended, cancelled, trial)
- Total users across all tenants
- Active trial accounts
- Monthly Recurring Revenue (MRR) and Annual Recurring Revenue (ARR)

**Analytics:**
- Tenant distribution by plan (Trial, Starter, Professional, Enterprise)
- Tenant breakdown by status
- User distribution by role
- Recent activity timeline (last 10 actions)

**Revenue Metrics:**
- MRR calculation based on active subscriptions
- ARR projection (MRR × 12)
- Paying tenant count (excludes trials)
- Revenue trends (if implemented)

### 2. Tenant Management (`/admin/tenants`)

**Features:**
- 📊 **List View:** All tenants with search and filters
- 🔍 **Search:** By name, email, or company
- 🏷️ **Filters:** Status (active/suspended/cancelled) and plan
- 📄 **Pagination:** 20 tenants per page
- ⚡ **Actions:** View details, suspend, activate, upgrade plan

**Available Actions:**

| Action | Description | Endpoint |
|--------|-------------|----------|
| **View** | See tenant details, users, subscription | `GET /api/admin/tenants/{id}` |
| **Suspend** | Temporarily disable tenant access | `POST /api/admin/tenants/{id}/suspend` |
| **Activate** | Re-enable suspended tenant | `POST /api/admin/tenants/{id}/activate` |
| **Upgrade Plan** | Change subscription tier | `PUT /api/admin/tenants/{id}/upgrade-plan` |
| **Extend Subscription** | Add days to trial/subscription | `PUT /api/admin/tenants/{id}/extend-subscription` |
| **Delete** | Permanently remove tenant (soft delete) | `DELETE /api/admin/tenants/{id}` |

**Tenant Status Badges:**
- 🟢 **Active** - Green badge
- 🔴 **Suspended** - Red badge
- ⚫ **Cancelled** - Gray badge
- 🟡 **Trial** - Yellow badge

**Plan Badges:**
- 🔵 **Trial** - Blue badge
- 🟢 **Starter** - Green badge
- 🟣 **Professional** - Purple badge
- 🟠 **Enterprise** - Orange badge

### 3. User Management (`/admin/users`)

**Features:**
- 📋 **Cross-Tenant View:** See all users across all tenants
- 🔍 **Search:** By name or email
- 🏷️ **Filters:** Role and active status
- 👁️ **Tenant Association:** See which tenant each user belongs to
- ⚡ **Actions:** View, deactivate, activate, impersonate

**Available Actions:**

| Action | Description | Security Note |
|--------|-------------|---------------|
| **View** | See user details and tenant | Read-only |
| **Deactivate** | Disable user login | User can be reactivated |
| **Activate** | Re-enable deactivated user | Restores access |
| **Impersonate** | Login as the user | ⚠️ Cannot impersonate other super admins |
| **Delete** | Permanently remove user | Soft delete with audit trail |

**User Impersonation:**

Impersonation allows you to login as any user for support purposes.

**How it works:**
1. Click "Impersonate" on any user
2. System generates a temporary auth token for that user
3. You're automatically redirected to their tenant dashboard
4. You see exactly what they see (tenant-scoped data)
5. To return, logout and login as super admin again

**Security:**
- ✅ All impersonation events are logged in audit logs
- ✅ Cannot impersonate other super admins
- ✅ Includes metadata: who impersonated whom, when, from which IP
- ⚠️ Use only for legitimate support purposes

**Role Badges:**
- 🔴 **Super Admin** - Red badge (highest level)
- 🟣 **Admin** - Purple badge (tenant level)
- 🔵 **Accountant** - Blue badge
- 🟢 **Manager** - Green badge
- 🟡 **User** - Yellow badge
- ⚫ **Viewer** - Gray badge (read-only)

### 4. Audit Logs (`/admin/audit-logs`)

**Features:**
- 📜 **Complete Activity Trail:** Every admin action logged
- 🔍 **Advanced Filters:** By action type, date range, user, entity
- 📊 **Statistics Dashboard:** 30-day overview with critical action tracking
- 📥 **CSV Export:** Download logs for compliance or analysis
- 🔎 **Detailed View:** See changes, metadata, IP, user agent

**Logged Actions:**

| Category | Actions |
|----------|---------|
| **Tenant** | created, suspended, activated, plan_upgraded, subscription_extended, deleted |
| **User** | created, updated, deleted, deactivated, activated, impersonated |
| **Audit** | exported, viewed |

**Log Entry Details:**
- **Who:** User who performed the action
- **What:** Action type (e.g., `user.impersonated`)
- **When:** Timestamp
- **Where:** IP address
- **How:** User agent (browser/device)
- **Changes:** JSON diff of what changed
- **Metadata:** Additional context (e.g., impersonated_by)

**Statistics:**
- Total logs in last 30 days
- Top action type
- Critical actions count (suspensions, deletions, impersonations)

**Export:**
- Click "Export to CSV" button
- Optionally filter by date range before exporting
- Downloads: `audit_logs_YYYY-MM-DD.csv`
- Contains all log fields in spreadsheet format

**Compliance Use Cases:**
- 🏛️ Regulatory audits (SOC 2, ISO 27001)
- 🔒 Security investigations
- 📊 Usage analytics
- 🐛 Troubleshooting user issues
- 📝 Change tracking

---

## Security Best Practices

### 1. Password Security

**Super Admin Passwords Should:**
- ✅ Be at least 16 characters long
- ✅ Include uppercase, lowercase, numbers, symbols
- ✅ Be unique (not used anywhere else)
- ✅ Be changed every 90 days
- ✅ Never be shared or written down

**Example Strong Password:**
```
Tb$uP3r@dm1n!2024&Secure#99
```

### 2. Access Control

**Principle of Least Privilege:**
- Only grant super admin to people who absolutely need it
- Most team members should have tenant-level admin roles instead
- Regularly review and revoke unnecessary super admin access

**Recommended Structure:**
```
Super Admins (2-3 people):
├── CEO/Founder
├── CTO/Technical Lead
└── Senior Operations Manager

Tenant Admins (per client):
├── Client's primary contact (admin role)
├── Client's accountant (accountant role)
└── Client's staff (user/viewer roles)
```

### 3. Audit Log Monitoring

**Set Up Regular Reviews:**
- Weekly: Review critical actions (suspensions, impersonations)
- Monthly: Export full audit logs for compliance records
- Real-time: Monitor for unusual patterns

**Red Flags to Watch For:**
- ⚠️ Impersonation at unusual hours (e.g., 3 AM)
- ⚠️ Bulk deletions or suspensions
- ⚠️ Login from unexpected IP addresses
- ⚠️ Multiple failed login attempts
- ⚠️ Rapid changes to critical settings

### 4. Multi-Factor Authentication (MFA)

**Recommended MFA Setup:**
- Use TOTP apps (Google Authenticator, Authy, 1Password)
- Backup codes stored securely offline
- SMS as fallback only (less secure)

**Implementation:**
```bash
# Install Laravel Fortify for 2FA
composer require laravel/fortify
php artisan fortify:install
php artisan migrate
```

### 5. IP Whitelisting (Production)

Restrict admin access to known IPs:

```php
// backend/app/Http/Middleware/EnsureSuperAdmin.php

public function handle(Request $request, Closure $next): Response
{
    // Check super admin role
    if (!$request->user() || !$request->user()->isSuperAdmin()) {
        return response()->json(['message' => 'Unauthorized'], 403);
    }

    // IP whitelist for production
    if (app()->environment('production')) {
        $allowedIps = [
            '203.0.113.0/24', // Office network
            '198.51.100.45',  // VPN IP
        ];

        if (!in_array($request->ip(), $allowedIps)) {
            AuditLog::log('admin.access_denied_ip', metadata: [
                'ip' => $request->ip()
            ]);
            return response()->json(['message' => 'Access denied'], 403);
        }
    }

    return $next($request);
}
```

### 6. Session Management

**Laravel Sanctum Configuration:**

```php
// backend/config/sanctum.php

'expiration' => 120, // 2 hours for super admin sessions
'token_refresh' => true,
```

**Best Practices:**
- ✅ Short session timeouts (2 hours max)
- ✅ Auto-logout on browser close
- ✅ Single device login enforcement
- ✅ Token refresh on activity

---

## API Reference

### Authentication

All admin endpoints require:
1. Valid Sanctum token
2. User role = `super_admin`

**Headers:**
```http
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

### Base URL

```
https://thirdbooks.digital/api/admin
```

### Endpoints

#### Analytics

```http
GET /admin/analytics/dashboard
```

**Response:**
```json
{
  "overview": {
    "total_tenants": 150,
    "active_tenants": 142,
    "suspended_tenants": 5,
    "cancelled_tenants": 3,
    "total_users": 450,
    "trial_tenants": 25
  },
  "tenant_stats": {
    "by_plan": {
      "trial": 25,
      "starter": 80,
      "professional": 40,
      "enterprise": 5
    },
    "by_status": {
      "active": 142,
      "suspended": 5,
      "cancelled": 3
    }
  },
  "user_stats": {
    "by_role": {
      "admin": 150,
      "accountant": 120,
      "manager": 80,
      "user": 90,
      "viewer": 10
    }
  },
  "revenue": {
    "mrr": 8950,
    "arr": 107400,
    "paying_tenants": 125
  },
  "recent_activity": [...]
}
```

#### Tenant Management

```http
# List tenants
GET /admin/tenants?search={query}&status={status}&plan={plan}&page={page}

# Get tenant details
GET /admin/tenants/{id}

# Suspend tenant
POST /admin/tenants/{id}/suspend

# Activate tenant
POST /admin/tenants/{id}/activate

# Upgrade plan
PUT /admin/tenants/{id}/upgrade-plan
Body: { "plan": "professional" }

# Extend subscription
PUT /admin/tenants/{id}/extend-subscription
Body: { "days": 30 }

# Delete tenant
DELETE /admin/tenants/{id}
```

#### User Management

```http
# List users
GET /admin/users?search={query}&role={role}&is_active={bool}&page={page}

# Get user details
GET /admin/users/{id}

# Deactivate user
POST /admin/users/{id}/deactivate

# Activate user
POST /admin/users/{id}/activate

# Impersonate user
POST /admin/users/{id}/impersonate

# Delete user
DELETE /admin/users/{id}
```

**Impersonate Response:**
```json
{
  "token": "3|abc123...",
  "user": {...},
  "tenant": {...}
}
```

#### Audit Logs

```http
# List logs
GET /admin/audit-logs?action={action}&from_date={date}&to_date={date}&page={page}

# Get statistics
GET /admin/audit-logs/statistics

# Export CSV
GET /admin/audit-logs/export?from_date={date}&to_date={date}
```

---

## Troubleshooting

### Cannot Access Admin Portal

**Symptom:** Getting redirected to `/dashboard` when visiting `/admin`

**Solution:**
1. Verify your user has `role = 'super_admin'`:
   ```sql
   SELECT id, email, role FROM users WHERE email = 'your.email@example.com';
   ```

2. If role is incorrect:
   ```sql
   UPDATE users SET role = 'super_admin' WHERE email = 'your.email@example.com';
   ```

3. Clear browser cache and logout/login again

### 403 Unauthorized Errors

**Symptom:** API calls return 403 Forbidden

**Causes:**
1. **Not Super Admin:** Check user role in database
2. **Invalid Token:** Token expired or invalid
3. **Middleware Issue:** EnsureSuperAdmin not registered

**Debug:**
```bash
# Check middleware registration
grep -r "super_admin" backend/bootstrap/app.php

# Should see:
# 'super_admin' => \App\Http\Middleware\EnsureSuperAdmin::class
```

### Impersonation Not Working

**Symptom:** Impersonate button does nothing or errors

**Solutions:**
1. **Cannot impersonate super admins:** This is by design for security
2. **Check user is active:** Cannot impersonate deactivated users
3. **Browser console errors:** Check DevTools for JavaScript errors
4. **API endpoint issue:** Verify backend is running and accessible

### Audit Logs Empty

**Symptom:** No logs appearing in admin portal

**Causes:**
1. **Fresh database:** No actions performed yet
2. **Migration not run:** `audit_logs` table doesn't exist
3. **Logging not triggered:** Check `AuditLog::log()` calls in controllers

**Verify:**
```sql
SELECT COUNT(*) FROM audit_logs;
SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 10;
```

### CSV Export Not Downloading

**Symptom:** Export button doesn't trigger download

**Solutions:**
1. **Browser popup blocker:** Check if download was blocked
2. **CORS issue:** Verify API CORS headers allow file downloads
3. **API error:** Open browser DevTools → Network tab → Check response

---

## Additional Resources

### Related Documentation

- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [API Documentation](./backend/README.md)
- [Database Schema](./backend/database/schema.md)
- [Security Policy](./SECURITY.md)

### Support

For issues or questions:
- 📧 Email: support@thirdbooks.digital
- 📝 GitHub Issues: https://github.com/SAVIOUR26/THIRD-BOOKS/issues
- 📚 Documentation: https://docs.thirdbooks.digital

---

## Changelog

### Phase 5 - Super Admin Portal (January 2024)

**Backend (Phase 5.1):**
- ✅ 28 API endpoints across 4 controllers
- ✅ Audit logging system with IP/user agent tracking
- ✅ EnsureSuperAdmin middleware
- ✅ MRR/ARR revenue analytics
- ✅ System health monitoring

**Frontend (Phase 5.2):**
- ✅ Admin dashboard with analytics
- ✅ Tenant management UI
- ✅ User management with impersonation
- ✅ Audit logs with CSV export
- ✅ Route guards and security

**Tools & Seeders:**
- ✅ SuperAdminSeeder for initial setup
- ✅ CreateSuperAdminCommand for CLI management
- ✅ Comprehensive documentation

---

**Last Updated:** January 22, 2024
**Version:** 1.0.0
**Status:** Production Ready ✅
