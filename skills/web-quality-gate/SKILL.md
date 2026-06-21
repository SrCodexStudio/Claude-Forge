---
name: web-quality-gate
description: Comprehensive web quality audit covering accessibility (WCAG 2.2), best practices (CSP, headers), Core Web Vitals (LCP, INP, CLS), performance (loading, bundling), and SEO (meta tags, structured data). Gate that must pass before declaring any web task complete.
triggers:
  - "quality check"
  - "audit web"
  - "check quality"
  - "web audit"
  - "quality gate"
  - "check my site"
  - "review web quality"
  - "run lighthouse"
author: SrCodexStudio
version: 1.0.0
references:
  - https://github.com/nicholasadamou/web-quality-skills
---

# Web Quality Gate

Comprehensive web quality audit that runs 150+ checks across 6 domains. This skill acts as a mandatory gate -- no web task should be declared complete until it passes. Based on the addyosmani/nicholasadamou web-quality-skills framework.

## Activation

Run this skill:
- BEFORE declaring any web development task complete (mandatory gate)
- When the user says "quality check", "audit web", "check quality"
- After building or modifying any web page, component, or route
- During code review of frontend/web changes

## The 6 Audit Domains

### Domain 1: Accessibility (WCAG 2.2)

Audit for compliance with Web Content Accessibility Guidelines 2.2 Level AA.

```
CHECKS:

Semantic HTML:
  [ ] Proper heading hierarchy (h1 > h2 > h3, no skips)
  [ ] Landmarks used correctly (main, nav, aside, footer, header)
  [ ] Lists use <ul>, <ol>, <dl> -- not styled divs
  [ ] Tables have <thead>, <th>, scope attributes
  [ ] Forms use <fieldset> and <legend> for grouped controls

ARIA:
  [ ] Interactive elements have accessible names (aria-label or visible text)
  [ ] Dynamic content uses aria-live regions
  [ ] Decorative images have alt="" (empty alt, not missing alt)
  [ ] Informative images have descriptive alt text
  [ ] aria-hidden="true" on purely decorative elements
  [ ] No redundant ARIA (e.g., role="button" on a <button>)
  [ ] aria-expanded, aria-selected, aria-checked on applicable controls

Keyboard Navigation:
  [ ] All interactive elements reachable via Tab
  [ ] Logical tab order (no tabindex > 0)
  [ ] Focus visible on all interactive elements (:focus-visible styles)
  [ ] Escape closes modals/dropdowns
  [ ] Arrow keys navigate within composite widgets (tabs, menus)
  [ ] No keyboard traps
  [ ] Skip-to-content link present

Color and Contrast:
  [ ] Text contrast ratio >= 4.5:1 (normal text)
  [ ] Text contrast ratio >= 3:1 (large text, 18px+ or 14px+ bold)
  [ ] UI component contrast >= 3:1 (borders, icons, focus indicators)
  [ ] Information not conveyed by color alone
  [ ] Focus indicators have >= 3:1 contrast against adjacent colors

Forms:
  [ ] Every input has a visible <label> or aria-label
  [ ] Required fields marked with aria-required="true"
  [ ] Error messages associated via aria-describedby
  [ ] Error messages are descriptive (not just "invalid")
  [ ] Autocomplete attributes on applicable fields

Media:
  [ ] Videos have captions
  [ ] Audio has transcripts
  [ ] Animations respect prefers-reduced-motion
  [ ] No auto-playing media with sound
```

### Domain 2: Best Practices (Security and Standards)

Audit for modern web security headers, safe coding patterns, and standards compliance.

```
CHECKS:

Security Headers:
  [ ] Content-Security-Policy (CSP) header present
  [ ] X-Content-Type-Options: nosniff
  [ ] X-Frame-Options: DENY or SAMEORIGIN
  [ ] Referrer-Policy: strict-origin-when-cross-origin (or stricter)
  [ ] Permissions-Policy restricting unused APIs
  [ ] Strict-Transport-Security (HSTS) with max-age >= 31536000

Safe Coding:
  [ ] No inline <script> tags (use external files or nonce-based CSP)
  [ ] No document.write() usage
  [ ] No eval() or new Function() from strings
  [ ] No innerHTML with unsanitized user input
  [ ] All external links use rel="noopener noreferrer"
  [ ] Subresource Integrity (SRI) on CDN-hosted scripts/styles

HTTPS:
  [ ] All resources loaded over HTTPS (no mixed content)
  [ ] HTTP redirects to HTTPS
  [ ] Secure cookies (Secure, HttpOnly, SameSite attributes)

Dependencies:
  [ ] No known vulnerable dependencies (npm audit / composer audit)
  [ ] No deprecated APIs in use
  [ ] No console.log in production code
  [ ] Error boundaries/handlers in place (no unhandled exceptions visible to users)

Trusted Types:
  [ ] CSP includes trusted-types directive (if applicable)
  [ ] DOM sinks protected from injection
```

