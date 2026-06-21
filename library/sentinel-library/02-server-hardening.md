# Sentinel Library: Server Hardening

> Reference knowledge for securing Linux servers and web infrastructure
> Read BEFORE configuring SSH, firewalls, web servers, or containers

---

## 1. SSH Hardening

### 1.1 Key-Only Authentication

Password authentication is the single most exploited vector on internet-facing servers.
Disable it entirely once SSH keys are in place.

**Generate a strong key pair on the CLIENT machine:**

```bash
# Ed25519 is the modern standard -- shorter, faster, more secure than RSA
ssh-keygen -t ed25519 -C "admin@myserver" -f ~/.ssh/myserver_ed25519

# If you must support legacy systems that lack Ed25519
ssh-keygen -t rsa -b 4096 -C "admin@myserver" -f ~/.ssh/myserver_rsa
```

**Copy the public key to the server:**

```bash
ssh-copy-id -i ~/.ssh/myserver_ed25519.pub -p 2222 admin@server-ip
```

### 1.2 sshd_config -- Complete Hardened Configuration

```bash
# /etc/ssh/sshd_config -- Hardened SSH configuration
# Apply with: systemctl restart sshd

# ---------- NETWORK ----------
# Use a non-standard port to reduce automated scanning noise.
# This is NOT security by itself, but cuts 99% of brute-force attempts.
Port 2222

# Listen only on the management interface if the server has multiple NICs
#ListenAddress 10.0.0.5

# Use only SSHv2 -- SSHv1 is broken beyond repair
Protocol 2

# ---------- AUTHENTICATION ----------
# Disable password login entirely -- keys only
PasswordAuthentication no
ChallengeResponseAuthentication no

# Disable empty passwords (defense in depth even with password auth off)
PermitEmptyPasswords no

# Enable public key authentication
PubkeyAuthentication yes

# Where to find authorized keys
AuthorizedKeysFile .ssh/authorized_keys

# Disable root login -- always use a regular user + sudo
PermitRootLogin no

# Only allow specific users to connect via SSH
AllowUsers deployer admin
# Alternative: restrict by group
# AllowGroups sshusers

# Limit authentication attempts per connection
MaxAuthTries 3

# Close sessions that fail to authenticate within 30 seconds
LoginGraceTime 30

# ---------- SESSION HARDENING ----------
# Disconnect idle sessions after 5 minutes (300 seconds)
ClientAliveInterval 300
ClientAliveCountMax 0

# Limit maximum concurrent unauthenticated connections
MaxStartups 3:50:10

# Disable X11 forwarding -- rarely needed on servers
X11Forwarding no

# Disable TCP forwarding unless explicitly needed
AllowTcpForwarding no

# Disable agent forwarding -- leaking your SSH agent to a compromised
# server lets an attacker use YOUR keys to reach other machines
AllowAgentForwarding no

# Disable gateway ports
GatewayPorts no

# ---------- CRYPTO ----------
# Restrict key exchange, ciphers, and MACs to strong algorithms only
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# ---------- LOGGING ----------
LogLevel VERBOSE
# VERBOSE logs key fingerprints on login -- essential for auditing who accessed the server

# ---------- MISC ----------
# Disable MOTD and banner spam
PrintMotd no
PrintLastLog yes

# Restrict SFTP to a chroot if needed
# Subsystem sftp internal-sftp
# Match Group sftponly
#     ChrootDirectory /srv/sftp/%u
#     ForceCommand internal-sftp
#     AllowTcpForwarding no
```

### 1.3 SSH Agent Forwarding Risks

```
DANGEROUS: Agent forwarding (-A flag or ForwardAgent yes)

When you SSH to Server A with agent forwarding enabled, Server A can use
YOUR private key to authenticate to Server B on your behalf.

If Server A is compromised, the attacker gains access to every server
your SSH agent holds keys for -- without ever seeing the private key file.

SAFER ALTERNATIVE: Use ProxyJump (-J flag)
  ssh -J jump-host target-host

ProxyJump tunnels the SSH connection through the jump host without
exposing your agent socket on the intermediate machine.
```

