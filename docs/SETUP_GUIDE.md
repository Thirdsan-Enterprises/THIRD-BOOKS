# ThirdBooks Setup Guide

Complete guide to setting up ThirdBooks for development and production.

## Prerequisites

### Required Software

- **PHP 8.3+**
- **Composer 2.x**
- **PostgreSQL 15+**
- **Redis 7.x**
- **Node.js 18+ & npm**
- **Flutter 3.x** (for mobile apps)
- **Git**

### Optional Tools

- **Docker** & Docker Compose (for containerized setup)
- **Laravel Valet** or **Herd** (for macOS)
- **TablePlus** or **pgAdmin** (database GUI)

---

## Installation Steps

### 1. Clone Repository

```bash
git clone https://github.com/your-org/thirdbooks.git
cd thirdbooks
```

### 2. Backend Setup (Laravel API)

```bash
cd backend

# Install PHP dependencies
composer install

# Copy environment file
cp .env.example .env

# Generate application key
php artisan key:generate

# Configure database in .env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=thirdbooks_central
DB_USERNAME=postgres
DB_PASSWORD=your_password

# Configure Redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
```

### 3. Database Setup

```bash
# Create databases
createdb thirdbooks_central

# Run central migrations
php artisan migrate --path=database/migrations/central

# Seed currencies
php artisan db:seed --class=CurrencySeeder
```

### 4. Create First Tenant

```bash
# Via Tinker
php artisan tinker

# In tinker:
$tenant = \App\Models\Tenant\Tenant::create([
    'name' => 'Demo Company',
    'company_name' => 'Demo Company Ltd',
    'email' => 'demo@thirdbooks.test',
    'base_currency' => 'UGX',
    'plan' => 'trial'
]);

$tenant->domains()->create([
    'domain' => 'demo.thirdbooks.test',
    'is_primary' => true
]);

# Run tenant migrations
php artisan tenants:migrate --tenants=$tenant->id

# Seed Chart of Accounts
php artisan tenants:seed --tenants=$tenant->id --class=ChartOfAccountsSeeder
```

### 5. Create First User

```bash
php artisan tinker

# In tinker:
$user = \App\Models\User::create([
    'tenant_id' => 'your-tenant-uuid',
    'name' => 'Admin User',
    'email' => 'admin@demo.com',
    'password' => bcrypt('password'),
    'role' => 'admin',
]);
```

### 6. Start Development Server

```bash
# Start Laravel
php artisan serve

# In another terminal, start queue worker
php artisan queue:work

# In another terminal, start scheduler
php artisan schedule:work
```

API will be available at: `http://localhost:8000`

### 7. Web App Setup (Optional)

```bash
cd web-app

# Install dependencies
npm install

# Copy environment
cp .env.example .env

# Configure API endpoint
VITE_API_URL=http://localhost:8000

# Start development server
npm run dev
```

Web app will be available at: `http://localhost:3000`

### 8. Mobile App Setup (Optional)

```bash
cd mobile-admin

# Get Flutter dependencies
flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Run on simulator/device
flutter run
```

---

## Testing the Installation

### 1. API Health Check

```bash
curl http://localhost:8000/api/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-09T10:00:00.000000Z"
}
```

### 2. Login Test

```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@demo.com",
    "password": "password"
  }'
```

Expected response:
```json
{
  "token": "your-jwt-token",
  "user": {
    "id": 1,
    "name": "Admin User",
    "email": "admin@demo.com",
    "tenant_id": "uuid"
  }
}
```

### 3. Chart of Accounts Test

```bash
curl -X GET http://localhost:8000/api/accounts \
  -H "Authorization: Bearer your-jwt-token" \
  -H "X-Tenant-ID: your-tenant-uuid"
```

---

## Docker Setup (Alternative)

### 1. Using Docker Compose

```bash
# Copy docker environment
cp .env.docker .env

# Start containers
docker-compose up -d

# Run migrations
docker-compose exec app php artisan migrate

# Create tenant
docker-compose exec app php artisan tinker
# ... (follow steps above)
```

