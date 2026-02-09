# 🚀 ThirdBooks - Complete Manual Installation Guide

## Overview

This guide will walk you through downloading and manually installing:
1. **Backend API** (Laravel) → api.thirdbooks.digital
2. **Admin Panel** (PHP) → admin.thirdbooks.digital
3. **Landing Page** (HTML/CSS/JS) → thirdbooks.digital
4. **Database** (MySQL via phpMyAdmin)

**Time Required:** 30-45 minutes
**Prerequisites:** DirectAdmin access, FTP client (optional)

---

# PART 1: DOWNLOAD FILES FROM GITHUB

## Option A: Download ZIP (Easiest)

1. **Go to Repository:**
   - Open: https://github.com/SAVIOUR26/THIRD-BOOKS

2. **Switch to Correct Branch:**
   - Click the branch dropdown (shows "main" or current branch)
   - Select: `claude/analyze-repo-changes-LzoUX`

3. **Download ZIP:**
   - Click green **"Code"** button
   - Click **"Download ZIP"**
   - Save to your computer (e.g., Desktop)

4. **Extract ZIP:**
   - Right-click downloaded file
   - Choose "Extract All" or "Unzip"
   - Extract to: `Desktop/THIRD-BOOKS/`

**Result:** You now have all files on your computer!

---

## Option B: Clone with Git (Advanced)

```bash
# Open terminal/command prompt
cd Desktop

# Clone repository
git clone https://github.com/SAVIOUR26/THIRD-BOOKS.git

# Enter directory
cd THIRD-BOOKS

# Switch to correct branch
git checkout claude/analyze-repo-changes-LzoUX
```

---

# PART 2: PREPARE FILES FOR UPLOAD

## Step 1: Prepare Backend API

### 1.1 Navigate to Backend Folder
```
Desktop/THIRD-BOOKS/backend/
```

### 1.2 Create .env File

**On Windows:**
1. Open `backend` folder
2. Find file: `.env.production`
3. Copy it (Ctrl+C)
4. Paste (Ctrl+V) in same folder
5. Rename copy to: `.env` (just ".env" - no .production)

**On Mac/Linux:**
```bash
cd Desktop/THIRD-BOOKS/backend/
cp .env.production .env
```

### 1.3 Edit .env File

Open `.env` with text editor (Notepad, VS Code, etc.)

**Update these lines:**
```env
# Change this:
APP_KEY=base64:GENERATE_THIS_WITH_php_artisan_key:generate

# To: (we'll generate this in next step)
APP_KEY=base64:YOUR_GENERATED_KEY_HERE

# Change database settings:
DB_DATABASE=thirdbooks_db
DB_USERNAME=your_directadmin_db_user
DB_PASSWORD=your_directadmin_db_password

# Update your domains:
APP_URL=https://api.thirdbooks.digital
FRONTEND_URL=https://thirdbooks.digital
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,www.thirdbooks.digital
```

**Save file!**

### 1.4 Generate APP_KEY

**If you have PHP installed locally:**

```bash
# Windows (Command Prompt):
cd Desktop\THIRD-BOOKS\backend
php artisan key:generate --show

# Mac/Linux (Terminal):
cd Desktop/THIRD-BOOKS/backend
php artisan key:generate --show
```

Copy the output (looks like: `base64:abc123xyz...`)
Paste into `.env` as `APP_KEY` value

**If you DON'T have PHP:**
- Use online generator: https://generate-random.org/laravel-key-generator
- Copy the generated key
- Paste into `.env` as `APP_KEY` value

### 1.5 Create .htaccess File

Create new file: `backend/.htaccess`

**Copy this content:**
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

<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
</IfModule>

Options -Indexes

<FilesMatch "^\.">
    Order allow,deny
    Deny from all