### 1.4 fail2ban for SSH

```ini
# /etc/fail2ban/jail.local

[sshd]
enabled  = true
port     = 2222
filter   = sshd
logpath  = /var/log/auth.log
# Ban after 3 failed attempts
maxretry = 3
# Ban duration: 1 hour
bantime  = 3600
# Detection window: 10 minutes
findtime = 600
# Use iptables to enforce bans
banaction = iptables-multiport
```

---

## 2. Firewall Configuration

### 2.1 iptables -- Complete Web Server Script

```bash
#!/bin/bash
# /etc/iptables/rules.sh -- Complete firewall for a web server
# Run as root. Persist with: iptables-save > /etc/iptables/rules.v4

# ---------- FLUSH EXISTING RULES ----------
iptables -F
iptables -X
iptables -Z

# ---------- DEFAULT POLICIES ----------
# Drop everything by default -- whitelist approach
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ---------- LOOPBACK ----------
# Allow all traffic on localhost (required for many services)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ---------- ESTABLISHED/RELATED ----------
# Allow return traffic for connections WE initiated
# This is the foundation of stateful firewalling
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ---------- DROP INVALID PACKETS ----------
# Packets that don't belong to any known connection -- often scans or attacks
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# ---------- ICMP (PING) ----------
# Allow ping but rate-limit to prevent ping flood
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 4 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# ---------- SSH ----------
# Allow SSH on custom port with rate limiting
# -m recent: track source IPs and throttle repeated connections
iptables -A INPUT -p tcp --dport 2222 -m conntrack --ctstate NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 2222 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 2222 -m conntrack --ctstate NEW -j ACCEPT

# ---------- HTTP / HTTPS ----------
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# ---------- REJECT EVERYTHING ELSE ----------
# Use REJECT instead of DROP for TCP -- sends RST so legitimate clients
# fail fast instead of hanging until timeout
iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -A INPUT -j DROP

echo "Firewall rules applied."
```

### 2.2 ufw -- Simplified Ubuntu Setup

```bash
# Reset to clean state
sudo ufw reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow services
sudo ufw allow 2222/tcp comment 'SSH on custom port'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Rate limit SSH to prevent brute force (6 attempts in 30 seconds triggers block)
sudo ufw limit 2222/tcp

# Enable the firewall
sudo ufw enable

# Verify
sudo ufw status verbose
```

### 2.3 nftables -- Modern Replacement

```bash
#!/usr/sbin/nft -f
# /etc/nftables.conf -- Modern firewall using nftables

flush ruleset

table inet firewall {
    chain input {
        type filter hook input priority 0; policy drop;

        # Loopback
        iif lo accept

        # Established/related
        ct state established,related accept

        # Drop invalid
        ct state invalid drop

        # ICMP (rate limited)
        ip protocol icmp icmp type echo-request limit rate 1/second accept
        ip6 nexthdr ipv6-icmp icmpv6 type echo-request limit rate 1/second accept

        # SSH with rate limiting
        tcp dport 2222 ct state new limit rate 3/minute accept

        # HTTP and HTTPS
        tcp dport { 80, 443 } accept

        # Reject TCP with RST, drop everything else
        tcp flags & (fin|syn|rst|ack) == syn reject with tcp reset
        drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```

### 2.4 Port Knocking Concept

```
Port knocking hides services behind a sequence of connection attempts.
The SSH port stays closed until the correct "knock sequence" is received.

Example with knockd:

  Knock sequence: 7000, 8000, 9000 (TCP SYN to each in order)
  After correct sequence: SSH port 2222 opens for the source IP for 30 seconds

This adds obscurity on top of real security. It is NOT a replacement for
key-based auth, but it stops your SSH port from appearing in port scans.
```

---

## 3. Nginx Security Headers

### 3.1 Content-Security-Policy

