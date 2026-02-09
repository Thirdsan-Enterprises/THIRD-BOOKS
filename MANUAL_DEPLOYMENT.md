# ThirdBooks - Manual DirectAdmin Deployment Guide

## 📦 What You're Deploying

This guide walks you through manually uploading ThirdBooks to your DirectAdmin hosting.

---

## 📂 Files to Upload

### 1. Backend API (`backend/`)
**Upload to:** `/domains/api.thirdbooks.digital/public_html/`

**What to upload:**
- All files from `backend/` folder EXCEPT:
  - `.git/` folder
  - `node_modules/` folder
  - `tests/` folder
  - `.env` file (you'll create this)

**Important:** The contents of `backend/public/` should be in the root of `public_html/`

### 2. Landing Page (`landing-page/`)
**Upload to:** `/domains/thirdbooks.digital/public_html/`

**What to upload:**
- `index.html` (must be in root)
- `css/` folder
- `js/` folder
- `images/` folder

### 3. Database
**Import via:** DirectAdmin → MySQL Management → phpMyAdmin

**File:** `database-export.sql`

---

## 🚀 Step-by-Step Deployment

### STEP 1: Prepare Database

1. **Login to DirectAdmin**
   - URL: Your DirectAdmin URL (usually port 2222)

2. **Create MySQL Database**
   - Go to: **MySQL Management** → **Create new database**
   - Database name: `thirdbooks_db`
   - Click **Create**

3. **Create Database User**
   - Username: `thirdbooks_user`
   - Password: [Generate strong password]
   - Click **Create**

4. **Assign User to Database**
   - Select database: `thirdbooks_db`
   - Select user: `thirdbooks_user`
   - Grant: **All Privileges**
   - Click **Add User to Database**

5. **Import Database Schema**
   - Click **phpMyAdmin** link
   - Select `thirdbooks_db` database
   - Click **Import** tab
   - Choose file: `database-export.sql`
   - Click **Go**
   - Wait for success message

---

### STEP 2: Upload Backend Files

#### Option A: DirectAdmin File Manager

1. **Navigate to Backend Directory**
   - Go to: **File Manager**
   - Navigate to: `/domains/api.thirdbooks.digital/public_html/`

2. **Delete Default Files** (if any)
   - Delete `index.html`, `default.php`, etc.

3. **Upload Backend Files**
   - Click **Upload Files**
   - Upload all files from `backend/` folder
   - **IMPORTANT:** Upload the contents, not the folder itself

4. **Create .env File**
   - Click **Create New File**
   - Name: `.env`
   - Copy contents from `backend/.env.production`
   - Update these values:
     ```
     APP_KEY=base64:... (generate below)
     DB_DATABASE=thirdbooks_db
     DB_USERNAME=thirdbooks_user
     DB_PASSWORD=YOUR_DB_PASSWORD_FROM_STEP1
     ```

#### Option B: FTP (Faster for large uploads)

1. **Connect via FTP**
   - Host: Your FTP host (from DirectAdmin)
   - Username: Your FTP username
   - Password: Your FTP password
   - Port: 21

2. **Navigate to:**
   - `/domains/api.thirdbooks.digital/public_html/`

3. **Upload all backend files**

4. **Create .env file** (same as Option A step 4)

---

### STEP 3: Configure Backend

#### 3.1 Generate Application Key

**Via DirectAdmin Terminal (if available):**
```bash
cd /domains/api.thirdbooks.digital/public_html
php artisan key:generate
```

**OR Generate Manually:**
```bash
# On your local machine:
cd backend
php artisan key:generate --show

# Copy the output (looks like: base64:xxx...)
# Paste into .env file as APP_KEY value
```

#### 3.2 Set File Permissions

**Via DirectAdmin File Manager:**
- Right-click `storage/` folder → **Change Permissions** → `775`
- Right-click `bootstrap/cache/` folder → **Change Permissions** → `775`

**Via SSH/Terminal:**
```bash
cd /domains/api.thirdbooks.digital/public_html
chmod -R 775 storage bootstrap/cache
chown -R nobody:nobody storage bootstrap/cache
```

#### 3.3 Run Migrations

**Via Terminal:**
```bash
cd /domains/api.thirdbooks.digital/public_html
php artisan migrate --force
php artisan db:seed --force
```

**If no terminal access:**
- Database is already imported from SQL file in Step 1
- Skip this step

#### 3.4 Cache Configuration

**Via Terminal:**
```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

#### 3.5 Create .htaccess

Create `.htaccess` in `/domains/api.thirdbooks.digital/public_html/`:

```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    
    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
    
    # Redirect to index.php
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
</IfModule>

# Disable Directory Listing
Options -Indexes

# Protect .env and other sensitive files
<FilesMatch "^\.">
    Order allow,deny
    Deny from all
</FilesMatch>
```

---

### STEP 4: Upload Landing Page

1. **Navigate to Landing Directory**
   - Go to: **File Manager**
   - Navigate to: `/domains/thirdbooks.digital/public_html/`

2. **Delete Default Files**
   - Delete any default files (index.html, etc.)

3. **Upload Landing Page Files**
   - Upload `index.html` to root
   - Upload `css/` folder
   - Upload `js/` folder
   - Upload `images/` folder

4. **Verify Structure:**
   ```
   /domains/thirdbooks.digital/public_html/
   ├── index.html
   ├── css/
   │   └── style.css
   ├── js/
   │   └── main.js
   └── images/
       └── favicon.svg
   ```

---

### STEP 5: Test Deployment

#### Test Landing Page
1. **Visit:** https://thirdbooks.digital
2. **Expected:** Beautiful landing page loads
3. **Check:** All sections, images, and links work

#### Test Backend API
1. **Visit:** https://api.thirdbooks.digital/api/health
2. **Expected:** JSON response:
   ```json
   {
     "status": "ok",
     "timestamp": "2024-...",
     "database": "connected",
     "redis": "disconnected"
   }
   ```

**If you get 500 error:**
- Check `.env` database credentials
- Check file permissions
- Check error logs in DirectAdmin

---

### STEP 6: Create Super Admin User

**Via Terminal:**
```bash
cd /domains/api.thirdbooks.digital/public_html
php artisan tinker

# In tinker:
$user = new App\Models\User();
$user->name = 'Admin';
$user->email = 'admin@thirdbooks.digital';
$user->password = bcrypt('your-secure-password');
$user->email_verified_at = now();
$user->save();
```

**OR via phpMyAdmin:**
1. Go to `users` table
2. Click **Insert**
3. Fill in:
   - `name`: Admin
   - `email`: admin@thirdbooks.digital
   - `password`: [Use online bcrypt generator]
   - `email_verified_at`: Current timestamp
4. Click **Go**

---

### STEP 7: Test Desktop App Sync

1. **Open Desktop App**
2. **Login with:**
   - Email: admin@thirdbooks.digital
   - Password: [your password from step 6]
   - API URL: https://api.thirdbooks.digital

3. **Test Sync:**
   - Create a customer
   - Create an invoice
   - Check if data appears in phpMyAdmin
   - Toggle offline mode
   - Make changes offline
   - Go back online
   - Verify sync works

---

## 🔧 Troubleshooting

### Backend Returns 500 Error

**Check:**
1. `.env` file exists and is configured correctly
2. Database credentials are correct
3. File permissions are set (775 for storage/)
4. PHP version is 8.3+ (check in DirectAdmin)

**View Logs:**
- DirectAdmin → **Error Logs**
- Or check: `storage/logs/laravel.log`

### Landing Page Not Loading

**Check:**
1. `index.html` is in root of `public_html/`
2. Domain points to correct directory in DirectAdmin
3. No .htaccess redirecting elsewhere

### Database Connection Failed

**Check:**
1. Database name, username, password in `.env`
2. Database user has privileges on database
3. MySQL service is running

### CORS Errors in Desktop App

**Update .env:**
```env
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,www.thirdbooks.digital
SESSION_DOMAIN=.thirdbooks.digital
```

**Restart app after changing .env**

---

## 📋 Post-Deployment Checklist

- [ ] Landing page loads at https://thirdbooks.digital
- [ ] API health endpoint works at https://api.thirdbooks.digital/api/health
- [ ] Database connection successful
- [ ] Super admin user created
- [ ] Desktop app can login
- [ ] Desktop app can sync data
- [ ] Offline mode works in desktop app
- [ ] File permissions set correctly
- [ ] SSL certificates active (HTTPS)
- [ ] Error logs are clean

---

## 🎉 Success!

Your ThirdBooks deployment is complete! You now have:
- ✅ Professional landing page
- ✅ Fully functional backend API
- ✅ Desktop app syncing with cloud
- ✅ Offline-first accounting system

---

## 📞 Need Help?

If you encounter issues:
1. Check DirectAdmin error logs
2. Check `storage/logs/laravel.log`
3. Verify all steps were completed
4. Check file permissions
5. Verify database credentials

---

**Deployed:** $(date)
**Version:** 1.0.0
**Platform:** DirectAdmin Shared Hosting
