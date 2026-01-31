# ThirdBooks Deployment Guide

## Deployment to DirectAdmin Shared Hosting

This guide covers deploying ThirdBooks to your DirectAdmin shared hosting:
- **API Backend**: api.thirdbooks.digital
- **Admin Panel**: thirdbooks.digital

---

## Prerequisites

Before starting, ensure you have:
- [ ] FTP access to your hosting account
- [ ] DirectAdmin control panel access
- [ ] MySQL database credentials
- [ ] Domain DNS configured (both api.thirdbooks.digital and thirdbooks.digital)

---

## Step 1: Create Database

### 1.1 Login to DirectAdmin
1. Go to your DirectAdmin panel
2. Navigate to **MySQL Management** or **Databases**

### 1.2 Create Database
1. Create a new database (e.g., `thirdbooks_db`)
2. Create a database user (e.g., `thirdbooks_user`)
3. Assign ALL privileges to the user on the database
4. **Note down**: Database name, username, and password

### 1.3 Import Database Schema
1. Go to **phpMyAdmin** in DirectAdmin
2. Select your newly created database
3. Click **Import** tab
4. Upload `deployment/database.sql`
5. Click **Go** to import

**After import, you'll have:**
- All required tables created
- Default currencies (UGX, USD, EUR, etc.)
- Super admin user: `admin@thirdbooks.digital` (password: `Admin@123`)
- Demo tenant with chart of accounts

---

## Step 2: Deploy API Backend (api.thirdbooks.digital)

### 2.1 Prepare Laravel Files
The backend is in the `backend/` folder. Before uploading:

1. **Copy production .env**:
   ```bash
   cp deployment/api/.env.production backend/.env
   ```

2. **Edit backend/.env** with your database credentials:
   ```env
   DB_DATABASE=your_database_name
   DB_USERNAME=your_database_user
   DB_PASSWORD=your_database_password
   ```

3. **Generate APP_KEY** (run locally if you have PHP):
   ```bash
   cd backend
   php artisan key:generate
   ```
   Or manually set a random 32-character base64 key.

### 2.2 Upload Files via FTP

1. Connect to your FTP using:
   - Host: ftp.thirdbooks.digital (or your FTP host)
   - Username: Your FTP username
   - Password: Your FTP password

2. Navigate to `domains/api.thirdbooks.digital/public_html/` (or equivalent)

3. Upload the entire contents of `backend/` folder:
   ```
   backend/
   ├── app/
   ├── bootstrap/
   ├── config/
   ├── database/
   ├── public/
   ├── resources/
   ├── routes/
   ├── storage/
   ├── vendor/         ← If exists, upload this too
   ├── .env            ← With your production settings
   ├── artisan
   ├── composer.json
   └── ...
   ```

### 2.3 Configure Document Root

**IMPORTANT**: Laravel's entry point is the `public/` folder.

**Option A: DirectAdmin Document Root** (Preferred)
1. In DirectAdmin, go to **Domain Setup**
2. Find api.thirdbooks.digital
3. Set Document Root to: `public_html/public`