```nginx
# Content-Security-Policy controls WHAT content the browser is allowed to load.
# Each directive restricts a specific resource type.

# STARTER POLICY -- restrictive baseline
add_header Content-Security-Policy "
    default-src 'self';
    script-src 'self';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    font-src 'self';
    connect-src 'self';
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
    upgrade-insecure-requests;
" always;

# DIRECTIVE BREAKDOWN:
#   default-src 'self'       -- Fallback: only allow content from same origin
#   script-src 'self'        -- JavaScript only from our domain (blocks inline scripts)
#   style-src 'self' 'unsafe-inline' -- CSS from our domain + inline styles
#                               (inline needed for many frameworks; use nonces if possible)
#   img-src 'self' data: https: -- Images from our domain, data URIs, and any HTTPS source
#   font-src 'self'          -- Fonts only from our domain
#   connect-src 'self'       -- XHR/fetch/WebSocket only to our domain
#   frame-ancestors 'none'   -- Prevent ANY site from embedding us in iframe (replaces X-Frame-Options)
#   base-uri 'self'          -- Prevent base tag hijacking
#   form-action 'self'       -- Forms can only submit to our domain
#   upgrade-insecure-requests -- Auto-upgrade HTTP requests to HTTPS
```

```
DANGEROUS: Overly permissive CSP that provides no protection

    Content-Security-Policy: default-src * 'unsafe-inline' 'unsafe-eval'

    This allows scripts from anywhere, inline scripts, and eval() -- 
    effectively the same as having no CSP at all.
```

### 3.2 Complete Nginx Server Block with All Headers

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    # --- SSL (see Section 4 for full config) ---
    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    # --- SECURITY HEADERS ---

    # HSTS: tell browsers to ONLY use HTTPS for this domain
    # max-age=31536000 = 1 year; includeSubDomains covers *.example.com
    # preload: submit to hstspreload.org to be hardcoded in browsers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Prevent MIME type sniffing -- browser must respect declared Content-Type
    add_header X-Content-Type-Options "nosniff" always;

    # Clickjacking protection -- use frame-ancestors in CSP instead if possible
    # DENY = no framing at all; SAMEORIGIN = only same domain can frame
    add_header X-Frame-Options "DENY" always;

    # Referrer-Policy: control what URL info is sent in the Referer header
    # strict-origin-when-cross-origin: send origin only for cross-origin, full URL for same-origin
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Permissions-Policy: disable browser features you do not use
    # Reduces attack surface from compromised JavaScript
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()" always;

    # CSP (see 3.1 for detailed breakdown)
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; upgrade-insecure-requests;" always;

    # Prevent browsers from caching sensitive pages
    # Apply selectively to admin/auth routes, not static assets
    # add_header Cache-Control "no-store, no-cache, must-revalidate" always;

    # --- HIDE SERVER INFO ---
    # Do not reveal nginx version in headers or error pages
    server_tokens off;

    # Remove X-Powered-By header set by PHP/Node/etc
    proxy_hide_header X-Powered-By;
    fastcgi_hide_header X-Powered-By;

    # --- ROOT AND LOCATIONS ---
    root /var/www/example.com/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Block access to hidden files (.env, .git, .htaccess)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block access to sensitive file extensions
    location ~* \.(sql|bak|log|ini|conf|env|yml|yaml|toml|lock)$ {
        deny all;
    }

    access_log /var/log/nginx/example.com.access.log;
    error_log  /var/log/nginx/example.com.error.log warn;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}
```

---

## 4. SSL/TLS Configuration

### 4.1 Generate Strong DH Parameters

```bash
# Generate a 4096-bit DH parameter file -- this takes several minutes
# Used for DHE key exchange (forward secrecy for older clients)
openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
```

### 4.2 Complete ssl-params.conf

```nginx
# /etc/nginx/snippets/ssl-params.conf
# Include this file in every server block that serves HTTPS

# ---------- PROTOCOL VERSIONS ----------
# TLS 1.2 is the minimum safe version. TLS 1.3 is preferred.
# TLS 1.0 and 1.1 have known vulnerabilities and must NOT be enabled.
ssl_protocols TLSv1.2 TLSv1.3;

