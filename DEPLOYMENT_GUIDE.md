# ThirdBooks Deployment Guide

## Overview

This guide covers deploying ThirdBooks to production, including your specific setup with **thirdbooks.digital** on **DirectAdmin shared hosting**.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Deployment Options](#deployment-options)
3. [Recommended: Hybrid Deployment](#recommended-hybrid-deployment)
4. [Backend Deployment (VPS)](#backend-deployment-vps)
5. [Frontend Deployment (Shared Hosting)](#frontend-deployment-shared-hosting)
6. [Database Setup](#database-setup)
7. [Environment Configuration](#environment-configuration)
8. [Post-Deployment Setup](#post-deployment-setup)
9. [SSL/HTTPS Configuration](#sslhttps-configuration)
10. [Monitoring & Maintenance](#monitoring--maintenance)

---

## Architecture Overview

### ThirdBooks Stack

**Backend (Laravel 11):**
- PHP 8.2+
- PostgreSQL 14+ (required for event sourcing)
- Redis (for queues and caching)
- Composer for dependencies

**Frontend (Vue.js 3):**
- Node.js 18+ (for building)
- Static files (HTML, CSS, JS)
- Nginx or Apache for serving

**Mobile (Flutter):**
- Android APK
- iOS IPA (requires Apple Developer account)

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **Backend** | | |
| CPU | 1 core | 2+ cores |
| RAM | 1 GB | 2-4 GB |
| Storage | 10 GB | 20+ GB SSD |
| PHP | 8.2 | 8.3 |
| PostgreSQL | 14 | 15+ |
| **Frontend** | | |
| Static hosting | Any | CDN |
| Build | Node 18 | Node 20 |

---

## Deployment Options

### Option A: All-in-One VPS (Recommended)

**Pros:**
- ✅ Full control over environment
- ✅ PostgreSQL support guaranteed
- ✅ Easy to scale
- ✅ Can run background jobs
- ✅ Better performance

**Cons:**
- ❌ Higher cost ($5-20/month)
- ❌ Requires server management

**Providers:**
- DigitalOcean ($6/month)
- Vultr ($6/month)
- Linode ($5/month)
- Hetzner ($4/month)

### Option B: Hybrid (Frontend on Shared, Backend on VPS)

**Pros:**
- ✅ Use existing shared hosting for frontend
- ✅ VPS only for backend (can use small instance)
- ✅ Cost-effective ($4-6/month for VPS)
- ✅ PostgreSQL support on VPS

**Cons:**
- ❌ Manage two environments
- ❌ CORS configuration needed

**Recommended for your setup!**

### Option C: Shared Hosting Only

**Pros:**
- ✅ No additional costs
- ✅ Simple deployment

**Cons:**
- ❌ Most shared hosts don't support PostgreSQL
- ❌ Limited to MySQL (breaks event sourcing)
- ❌ No Redis support
- ❌ Limited background job processing
- ❌ Performance constraints

**Not recommended for ThirdBooks** due to PostgreSQL requirement.

---

## Recommended: Hybrid Deployment

This is the best approach for your **thirdbooks.digital** setup.

### Architecture

```
┌─────────────────────────────────────────────┐
│           thirdbooks.digital                │
│         (DirectAdmin Shared Hosting)        │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │  Vue.js Frontend (Static Files)    │    │
│  │  - /index.html                     │    │
│  │  - /assets/*                       │    │
│  │  - /admin/*                        │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
              │
              │ API Calls (HTTPS)
              ▼
┌─────────────────────────────────────────────┐
│        api.thirdbooks.digital               │
│              (VPS - Ubuntu)                 │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │  Laravel Backend                   │    │
│  │  - Nginx + PHP-FPM                 │    │
│  │  - PostgreSQL                      │    │
│  │  - Redis                           │    │
│  │  - Queue Workers                   │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### DNS Configuration

Set up these DNS records in your domain registrar:

```
# Main domain - Points to shared hosting
thirdbooks.digital         A      203.0.113.10  (Shared hosting IP)
www.thirdbooks.digital     CNAME  thirdbooks.digital

# API subdomain - Points to VPS
api.thirdbooks.digital     A      198.51.100.50 (VPS IP)
```

---

## Backend Deployment (VPS)

### 1. Choose VPS Provider

**Recommended: DigitalOcean ($6/month)**

1. Sign up at https://digitalocean.com
2. Create Droplet:
   - **Image:** Ubuntu 22.04 LTS
   - **Plan:** Basic ($6/month - 1GB RAM, 1 CPU, 25GB SSD)
   - **Datacenter:** Choose closest to your users
   - **Hostname:** `thirdbooks-api`

**Alternative: Hetzner ($4/month - cheaper, good performance)**

### 2. Initial Server Setup

SSH into your VPS:

```bash
ssh root@198.51.100.50
```

**Update system:**

```bash
apt update && apt upgrade -y
```

**Create deployment user:**

```bash
adduser deploy
usermod -aG sudo deploy
su - deploy
```

**Install dependencies:**

```bash
# PHP 8.3
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.3 php8.3-fpm php8.3-cli php8.3-common \
  php8.3-pgsql php8.3-redis php8.3-xml php8.3-mbstring \
  php8.3-curl php8.3-zip php8.3-bcmath php8.3-intl

# PostgreSQL 15
sudo apt install -y postgresql postgresql-contrib

# Redis
sudo apt install -y redis-server

# Nginx
sudo apt install -y nginx

# Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Git
sudo apt install -y git
```

### 3. Database Setup

```bash
# Login as postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE thirdbooks;
CREATE USER thirdbooks_user WITH PASSWORD 'YourSecurePassword123!';
GRANT ALL PRIVILEGES ON DATABASE thirdbooks TO thirdbooks_user;
\q
```

**Test connection:**

```bash
psql -h localhost -U thirdbooks_user -d thirdbooks
# Enter password when prompted
# If successful, you'll see: thirdbooks=>
\q
```

### 4. Deploy Laravel Backend

```bash
# Clone repository
cd /var/www
sudo mkdir thirdbooks-api
sudo chown deploy:deploy thirdbooks-api
cd thirdbooks-api
git clone https://github.com/SAVIOUR26/THIRD-BOOKS.git .

# Install dependencies
cd backend
composer install --optimize-autoloader --no-dev

# Set permissions
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

### 5. Environment Configuration

```bash
cd /var/www/thirdbooks-api/backend
cp .env.example .env
nano .env
```

**Update .env:**

```env
APP_NAME="ThirdBooks"
APP_ENV=production
APP_KEY=  # Generate with: php artisan key:generate
APP_DEBUG=false
APP_URL=https://api.thirdbooks.digital

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=thirdbooks
DB_USERNAME=thirdbooks_user
DB_PASSWORD=YourSecurePassword123!

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# CORS - Allow your frontend domain
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,www.thirdbooks.digital
SESSION_DOMAIN=.thirdbooks.digital

# Frontend URL
FRONTEND_URL=https://thirdbooks.digital
```

**Generate key:**

```bash
php artisan key:generate
```

### 6. Run Migrations & Seeders

```bash
# Run migrations
php artisan migrate --force

# Seed currencies
php artisan db:seed --class=CurrencySeeder

# Create super admin
php artisan admin:create-super \
  --email="your.email@example.com" \
  --name="Your Name" \
  --password="YourSecurePassword123!"
```

### 7. Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/thirdbooks-api
```

**Nginx config:**

```nginx
server {
    listen 80;
    server_name api.thirdbooks.digital;
    root /var/www/thirdbooks-api/backend/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

**Enable site:**

```bash
sudo ln -s /etc/nginx/sites-available/thirdbooks-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 8. Setup SSL (Let's Encrypt)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.thirdbooks.digital
```

Follow prompts:
- Enter email
- Agree to terms
- Choose: Redirect HTTP to HTTPS (option 2)

**Auto-renewal:**

```bash
sudo certbot renew --dry-run
```

### 9. Setup Queue Workers

```bash
sudo nano /etc/systemd/system/thirdbooks-worker.service
```

**Service file:**

```ini
[Unit]
Description=ThirdBooks Queue Worker
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/thirdbooks-api/backend
ExecStart=/usr/bin/php artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Start worker:**

```bash
sudo systemctl enable thirdbooks-worker
sudo systemctl start thirdbooks-worker
sudo systemctl status thirdbooks-worker
```

### 10. Setup Scheduler

```bash
sudo crontab -e
```

**Add line:**

```cron
* * * * * cd /var/www/thirdbooks-api/backend && php artisan schedule:run >> /dev/null 2>&1
```

---

## Frontend Deployment (Shared Hosting)

### 1. Build Frontend Locally

```bash
cd web-app

# Update API URL in .env
nano .env
```

**Update .env:**

```env
VITE_API_URL=https://api.thirdbooks.digital/api
```

**Build:**

```bash
npm install
npm run build
```

This creates a `dist/` folder with static files.

### 2. Upload to DirectAdmin

**Option A: File Manager (DirectAdmin)**

1. Login to DirectAdmin: https://your-server:2222
2. Go to **File Manager**
3. Navigate to `public_html/`
4. Upload entire `dist/` folder contents
5. Ensure `index.html` is in root of `public_html/`

**Option B: FTP**

```bash
# Using FileZilla or similar
Host: ftp.thirdbooks.digital
Username: your-directadmin-username
Password: your-directadmin-password
Port: 21

# Upload dist/* to /public_html/
```

**Option C: SCP (if SSH access enabled)**

```bash
scp -r dist/* your-username@thirdbooks.digital:~/public_html/
```

### 3. Configure .htaccess (for SPA routing)

Create `.htaccess` in `public_html/`:

```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  RewriteRule ^index\.html$ - [L]
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule . /index.html [L]
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
  ExpiresByType application/pdf "access plus 1 month"
  ExpiresByType application/x-font-ttf "access plus 1 year"
  ExpiresByType application/x-font-woff "access plus 1 year"
</IfModule>

# Compression
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html
  AddOutputFilterByType DEFLATE text/css
  AddOutputFilterByType DEFLATE text/javascript
  AddOutputFilterByType DEFLATE application/javascript
  AddOutputFilterByType DEFLATE application/json
</IfModule>
```

### 4. Setup SSL (DirectAdmin)

1. Login to DirectAdmin
2. Go to **SSL Certificates**
3. Select **Let's Encrypt**
4. Check `thirdbooks.digital` and `www.thirdbooks.digital`
5. Click **Save**

---

## Database Setup

### PostgreSQL Configuration

**Optimize for production:**

```bash
sudo nano /etc/postgresql/15/main/postgresql.conf
```

**Key settings:**

```conf
# Memory
shared_buffers = 256MB          # 25% of RAM (for 1GB VPS)
effective_cache_size = 768MB    # 75% of RAM
work_mem = 4MB                   # Per-operation memory
maintenance_work_mem = 64MB      # For VACUUM, etc

# Connections
max_connections = 100

# Logging
log_statement = 'ddl'            # Log schema changes
log_min_duration_statement = 1000 # Log slow queries (>1s)
```

**Restart PostgreSQL:**

```bash
sudo systemctl restart postgresql
```

### Backup Strategy

**Automated daily backups:**

```bash
sudo nano /usr/local/bin/thirdbooks-backup.sh
```

**Backup script:**

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/thirdbooks"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="thirdbooks_${DATE}.sql.gz"

mkdir -p $BACKUP_DIR

# Dump database
pg_dump -h localhost -U thirdbooks_user thirdbooks | gzip > $BACKUP_DIR/$FILENAME

# Keep only last 30 days
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: $FILENAME"
```

**Make executable:**

```bash
sudo chmod +x /usr/local/bin/thirdbooks-backup.sh
```

**Add to cron:**

```bash
sudo crontab -e
```

```cron
0 2 * * * /usr/local/bin/thirdbooks-backup.sh >> /var/log/thirdbooks-backup.log 2>&1
```

**Test backup:**

```bash
sudo /usr/local/bin/thirdbooks-backup.sh
ls -lh /var/backups/thirdbooks/
```

---

## Environment Configuration

### Backend (.env)

Critical production settings:

```env
# Security
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:GENERATED_KEY_HERE

# Database
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_DATABASE=thirdbooks
DB_USERNAME=thirdbooks_user
DB_PASSWORD=STRONG_PASSWORD_HERE

# Sessions & Auth
SESSION_DRIVER=redis
SESSION_LIFETIME=120
SESSION_DOMAIN=.thirdbooks.digital

# CORS
SANCTUM_STATEFUL_DOMAINS=thirdbooks.digital,www.thirdbooks.digital

# URLs
APP_URL=https://api.thirdbooks.digital
FRONTEND_URL=https://thirdbooks.digital

# Cache & Queues
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

# Mail (configure SMTP)
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@thirdbooks.digital
MAIL_FROM_NAME="ThirdBooks"
```

### Frontend (.env)

```env
VITE_API_URL=https://api.thirdbooks.digital/api
VITE_APP_NAME=ThirdBooks
VITE_APP_VERSION=1.0.0
```

---

## Post-Deployment Setup

### 1. Create First Super Admin

```bash
ssh deploy@api.thirdbooks.digital
cd /var/www/thirdbooks-api/backend
php artisan admin:create-super
```

### 2. Test API

```bash
curl https://api.thirdbooks.digital/api/health
```

Expected response:

```json
{
  "status": "ok",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

### 3. Test Frontend

Visit: https://thirdbooks.digital

- Should load login page
- Try logging in with super admin credentials
- Navigate to /admin
- Verify all features work

### 4. Setup Monitoring

**Install Uptime Monitor:**

Free options:
- UptimeRobot (https://uptimerobot.com) - Free 50 monitors
- Freshping (https://freshping.io) - Free 50 checks
- Pingdom (https://pingdom.com) - Free 1 site

**Monitor these URLs:**
- https://thirdbooks.digital (Frontend)
- https://api.thirdbooks.digital/api/health (Backend)

### 5. Configure Error Reporting

**Install Sentry (optional):**

```bash
cd /var/www/thirdbooks-api/backend
composer require sentry/sentry-laravel
php artisan sentry:publish --dsn=YOUR_SENTRY_DSN
```

### 6. Optimize Laravel

```bash
cd /var/www/thirdbooks-api/backend
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize
```

**Re-run after code changes!**

---

## SSL/HTTPS Configuration

### Backend (Let's Encrypt - Done Above)

Already configured via certbot.

**Verify:**

```bash
sudo certbot certificates
```

**Auto-renewal test:**

```bash
sudo certbot renew --dry-run
```

### Frontend (DirectAdmin)

Already configured via DirectAdmin SSL Certificates.

**Force HTTPS via .htaccess** (already included above)

---

## Monitoring & Maintenance

### Health Checks

**Create health endpoint:**

```bash
nano /var/www/thirdbooks-api/backend/routes/api.php
```

Add:

```php
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toISOString(),
        'database' => DB::connection()->getPdo() ? 'connected' : 'disconnected',
        'redis' => Redis::connection()->ping() ? 'connected' : 'disconnected',
    ]);
});
```

### Log Monitoring

**View Laravel logs:**

```bash
tail -f /var/www/thirdbooks-api/backend/storage/logs/laravel.log
```

**View Nginx logs:**

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

**View queue worker logs:**

```bash
sudo journalctl -u thirdbooks-worker -f
```

### Performance Monitoring

**Install Laravel Telescope (dev only):**

```bash
composer require laravel/telescope --dev
php artisan telescope:install
php artisan migrate
```

Access at: https://api.thirdbooks.digital/telescope

### Database Maintenance

**Weekly VACUUM:**

```bash
sudo -u postgres psql thirdbooks -c "VACUUM ANALYZE;"
```

**Add to cron:**

```cron
0 3 * * 0 sudo -u postgres psql thirdbooks -c "VACUUM ANALYZE;"
```

### Update Procedure

**Backend updates:**

```bash
cd /var/www/thirdbooks-api/backend
git pull origin main
composer install --optimize-autoloader --no-dev
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
sudo systemctl restart thirdbooks-worker
sudo systemctl reload php8.3-fpm
```

**Frontend updates:**

```bash
# Locally:
cd web-app
git pull
npm install
npm run build

# Upload dist/* to shared hosting
```

---

## Troubleshooting

### Issue: 500 Internal Server Error

**Check Laravel logs:**

```bash
tail -50 /var/www/thirdbooks-api/backend/storage/logs/laravel.log
```

**Common causes:**
- Permission issues: `sudo chown -R www-data:www-data storage bootstrap/cache`
- .env misconfiguration: Verify database credentials
- Cache issues: `php artisan cache:clear && php artisan config:clear`

### Issue: CORS Errors

**Update backend CORS config:**

```bash
nano /var/www/thirdbooks-api/backend/config/cors.php
```

```php
'paths' => ['api/*', 'sanctum/csrf-cookie'],
'allowed_origins' => [
    'https://thirdbooks.digital',
    'https://www.thirdbooks.digital',
],
'supports_credentials' => true,
```

### Issue: Database Connection Failed

**Check PostgreSQL is running:**

```bash
sudo systemctl status postgresql
```

**Test connection:**

```bash
psql -h localhost -U thirdbooks_user -d thirdbooks
```

**Check firewall:**

```bash
sudo ufw status
sudo ufw allow 5432/tcp
```

### Issue: Queue Jobs Not Processing

**Check worker status:**

```bash
sudo systemctl status thirdbooks-worker
```

**Restart worker:**

```bash
sudo systemctl restart thirdbooks-worker
```

**Check queue:**

```bash
php artisan queue:failed
php artisan queue:retry all
```

---

## Security Checklist

Before going live:

- [ ] Change all default passwords
- [ ] Enable HTTPS everywhere (check with: https://www.ssllabs.com/ssltest/)
- [ ] Set `APP_DEBUG=false` in production
- [ ] Configure firewall (allow only 80, 443, 22)
- [ ] Setup automated backups
- [ ] Enable fail2ban for SSH protection
- [ ] Review CORS settings
- [ ] Set strong database passwords
- [ ] Enable audit logging
- [ ] Configure error reporting (Sentry)
- [ ] Setup uptime monitoring
- [ ] Document recovery procedures
- [ ] Test backup restoration
- [ ] Review super admin access
- [ ] Enable 2FA for super admins

---

## Cost Estimate (Hybrid Setup)

| Service | Provider | Cost/Month |
|---------|----------|------------|
| VPS (Backend) | DigitalOcean | $6 |
| Shared Hosting (Frontend) | InterServer | $5 (existing) |
| Domain | Namecheap | $1 |
| SSL Certificates | Let's Encrypt | Free |
| **Total** | | **$12/month** |

---

## Next Steps

1. ✅ Review this deployment guide
2. ⏳ Sign up for VPS (DigitalOcean recommended)
3. ⏳ Configure DNS records
4. ⏳ Deploy backend to VPS
5. ⏳ Deploy frontend to shared hosting
6. ⏳ Create super admin user
7. ⏳ Test complete workflow
8. ⏳ Setup monitoring
9. ⏳ Configure backups
10. ⏳ Go live!

---

## Support

Need help with deployment?

- 📧 Email: support@thirdbooks.digital
- 📝 GitHub: https://github.com/SAVIOUR26/THIRD-BOOKS/issues
- 📚 Docs: Check ADMIN_PORTAL_GUIDE.md

---

**Last Updated:** January 22, 2024
**Version:** 1.0.0
**Tested:** Ubuntu 22.04, PHP 8.3, PostgreSQL 15
