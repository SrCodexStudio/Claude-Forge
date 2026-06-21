# Web Quality Enforcement

> Auto-active for all web projects. No user action required to enable.

## Detection

This rule activates when any of the following are present in the project:

- `composer.json` with Laravel or PHP framework
- `package.json` with react, next, vue, svelte, or similar
- `.blade.php`, `.html`, `.tsx`, `.jsx` files
- `routes/web.php` or `artisan` binary
- User mentions "website", "landing page", "dashboard", "web app"

## During Development

Apply these patterns inline as you write code. Do not wait for an audit step.

### Accessibility (WCAG 2.2)

- Use semantic HTML elements: `<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`.
- Add `alt` text to every `<img>`. Use `alt=""` only for purely decorative images.
- Include `aria-label` or `aria-labelledby` on interactive elements without visible text.
- Ensure keyboard navigation works: all interactive elements must be focusable and operable.
- Maintain color contrast ratio of at least 4.5:1 for normal text, 3:1 for large text.
- Add `focus-visible` styles to all interactive elements. Never use `outline: none` without a replacement.
- Use `role` attributes only when semantic HTML is insufficient.
- Form inputs must have associated `<label>` elements or `aria-label`.

### Best Practices

- No inline `<script>` tags -- use external files with `src`.
- No `document.write()` calls.
- All external links use HTTPS.
- No deprecated HTML attributes or APIs.
- Set `lang` attribute on the `<html>` element.
- Include `<meta charset="utf-8">` and `<meta name="viewport">`.

### Performance

- Lazy load images below the fold: `loading="lazy"`.
- Use `async` or `defer` on non-critical scripts.
- Preload critical assets: `<link rel="preload">` for fonts and above-the-fold images.
- Use responsive images: `srcset` and `sizes` attributes, or `<picture>` element.
- Minimize render-blocking CSS. Inline critical CSS for above-the-fold content.

### Core Web Vitals

- Set explicit `width` and `height` on all images and videos to prevent layout shifts (CLS).
- Add `fetchpriority="high"` on the Largest Contentful Paint (LCP) element.
- Avoid large layout shifts caused by dynamically injected content.
- Keep Interaction to Next Paint (INP) low: avoid long-running synchronous JavaScript on user events.

### SEO

- Every page has a unique `<title>` (50-60 characters) and `<meta name="description">` (150-160 characters).
- Set a canonical URL: `<link rel="canonical">`.
- Use a single `<h1>` per page with proper heading hierarchy (`h1` > `h2` > `h3`).
- Include structured data (JSON-LD) for content-rich pages.
- Ensure the site has a `sitemap.xml` and `robots.txt`.
- Add Open Graph and Twitter Card meta tags for social sharing.

## Before Declaring Task Complete

When web work is finished, run the full quality audit:

1. Invoke the `web-quality-audit` skill to execute the 150+ check suite.
2. Fix all CRITICAL and HIGH severity findings before reporting done.
3. Report remaining MEDIUM and LOW findings to the user with remediation suggestions.

Never declare a web task complete without running the audit. "It looks good" is not evidence.

## Quality Skill Stack

These skills are invoked proactively during web development, not on user request:

| Skill              | Covers                                                |
|--------------------|-------------------------------------------------------|
| `accessibility`    | WCAG 2.2 compliance, ARIA, keyboard nav, contrast     |
| `best-practices`   | CSP, security headers, Trusted Types, SRI             |
| `core-web-vitals`  | LCP, INP, CLS measurement and optimization            |
| `performance`      | Loading strategy, bundling, images, cache, lazy load   |
| `seo`              | Meta tags, structured data, JSON-LD, sitemap           |
| `web-quality-audit`| Final gate: comprehensive 150+ check audit             |

## Workflow Summary

```
1. Develop with accessibility + best-practices patterns applied inline.
2. Optimize with performance + core-web-vitals patterns.
3. Add SEO elements if the page is publicly accessible.
4. Run web-quality-audit as the final verification gate.
5. Fix critical/high findings. Report medium/low.
6. Only then declare the task complete.
```