# ---------- CIPHER SUITES ----------
# Prefer server ciphers over client ciphers to enforce strong crypto
ssl_prefer_server_ciphers on;

# TLS 1.2 ciphers -- ECDHE for forward secrecy, AESGCM for authenticated encryption
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
# TLS 1.3 ciphers are configured automatically by OpenSSL and cannot be overridden

# ---------- DIFFIE-HELLMAN ----------
ssl_dhparam /etc/ssl/certs/dhparam.pem;

# ---------- ECDH CURVE ----------
ssl_ecdh_curve X25519:secp384r1;

# ---------- SESSION CACHING ----------
# Shared cache reduces SSL handshake overhead for returning visitors
ssl_session_cache shared:TLS:10m;
ssl_session_timeout 1d;
# Disable session tickets -- they can weaken forward secrecy if the
# ticket key is compromised and not rotated
ssl_session_tickets off;

# ---------- OCSP STAPLING ----------
# Server fetches certificate revocation status and staples it to the TLS
# handshake -- faster for clients and more private (client doesn't need
# to contact the CA's OCSP responder)
ssl_stapling on;
ssl_stapling_verify on;

# Trusted CA chain for OCSP verification
ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

# Use a public DNS resolver for OCSP fetching
resolver 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 5s;
```

```
DANGEROUS: Weak SSL configuration that is still common

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;    # TLS 1.0/1.1 are broken
    ssl_ciphers ALL:!aNULL;                   # Includes weak ciphers like RC4, 3DES
    ssl_prefer_server_ciphers off;            # Lets client choose weak ciphers
    ssl_session_tickets on;                   # Weakens forward secrecy
```

### 4.3 Let's Encrypt Automation

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate (nginx plugin handles config automatically)
sudo certbot --nginx -d example.com -d www.example.com

# Verify auto-renewal timer
sudo systemctl status certbot.timer

# Test renewal without actually renewing
sudo certbot renew --dry-run

# Renewal hook to reload nginx after certificate update
# /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
#!/bin/bash
systemctl reload nginx
```

---

## 5. Rate Limiting

### 5.1 Nginx Rate Limiting

```nginx
# /etc/nginx/conf.d/rate-limiting.conf

# ---------- ZONE DEFINITIONS ----------
# Define rate limit zones in the http {} block (not inside server {})

# General requests: 10 requests per second per IP
# Zone size 10m can track ~160,000 unique IPs
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

# Login endpoint: 5 requests per minute per IP (strict)
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# API endpoint: 30 requests per second per IP
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

# Per-server rate limit (aggregate across all clients)
limit_req_zone $server_name zone=server_total:1m rate=1000r/s;

# ---------- APPLY LIMITS ----------
server {
    # General pages -- allow burst of 20 with no delay for the first 10
    location / {
        limit_req zone=general burst=20 nodelay;
        # burst=20: queue up to 20 excess requests
        # nodelay: serve burst requests immediately instead of spacing them
        # Requests beyond burst are rejected with 503
        limit_req_status 429;  # Return 429 Too Many Requests instead of 503
    }

    # Login -- very strict rate limiting
    location /login {
        limit_req zone=login burst=3 nodelay;
        limit_req_status 429;
    }

    # API -- generous burst for legitimate clients
    location /api/ {
        limit_req zone=api burst=50 nodelay;
        limit_req_status 429;
    }
}
```

### 5.2 Application-Level Rate Limiting (Token Bucket -- PHP)

