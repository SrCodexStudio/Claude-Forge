# Forge Library: Deployment and Security

> Reference knowledge for deploying and maintaining production web applications
> Read BEFORE configuring servers, CI/CD pipelines, or production environments

---

## Nginx Production Configuration

```nginx
# /etc/nginx/nginx.conf
worker_processes auto;                   # Match CPU core count
worker_rlimit_nofile 65535;              # >= 2x worker_connections (client+upstream FDs)
pid /run/nginx.pid;

events {
    worker_connections 4096;             # Total capacity = workers * connections
    use epoll;                           # Best event model on Linux 2.6+
    multi_accept on;                     # Accept all pending connections per cycle
}

http {
    sendfile on;                         # Kernel-level file transfer
    tcp_nopush on;                       # Batch headers + data into fewer packets
    tcp_nodelay on;                      # Disable Nagle for low latency
    keepalive_timeout 30;
    keepalive_requests 1000;
    client_body_buffer_size 16k;
    client_header_buffer_size 1k;
    client_max_body_size 50m;            # Upload limit
    large_client_header_buffers 4 16k;
    server_tokens off;                   # Hide nginx version

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip: 60-80% bandwidth savings for text assets
    gzip on;  gzip_vary on;  gzip_proxied any;
    gzip_comp_level 4;                   # 90% of max compression at 30% CPU
    gzip_min_length 256;
    gzip_types text/plain text/css text/javascript application/javascript
               application/json application/xml image/svg+xml font/woff2;

    # Structured logging with upstream timing
    log_format main '$remote_addr [$time_local] "$request" $status $body_bytes_sent '
                    '$request_time $upstream_response_time';
    access_log /var/log/nginx/access.log main buffer=32k flush=5s;
    error_log /var/log/nginx/error.log warn;

    # Static asset cache map
    map $sent_http_content_type $expires {
        default off;  text/html epoch;  text/css 30d;  application/javascript 30d;
        image/png 90d;  image/jpeg 90d;  image/webp 90d;  font/woff2 365d;
    }

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### Server Block: Laravel + React with WebSocket

```nginx
limit_req_zone $binary_remote_addr zone=app_limit:10m rate=10r/s;
upstream php_fpm { server unix:/run/php/php8.3-fpm.sock; }
upstream node_app { server 127.0.0.1:3000; keepalive 32; }

