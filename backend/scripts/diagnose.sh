#!/usr/bin/env bash
# =============================================================================
#  ThirdBooks / MagicBet — Pre-Boot Server Diagnostic
#  Run this FIRST on the server before anything else.
#  It catches all infrastructure-level issues that cause the 500 error.
#
#  Usage:
#    bash scripts/diagnose.sh
#
#  Run from the Laravel root directory:
#    cd /var/www/thirdbooks   (or wherever the project lives)
#    bash scripts/diagnose.sh
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
FAILED_ITEMS=()

pass()  { echo -e "  ${GREEN}✓${NC}  $1${2:+  \033[0;90m($2)\033[0m}"; ((PASS++)); }
fail()  { echo -e "  ${RED}✗${NC}  ${RED}$1${NC}${2:+  → $2}"; ((FAIL++)); FAILED_ITEMS+=("$1"); }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1${2:+  → $2}"; ((WARN++)); }
section() { echo -e "\n${CYAN}${BOLD}── $1 $(printf '─%.0s' $(seq 1 $((54 - ${#1}))))${NC}"; }

# ── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ThirdBooks / MagicBet  —  Pre-Boot Server Diagnostic   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Working directory: $(pwd)"
echo -e "  Run as user:       $(whoami)"
echo -e "  Date/time:         $(date)"

# ── 1. PHP ────────────────────────────────────────────────────────────────────
section "PHP RUNTIME"

if command -v php &>/dev/null; then
    PHP_VER=$(php -r 'echo PHP_VERSION;')
    PHP_ID=$(php -r 'echo PHP_VERSION_ID;')
    if [ "$PHP_ID" -ge 80200 ]; then
        pass "PHP $PHP_VER (>= 8.2 required)"
    else
        fail "PHP $PHP_VER is too old — 8.2+ required" "Install PHP 8.2 or higher"
    fi
else
    fail "PHP not found in PATH" "Install PHP 8.2+"
fi

# Required extensions
REQUIRED_EXTENSIONS="pdo pdo_mysql mbstring openssl tokenizer xml ctype json bcmath fileinfo"
for ext in $REQUIRED_EXTENSIONS; do
    if php -m 2>/dev/null | grep -qi "^${ext}$"; then
        pass "Extension: $ext"
    else
        fail "Extension missing: $ext" "Run: sudo apt install php8.2-$ext  (or equivalent)"
    fi
done

# ── 2. Project structure ──────────────────────────────────────────────────────
section "PROJECT FILES"

[ -f "artisan" ]         && pass "artisan found"              || fail "artisan not found"        "Wrong directory?"
[ -f ".env" ]            && pass ".env file exists"           || fail ".env file MISSING"        "cp .env.example .env && php artisan key:generate"
[ -d "vendor" ]          && pass "vendor/ directory exists"   || fail "vendor/ MISSING"          "Run: composer install --no-dev"
[ -d "storage" ]         && pass "storage/ directory exists"  || fail "storage/ MISSING"         "git checkout storage/"
[ -f "bootstrap/app.php" ] && pass "bootstrap/app.php found" || fail "bootstrap/app.php MISSING" "Reinstall project"

# ── 3. .env validation ────────────────────────────────────────────────────────
section ".ENV VALIDATION"

if [ -f ".env" ]; then
    get_env() { grep -E "^$1=" .env | cut -d= -f2- | tr -d '"' | tr -d "'"; }

    APP_KEY=$(get_env APP_KEY)
    DB_HOST=$(get_env DB_HOST)
    DB_DATABASE=$(get_env DB_DATABASE)
    DB_USERNAME=$(get_env DB_USERNAME)
    APP_URL=$(get_env APP_URL)

    [ -n "$APP_KEY" ] && [[ "$APP_KEY" == base64:* ]] \
        && pass "APP_KEY is set" \
        || fail "APP_KEY missing or invalid" "Run: php artisan key:generate"

    [ -n "$APP_URL" ] \
        && pass "APP_URL = $APP_URL" \
        || warn "APP_URL not set" "Should be https://api.thirdbooks.digital"

    [ -n "$DB_HOST" ]     && pass "DB_HOST = $DB_HOST"         || fail "DB_HOST not set"
    [ -n "$DB_DATABASE" ] && pass "DB_DATABASE = $DB_DATABASE" || fail "DB_DATABASE not set"
    [ -n "$DB_USERNAME" ] && pass "DB_USERNAME = $DB_USERNAME" || fail "DB_USERNAME not set"