```php
<?php
// Token bucket rate limiter using Redis
// Each user/IP gets a bucket with a fixed capacity that refills at a constant rate

class RateLimiter
{
    private Redis $redis;
    private int $capacity;     // Maximum tokens in the bucket
    private int $refillRate;   // Tokens added per second

    public function __construct(Redis $redis, int $capacity, int $refillRate)
    {
        $this->redis = $redis;
        $this->capacity = $capacity;
        $this->refillRate = $refillRate;
    }

    public function attempt(string $key): bool
    {
        $now = microtime(true);
        $bucketKey = "rate_limit:{$key}";

        // Lua script for atomic operation -- prevents race conditions
        $script = <<<'LUA'
            local key = KEYS[1]
            local capacity = tonumber(ARGV[1])
            local refill_rate = tonumber(ARGV[2])
            local now = tonumber(ARGV[3])

            local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
            local tokens = tonumber(bucket[1]) or capacity
            local last_refill = tonumber(bucket[2]) or now

            -- Calculate tokens to add since last request
            local elapsed = now - last_refill
            tokens = math.min(capacity, tokens + (elapsed * refill_rate))

            if tokens >= 1 then
                tokens = tokens - 1
                redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
                redis.call('EXPIRE', key, math.ceil(capacity / refill_rate) * 2)
                return 1
            else
                return 0
            end
        LUA;

        return (bool) $this->redis->eval(
            $script,
            [$bucketKey, $this->capacity, $this->refillRate, $now],
            1
        );
    }
}
```

### 5.3 Per-Endpoint Strategy

```
RATE LIMITING STRATEGY BY ENDPOINT TYPE:

| Endpoint        | Rate          | Burst | Key          | Why                               |
|-----------------|---------------|-------|--------------|-----------------------------------|
| /login          | 5/minute      | 3     | IP           | Prevent brute force               |
| /register       | 3/minute      | 2     | IP           | Prevent spam accounts             |
| /api/public     | 30/second     | 50    | IP           | General API protection            |
| /api/auth/*     | 60/second     | 100   | User ID      | Authenticated users get more      |
| /api/search     | 10/second     | 15    | IP + User    | Search is expensive               |
| /api/upload     | 5/minute      | 2     | User ID      | File uploads are resource-heavy   |
| /password-reset | 3/hour        | 1     | IP + Email   | Prevent email flooding            |
| /webhook        | 100/second    | 200   | Source IP    | Trusted sources need throughput   |
```

---

## 6. DDoS Mitigation Basics

### 6.1 Kernel Hardening Parameters

```bash
# /etc/sysctl.d/99-ddos-protection.conf
# Apply with: sysctl --system

# ---------- SYN FLOOD PROTECTION ----------
# Enable SYN cookies -- responds to SYN floods without allocating resources
# until the three-way handshake is complete
net.ipv4.tcp_syncookies = 1

# Reduce SYN-ACK retries (default is 5, which waits ~3 minutes per half-open conn)
net.ipv4.tcp_synack_retries = 2

# Increase SYN backlog to handle burst traffic
net.ipv4.tcp_max_syn_backlog = 4096

# ---------- CONNECTION TRACKING ----------
# Increase connection tracking table size for high-traffic servers
net.netfilter.nf_conntrack_max = 1000000

# Reduce timeout for established connections (default 432000 = 5 days)
net.netfilter.nf_conntrack_tcp_timeout_established = 86400

# ---------- GENERAL TCP HARDENING ----------
# Disable source routing (prevents IP spoofing attacks)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Enable reverse path filtering (drop packets with spoofed source IPs)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects (prevents MITM routing attacks)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Ignore broadcast pings (prevents Smurf amplification attacks)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Log martian packets (impossible source addresses -- often attack traffic)
net.ipv4.conf.all.log_martians = 1

# ---------- MEMORY TUNING ----------
# Increase socket buffer sizes for high-traffic scenarios
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# Reduce TIME_WAIT sockets (free up ports faster after connections close)
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
```

### 6.2 Nginx Timeout and Connection Limiting

