FROM php:8.4-cli

# ─── System dependencies ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    git curl unzip libpng-dev libonig-dev \
    libxml2-dev libzip-dev gosu \
    && docker-php-ext-install \
        pdo_mysql mbstring zip pcntl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2.6 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# ─── PHP dependencies (cached layer) ──────────────────────────────────────────
COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-scripts

# ─── Application ──────────────────────────────────────────────────────────────
COPY . .

RUN composer run-script post-autoload-dump --no-interaction 2>/dev/null || true \
    && mkdir -p storage/framework/views storage/framework/sessions storage/framework/cache \
        storage/logs bootstrap/cache database \
    && touch database/database.sqlite \
    && cp .env.example .env \
    && chown -R www-data:www-data /var/www \
    && chmod -R 775 storage bootstrap/cache

# ─── Entrypoint ───────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

# Reverb is a pure Pusher-protocol server (no Laravel HTTP routes). Any HTTP
# response on :8080 means the process is alive; only connection-refused fails.
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -s -o /dev/null --max-time 5 "http://127.0.0.1:8080" || exit 1

CMD ["/entrypoint.sh"]
