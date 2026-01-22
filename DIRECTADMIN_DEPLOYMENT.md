# ThirdBooks DirectAdmin Deployment Guide

Complete guide for deploying ThirdBooks backend and web frontend to **DirectAdmin shared hosting** at **thirdbooks.digital**.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Database Setup (Neon.tech PostgreSQL)](#database-setup-neontech-postgresql)
4. [Backend Deployment](#backend-deployment)
5. [Frontend Deployment](#frontend-deployment)
6. [DNS Configuration](#dns-configuration)
7. [SSL Certificate](#ssl-certificate)
8. [Testing](#testing)
9. [Maintenance](#maintenance)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### Architecture

```
┌─────────────────────────────────────────────────────┐
│         thirdbooks.digital (DirectAdmin)            │
│  ┌───────────────────────────────────────────────┐ │
│  │  Frontend: Vue.js Static Files                │ │
│  │  Location: public_html/                       │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │  Backend: Laravel API                         │ │
│  │  Location: public_html/api/                   │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                      │
                      │ PostgreSQL Connection
                      ▼
┌─────────────────────────────────────────────────────┐
│        Neon.tech (Free PostgreSQL Database)         │
│        - 512MB Storage (Free Forever)               │
│        - Serverless PostgreSQL                      │
└─────────────────────────────────────────────────────┘
```

### Why Neon.tech?

DirectAdmin shared hosting typically only supports **MySQL/MariaDB**. ThirdBooks requires **PostgreSQL** for:
- Event sourcing with advanced JSONB queries
- Row-level locking for conflict resolution
- Sequence generation for event ordering

**Neon.tech Solution:**
- ✅ Free 512MB PostgreSQL database (no credit card)
- ✅ Serverless with automatic scaling
- ✅ SSL connections
- ✅ Daily backups
- ✅ 99.9% uptime

---

## Prerequisites

### What You Need

1. **DirectAdmin Access**
   - URL: `https://your-server.com:2222`
   - Username: Your DirectAdmin username
   - Password: Your DirectAdmin password

2. **Domain Configured**
   - Domain: `thirdbooks.digital`
   - DNS pointing to your DirectAdmin server

3. **Local Development Tools**
   - Node.js 18+ (for building frontend)
   - Composer (for backend dependencies)
   - Git
   - FTP client (FileZilla) or SSH access

4. **Free Accounts**
   - Neon.tech account (for PostgreSQL)

---

## Database Setup (Neon.tech PostgreSQL)

### Step 1: Create Neon.tech Account

1. Go to https://neon.tech
2. Click "Sign Up" (use GitHub, Google, or email)
3. No credit card required!

### Step 2: Create Database

1. Click "Create Project"
2. **Project Name:** `thirdbooks`
3. **Region:** Choose closest to your users (e.g., US East, Europe, Asia)
4. **PostgreSQL Version:** 15 or 16
5. Click "Create Project"

### Step 3: Get Connection String

After project creation, you'll see:

```
Connection String:
postgresql://username:password@ep-xyz-123.us-east-2.aws.neon.tech/neondb?sslmode=require
```

**Save this!** You'll need it for backend configuration.

**Extract these values:**
```
DB_HOST=ep-xyz-123.us-east-2.aws.neon.tech
DB_PORT=5432
DB_DATABASE=neondb
DB_USERNAME=username
DB_PASSWORD=password
```

### Step 4: Create Tables (Later)

We'll run migrations after deploying the backend.

---

## Backend Deployment

### Step 1: Prepare Backend Locally

```bash
cd backend

# Install dependencies (production only)
composer install --no-dev --optimize-autoloader

# Clear any local caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
```

### Step 2: Create .env File

Create `backend/.env` with production settings:

```env
APP_NAME=ThirdBooks
APP_ENV=production
APP_KEY=   # Generate with: php artisan key:generate --show
APP_DEBUG=false
APP_URL=https://thirdbooks.digital

LOG_CHANNEL=stack
LOG_LEVEL=error

# Neon.tech PostgreSQL Database
DB_CONNECTION=pgsql
DB_HOST=ep-xyz-123.us-east-2.aws.neon.tech
DB_PORT=5432
DB_DATABASE=neondb
DB_USERNAME=your_username
DB_PASSWORD=your_password

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=database
SESSION_DRIVER=file
SESSION_LIFETIME=120

# Frontend URL
FRONTEND_URL=https://thirdbooks.digital

# CORS
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,www.thirdbooks.digital
SESSION_DOMAIN=.thirdbooks.digital

# Mail (configure later)
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@thirdbooks.digital
MAIL_FROM_NAME=ThirdBooks
```

**Generate APP_KEY:**
```bash
php artisan key:generate --show
# Copy the output to APP_KEY in .env
```

### Step 3: Upload Backend Files to DirectAdmin

**Option A: Using DirectAdmin File Manager**

1. Login to DirectAdmin: `https://your-server.com:2222`
2. Go to **File Manager**
3. Navigate to `public_html/`
4. Create folder: `api`
5. Upload all backend files **except** `public/*` to `public_html/api/`
6. Upload contents of `backend/public/*` to `public_html/api/`

**Final structure:**
```
public_html/
├── api/
│   ├── .env
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── routes/
│   ├── vendor/
│   ├── .htaccess        # From public/
│   ├── index.php        # From public/
│   └── ...
└── (frontend files will go here)
```

**Option B: Using FTP (FileZilla)**

1. Connect to your server:
   - **Host:** `ftp.thirdbooks.digital`
   - **Username:** Your DirectAdmin username
   - **Password:** Your DirectAdmin password
   - **Port:** 21

2. Navigate to `public_html/`
3. Create `api` folder
4. Upload backend files as described above

**Option C: Using SSH (if enabled)**

```bash
# Zip backend locally
cd backend
zip -r backend.zip . -x "node_modules/*" ".git/*"

# Upload via SCP
scp backend.zip username@thirdbooks.digital:~/public_html/

# SSH into server
ssh username@thirdbooks.digital

# Extract
cd public_html
mkdir api
unzip backend.zip -d api/
rm backend.zip

# Move public folder contents
mv api/public/* api/
mv api/public/.htaccess api/
rmdir api/public
```

### Step 4: Configure .htaccess for Laravel

Ensure `public_html/api/.htaccess` contains:

```apache
<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>

    RewriteEngine On

    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    # Redirect Trailing Slashes If Not A Folder...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_URI} (.+)/$
    RewriteRule ^ %1 [L,R=301]

    # Send Requests To Front Controller...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>

# Force HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# PHP Settings
php_value upload_max_filesize 20M
php_value post_max_size 20M
php_value max_execution_time 300
php_value memory_limit 256M
```

### Step 5: Set File Permissions

Via DirectAdmin File Manager:
1. Select `storage` folder → **Permissions** → `775`
2. Select `bootstrap/cache` → **Permissions** → `775`

Via SSH:
```bash
cd public_html/api
chmod -R 775 storage bootstrap/cache
```

### Step 6: Run Database Migrations

**Via SSH:**
```bash
cd public_html/api
php artisan migrate --force
php artisan db:seed --class=CurrencySeeder --force
php artisan db:seed --class=SuperAdminSeeder --force
```

**Via local terminal (if SSH not available):**

You can run migrations locally but pointed at production database:

```bash
# Update local .env to point to Neon.tech database
# Then run:
php artisan migrate --force
php artisan db:seed --class=CurrencySeeder --force
php artisan db:seed --class=SuperAdminSeeder --force
```

### Step 7: Optimize Laravel

```bash
cd public_html/api
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize
```

### Step 8: Setup Cron Job (for Scheduler)

In DirectAdmin:
1. Go to **Cron Jobs**
2. Click **Create Cron Job**
3. **Minute:** `*`
4. **Hour:** `*`
5. **Day:** `*`
6. **Month:** `*`
7. **Weekday:** `*`
8. **Command:**
   ```bash
   cd /home/username/public_html/api && php artisan schedule:run >> /dev/null 2>&1
   ```
   *(Replace `username` with your DirectAdmin username)*

---

## Frontend Deployment

### Step 1: Build Frontend Locally

```bash
cd web-app

# Install dependencies
npm install

# Create production .env
cat > .env << EOF
VITE_API_URL=https://thirdbooks.digital/api/api
EOF

# Build for production
npm run build
```

This creates `dist/` folder with optimized static files.

### Step 2: Upload to DirectAdmin

**Via File Manager:**
1. Go to DirectAdmin → **File Manager**
2. Navigate to `public_html/`
3. Upload **contents** of `dist/` folder (not the folder itself)
4. Final structure:
   ```
   public_html/
   ├── index.html
   ├── assets/
   │   ├── index-abc123.js
   │   ├── index-def456.css
   │   └── ...
   ├── favicon.ico
   └── api/
       └── (backend files)
   ```

**Via FTP:**
- Upload `dist/*` to `public_html/`

**Via SSH:**
```bash
# Locally, zip the dist folder
cd web-app
zip -r dist.zip dist/

# Upload
scp dist.zip username@thirdbooks.digital:~/public_html/

# SSH and extract
ssh username@thirdbooks.digital
cd public_html
unzip -o dist.zip
mv dist/* ./
rmdir dist
rm dist.zip
```

### Step 3: Configure .htaccess for SPA Routing

Create/edit `public_html/.htaccess`:

```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /

  # Don't rewrite if file/directory exists
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d

  # Don't rewrite API calls
  RewriteCond %{REQUEST_URI} !^/api/

  # Rewrite everything else to index.html
  RewriteRule ^ /index.html [L]
</IfModule>

# Force HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Cache static assets
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/jpg "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/gif "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/svg+xml "access plus 1 year"
  ExpiresByType text/css "access plus 1 month"
  ExpiresByType application/javascript "access plus 1 month"
</IfModule>

# Compression
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/css text/javascript application/javascript application/json
</IfModule>
```

---

## DNS Configuration

Ensure your domain DNS is configured:

### At Your Domain Registrar (e.g., Namecheap)

```
Type    Host    Value                           TTL
A       @       YOUR_DIRECTADMIN_SERVER_IP     300
A       www     YOUR_DIRECTADMIN_SERVER_IP     300
CNAME   api     thirdbooks.digital             300
```

**Get DirectAdmin Server IP:**
- Login to DirectAdmin
- Check top right corner or email from hosting provider

**Test DNS:**
```bash
dig thirdbooks.digital +short
# Should return your DirectAdmin server IP
```

**Allow 24-48 hours for DNS propagation.**

---

## SSL Certificate

### Option 1: Let's Encrypt (via DirectAdmin)

1. Login to DirectAdmin
2. Go to **SSL Certificates**
3. Click **Let's Encrypt**
4. Select:
   - ☑ `thirdbooks.digital`
   - ☑ `www.thirdbooks.digital`
5. Click **Save**

Certificate automatically renews every 90 days.

### Option 2: CloudFlare (Free SSL + CDN)

1. Sign up at https://cloudflare.com
2. Add domain: `thirdbooks.digital`
3. Update nameservers at your registrar to CloudFlare's
4. Enable **SSL/TLS** → **Full (strict)**
5. Enable **Always Use HTTPS**

Benefits:
- Free SSL
- CDN for faster loading
- DDoS protection
- Analytics

---

## Testing

### 1. Test Backend API

```bash
# Health check (create this endpoint if needed)
curl https://thirdbooks.digital/api/api/health

# Test login endpoint
curl -X POST https://thirdbooks.digital/api/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@thirdbooks.digital","password":"SuperAdmin@2024"}'
```

Expected: JSON response with token

### 2. Test Frontend

1. Visit https://thirdbooks.digital
2. Should load login page
3. Test login with super admin credentials
4. Navigate to different pages
5. Check browser console for errors

### 3. Test Super Admin Portal

1. Login with super admin account
2. Visit https://thirdbooks.digital/admin
3. Verify dashboard loads
4. Check tenant management
5. Check user management
6. Check audit logs

---

## Maintenance

### Updating Backend

```bash
# Locally, pull latest changes
git pull origin main
composer install --no-dev --optimize-autoloader

# Upload changed files to DirectAdmin
# Run migrations if any
php artisan migrate --force

# Clear caches
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Updating Frontend

```bash
# Locally
git pull origin main
npm install
npm run build

# Upload dist/* to public_html/
```

### Database Backups

**Neon.tech provides automatic daily backups** (7 days retention on free plan).

**Manual Export:**
1. Login to Neon.tech dashboard
2. Select project → **Settings** → **Export**
3. Download SQL dump

**Restore:**
```bash
psql -h ep-xyz.aws.neon.tech -U username -d neondb < backup.sql
```

### Monitoring

**Setup Uptime Monitoring:**
- UptimeRobot (free): https://uptimerobot.com
- Monitor: `https://thirdbooks.digital/api/api/health`

**Check Logs:**
- DirectAdmin → **File Manager** → `public_html/api/storage/logs/laravel.log`

---

## Troubleshooting

### Issue: 500 Internal Server Error

**Check Laravel logs:**
- DirectAdmin → File Manager → `api/storage/logs/laravel.log`

**Common causes:**
1. **File permissions:** Ensure `storage` and `bootstrap/cache` are 775
2. **.env missing or incorrect:** Verify database credentials
3. **APP_KEY not set:** Run `php artisan key:generate --show`

**Fix:**
```bash
chmod -R 775 storage bootstrap/cache
php artisan config:clear
```

### Issue: Database Connection Failed

**Verify Neon.tech connection:**
```bash
php artisan tinker
DB::connection()->getPdo();
```

If fails:
- Check DB_HOST, DB_USERNAME, DB_PASSWORD in `.env`
- Verify Neon.tech database is active (login to dashboard)
- Check SSL mode: `?sslmode=require` should be in connection string

### Issue: CORS Errors

**Update backend config:**

Edit `public_html/api/config/cors.php`:
```php
'paths' => ['api/*', 'sanctum/csrf-cookie'],
'allowed_origins' => [
    'https://thirdbooks.digital',
    'https://www.thirdbooks.digital',
],
'supports_credentials' => true,
```

Then:
```bash
php artisan config:cache
```

### Issue: Frontend Shows Blank Page

**Check browser console:**
- Right-click → Inspect → Console tab
- Look for errors

**Common causes:**
1. **API URL wrong:** Check `VITE_API_URL` in build
2. **CORS issues:** See above
3. **.htaccess missing:** Ensure SPA routing works

### Issue: Schedule Not Running

**Verify cron job:**
```bash
# SSH into server
crontab -l

# Should see:
* * * * * cd /home/username/public_html/api && php artisan schedule:run >> /dev/null 2>&1
```

**Test manually:**
```bash
cd public_html/api
php artisan schedule:run
```

### Issue: File Upload Fails

**Increase PHP limits in `.htaccess`:**
```apache
php_value upload_max_filesize 50M
php_value post_max_size 50M
php_value max_execution_time 600
php_value memory_limit 512M
```

---

## Cost Summary

| Service | Cost |
|---------|------|
| **DirectAdmin Hosting** | $5-10/month (existing) |
| **Domain** | $12/year |
| **Neon.tech PostgreSQL** | **FREE** (512MB) |
| **SSL Certificate** | **FREE** (Let's Encrypt) |
| **Total** | **~$6-11/month** |

---

## Next Steps

After deployment:

1. ✅ Create super admin account
2. ✅ Test all features
3. ✅ Setup monitoring (UptimeRobot)
4. ✅ Configure automated backups
5. ✅ Build and distribute desktop app
6. ✅ Create first tenant account
7. ✅ Train users
8. ✅ Go live!

---

## Desktop App Distribution

The desktop app runs independently and connects to your deployed backend:

1. **Build desktop app** (see `web-app/DESKTOP_APP_README.md`)
2. **Distribute installers** to users:
   - Windows: `.msi` or `.exe`
   - macOS: `.dmg`
   - Linux: `.AppImage` or `.deb`
3. **Users install and run locally**
4. **App connects to:** `https://thirdbooks.digital/api/api`

Desktop app automatically detects API URL and works offline with local SQLite database.

---

## Support

Need help?
- 📧 Email: support@thirdbooks.digital
- 📚 Docs: ADMIN_PORTAL_GUIDE.md
- 🖥️ Desktop: DESKTOP_APP_README.md

---

**Last Updated:** January 22, 2024
**Version:** 1.0.0
**Tested:** DirectAdmin + Neon.tech PostgreSQL ✅