### Domain 3: Core Web Vitals

Audit for the three Core Web Vitals metrics that affect search ranking and user experience.

```
CHECKS:

LCP (Largest Contentful Paint) -- Target: < 2.5s:
  [ ] LCP element identified and optimized
  [ ] fetchpriority="high" on LCP image/resource
  [ ] LCP image preloaded: <link rel="preload" as="image">
  [ ] No render-blocking CSS/JS before LCP element
  [ ] Server response time < 200ms (TTFB)
  [ ] LCP element is not lazy-loaded
  [ ] Font used by LCP text has font-display: swap or optional

INP (Interaction to Next Paint) -- Target: < 200ms:
  [ ] No long tasks (>50ms) blocking main thread
  [ ] Event handlers do not perform synchronous layout
  [ ] Heavy computation offloaded to Web Workers
  [ ] Input handlers debounced/throttled where appropriate
  [ ] requestAnimationFrame used for visual updates
  [ ] No forced synchronous layouts (read then write in loops)

CLS (Cumulative Layout Shift) -- Target: < 0.1:
  [ ] All images have explicit width and height attributes
  [ ] All videos/iframes have explicit dimensions
  [ ] Web fonts do not cause layout shift (font-display strategy)
  [ ] Dynamically injected content has reserved space
  [ ] Ads/embeds have fixed-size containers
  [ ] No content inserted above existing content after load
  [ ] transform animations used instead of top/left/width/height
```

### Domain 4: Performance

Audit for loading performance, bundle efficiency, and runtime optimization.

```
CHECKS:

Loading:
  [ ] Critical CSS inlined or preloaded
  [ ] Non-critical CSS loaded asynchronously
  [ ] JavaScript deferred or async where possible
  [ ] Resources preconnected: <link rel="preconnect">
  [ ] DNS prefetched for known third-party domains
  [ ] Service worker registered for offline/cache (if applicable)

Images:
  [ ] Modern formats used (WebP, AVIF with fallbacks)
  [ ] Responsive images with srcset and sizes
  [ ] Images lazy-loaded (loading="lazy") except above-the-fold
  [ ] Images properly sized (not larger than display size)
  [ ] SVG used for icons and simple graphics
  [ ] Image compression applied (quality 75-85 for photos)

Bundling:
  [ ] Code splitting active (dynamic imports for routes/features)
  [ ] Tree shaking enabled (no dead code in bundles)
  [ ] Bundle size analyzed (no single chunk > 200KB gzipped)
  [ ] Third-party scripts loaded efficiently (defer, async, or dynamic)
  [ ] No duplicate dependencies in bundle

Caching:
  [ ] Static assets have cache-control headers (max-age >= 1 year for hashed files)
  [ ] HTML has short or no-cache policy
  [ ] ETags or Last-Modified headers present
  [ ] CDN configured for static assets

Runtime:
  [ ] No memory leaks (event listeners cleaned up, intervals cleared)
  [ ] Virtualized lists for large datasets (>100 items)
  [ ] Debounced scroll/resize handlers
  [ ] requestIdleCallback for non-urgent work
```

### Domain 5: SEO

Audit for search engine optimization fundamentals.

```
CHECKS:

Meta Tags:
  [ ] Unique <title> per page (50-60 characters)
  [ ] Unique <meta name="description"> per page (120-160 characters)
  [ ] <meta name="viewport" content="width=device-width, initial-scale=1">
  [ ] <html lang="xx"> attribute set correctly
  [ ] Canonical URL: <link rel="canonical">
  [ ] Open Graph tags (og:title, og:description, og:image, og:url)
  [ ] Twitter Card tags (twitter:card, twitter:title, twitter:description)

Structure:
  [ ] Single <h1> per page
  [ ] Heading hierarchy follows document outline
  [ ] Semantic HTML used (article, section, nav, aside)
  [ ] Breadcrumbs present (if applicable)
  [ ] Internal links use descriptive anchor text (not "click here")

Structured Data:
  [ ] JSON-LD schema present (Organization, WebSite, BreadcrumbList minimum)
  [ ] Schema validates against schema.org
  [ ] Article/Product/FAQ schema where applicable
  [ ] sameAs links to social profiles in Organization schema

Technical SEO:
  [ ] sitemap.xml present and valid
  [ ] robots.txt present and correct
  [ ] No noindex on pages that should be indexed
  [ ] 404 page returns proper 404 status code
  [ ] Redirects use 301 (permanent) not 302 (temporary)
  [ ] URLs are clean, lowercase, hyphenated
  [ ] No duplicate content (canonical tags handle variants)

Indexability:
  [ ] Pages are crawlable (not blocked by robots.txt or meta robots)
  [ ] SSR or SSG for content pages (not client-only rendering)
  [ ] Dynamic content visible in page source (not hidden behind JS)
```