```nginx
# /etc/nginx/conf.d/ddos-mitigation.conf

# ---------- TIMEOUTS ----------
# Slowloris mitigation: close connections that send data too slowly
# Slowloris holds connections open by sending partial headers very slowly,
# exhausting server connection limits

client_body_timeout   10;   # Time to receive request body
client_header_timeout 10;   # Time to receive request headers
send_timeout          10;   # Time between successive write operations
keepalive_timeout     15;   # How long to keep idle connections open

# Limit request body size -- prevents memory exhaustion from large uploads
client_max_body_size 10m;

# Limit request header size
large_client_header_buffers 4 8k;

# ---------- CONNECTION LIMITING ----------
# Define zone: track connections per IP
limit_conn_zone $binary_remote_addr zone=conn_per_ip:10m;

# Apply limit: max 50 concurrent connections per IP
limit_conn conn_per_ip 50;
limit_conn_status 429;

# ---------- BUFFER OVERFLOW PROTECTION ----------
client_body_buffer_size   1k;
client_header_buffer_size 1k;
```

### 6.3 Cloudflare Integration Basics

```nginx
# When behind Cloudflare, restore the real visitor IP
# Cloudflare sends the original IP in CF-Connecting-IP header

# Trust Cloudflare proxy IPs (update periodically from cloudflare.com/ips)
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;

# Use the CF-Connecting-IP header as the real client IP
real_ip_header CF-Connecting-IP;

# IMPORTANT: When behind Cloudflare, block direct IP access to your server
# Only allow Cloudflare IPs to reach your web ports
# This prevents attackers from bypassing Cloudflare by hitting your IP directly
```

---

## 7. Docker Security

### 7.1 Running Containers as Non-Root

```dockerfile
# Dockerfile -- Running as non-root user

FROM node:20-alpine

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy package files and install dependencies as root (needs write to /app)
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY --chown=appuser:appgroup . .

# Switch to non-root user BEFORE running the application
# Everything after this line runs as appuser
USER appuser

EXPOSE 3000

CMD ["node", "server.js"]
```

```
DANGEROUS: Running as root inside containers

    FROM node:20
    COPY . /app
    CMD ["node", "server.js"]
    # No USER directive -- defaults to root
    # If the application has an RCE vulnerability, the attacker gets root
    # inside the container and can potentially escape to the host
```

### 7.2 Read-Only Filesystem and Resource Limits

```yaml
# docker-compose.yml -- Security-hardened service

version: '3.8'

services:
  web:
    image: myapp:latest
    # Drop all Linux capabilities except what the app needs
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE   # Allow binding to ports < 1024 if needed
    # Make filesystem read-only -- prevents attackers from writing malware
    read_only: true
    # Temporary writable directories for runtime needs
    tmpfs:
      - /tmp:size=64M
      - /var/run:size=1M
    # Resource limits -- prevent a compromised container from consuming all host resources
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.25'
    # Security options
    security_opt:
      - no-new-privileges:true   # Prevent privilege escalation inside container
    # Health check
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  db:
    image: postgres:16-alpine
    read_only: true
    tmpfs:
      - /tmp:size=64M
      - /run/postgresql:size=1M
    volumes:
      # Data volume is the ONLY writable mount
      - pgdata:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '2.0'
    security_opt:
      - no-new-privileges:true
    # Do NOT expose database port to the host
    # Only accessible from other containers on the same network
    # ports:            # INTENTIONALLY OMITTED
    #   - "5432:5432"   # NEVER expose DB to host network

volumes:
  pgdata:
```

### 7.3 Network Isolation

```yaml
# docker-compose.yml -- Network isolation example

version: '3.8'

services:
  nginx:
    image: nginx:alpine
    networks:
      - frontend    # Can reach the internet and the app
    ports:
      - "443:443"

  app:
    image: myapp:latest
    networks:
      - frontend    # Reachable by nginx
      - backend     # Can reach the database
    # No ports exposed to host -- only accessible through nginx

  db:
    image: postgres:16-alpine
    networks:
      - backend     # ONLY reachable by app -- NOT by nginx, NOT from host
    # No ports exposed to host

  redis:
    image: redis:7-alpine
    networks:
      - backend
    # No ports exposed to host

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No outbound internet access from this network
```

### 7.4 Secrets Management