server { listen 80; server_name example.com; return 301 https://$host$request_uri; }

server {
    listen 443 ssl http2;
    server_name example.com;
    root /var/www/app/public;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_stapling on;  ssl_stapling_verify on;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
    limit_req zone=app_limit burst=20 nodelay;

    # Immutable hashed assets
    location ~* \.(js|css|png|jpg|gif|ico|svg|woff2|webp)$ {
        expires max;  add_header Cache-Control "public, immutable";
        access_log off;  try_files $uri =404;
    }
    location /api { try_files $uri $uri/ /index.php?$query_string; }
    location ~ \.php$ {
        fastcgi_pass php_fpm;  fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 16k;  fastcgi_buffers 4 16k;
        fastcgi_read_timeout 60s;
    }
    # WebSocket -- Upgrade headers are mandatory
    location /ws {
        proxy_pass http://node_app;  proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
    }
    location / { try_files $uri $uri/ /index.php?$query_string; }
    location ~ /\.(?!well-known) { deny all; }
}
```

---

## PHP-FPM Tuning

```ini
; /etc/php/8.3/fpm/pool.d/www.conf
[www]
user = www-data
listen = /run/php/php8.3-fpm.sock
listen.owner = www-data

pm = dynamic                             ; Adjusts pool size to traffic
; max_children = (RAM - OS overhead) / avg_process_MB
; Example: (4096 - 1024) / 40 = ~76
pm.max_children = 50
pm.start_servers = 12
pm.min_spare_servers = 8
pm.max_spare_servers = 20
pm.max_requests = 500                    ; Recycle to contain memory leaks
request_terminate_timeout = 60s
request_slowlog_timeout = 5s             ; Log slow requests for debugging
slowlog = /var/log/php-fpm/slow.log
pm.status_path = /fpm-status
security.limit_extensions = .php

; /etc/php/8.3/fpm/conf.d/10-opcache.ini
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0          ; DISABLE in production. Clear after deploy.
opcache.jit = tracing
opcache.jit_buffer_size = 128M
```

---

## Node.js PM2

```javascript
// ecosystem.config.js
module.exports = { apps: [{
  name: 'app-api',
  script: './dist/server.js',
  instances: 'max',                      // One process per CPU core
  exec_mode: 'cluster',
  kill_timeout: 5000,                    // Grace period for in-flight requests
  autorestart: true,
  max_restarts: 15,
  max_memory_restart: '512M',
  watch: false,                          // Never in production
  env_production: { NODE_ENV: 'production', PORT: 3000 },
  error_file: '/var/log/pm2/app-error.log',
  out_file: '/var/log/pm2/app-out.log',
  merge_logs: true,
  exp_backoff_restart_delay: 100,
}]};
```

```bash
pm2 start ecosystem.config.js --env production
pm2 reload app-api              # Zero-downtime (NOT restart)
pm2 startup systemd && pm2 save # Persist across reboots
pm2 install pm2-logrotate && pm2 set pm2-logrotate:max_size 50M
```

---

## Docker Multi-Stage Builds

```dockerfile
# Stage 1: Composer
FROM composer:2 AS deps
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --optimize-autoloader

# Stage 2: Frontend
FROM node:20-alpine AS frontend
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false
COPY resources/ resources/
COPY vite.config.js tailwind.config.js postcss.config.js ./
RUN npm run build

# Stage 3: Production
FROM php:8.3-fpm-alpine
RUN apk add --no-cache libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev icu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo_mysql gd zip intl mbstring opcache bcmath
WORKDIR /var/www/app
COPY --chown=www-data:www-data . .
COPY --from=deps --chown=www-data:www-data /app/vendor ./vendor
COPY --from=frontend --chown=www-data:www-data /app/public/build ./public/build
RUN composer dump-autoload --optimize --classmap-authoritative \
    && php artisan config:cache && php artisan route:cache && php artisan view:cache
USER www-data
EXPOSE 9000
CMD ["php-fpm"]
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD php-fpm-healthcheck || exit 1
```

```yaml
# docker-compose.yml
services:
  app:
    build: { context: ., target: production }
    restart: unless-stopped
    depends_on: { db: { condition: service_healthy }, redis: { condition: service_healthy } }
    env_file: .env
    volumes: [storage:/var/www/app/storage]
  nginx:
    image: nginx:alpine
    ports: ["443:443", "80:80"]
    volumes: [./docker/nginx/app.conf:/etc/nginx/conf.d/default.conf:ro, ./public:/var/www/app/public:ro]
    depends_on: [app]
  db:
    image: mysql:8.0
    environment: { MYSQL_DATABASE: "${DB_DATABASE}", MYSQL_USER: "${DB_USERNAME}", MYSQL_PASSWORD: "${DB_PASSWORD}", MYSQL_ROOT_PASSWORD: "${DB_ROOT_PASSWORD}" }
    volumes: [dbdata:/var/lib/mysql]
    healthcheck: { test: ["CMD", "mysqladmin", "ping", "-h", "localhost"], interval: 10s, retries: 5 }
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    healthcheck: { test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"], interval: 10s, retries: 5 }
    volumes: [redisdata:/data]
volumes: { dbdata: null, redisdata: null, storage: null }
```

---

## CI/CD with GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Test and Deploy
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
concurrency: { group: "${{ github.workflow }}-${{ github.ref }}", cancel-in-progress: true }

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env: { MYSQL_DATABASE: testing, MYSQL_ROOT_PASSWORD: rootpass }
        ports: ["3306:3306"]
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-retries=5
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.3', extensions: pdo_mysql, coverage: xdebug }
      - run: composer install --no-interaction --prefer-dist
      - run: php artisan test --coverage-clover=coverage.xml
        env: { DB_HOST: 127.0.0.1, DB_DATABASE: testing, DB_USERNAME: root, DB_PASSWORD: rootpass }
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: npm }
      - run: npm ci && npm test -- --coverage

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          port: ${{ secrets.DEPLOY_PORT }}
          script: |
            cd /var/www/app && docker compose pull && docker compose up -d --remove-orphans
            docker compose exec -T app php artisan migrate --force
            docker compose exec -T app php artisan config:cache
            docker compose exec -T app php artisan route:cache
            docker compose exec -T app php artisan queue:restart
```

---

## Environment Management

```env
# .env.example -- Copy to .env. NEVER commit real values.
APP_NAME=MyApp
APP_ENV=local
APP_KEY=
APP_URL=http://localhost
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=
DB_USERNAME=
DB_PASSWORD=
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
CACHE_DRIVER=redis
LOG_CHANNEL=daily
MAIL_MAILER=smtp
MAIL_HOST=
MAIL_PORT=587
RATE_LIMIT_PER_MINUTE=60
```

### Startup Validation (fail fast on missing vars)

```php
// AppServiceProvider::boot()
$missing = array_filter(['APP_KEY','DB_HOST','DB_DATABASE','DB_PASSWORD'], fn($v) => empty(env($v)));
if ($missing) throw new RuntimeException('Missing env: ' . implode(', ', $missing));
```

```javascript
// lib/env.js
function req(name) { if (!process.env[name]) { console.error(`FATAL: ${name} missing`); process.exit(1); } return process.env[name]; }
module.exports = { port: +req('PORT'), dbUrl: req('DATABASE_URL'), jwtSecret: req('JWT_SECRET') };
```

---

## Zero-Downtime Deployment

```bash
#!/bin/bash
# deploy.sh -- Atomic symlink. New release prepared separately, then switched.
set -euo pipefail
RELEASES="/var/www/app/releases"; SHARED="/var/www/app/shared"
REL="$(date +%Y%m%d%H%M%S)"; TARGET="${RELEASES}/${REL}"; KEEP=5

mkdir -p "${TARGET}" && git clone --depth 1 --branch main "${REPO_URL}" "${TARGET}"
cd "${TARGET}"
composer install --no-dev --no-interaction --optimize-autoloader
npm ci --production && npm run build
ln -sfn "${SHARED}/storage" storage && ln -sfn "${SHARED}/.env" .env
php artisan migrate --force   # Must be backward-compatible
php artisan config:cache && php artisan route:cache && php artisan view:cache
ln -sfn "${TARGET}" /var/www/app/current  # Atomic switch (single rename syscall)
sudo systemctl reload php8.3-fpm && sudo systemctl reload nginx
php artisan queue:restart
cd "${RELEASES}" && ls -dt */ | tail -n +$((KEEP+1)) | xargs rm -rf
```

```bash
#!/bin/bash
# rollback.sh
CURRENT=$(readlink -f /var/www/app/current)
PREV=$(ls -dt /var/www/app/releases/*/ | grep -v "$(basename ${CURRENT})" | head -1)
[ -z "${PREV}" ] && echo "No previous release" && exit 1
ln -sfn "${PREV}" /var/www/app/current
sudo systemctl reload php8.3-fpm nginx && echo "Rolled back to $(basename ${PREV})"
```

---

## Backup Strategies

```bash
#!/bin/bash
# backup.sh -- Daily with weekly/monthly rotation, S3 upload, integrity check
set -euo pipefail
DIR="/var/backups/app"; DATE="$(date +%Y%m%d_%H%M%S)"
mkdir -p "${DIR}"/{daily,weekly,monthly}

DB="${DIR}/daily/db_${DATE}.sql.gz"
mysqldump --host="${DB_HOST}" --user="${DB_USERNAME}" --password="${DB_PASSWORD}" \
    --single-transaction --routines --quick "${DB_DATABASE}" | gzip > "${DB}"
FILES="${DIR}/daily/files_${DATE}.tar.gz"
tar czf "${FILES}" -C /var/www/app/current storage/app .env

[ "$(date +%u)" = "7" ] && cp "${DB}" "${FILES}" "${DIR}/weekly/"
[ "$(date +%d)" = "01" ] && cp "${DB}" "${FILES}" "${DIR}/monthly/"
find "${DIR}/daily" -mtime +7 -delete; find "${DIR}/weekly" -mtime +28 -delete
find "${DIR}/monthly" -mtime +180 -delete
command -v aws &>/dev/null && aws s3 cp "${DB}" "s3://${S3_BUCKET}/backups/"
gzip -t "${DB}" && echo "OK" || { echo "INTEGRITY FAIL"; exit 1; }
```

---

## Monitoring

### Health Checks

```php
// PHP
Route::get('/health', function () {
    $c = [];
    try { DB::connection()->getPdo(); $c['db'] = 'ok'; } catch (\Exception $e) { $c['db'] = 'fail'; }
    try { Redis::ping(); $c['redis'] = 'ok'; } catch (\Exception $e) { $c['redis'] = 'fail'; }
    $c['disk'] = disk_free_space('/') > 500*1024*1024 ? 'ok' : 'warn';
    $ok = !in_array('fail', $c);
    return response()->json(['status' => $ok ? 'healthy' : 'unhealthy', 'checks' => $c], $ok ? 200 : 503);
});
```

```javascript
// Node.js
module.exports = async (req, res) => {
  const c = {};
  try { await db.raw('SELECT 1'); c.db = 'ok'; } catch { c.db = 'fail'; }
  try { await redis.ping(); c.redis = 'ok'; } catch { c.redis = 'fail'; }
  const h = process.memoryUsage();
  c.memory = h.heapUsed/h.heapTotal < 0.9 ? 'ok' : 'warn';
  const ok = !Object.values(c).includes('fail');
  res.status(ok ? 200 : 503).json({ status: ok ? 'healthy' : 'unhealthy', checks: c });
};
```

### Alert Thresholds

```yaml
critical:  # Page on-call
  - health check failing 3x consecutively
  - 5xx rate > 5% over 5 minutes
  - disk usage > 90%
warning:   # Slack notification
  - p95 response > 2s for 10 min
  - memory > 80%
  - queue backlog > 1000 for 15 min
  - SSL cert expiry < 14 days
```

---

## CDN Setup

```
Cloudflare DNS (proxied):
  A     example.com   -> server_ip
  CNAME www           -> example.com

SSL/TLS: Full (Strict), min TLS 1.2, HSTS ON
Page Rules:
  /api/*    -> Cache Bypass (dynamic responses)
  /build/*  -> Cache Everything, TTL 1 month (hashed filenames)
  /*.html   -> Cache Bypass (always fresh)
```

```nginx
# Origin cache headers for Cloudflare
location /build/ { expires max; add_header Cache-Control "public, immutable"; }
location ~* \.html$ { add_header Cache-Control "no-cache, must-revalidate"; }
location /api/ { add_header Cache-Control "no-store, private"; }
```

```bash
# Purge cache after deploy (HTML only -- static assets use hashed names)
curl -sX POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"files":["https://example.com/","https://example.com/index.html"]}'
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Reload nginx | `sudo nginx -t && sudo systemctl reload nginx` |
| Reload PHP-FPM | `sudo systemctl reload php8.3-fpm` |
| PM2 zero-downtime | `pm2 reload ecosystem.config.js` |
| Clear OPcache | restart FPM or `php artisan opcache:clear` |
| Docker rebuild | `docker compose build --no-cache app` |
| Rollback | `ln -sfn /releases/PREV /var/www/app/current` |
| Manual backup | `/usr/local/bin/backup.sh` |
| Restore DB | `gunzip < backup.sql.gz \| mysql -u USER -p DB` |
| Check SSL | `openssl s_client -connect example.com:443 </dev/null 2>&1 \| openssl x509 -noout -dates` |
