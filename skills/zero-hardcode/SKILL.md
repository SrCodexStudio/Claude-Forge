---
name: zero-hardcode
description: Scan codebase for hardcoded secrets, tokens, API keys, fallback patterns, and inline defaults. Reports violations with file, line, severity, and fix suggestions.
triggers:
  - "scan for hardcode"
  - "security scan"
  - "check secrets"
  - "hardcode check"
  - "zero hardcode"
  - "find hardcoded"
  - "scan secrets"
  - "check for credentials"
author: SrCodexStudio
version: 1.0.0
---

# Zero Hardcode Scanner

Scan the entire codebase for hardcoded secrets, tokens, API keys, fallback patterns, and inline defaults. Produce a structured report with file path, line number, pattern matched, severity level, and a concrete fix suggestion for each violation.

## Activation

Run this skill:
- Before writing or modifying ANY code (Rule 0 enforcement)
- When the user says "scan for hardcode", "security scan", "check secrets"
- As a pre-commit quality gate
- During security audits

## Scan Targets

### Category 1: Direct Secret Hardcoding (CRITICAL)

Scan for literals that look like secrets embedded directly in source code:

```
PATTERNS:
  API Keys:        sk-[a-zA-Z0-9]{20,}
                   ghp_[a-zA-Z0-9]{36}
                   AKIA[A-Z0-9]{16}
                   AIzaSy[a-zA-Z0-9_-]{33}
  Bot Tokens:      xoxb-[a-zA-Z0-9-]+
                   [A-Za-z0-9]{24}\.[A-Za-z0-9]{6}\.[A-Za-z0-9_-]{27}  (Discord)
  Bearer Tokens:   Bearer [a-zA-Z0-9._-]{20,}
  Private Keys:    -----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----
  Connection Strings: (mysql|postgres|mongodb|redis):\/\/[^\s'"]+
  Passwords:       password\s*=\s*['"][^'"]{4,}['"]
  Webhook URLs:    https:\/\/discord\.com\/api\/webhooks\/
                   https:\/\/hooks\.slack\.com\/
```

### Category 2: Fallback Anti-Patterns (HIGH)

Scan for environment variable reads with inline fallback values that expose real defaults:

```
PATTERNS (by language):

JavaScript/TypeScript:
  process\.env\.\w+\s*\|\|\s*['"][^'"]+['"]
  process\.env\.\w+\s*\?\?\s*['"][^'"]+['"]

PHP/Laravel:
  env\(\s*['"][^'"]+['"]\s*,\s*['"][^'"]+['"]\s*\)
  config\(\s*['"][^'"]+['"]\s*,\s*['"0-9][^)]*\)
  Env::value\(\s*['"][^'"]+['"]\s*,\s*['"][^'"]+['"]\s*\)

Python:
  os\.getenv\(\s*['"][^'"]+['"]\s*,\s*['"][^'"]+['"]\s*\)
  os\.environ\.get\(\s*['"][^'"]+['"]\s*,\s*['"][^'"]+['"]\s*\)

Kotlin/Java:
  System\.getenv\(\s*['"][^'"]+['"]\s*\)\s*\?:\s*['"][^'"]+['"]
  getProperty\(\s*['"][^'"]+['"]\s*,\s*['"][^'"]+['"]\s*\)

Go:
  os\.Getenv\(".*"\)\s*$  (followed by if == "" { variable = "default" })
```

### Category 3: Hardcoded Infrastructure (MEDIUM)

Scan for hardcoded network values that should be configurable:

```
PATTERNS:
  IP Addresses:    \b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b  (excluding 127.0.0.1, 0.0.0.0)
  Ports:           :\d{4,5}  (in connection strings or URLs)
  URLs:            https?:\/\/[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}\/[^\s'"]+  (non-CDN, non-standard-library)
```

### Category 4: Inline Config Defaults (LOW)

Scan for configuration values that should live in config files:

```
PATTERNS:
  config\(\s*['"][^'"]+['"]\s*,\s*\d+\s*\)           (numeric defaults)
  config\(\s*['"][^'"]+['"]\s*,\s*(true|false)\s*\)   (boolean defaults)
  setTimeout\(\s*.*,\s*\d{4,}\s*\)                    (hardcoded timeouts > 999ms)
```

## Exclusions

Do NOT flag these as violations:
- HTTP status codes: `200`, `404`, `500`
- Mathematical constants: `Math.PI`, `3.14159`
- Standard charsets: `utf-8`, `UTF-8`
- Content types: `application/json`, `text/html`
- Array indices and loop bounds
- Language primitives: `true`, `false`, `null`, `undefined`
- Standard CDN URLs: `cdnjs.cloudflare.com`, `unpkg.com`, `cdn.jsdelivr.net`
- File paths within the project (relative imports)
- Test files with mock/fixture data (unless they contain real-looking secrets)
- `.env.example` files (they contain placeholders, not real values)