### 2. Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/var/www
    environment:
      - DB_HOST=db
      - REDIS_HOST=redis
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: thirdbooks_central
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  queue:
    build:
      context: ./backend
      dockerfile: Dockerfile
    command: php artisan queue:work
    volumes:
      - ./backend:/var/www
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
  redis_data:
```

---

## Production Deployment

### 1. Server Requirements

- **Ubuntu 22.04 LTS** or similar
- **2 CPU cores minimum** (4+ recommended)
- **4GB RAM minimum** (8GB+ recommended)
- **50GB storage** (100GB+ recommended)

### 2. Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install PHP 8.3
sudo add-apt-repository ppa:ondrej/php
sudo apt install php8.3 php8.3-cli php8.3-fpm php8.3-pgsql \
  php8.3-mbstring php8.3-xml php8.3-bcmath php8.3-curl \
  php8.3-zip php8.3-redis

# Install PostgreSQL
sudo apt install postgresql-15

# Install Redis
sudo apt install redis-server

# Install Nginx
sudo apt install nginx

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs
```

### 3. Application Deployment

```bash
# Clone repository
cd /var/www
sudo git clone https://github.com/your-org/thirdbooks.git
cd thirdbooks/backend

# Install dependencies
composer install --no-dev --optimize-autoloader

# Set permissions
sudo chown -R www-data:www-data /var/www/thirdbooks
sudo chmod -R 755 /var/www/thirdbooks

# Configure environment
sudo cp .env.example .env
sudo nano .env  # Edit production values

# Generate key
php artisan key:generate

# Run migrations
php artisan migrate --force

# Optimize
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### 4. Nginx Configuration

```nginx
server {
    listen 80;
    server_name thirdbooks.com;
    root /var/www/thirdbooks/backend/public;

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

### 5. SSL with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d thirdbooks.com -d www.thirdbooks.com
```

### 6. Supervisor for Queue

```bash
sudo apt install supervisor

# Create supervisor config
sudo nano /etc/supervisor/conf.d/thirdbooks-worker.conf
```

```ini
[program:thirdbooks-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/thirdbooks/backend/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/thirdbooks/backend/storage/logs/worker.log
stopwaitsecs=3600
```

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start thirdbooks-worker:*
```

### 7. Cron Job for Scheduler

```bash
sudo crontab -e -u www-data
```

Add:
```
* * * * * cd /var/www/thirdbooks/backend && php artisan schedule:run >> /dev/null 2>&1
```

---

## Troubleshooting

### Database Connection Error

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check credentials
psql -U postgres -d thirdbooks_central -h 127.0.0.1

# Check .env file
cat .env | grep DB_
```

### Permission Errors

```bash
# Fix storage permissions
sudo chown -R www-data:www-data storage
sudo chmod -R 775 storage

# Fix bootstrap/cache
sudo chown -R www-data:www-data bootstrap/cache
sudo chmod -R 775 bootstrap/cache
```

### Redis Connection Error

```bash
# Check Redis is running
sudo systemctl status redis

# Test connection
redis-cli ping
```

### Queue Not Processing

```bash
# Check supervisor
sudo supervisorctl status

# Check logs
tail -f storage/logs/worker.log

# Restart queue
sudo supervisorctl restart thirdbooks-worker:*
```

---

## Security Checklist

- [ ] Change default passwords
- [ ] Enable 2FA for admin users
- [ ] Configure firewall (UFW)
- [ ] Set up SSL certificates
- [ ] Configure backup system
- [ ] Enable rate limiting
- [ ] Set up monitoring (e.g., New Relic, Sentry)
- [ ] Review .env for production values
- [ ] Disable debug mode (APP_DEBUG=false)
- [ ] Set up database backups
- [ ] Configure fail2ban for brute force protection

---

## Maintenance

### Daily Tasks
- Monitor error logs
- Check backup status
- Review system performance

### Weekly Tasks
- Review audit logs
- Check disk space
- Update exchange rates manually if API fails

### Monthly Tasks
- Update dependencies
- Review security patches
- Test backup restoration

---

## Support

For issues or questions:
- **Documentation:** https://docs.thirdbooks.com
- **GitHub Issues:** https://github.com/your-org/thirdbooks/issues
- **Email:** support@thirdbooks.com

---

**Last Updated:** January 2026
**Version:** 1.0.0