```yaml
# docker-compose.yml -- Using Docker secrets instead of env vars

version: '3.8'

services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    environment:
      # Reference secret FILES, not the values directly
      DB_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key

# Secrets are mounted as files in /run/secrets/ inside the container
# They are stored encrypted and only available to services that declare them
secrets:
  db_password:
    file: ./secrets/db_password.txt     # For development
    # external: true                    # For production (Docker Swarm)
  api_key:
    file: ./secrets/api_key.txt
```

```
DANGEROUS: Passing secrets via environment variables

    environment:
      - DB_PASSWORD=SuperSecret123
      - API_KEY=sk-live-abc123

    Environment variables are visible in:
      - docker inspect output
      - /proc/1/environ inside the container
      - docker-compose.yml committed to version control
      - CI/CD logs that dump environment
    
    Use Docker secrets or a secrets manager (Vault, AWS SM) instead.
```

### 7.5 Image Scanning

```bash
# Scan images for known vulnerabilities before deploying

# Trivy -- fast, comprehensive vulnerability scanner
trivy image myapp:latest

# Output: lists CVEs by severity (CRITICAL, HIGH, MEDIUM, LOW)
# Fix: update base image and dependencies, rebuild

# Grype -- alternative scanner
grype myapp:latest

# Integrate into CI/CD pipeline:
# Fail the build if CRITICAL or HIGH vulnerabilities are found
trivy image --exit-code 1 --severity CRITICAL,HIGH myapp:latest
```

---

## 8. Log Monitoring

### 8.1 Centralized Logging with rsyslog

```bash
# /etc/rsyslog.d/50-remote.conf
# Forward all logs to a central log server

# Send auth logs to remote syslog server over TLS
auth,authpriv.*    @@logserver.internal:6514

# Send all logs at warning level or above
*.warn             @@logserver.internal:6514

# Local retention: keep auth logs separately
auth,authpriv.*    /var/log/auth.log
```

### 8.2 Log Rotation

```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily              # Rotate every day
    missingok          # Don't error if log file is missing
    rotate 30          # Keep 30 rotated files
    compress           # Compress rotated files with gzip
    delaycompress      # Don't compress the most recent rotated file
    notifempty         # Don't rotate if log is empty
    create 0640 www-data adm   # Permissions for new log file
    sharedscripts      # Run postrotate once for all matching files
    postrotate
        # Signal nginx to reopen log files after rotation
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 $(cat /var/run/nginx.pid)
        fi
    endscript
}
```

### 8.3 Security-Relevant Log Patterns

```bash
# Patterns to watch in auth.log (SSH attacks)
# Failed password -- brute force indicator
grep "Failed password" /var/log/auth.log | tail -20

# Invalid user -- scanning for common usernames
grep "Invalid user" /var/log/auth.log | tail -20

# Accepted publickey -- audit who logged in and when
grep "Accepted publickey" /var/log/auth.log | tail -20

# Patterns to watch in nginx access.log
# 4xx errors spike -- scanning or fuzzing
awk '$9 ~ /^4/ {print $1, $7, $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Requests to sensitive paths -- looking for .env, wp-admin, phpmyadmin
grep -E '\.(env|git|bak|sql|config)' /var/log/nginx/access.log

# Suspiciously large request bodies -- possible upload attacks
awk '$10 > 1000000 {print $1, $7, $10}' /var/log/nginx/access.log

# SQL injection attempts in URLs
grep -iE "(union|select|drop|insert|update|delete|script|alert)\b" /var/log/nginx/access.log
```

### 8.4 Custom fail2ban Filters

```ini
# /etc/fail2ban/filter.d/nginx-badbots.conf
# Block bots that scan for vulnerabilities

[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*(wp-login|wp-admin|phpMyAdmin|phpmyadmin|\.env|\.git|cgi-bin|admin\.php).*" (400|403|404|444)
ignoreregex =

# /etc/fail2ban/filter.d/nginx-auth.conf
# Block repeated failed authentication attempts

[Definition]
failregex = ^<HOST> .* "(GET|POST) /login.*" (401|403)
            ^<HOST> .* "(POST) /api/auth.*" (401|403)
ignoreregex =
```

