# ThirdBooks Admin Panel

A PHP-based admin panel for managing ThirdBooks tenants and system settings.

## Requirements

- PHP 8.1 or higher
- Composer
- Web server (Apache/Nginx) or PHP built-in server

## Installation

1. Install dependencies:
   ```bash
   cd admin-panel
   composer install
   ```

2. Copy environment file:
   ```bash
   cp .env.example .env
   ```

3. Configure your environment variables in `.env`:
   - Set `API_BASE_URL` to your ThirdBooks API endpoint
   - Configure admin credentials

## Running Locally

Using PHP built-in server:
```bash
composer start
```
Or manually:
```bash
php -S localhost:8080 -t public
```

Then open http://localhost:8080 in your browser.

## Default Credentials

For development, use the credentials set in `.env`:
- Email: `admin@thirdbooks.com`
- Password: `admin123`

## Features

- **Dashboard**: Overview of system statistics
- **Tenant Management**: Create, edit, suspend, and delete tenants
- **User Management**: View all users across tenants
- **Reports**: System-wide analytics and reports
- **Settings**: Configure system settings

## Project Structure

```
admin-panel/
├── config/           # Configuration files
├── public/           # Web root
│   ├── assets/       # CSS, JS, images
│   └── index.php     # Entry point
├── src/
│   ├── Controllers/  # Request handlers
│   ├── Models/       # Data models
│   └── Views/        # PHP templates
├── composer.json
└── .env.example
```

## Deployment

For production deployment:

1. Set `APP_ENV=production` and `APP_DEBUG=false`
2. Configure a proper web server (Apache/Nginx)
3. Point document root to the `public/` directory
4. Set up SSL certificate for HTTPS
5. Configure proper session security settings

## License

Proprietary - ThirdBooks Ltd.