</FilesMatch>
```

**Save file!**

---

## Step 2: Prepare Admin Panel

Admin panel is ready! Just need to upload.

**Location:** `Desktop/THIRD-BOOKS/admin-panel/`

**What's inside:**
- index.php (main dashboard)
- login.php (admin login)
- tenants.php (manage tenants)
- users.php (user management)
- All configuration files

---

## Step 3: Prepare Landing Page

Landing page is ready! No changes needed.

**Location:** `Desktop/THIRD-BOOKS/landing-page/`

**Files to upload:**
- index.html
- css/ (folder with style.css)
- js/ (folder with main.js)
- images/ (folder with favicon.svg)

---

## Step 4: Prepare Database

**Location:** `Desktop/THIRD-BOOKS/database-export.sql`

This file is ready to import!

---

# PART 3: UPLOAD TO DIRECTADMIN

## Step 1: Setup Database FIRST

### 1.1 Login to DirectAdmin
- URL: Your DirectAdmin URL (usually: https://yourdomain.com:2222)
- Username: Your DA username
- Password: Your DA password

### 1.2 Create Database

1. Click **"MySQL Management"**
2. Click **"Create new database"** tab
3. Database name: `thirdbooks_db`
4. Click **"Create Database"**
5. ✅ Database created!

### 1.3 Create Database User

1. Still in MySQL Management
2. Click **"Create new user"** section
3. Username: `thirdbooks_user` (or choose your own)
4. Password: **Generate strong password** (click generate button)
5. **SAVE THIS PASSWORD!** You'll need it for .env file
6. Click **"Create User"**
7. ✅ User created!

### 1.4 Assign User to Database

1. Scroll to **"Add User to Database"** section
2. Select User: `thirdbooks_user`
3. Select Database: `thirdbooks_db`
4. Check: **"All Privileges"** (select all boxes)
5. Click **"Add User to Database"**
6. ✅ User has access!

### 1.5 Import Database Schema

1. In MySQL Management, click **"phpMyAdmin"** link
2. phpMyAdmin opens in new tab
3. On left sidebar, click: `thirdbooks_db` (your database)
4. Top menu, click: **"Import"** tab
5. Click **"Choose File"** button
6. Navigate to: `Desktop/THIRD-BOOKS/database-export.sql`
7. Select the file
8. Scroll down, click **"Go"** button
9. Wait 10-30 seconds...
10. ✅ Success message: "Import has been successfully finished"

**Verify:** On left sidebar, you should see 20+ tables:
- tenants
- users
- companies
- currencies
- accounts
- invoices
- customers
- etc.

---

## Step 2: Upload Backend API

### Option A: Using FTP Client (Recommended - Faster)

**Get FTP Credentials from DirectAdmin:**
1. In DirectAdmin, go to **"FTP Management"**
2. Note these details:
   - FTP Server: (your FTP host)
   - Username: (your FTP username)
   - Password: (your DirectAdmin password)
   - Port: 21

**Using FileZilla (or any FTP client):**

1. **Connect to FTP:**
   - Open FileZilla
   - Host: Your FTP server
   - Username: Your FTP username
   - Password: Your FTP password
   - Port: 21
   - Click **"Quickconnect"**

2. **Navigate on Remote (server):**
   - Right side shows server
   - Navigate to: `/domains/api.thirdbooks.digital/public_html/`
   - **Delete any default files** (index.html, default.php, etc.)

3. **Navigate on Local (your computer):**
   - Left side shows your computer
   - Navigate to: `Desktop/THIRD-BOOKS/backend/`

4. **Upload ALL backend files:**
   - Select ALL files and folders in `backend/`
   - Right-click → **"Upload"**
   - Wait for upload to complete (5-15 minutes depending on internet)
   - ✅ All files uploaded!

**IMPORTANT: Update .env on server with correct database password**
- Find `.env` file on server
- Right-click → **"View/Edit"**
- Update `DB_PASSWORD=` with the password you saved earlier
- Save file
- FileZilla will ask to re-upload → Click **"Yes"**

---

### Option B: Using DirectAdmin File Manager

**Upload via File Manager:**

1. **Open File Manager:**
   - In DirectAdmin, click **"File Manager"**
   - Navigate to: `/domains/api.thirdbooks.digital/public_html/`

2. **Clean Directory:**
   - Select any default files (index.html, etc.)
   - Click **"Delete"** button
   - Directory should be empty

3. **Upload Files:**
   - Click **"Upload Files"** button
   - Click **"Select Files"**
   - Navigate to: `Desktop/THIRD-BOOKS/backend/`
   - **Problem:** File Manager has upload limits!

**Solution: Upload in Batches**

Since File Manager limits file size/count, upload in batches:

**Batch 1 - Core Files:**
- Select and upload: `.env`, `.htaccess`, `artisan`, `composer.json`, `composer.lock`

**Batch 2 - App Folder:**
- Create folder: `app`
- Enter `app` folder
- Upload all files from `backend/app/`

**Batch 3 - Public Folder:**
- Upload files from `backend/public/` to root of `public_html/`

**Batch 4 - Other Folders:**
- Repeat for: `bootstrap/`, `config/`, `database/`, `resources/`, `routes/`, `storage/`

**This is tedious! FTP is much faster.**

---

### 2.1 Set File Permissions (CRITICAL!)

**Via DirectAdmin File Manager:**

1. In File Manager at: `/domains/api.thirdbooks.digital/public_html/`
2. Find `storage` folder
3. Right-click → **"Change Permissions"**
4. Check boxes for: `775` (Owner: rwx, Group: rwx, World: r-x)
5. Check: **"Apply to subdirectories"**
6. Click **"Save"**
7. Repeat for `bootstrap/cache` folder

**Via SSH (if you have access):**
```bash
cd /domains/api.thirdbooks.digital/public_html/
chmod -R 775 storage bootstrap/cache
```

---

## Step 3: Upload Admin Panel

### 3.1 Via FTP (FileZilla):

1. **Remote side:** Navigate to `/domains/admin.thirdbooks.digital/public_html/`
2. **Local side:** Navigate to `Desktop/THIRD-BOOKS/admin-panel/`
3. **Delete** any default files on server
4. **Upload** all files from `admin-panel/` folder
5. ✅ Admin panel uploaded!

### 3.2 Via DirectAdmin File Manager:

1. Navigate to: `/domains/admin.thirdbooks.digital/public_html/`
2. Delete default files
3. Click **"Upload Files"**
4. Upload all files from `Desktop/THIRD-BOOKS/admin-panel/`

---

## Step 4: Upload Landing Page

### 4.1 Via FTP (FileZilla):

1. **Remote side:** Navigate to `/domains/thirdbooks.digital/public_html/`
2. **Local side:** Navigate to `Desktop/THIRD-BOOKS/landing-page/`
3. **Delete** any default files on server
4. **Upload these files:**
   - `index.html` (upload to root!)
   - `css/` folder
   - `js/` folder
   - `images/` folder
5. ✅ Landing page uploaded!

**Verify structure on server:**
```
/domains/thirdbooks.digital/public_html/
├── index.html          ← Must be in root!
├── css/
│   └── style.css
├── js/
│   └── main.js
└── images/
    └── favicon.svg