else
    warn ".env missing — skipping .env checks"
fi

# ── 4. Database connectivity (raw TCP + MySQL CLI) ────────────────────────────
section "DATABASE CONNECTIVITY"

if [ -f ".env" ]; then
    DB_HOST=$(get_env DB_HOST)
    DB_PORT=$(get_env DB_PORT); DB_PORT=${DB_PORT:-3306}
    DB_DATABASE=$(get_env DB_DATABASE)
    DB_USERNAME=$(get_env DB_USERNAME)
    DB_PASSWORD=$(get_env DB_PASSWORD)

    # TCP reachability
    if command -v nc &>/dev/null; then
        if nc -zw3 "$DB_HOST" "$DB_PORT" 2>/dev/null; then
            pass "DB host $DB_HOST:$DB_PORT is reachable (TCP)"
        else
            fail "Cannot reach DB $DB_HOST:$DB_PORT" "Check DB_HOST, DB_PORT, and firewall rules"
        fi
    else
        warn "nc (netcat) not available — skipping TCP check"
    fi

    # MySQL auth + database existence
    if command -v mysql &>/dev/null; then
        MYSQL_CMD="mysql -h$DB_HOST -P$DB_PORT -u$DB_USERNAME"
        [ -n "$DB_PASSWORD" ] && MYSQL_CMD="$MYSQL_CMD -p$DB_PASSWORD"

        if $MYSQL_CMD -e "USE \`$DB_DATABASE\`;" 2>/dev/null; then
            pass "MySQL login OK, database '$DB_DATABASE' accessible"

            # Check key tables
            KEY_TABLES="users tenants events sync_queue device_sync_state conflicts personal_access_tokens"
            MISSING_TABLES=""
            for tbl in $KEY_TABLES; do
                EXISTS=$($MYSQL_CMD -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_DATABASE' AND table_name='$tbl';" 2>/dev/null)
                if [ "$EXISTS" = "1" ]; then
                    ROW_COUNT=$($MYSQL_CMD -sN -e "SELECT COUNT(*) FROM \`$DB_DATABASE\`.\`$tbl\`;" 2>/dev/null)
                    pass "Table: $tbl ($ROW_COUNT rows)"
                else
                    fail "Table MISSING: $tbl" "Run: php artisan migrate --force"
                    MISSING_TABLES="$MISSING_TABLES $tbl"
                fi
            done
        else
            fail "MySQL login FAILED for user '$DB_USERNAME'@'$DB_HOST'/$DB_DATABASE" \
                 "Check DB_USERNAME, DB_PASSWORD, and GRANT privileges"
        fi
    else
        warn "mysql CLI not available — skipping table checks"
        warn "Install with: sudo apt install mysql-client"
    fi
fi

# ── 5. File permissions ───────────────────────────────────────────────────────
section "FILE PERMISSIONS"

check_writable() {
    local path="$1" label="$2"
    if [ -d "$path" ]; then
        if [ -w "$path" ]; then
            pass "$label"
        else
            fail "$label is NOT writable" "Run: chmod -R 775 $path && chown -R www-data:www-data $path"
        fi
    else
        fail "$label directory missing" "mkdir -p $path"
    fi
}

check_writable "storage/logs"               "storage/logs"
check_writable "storage/framework/cache"    "storage/framework/cache"
check_writable "storage/framework/sessions" "storage/framework/sessions"
check_writable "storage/framework/views"    "storage/framework/views"
check_writable "bootstrap/cache"            "bootstrap/cache"

# ── 6. Composer dependencies ──────────────────────────────────────────────────
section "COMPOSER DEPENDENCIES"

if [ -d "vendor" ]; then
    if php -r "require 'vendor/autoload.php';" 2>/dev/null; then
        pass "vendor/autoload.php loads cleanly"
    else
        fail "vendor/autoload.php has errors" "Run: composer install --no-dev"
    fi
else
    fail "vendor/ directory missing" "Run: composer install --no-dev"
fi

# ── 7. Laravel bootstrap ──────────────────────────────────────────────────────
section "LARAVEL BOOTSTRAP"

if [ -f "artisan" ] && [ -d "vendor" ] && [ -f ".env" ]; then
    ARTISAN_OUT=$(php artisan --version 2>&1)
    if echo "$ARTISAN_OUT" | grep -qi "laravel"; then
        pass "php artisan bootstraps OK" "$ARTISAN_OUT"
    else
        fail "php artisan failed to boot" "$ARTISAN_OUT"
        echo ""
        echo -e "  ${YELLOW}Full artisan error output:${NC}"
        php artisan --version 2>&1 | sed 's/^/    /'
    fi

    # Health check simulation
    HEALTH_OUT=$(php artisan route:list --json 2>/dev/null | php -r "
        \$routes = json_decode(file_get_contents('php://stdin'), true);
        foreach (\$routes as \$r) {
            if (strpos(\$r['uri'] ?? '', 'health') !== false) {
                echo 'FOUND: ' . \$r['uri'];
                exit(0);
            }
        }
        echo 'NOT FOUND';
    " 2>/dev/null || echo "Could not list routes")
    echo -e "  ${CYAN}ℹ${NC}  /api/health route: $HEALTH_OUT"

    # Run full artisan diagnose if available
    if php artisan list 2>/dev/null | grep -q "diagnose"; then
        echo ""
        echo -e "  ${CYAN}${BOLD}► Running php artisan diagnose ...${NC}"
        echo ""
        php artisan diagnose
    fi
else
    warn "Skipping artisan checks (missing artisan, vendor/, or .env)"
fi

# ── 8. Queue worker status ────────────────────────────────────────────────────
section "QUEUE WORKER"

if command -v supervisorctl &>/dev/null; then
    QUEUE_STATUS=$(supervisorctl status 2>/dev/null | grep -i "queue" || echo "not configured")
    echo -e "  ${CYAN}ℹ${NC}  Supervisor queue status: $QUEUE_STATUS"
elif command -v systemctl &>/dev/null; then
    echo -e "  ${CYAN}ℹ${NC}  Check queue service: systemctl status laravel-queue"
else
    warn "Queue worker status unknown" "Ensure 'php artisan queue:work' is running (via supervisor/cron)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "  Results:  ${GREEN}PASS $PASS${NC}   ${RED}FAIL $FAIL${NC}   ${YELLOW}WARN $WARN${NC}"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓  All checks passed. Ready to sync.${NC}"
elif [ "$FAIL" -eq 0 ]; then
    echo -e "  ${YELLOW}${BOLD}⚠  No failures, but warnings need attention.${NC}"
else
    echo -e "  ${RED}${BOLD}✗  $FAIL failure(s) found — fix these first:${NC}"
    echo ""
    for item in "${FAILED_ITEMS[@]}"; do
        echo -e "    ${RED}•${NC}  $item"
    done
    echo ""
    echo -e "  ${YELLOW}Quick fix sequence for a fresh server:${NC}"
    echo -e "  ${YELLOW}  1.  composer install --no-dev${NC}"
    echo -e "  ${YELLOW}  2.  cp .env.example .env  &&  nano .env   (set DB creds, APP_URL)${NC}"
    echo -e "  ${YELLOW}  3.  php artisan key:generate${NC}"
    echo -e "  ${YELLOW}  4.  php artisan migrate --force${NC}"
    echo -e "  ${YELLOW}  5.  chmod -R 775 storage bootstrap/cache${NC}"
    echo -e "  ${YELLOW}  6.  php artisan db:seed --class=SuperAdminSeeder${NC}"
    echo -e "  ${YELLOW}  7.  php artisan magicbet:setup${NC}"
    echo -e "  ${YELLOW}  8.  php artisan queue:work --daemon &${NC}"
fi

echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

exit $FAIL