**Option B: Using .htaccess** (If can't change document root)
1. Upload `deployment/api/.htaccess` to the root (`public_html/`)
2. Create this redirect .htaccess in root:
   ```apache
   <IfModule mod_rewrite.c>
       RewriteEngine On
       RewriteRule ^(.*)$ public/$1 [L]
   </IfModule>
   ```

### 2.4 Set Folder Permissions

Via FTP or SSH, set these permissions:
```bash
chmod -R 755 storage/
chmod -R 755 bootstrap/cache/
```

### 2.5 Install Dependencies (if vendor/ not uploaded)

If you have SSH access:
```bash
cd /path/to/api.thirdbooks.digital/public_html
composer install --no-dev --optimize-autoloader
```

If no SSH, upload the `vendor/` folder from your local installation.

### 2.6 Verify API is Working

1. Visit: https://api.thirdbooks.digital
2. You should see:
   ```json
   {
     "name": "ThirdBooks API",
     "version": "1.0.0",
     "status": "running"
   }
   ```

3. Test health endpoint: https://api.thirdbooks.digital/health

---

## Step 3: Deploy Admin Panel (thirdbooks.digital)

### 3.1 Update Configuration

1. Edit `admin-panel/config/config.php`:
   ```php
   define('DB_HOST', 'localhost');
   define('DB_NAME', 'your_database_name');      // Same as API
   define('DB_USER', 'your_database_user');
   define('DB_PASS', 'your_database_password');
   ```

### 3.2 Upload Files via FTP

1. Navigate to `domains/thirdbooks.digital/public_html/`

2. Upload the entire contents of `admin-panel/` folder:
   ```
   admin-panel/
   ├── config/
   │   └── config.php      ← With your DB credentials
   ├── views/
   │   └── layouts/
   ├── assets/
   ├── logs/               ← Create this folder
   ├── index.php
   ├── login.php
   ├── logout.php
   ├── tenants.php
   └── ...
   ```

### 3.3 Create Required Folders

Via FTP, create these folders with write permissions:
```
logs/       (chmod 755)
uploads/    (chmod 755)
```

### 3.4 Verify Admin Panel is Working

1. Visit: https://thirdbooks.digital/login.php
2. Login with:
   - Email: `admin@thirdbooks.digital`
   - Password: `Admin@123`
3. You should see the admin dashboard

---

## Step 4: SSL Certificates

### DirectAdmin AutoSSL
1. Go to **SSL Certificates** in DirectAdmin
2. Enable **Let's Encrypt** for both domains:
   - thirdbooks.digital
   - api.thirdbooks.digital
3. Force HTTPS redirect

---

## Step 5: Post-Deployment Security

### 5.1 Change Default Passwords
**CRITICAL**: Change the default admin password immediately!

1. Login to admin panel
2. Go to Settings or use phpMyAdmin to update:
   ```sql
   UPDATE users
   SET password = '$2y$12$YOUR_NEW_HASH'
   WHERE email = 'admin@thirdbooks.digital';
   ```

### 5.2 Secure Sensitive Files

Ensure these files are protected (add to .htaccess):
```apache
<FilesMatch "^\.env$">
    Order allow,deny
    Deny from all
</FilesMatch>
```

### 5.3 Update CORS Settings

In `backend/.env`, update:
```env
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,api.thirdbooks.digital
FRONTEND_URL=https://thirdbooks.digital
```

---

## File Structure After Deployment

```
DirectAdmin Hosting
├── domains/
│   ├── api.thirdbooks.digital/
│   │   └── public_html/
│   │       ├── app/
│   │       ├── bootstrap/
│   │       ├── config/
│   │       ├── public/          ← Document root should point here
│   │       │   ├── index.php
│   │       │   └── .htaccess
│   │       ├── storage/
│   │       ├── vendor/
│   │       └── .env
│   │
│   └── thirdbooks.digital/
│       └── public_html/
│           ├── config/
│           │   └── config.php
│           ├── views/
│           ├── logs/
│           ├── index.php
│           ├── login.php
│           └── ...
```

---

## Troubleshooting

### API Returns 500 Error
1. Check `storage/logs/laravel.log` for errors
2. Verify `.env` database credentials
3. Ensure `storage/` and `bootstrap/cache/` are writable

### Database Connection Failed
1. Verify database credentials in `.env` or `config.php`
2. Ensure database user has proper permissions
3. Check if MySQL is running

### Admin Panel Login Not Working
1. Verify database has the users table with admin user
2. Check password hash is correct in database
3. Clear browser cookies and try again

### CORS Errors from Desktop App
1. Update `SANCTUM_STATEFUL_DOMAINS` in `.env`
2. Clear Laravel cache:
   ```bash
   php artisan config:clear
   php artisan cache:clear
   ```

---

## Default Login Credentials

| Application | Email | Password |
|-------------|-------|----------|
| Admin Panel | admin@thirdbooks.digital | Admin@123 |
| Demo Tenant | demo@thirdbooks.digital | Demo@123 |

**⚠️ CHANGE THESE IMMEDIATELY AFTER DEPLOYMENT!**

---

## Next Steps After Deployment

1. ✅ Change all default passwords
2. ✅ Configure SSL certificates
3. ✅ Test API endpoints
4. ✅ Test admin panel functions
5. ✅ Update desktop app to point to production API
6. ✅ Configure email settings in `.env`
7. ✅ Set up database backups

---

## Support

For issues or questions:
- Check the logs: `storage/logs/` (API) or `logs/` (Admin)
- Review DirectAdmin error logs
- Ensure PHP version is 8.1 or higher
