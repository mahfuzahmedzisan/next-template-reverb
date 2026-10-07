FROM php:8.4-cli

# ─── System dependencies ──────────────────────────────────────────────────────
# curl is required for Coolify / Docker HEALTHCHECK (do not remove).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    libonig-dev \
    libpng-dev \
    libxml2-dev \
    libzip-dev \
    unzip \
    && docker-php-ext-install \
        mbstring \
        pcntl \
        pdo_mysql \
        zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2.6 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# ─── PHP dependencies (cached layer) ──────────────────────────────────────────
# Do not bake REVERB_APP_* / APP_KEY via ARG/ENV — Coolify injects them at runtime.
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
RUN chmod +x /entrypoint.sh \
    && curl --version >/dev/null

EXPOSE 8080

# Reverb speaks HTTP on :8080 (Pusher protocol). Any TCP/HTTP response means
# the process is up — do not use curl -f (non-2xx is still "alive").
# Longer start-period: Coolify waits this long before the first probe.
HEALTHCHECK --interval=15s --timeout=5s --start-period=40s --retries=5 \
    CMD curl -sS --max-time 3 -o /dev/null "http://127.0.0.1:8080/" || exit 1

CMD ["/entrypoint.sh"]