## Execution Procedure

```
STEP 1: ANNOUNCE
  Print: "EJECUTANDO CHEQUEO DE HARDCODEO..."

STEP 2: DETECT PROJECT TYPE
  Scan for: package.json, composer.json, build.gradle.kts, go.mod, pyproject.toml, requirements.txt
  Determine file extensions to scan based on detected project type

STEP 3: SCAN
  For each scan category (1-4):
    Use Grep tool with each regex pattern against the codebase
    Exclude: node_modules/, vendor/, .git/, dist/, build/, __pycache__/, .venv/
    Exclude: *.min.js, *.min.css, *.map, *.lock, *.sum
    Record: file path, line number, matched text, category, severity

STEP 4: DEDUPLICATE
  Remove duplicate findings (same file + same line)
  Group findings by file

STEP 5: GENERATE REPORT
  Format output as shown in Report Format section below

STEP 6: SUGGEST FIXES
  For each finding, provide:
    - What to add to .env
    - What to add to .env.example
    - How to modify the source code
    - Whether .gitignore needs updating
```

## Report Format

```
========================================
  ZERO HARDCODE SCAN REPORT
========================================

Project: [project name]
Scanned: [N] files
Date: [timestamp]

SUMMARY:
  CRITICAL: [count]  (direct secrets)
  HIGH:     [count]  (fallback patterns)
  MEDIUM:   [count]  (hardcoded infrastructure)
  LOW:      [count]  (inline defaults)
  TOTAL:    [count]

----------------------------------------

[CRITICAL] src/config/database.ts:15
  Pattern:  Direct secret hardcoding
  Match:    const dbUrl = "mysql://root:password@localhost:3306/mydb"
  Fix:      Move to .env as DATABASE_URL, reference via process.env.DATABASE_URL
  .env:     DATABASE_URL=mysql://root:password@localhost:3306/mydb
  .env.example: DATABASE_URL=mysql://user:password@host:3306/dbname

[HIGH] src/server.ts:8
  Pattern:  Fallback anti-pattern (||)
  Match:    const port = process.env.PORT || 3000
  Fix:      Remove fallback, add PORT=3000 to .env, add validation
  .env:     PORT=3000
  Code:     const port = parseInt(process.env.PORT); if (!port) throw new Error('PORT required');

[MEDIUM] src/api/client.ts:22
  Pattern:  Hardcoded IP address
  Match:    const host = "192.168.1.100"
  Fix:      Move to .env as API_HOST
  .env:     API_HOST=192.168.1.100

[LOW] src/cache.ts:5
  Pattern:  Inline config default
  Match:    config('cache.ttl', 3600)
  Fix:      Define default in config/cache.php, not inline
  Config:   'ttl' => env('CACHE_TTL', 3600),

----------------------------------------

VERIFICATION CHECKLIST:
  [ ] All secrets moved to .env
  [ ] .env.example updated with placeholders
  [ ] .env listed in .gitignore
  [ ] Source code references env vars, not literals
  [ ] Fail-fast validation added for required vars

========================================
```

## Integration

This skill should run:
1. BEFORE any code modification task (mandatory gate)
2. As part of CI/CD pipelines (export findings as JSON)
3. During code review (flag new violations in diff)
4. On demand when user requests a security scan

## Language-Specific Fix Templates

### JavaScript/TypeScript
```javascript
// Before (violation)
const token = process.env.TOKEN || 'sk-default-token';
// After (fixed)
const token = process.env.TOKEN;
if (!token) throw new Error('TOKEN environment variable is required');
```

### PHP/Laravel
```php
// Before (violation)
$timeout = config('auth.lockout', 15);
// After (fixed)
// In config/auth.php: 'lockout' => env('AUTH_LOCKOUT_MINUTES'),
// In .env: AUTH_LOCKOUT_MINUTES=15
$timeout = config('auth.lockout');
```

### Python
```python
# Before (violation)
timeout = os.getenv('TIMEOUT', '30')
# After (fixed)
timeout = os.environ['TIMEOUT']  # Fails fast if missing
```

### Kotlin
```kotlin
// Before (violation)
val port = System.getenv("PORT") ?: "25565"
// After (fixed)
val port = System.getenv("PORT")
    ?: throw IllegalStateException("PORT environment variable is required")
```

### Go
```go
// Before (violation)
port := os.Getenv("PORT")
if port == "" { port = "8080" }
// After (fixed)
port := os.Getenv("PORT")
if port == "" {
    log.Fatal("PORT environment variable is required")
}
```
