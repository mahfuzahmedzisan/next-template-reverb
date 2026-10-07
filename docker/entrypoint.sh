#!/bin/bash
set -e

cd /var/www

echo "[entrypoint] Starting reverb_server container..."

# ─── Merge runtime env vars into .env ─────────────────────────────────────────
# Coolify injects configuration as container environment variables. Laravel reads
# .env, so we project the relevant variables into .env on boot. Only non-empty
# values are written; existing keys are updated in place, new keys are appended.
if [ -f .env ]; then
    cp .env .env.backup
fi

printenv | grep -E "^(APP_|DB_|REVERB_|LOG_|CACHE_|SESSION_|QUEUE_|REDIS_|FRONTEND_)" | while IFS='=' read -r key value; do
    if [ -n "$value" ]; then
        # '|' is a safe delimiter: base64 keys, domains and URLs never contain it
        if grep -q "^${key}=" .env 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${value}|" .env
        else
            echo "${key}=${value}" >> .env
        fi
    fi
done

echo "[entrypoint] Environment written to .env"

# ─── Ensure an APP_KEY exists (Reverb boots Laravel, which expects one) ────────
php artisan config:clear 2>/dev/null || true

APP_KEY_VAL=$(grep "^APP_KEY=" .env 2>/dev/null | cut -d'=' -f2-)
if [ -z "$APP_KEY_VAL" ] || [ "$APP_KEY_VAL" = '""' ]; then
    echo "[entrypoint] APP_KEY missing — generating one"
    php artisan key:generate --force --no-interaction || true
fi

# ─── SQLite file so the framework can boot (Reverb needs no real DB) ───────────
if grep -q "DB_CONNECTION=sqlite" .env 2>/dev/null; then
    mkdir -p database
    touch database/database.sqlite
    echo "[entrypoint] SQLite database file ensured"
fi

# ─── Permissions ──────────────────────────────────────────────────────────────
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true

echo "[entrypoint] Launching Reverb on 0.0.0.0:8080 ..."
exec gosu www-data php artisan reverb:start --host=0.0.0.0 --port=8080 --no-interaction