```ini
# /etc/fail2ban/jail.local -- Custom jails

[nginx-badbots]
enabled  = true
port     = http,https
filter   = nginx-badbots
logpath  = /var/log/nginx/access.log
maxretry = 3
bantime  = 86400    # 24 hours
findtime = 3600     # 1 hour window

[nginx-auth]
enabled  = true
port     = http,https
filter   = nginx-auth
logpath  = /var/log/nginx/access.log
maxretry = 5
bantime  = 3600     # 1 hour
findtime = 300      # 5 minute window
```

### 8.5 Log Integrity

```bash
# ---------- APPEND-ONLY LOGS ----------
# Use chattr to make log files append-only
# Even root cannot delete or truncate -- only append new entries
chattr +a /var/log/auth.log
chattr +a /var/log/syslog

# Verify the attribute
lsattr /var/log/auth.log
# Output: -----a--------e---- /var/log/auth.log

# To rotate logs, temporarily remove the attribute:
# chattr -a /var/log/auth.log
# logrotate -f /etc/logrotate.d/rsyslog
# chattr +a /var/log/auth.log

# ---------- REMOTE LOGGING ----------
# The most reliable tamper protection is to send logs to a separate server
# that the main server cannot modify.
#
# If an attacker compromises the web server, they can wipe local logs
# but the remote copy is safe.
#
# Use rsyslog, Fluentd, or Vector to forward logs in real-time.
# The log server should accept append-only writes and deny deletion.
```

### 8.6 Alerting on Suspicious Patterns

```bash
#!/bin/bash
# /usr/local/bin/security-alert.sh
# Run via cron every 5 minutes to detect suspicious patterns

LOG="/var/log/auth.log"
NGINX_LOG="/var/log/nginx/access.log"
ALERT_EMAIL="admin@example.com"
THRESHOLD_SSH=10
THRESHOLD_404=100

# Count SSH failures in the last 5 minutes
SSH_FAILS=$(grep "Failed password" "$LOG" \
    | awk -v cutoff="$(date -d '5 minutes ago' '+%b %d %H:%M')" '$0 >= cutoff' \
    | wc -l)

if [ "$SSH_FAILS" -gt "$THRESHOLD_SSH" ]; then
    echo "ALERT: $SSH_FAILS SSH failures in last 5 minutes" \
        | mail -s "[SECURITY] SSH brute force detected" "$ALERT_EMAIL"
fi

# Count 404s in the last 5 minutes (scanning indicator)
NOTFOUND=$(awk -v cutoff="$(date -d '5 minutes ago' '+%d/%b/%Y:%H:%M')" \
    '$4 >= "["cutoff && $9 == 404' "$NGINX_LOG" | wc -l)

if [ "$NOTFOUND" -gt "$THRESHOLD_404" ]; then
    echo "ALERT: $NOTFOUND 404 errors in last 5 minutes -- possible scanning" \
        | mail -s "[SECURITY] Scan activity detected" "$ALERT_EMAIL"
fi
```

```bash
# Cron entry to run every 5 minutes
# crontab -e
*/5 * * * * /usr/local/bin/security-alert.sh
```

---

## Quick Reference: Post-Install Hardening Checklist

```
AFTER PROVISIONING A NEW SERVER:

[ ] 1. Create non-root user with sudo
[ ] 2. Deploy SSH keys and disable password auth
[ ] 3. Change SSH port and restart sshd
[ ] 4. Install and configure fail2ban
[ ] 5. Configure firewall (ufw or iptables)
[ ] 6. Apply kernel hardening sysctl parameters
[ ] 7. Configure automatic security updates (unattended-upgrades)
[ ] 8. Install and configure nginx with security headers
[ ] 9. Obtain TLS certificate with certbot
[ ] 10. Configure log rotation and remote logging
[ ] 11. Remove unnecessary packages and services
[ ] 12. Disable IPv6 if not needed (reduces attack surface)
[ ] 13. Set up monitoring and alerting
[ ] 14. Test with: nmap, nikto, testssl.sh, Mozilla Observatory
```