### Domain 6: Mobile and Responsive

Audit for mobile-first design and responsive behavior.

```
CHECKS:

Responsive Design:
  [ ] Viewport meta tag present and correct
  [ ] No horizontal scroll on any viewport width
  [ ] Touch targets >= 44x44 CSS pixels
  [ ] Text readable without zooming (min 16px body text)
  [ ] Media queries use min-width (mobile-first)
  [ ] Content reflows properly at all breakpoints (320px to 1920px+)

Mobile UX:
  [ ] Phone numbers wrapped in tel: links
  [ ] Email addresses wrapped in mailto: links
  [ ] Forms use appropriate input types (tel, email, number, date)
  [ ] Autocomplete attributes on address/payment forms
  [ ] No hover-only interactions (touch alternatives exist)
```

## Execution Procedure

```
STEP 1: DETECT PROJECT TYPE
  Scan for framework indicators:
    - Next.js: next.config.js, app/ directory
    - Laravel: artisan, routes/web.php, resources/views/
    - React SPA: package.json with react, public/index.html
    - Static HTML: .html files without framework
  Determine which checks are applicable

STEP 2: RUN AUTOMATED CHECKS
  For each applicable domain:
    - Use Grep to search for patterns (missing alt text, inline scripts, etc.)
    - Use Read to inspect key files (layout, head, config)
    - Use Bash to run available tools (npm audit, lighthouse CLI if available)

STEP 3: MANUAL INSPECTION
  For checks that cannot be automated:
    - Note them as "MANUAL CHECK REQUIRED" in the report
    - Provide instructions for manual verification

STEP 4: SCORE AND REPORT
  Calculate per-domain scores and overall score
  Generate the report in the format below

STEP 5: FIX CRITICAL/HIGH ISSUES
  Automatically fix issues where possible:
    - Add missing alt="" to decorative images
    - Add missing width/height to images
    - Add rel="noopener noreferrer" to external links
    - Add loading="lazy" to below-fold images
  Report fixes applied

STEP 6: GATE DECISION
  PASS: No CRITICAL findings, no more than 3 HIGH findings
  CONDITIONAL PASS: No CRITICAL, but HIGH findings exist -- list required fixes
  FAIL: CRITICAL findings present -- must fix before declaring task complete
```

## Report Format

```
========================================
  WEB QUALITY GATE REPORT
========================================

Project: [name]
Framework: [detected framework]
Pages scanned: [count]
Date: [timestamp]

OVERALL SCORE: [0-100] / 100
GATE STATUS: PASS | CONDITIONAL PASS | FAIL

DOMAIN SCORES:
  Accessibility:     [0-100] [pass/fail]
  Best Practices:    [0-100] [pass/fail]
  Core Web Vitals:   [0-100] [pass/fail]
  Performance:       [0-100] [pass/fail]
  SEO:               [0-100] [pass/fail]
  Mobile:            [0-100] [pass/fail]

----------------------------------------

CRITICAL FINDINGS (must fix):
  [C1] [Domain] [file:line] Description -- Fix: [action]
  ...

HIGH FINDINGS (should fix):
  [H1] [Domain] [file:line] Description -- Fix: [action]
  ...

MEDIUM FINDINGS (recommended):
  [M1] [Domain] [file:line] Description -- Fix: [action]
  ...

LOW FINDINGS (nice to have):
  [L1] [Domain] [file:line] Description -- Fix: [action]
  ...

AUTO-FIXED:
  [F1] [file:line] Added alt="" to decorative image
  [F2] [file:line] Added rel="noopener noreferrer" to external link
  ...

MANUAL CHECKS REQUIRED:
  [ ] Keyboard navigation test (Tab through all interactive elements)
  [ ] Screen reader test (VoiceOver/NVDA on key pages)
  [ ] Mobile device test (real device, not just responsive mode)
  ...

========================================
```

## Scoring Algorithm

Each domain has equal weight (16.67% of total score).

Within each domain, checks are weighted:
- CRITICAL check failed: -20 points from domain score
- HIGH check failed: -10 points from domain score
- MEDIUM check failed: -5 points from domain score
- LOW check failed: -2 points from domain score

Domain score = max(0, 100 - sum of deductions)
Overall score = average of all domain scores

## Integration with Development Workflow

```
MANDATORY FLOW FOR WEB PROJECTS:

1. During development:
   - Apply accessibility patterns (semantic HTML, ARIA)
   - Apply best practices (no inline scripts, HTTPS)
   - Apply performance patterns (lazy loading, responsive images)

2. After building a page/component:
   - Run Core Web Vitals checks
   - Run SEO checks on public pages

3. Before declaring task complete:
   - Run full web-quality-gate audit
   - Fix all CRITICAL findings
   - Fix HIGH findings where possible
   - Report remaining MEDIUM/LOW to user

4. Only THEN declare the task complete
```