```

### 4.2 Via DirectAdmin File Manager:

1. Navigate to: `/domains/thirdbooks.digital/public_html/`
2. Delete default files
3. Upload `index.html` to root
4. Create folders: `css`, `js`, `images`
5. Upload respective files into each folder

---

# PART 4: CONFIGURE & TEST

## Step 1: Create Super Admin User

### Via phpMyAdmin (Easiest):

1. **Open phpMyAdmin** (from DirectAdmin MySQL Management)
2. **Select database:** `thirdbooks_db`
3. **Click table:** `users`
4. **Click:** "Insert" tab
5. **Fill in:**
   - `name`: Admin
   - `email`: admin@thirdbooks.digital
   - `password`: *(we'll generate this next)*
   - `email_verified_at`: `2024-01-01 00:00:00` (or current date/time)
6. **For password:**
   - Go to: https://bcrypt-generator.com/
   - Enter your desired password (e.g., "Admin@123!")
   - Copy the bcrypt hash (starts with $2y$10$...)
   - Paste into `password` field in phpMyAdmin
7. **Click:** "Go" button
8. ✅ Admin user created!

**SAVE YOUR LOGIN:**
- Email: admin@thirdbooks.digital
- Password: (whatever you chose above)

---

## Step 2: Test Deployments

### 2.1 Test Landing Page

1. **Open browser**
2. **Visit:** https://thirdbooks.digital
3. **Expected:** Beautiful landing page loads with:
   - Hero section with "ThirdBooks" title
   - Features section
   - Pricing section
   - Professional design

**If it doesn't load:**
- Check `index.html` is in root of `/domains/thirdbooks.digital/public_html/`
- Check domain is pointing to correct directory in DirectAdmin
- Clear browser cache (Ctrl+Shift+Del)

---

### 2.2 Test Backend API

1. **Open browser**
2. **Visit:** https://api.thirdbooks.digital/api/health
3. **Expected:** JSON response:
```json
{
  "status": "ok",
  "timestamp": "2024-02-05T10:30:00Z",
  "database": "connected"
}
```

**If you get 500 error:**

**Check 1 - .env file:**
- Via File Manager, open: `api.thirdbooks.digital/public_html/.env`
- Verify `DB_PASSWORD` matches your database password
- Save if changed

**Check 2 - Permissions:**
```bash
chmod -R 775 storage bootstrap/cache
```

**Check 3 - View error logs:**
- DirectAdmin → **"Error Logs"**
- Or check: `storage/logs/laravel.log`

**Check 4 - Run migrations (if SSH available):**
```bash
cd /domains/api.thirdbooks.digital/public_html
php artisan migrate --force
php artisan config:cache
```

---

### 2.3 Test Admin Panel

1. **Visit:** https://admin.thirdbooks.digital
2. **Expected:** Admin login page
3. **Login with:**
   - Email: admin@thirdbooks.digital
   - Password: (your password from Step 1)
4. **Expected:** Admin dashboard loads

---

## Step 3: Test Desktop App Sync

### 3.1 Open Desktop App

1. Open ThirdBooks desktop application
2. You'll see login screen

### 3.2 Login

**Enter:**
- **Email:** admin@thirdbooks.digital
- **Password:** (your password)
- **API URL:** https://api.thirdbooks.digital
- Click **"Login"**

**Expected:** Dashboard loads with menu showing:
- Dashboard
- Accounts
- Customers
- Vendors
- Invoices
- Bills
- Journals
- Reports

---

### 3.3 Test Creating Data

**Create a Customer:**
1. Click **"Customers"** in sidebar
2. Click **"Add Customer"** button
3. Fill in:
   - Name: Test Customer
   - Email: test@example.com
   - Phone: +256-xxx-xxx-xxx
4. Click **"Save"**
5. ✅ Customer created!

**Verify Sync:**
1. Open phpMyAdmin
2. Select `thirdbooks_db` database
3. Click `customers` table
4. Click **"Browse"**
5. **Expected:** You see "Test Customer" in the table!
6. ✅ Desktop app is syncing with cloud!

---

### 3.4 Test Offline Mode

**Test Offline Functionality:**
1. In desktop app, toggle **"Offline Mode"** (if available)
2. Create another customer: "Offline Customer"
3. Save
4. Toggle **"Online Mode"**
5. Click **"Sync"** button
6. Check phpMyAdmin → `customers` table
7. **Expected:** "Offline Customer" appears!
8. ✅ Offline sync works!

---

# PART 5: POST-INSTALLATION

## Optional: Setup Cron Jobs (if available)

If DirectAdmin provides Cron Jobs:

1. **Go to:** DirectAdmin → **"Cronjobs"**
2. **Add cron:**
   - Command: `cd /domains/api.thirdbooks.digital/public_html && php artisan schedule:run`
   - Frequency: Every minute (`* * * * *`)
3. **Save**

This enables Laravel's task scheduler.

---

## Optional: Configure Email

Edit `/domains/api.thirdbooks.digital/public_html/.env`:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@thirdbooks.digital
MAIL_FROM_NAME="ThirdBooks"
```

