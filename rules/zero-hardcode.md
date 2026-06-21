# Zero Hardcode Policy

> Priority: CRITICAL. This rule executes BEFORE all other rules. Security is non-negotiable.

## Enforcement Protocol

Before writing or modifying any code, announce the scan and execute it:

1. Scan the target file and its immediate dependencies for hardcoded values.
2. Report any violations found with file path and line reference.
3. Fix every violation before proceeding with the requested task.

This applies universally: new projects, existing codebases, bug fixes, feature additions, refactoring, prototyping.

## Forbidden Patterns

### Direct Secret Embedding

```
NEVER place raw credentials in source files:

  token    = "sk-proj-abc123..."        # API key in code
  password = "MyP@ssw0rd!"             # Literal password
  db_url   = "mysql://root:pw@host/db" # Connection string
  webhook  = "https://hooks.slack.com/T00/B00/xxxxx"
```

All of these must come from environment variables or a secrets manager.

### The Fallback Anti-Pattern

This is the most common violation. Fallback operators silently expose real values when the environment variable is missing:

```
FORBIDDEN in every language:

  process.env.TOKEN || 'xoxb-real-token'        # JS/TS
  os.getenv('SECRET', 'actual-secret-value')     # Python
  Env::value('KEY', '15')                        # PHP
  config('app.key', 'base64:REAL_KEY')           # Laravel
  System.getenv("X") ?: "fallback-value"         # Kotlin
  os.Getenv("PORT"); if port == "" { port = "8080" }  # Go
```

The correct approach: fail fast when a required variable is absent.

```
CORRECT -- no fallback, explicit failure:

  const token = process.env.TOKEN;
  if (!token) throw new Error('TOKEN environment variable is required');

  import os; token = os.environ['TOKEN']  # KeyError if missing

  $timeout = config('auth.lockout_minutes');  // default lives in config file, not inline
```

### Hardcoded Infrastructure Values

These are configurable per deployment and must not live in source code:

| Category         | Examples                                              |
|------------------|-------------------------------------------------------|
| Authentication   | Tokens, API keys, passwords, JWT secrets, OAuth IDs   |
| Database         | Host, port, credentials, connection strings, DB names |
| Network          | IP addresses, hostnames, ports, webhook URLs          |
| Services         | SMTP config, Redis host, cache drivers, queue names   |
| Limits           | Timeouts, retry counts, rate limits, page sizes       |
| Feature flags    | Debug mode, maintenance mode, log levels              |
| External APIs    | Endpoint URLs, API versions, client IDs               |
| Cryptography     | Encryption keys, salts, initialization vectors        |

### Acceptable Literals

These may remain in code because they are universal constants:

- HTTP status codes: `200`, `404`, `500`
- Mathematical constants: `Math.PI`, `Math.E`
- Protocol standards: `'utf-8'`, `'application/json'`
- Language primitives: `true`, `false`, `null`, `0`, `1`
- Array indices and loop bounds tied to algorithmic logic

## Scan Patterns

When executing the pre-code scan, search for these regex patterns:

```
# API keys and tokens
sk-[a-zA-Z0-9]{20,}
ghp_[a-zA-Z0-9]{36}
AKIA[A-Z0-9]{16}
xoxb-[a-zA-Z0-9-]+

# Connection strings
(mysql|postgres|mongodb|redis):\/\/[^\s'"]+

# IP addresses outside comments
\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}

# Private keys
-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----

# Fallback operators with string/number values
\|\|\s*['"][^'"]+['"]
\?\?\s*['"][^'"]+['"]
\?\:\s*['"][^'"]+['"]
os\.getenv\(.+,\s*['"]
os\.environ\.get\(.+,\s*['"]
config\(.+,\s*['"0-9]
env\(.+,\s*['"]
```

## Remediation Protocol

When a violation is found:

1. Identify every hardcoded value in the affected file.
2. Create an environment variable name in `SCREAMING_SNAKE_CASE`.
3. Add the variable with its current value to `.env` (never committed).
4. Add a placeholder to `.env.example` (committed, no real values).
5. Replace the hardcoded value with an environment variable reference.
6. Add validation that fails fast if the variable is missing.
7. Confirm `.env` is listed in `.gitignore`.
8. Report all changes to the user.

## The .env.example Mandate

Every project that uses environment variables must have a `.env.example` file committed to version control. It contains variable names and placeholder descriptions, never real values:

```
# .env.example
BOT_TOKEN=your_bot_token_here
DATABASE_URL=mysql://user:password@host:3306/dbname
REDIS_HOST=your_redis_host
CACHE_TTL=3600
MAX_RETRIES=5
```

The `.gitignore` must exclude all real env files:

```
.env
.env.local
.env.production
*.pem
*.key
credentials.json
```

## Per-Language Config Locations

| Stack              | Config files                          |
|--------------------|---------------------------------------|
| Node.js / React    | `.env`, `.env.local`                  |
| PHP / Laravel      | `.env`, `config/*.php`                |
| Python / Django    | `.env`, `settings.py` (reads from env)|
| Kotlin / JVM       | `config.yml`, `.env`                  |
| Go                 | `.env`, `config.yaml`                 |
| Docker             | `.env`, `docker-compose.yml`          |

## Priority

This rule is always checked first. Execution order across the rule system:

1. Zero Hardcode scan (this rule)
2. Context recovery and project memory
3. Skill detection and activation
4. Parallel agent orchestration
5. The actual requested task
