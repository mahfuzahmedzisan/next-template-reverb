#!/bin/bash
set -e

cd /var/www

echo "[entrypoint] Starting next-template-reverb container..."

# ─── Merge runtime env vars into .env ─────────────────────────────────────────
# Coolify injects configuration as container environment variables. Laravel
# reads .env, so we project the relevant variables on boot.
#
# Values MUST be double-quoted. Unquoted values with spaces (e.g. APP_NAME)
# make Dotenv throw "unexpected whitespace" and Reverb crash-loops before
# the healthcheck can pass.
if [ -f .env ]; then
    cp .env .env.backup
fi

dotenv_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

write_env() {
    local key="$1"
    local value="$2"
    local escaped
    escaped="$(dotenv_escape "$value")"

    if grep -q "^${key}=" .env 2>/dev/null; then
        # Use '|' delimiter; keys/values should not contain it.
        sed -i "s|^${key}=.*|${key}=\"${escaped}\"|" .env
    else
        printf '%s="%s"\n' "$key" "$escaped" >> .env
    fi
}

# Prefer key=value split that keeps everything after the first '=' (APP_KEY).
printenv | grep -E "^(APP_|DB_|REVERB_|LOG_|CACHE_|SESSION_|QUEUE_|REDIS_|FRONTEND_)" | while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    if [ -n "$key" ] && [ -n "$value" ]; then
        write_env "$key" "$value"
    fi
done

echo "[entrypoint] Environment written to .env"

# ─── Ensure an APP_KEY exists (Reverb boots Laravel, which expects one) ────────
php artisan config:clear 2>/dev/null || true

APP_KEY_VAL=$(grep "^APP_KEY=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"')
if [ -z "$APP_KEY_VAL" ] || [ "$APP_KEY_VAL" = "" ]; then
    echo "[entrypoint] APP_KEY missing — generating one"
    php artisan key:generate --force --no-interaction || true
fi

# ─── SQLite file so the framework can boot (Reverb needs no real DB) ───────────
if grep -qE '^DB_CONNECTION=["'\'']?sqlite' .env 2>/dev/null; then
    mkdir -p database
    touch database/database.sqlite
    chown www-data:www-data database/database.sqlite 2>/dev/null || true
    echo "[entrypoint] SQLite database file ensured"
fi

# ─── Permissions ──────────────────────────────────────────────────────────────
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true

echo "[entrypoint] Launching Reverb on 0.0.0.0:8080 ..."
exec gosu www-data php artisan reverb:start --host=0.0.0.0 --port=8080 --no-interaction