---

# TROUBLESHOOTING

## Issue: "500 Internal Server Error" on Backend

**Solution 1 - Check .env:**
- Verify `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` are correct
- Verify `APP_KEY` is set

**Solution 2 - Check Permissions:**
```bash
chmod -R 775 storage bootstrap/cache
```

**Solution 3 - Clear Caches:**
```bash
php artisan config:clear
php artisan cache:clear
php artisan view:clear
```

**Solution 4 - Check Error Logs:**
- DirectAdmin → Error Logs
- Or: `storage/logs/laravel.log`

---

## Issue: Landing Page Not Loading

**Solution 1 - Check File Location:**
- `index.html` must be in: `/domains/thirdbooks.digital/public_html/index.html`
- Not in a subfolder!

**Solution 2 - Check Domain Setup:**
- DirectAdmin → Domains → thirdbooks.digital
- Verify points to correct `public_html/` directory

**Solution 3 - Clear Browser Cache:**
- Press Ctrl+Shift+Del
- Clear all cached images and files

---

## Issue: Desktop App Can't Connect

**Solution 1 - Check API URL:**
- Must be: `https://api.thirdbooks.digital` (no trailing slash!)
- Must be https:// (not http://)

**Solution 2 - Check CORS:**
- Edit `.env`:
```env
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,www.thirdbooks.digital
SESSION_DOMAIN=.thirdbooks.digital
```

**Solution 3 - Test API:**
- Visit: https://api.thirdbooks.digital/api/health
- Must return JSON, not HTML error

---

# SUCCESS CHECKLIST

- [ ] Database `thirdbooks_db` created
- [ ] Database user created with all privileges
- [ ] Database schema imported (20+ tables visible in phpMyAdmin)
- [ ] Backend files uploaded to `api.thirdbooks.digital/public_html/`
- [ ] `.env` configured with correct database credentials
- [ ] `storage/` and `bootstrap/cache/` permissions set to 775
- [ ] Admin panel uploaded to `admin.thirdbooks.digital/public_html/`
- [ ] Landing page uploaded to `thirdbooks.digital/public_html/`
- [ ] Landing page loads at https://thirdbooks.digital
- [ ] API health check works at https://api.thirdbooks.digital/api/health
- [ ] Super admin user created in `users` table
- [ ] Desktop app can login
- [ ] Desktop app can create customer
- [ ] Customer appears in phpMyAdmin
- [ ] Offline sync works

---

# YOU'RE DONE! 🎉

Your ThirdBooks installation is complete and ready to use!

**You now have:**
- ✅ Professional landing page
- ✅ Fully functional backend API
- ✅ Admin panel for management
- ✅ Desktop app syncing with cloud
- ✅ Offline-first accounting system
- ✅ Multi-currency support (UGX, USD, EUR, GBP, KES, TZS)
- ✅ Complete accounting features

**Next Steps:**
1. Create your first company
2. Set up your chart of accounts
3. Add customers and vendors
4. Start creating invoices
5. Track payments
6. Generate financial reports

**Enjoy ThirdBooks!** 🚀📊
