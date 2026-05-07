# Security Review -- SureStep Official Website

**Reviewed:** 2026-04-16
**Posture:** Production
**Scope:** Full audit of surestep-site/ and surestep-site-upgraded/
**Reviewer:** Claude (security lens)

---

## 1. Executive summary

The SureStep website is a static marketing site served by nginx inside a Docker container. The attack surface is narrow by design: there are no server-side forms, no databases, no user authentication, and no application logic beyond client-side JavaScript for UI interactions (FAQ accordion, mobile nav, scroll animations, a recommendation quiz, and conditional Calendly embed loading). The only external data flow is outbound -- links to Calendly, WhatsApp, and Google Fonts.

The most significant finding is the nginx configuration, which is missing every standard security header (CSP, X-Frame-Options, HSTS, X-Content-Type-Options) and does not block access to dotfiles. If the `.git` directory were inadvertently copied into the container or served in any future deployment method, it would expose the full repository history. The Dockerfile also runs the nginx process as root (the nginx:alpine default), which is a container hardening gap. Finally, several `target="_blank"` links on older landing pages (hello.html, welcome.html, surestep-landing-v2.html) are missing `rel="noopener noreferrer"`, which is a minor but real reverse-tabnapping vector in older browsers.

On the positive side: no API keys, secrets, or credentials were found in any file or in either git history. There are no analytics trackers or third-party scripts loaded without consent. Cookie consent is properly gated. The Calendly embed only loads after explicit user acceptance. The inline JavaScript is minimal and well-scoped -- no `eval()`, no `document.write()`, and `innerHTML` usage is limited to the quiz widget on hello.html where it only inserts hardcoded template strings (no user input).

### Finding counts

| Severity | Count | Meaning |
|---|---|---|
| Critical | 0 | Blocks production. Exploitable today with low effort. |
| High | 2 | Should be fixed before going live; significant risk. |
| Medium | 3 | Fix during hardening sprint; limits impact of other bugs. |
| Low / Info | 5 | Good-practice improvements. |

---

## 2. High severity findings

### H-1. nginx missing all security headers

**File:** `nginx.conf` (entire file)

The nginx configuration contains zero security headers. None of the following are set:

- `X-Frame-Options` -- allows the site to be embedded in iframes on any domain (clickjacking risk)
- `Content-Security-Policy` -- no restriction on script sources, style sources, or frame ancestors
- `Strict-Transport-Security` (HSTS) -- browsers will not enforce HTTPS-only connections
- `X-Content-Type-Options` -- browsers may MIME-sniff responses
- `X-XSS-Protection` -- legacy XSS filter not activated (minor but free)
- `Referrer-Policy` -- full referrer sent to all external domains
- `Permissions-Policy` -- no restriction on browser features (camera, microphone, geolocation)

**Why it matters:** Without `X-Frame-Options` or CSP `frame-ancestors`, an attacker can embed the site in an iframe and overlay invisible UI elements to trick users into clicking (clickjacking). Without HSTS, users connecting over HTTP on the first visit can be downgraded by a MITM. Without CSP, any future XSS vulnerability (even in a third-party embed) has no containment.

**Action:** Add a headers block to nginx.conf:

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://assets.calendly.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://assets.calendly.com; font-src https://fonts.gstatic.com; img-src 'self' data:; frame-src https://calendly.com; connect-src 'self' https://calendly.com;" always;
```

### H-2. nginx does not block access to dotfiles (.git, .env, .claude)

**File:** `nginx.conf`

There is no `location` rule to deny access to dotfiles. The root directory contains `.git/`, `.claude/`, and `.DS_Store`. While the current Dockerfile selectively copies files (so `.git` is not in the container today), any change to the build process -- such as switching to `COPY . /usr/share/nginx/html/` -- would immediately expose the entire git history, including commit messages, author emails, and all historical file contents.

The `.claude/settings.local.json` file is present in the repo root and contains configuration details about allowed shell commands and tool permissions. If served, this would disclose internal development tooling.

**Why it matters:** An exposed `.git` directory allows an attacker to reconstruct the entire repository using `git-dumper` or similar tools. Even without `.git` in the container today, defense-in-depth requires blocking these paths at the server level.

**Action:** Add to nginx.conf:

```nginx
location ~ /\. {
    deny all;
    return 404;
}
```

---

## 3. Medium severity findings

### M-1. Dockerfile runs nginx as root

**File:** `Dockerfile`

The image `nginx:alpine` runs the master process as root by default. The Dockerfile does not create or switch to a non-root user. If an nginx vulnerability allowed code execution, the attacker would have root privileges inside the container.

**Why it matters:** Running as root inside a container increases blast radius. Container escapes combined with root access are the most common path to host compromise.

**Action:** Add user creation and permission adjustment:

```dockerfile
FROM nginx:alpine
# ... COPY statements ...
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid
USER nginx
```

And change `listen 80;` to `listen 8080;` (non-privileged port) in nginx.conf, updating the EXPOSE directive accordingly.

### M-2. Missing `rel="noopener noreferrer"` on several `target="_blank"` links

**Files:** `hello.html`, `welcome.html`, `surestep-landing-v2.html`

Multiple `target="_blank"` links to external domains (Calendly, WhatsApp) in these pages are missing `rel="noopener noreferrer"`:

- `hello.html` lines 875, 889, 1095, 1239, 1250, 1262, 1266
- `welcome.html` lines 625, 639, 831, 842, 854, 858
- `surestep-landing-v2.html` lines 617, 631, 823, 834, 846, 850

In contrast, the main `index.html` and all blog/case-study/legal pages correctly include `rel="noopener noreferrer"` on their external links.

**Why it matters:** In older browsers, the opened page can access `window.opener` and redirect the original tab to a phishing page (reverse tabnapping). Modern browsers mitigate this by default for cross-origin links, but the fix is trivial and provides defense-in-depth.

**Action:** Add `rel="noopener noreferrer"` to every `target="_blank"` link across all affected files.

### M-3. `innerHTML` usage in quiz widget without sanitization

**File:** `hello.html`, lines 1338-1348

The recommendation quiz uses `innerHTML` to render result cards:

```javascript
card.innerHTML = `
    <div class="result-match">${i === 0 ? '...' : '...'}</div>
    <h3>${rec.title}</h3>
    <p>${rec.description}</p>
    <div class="result-tags">${rec.tags.map(t => `<span class="result-tag">${t}</span>`).join('')}</div>
`;
```

The data comes from a hardcoded JavaScript object (`all = {...}`), not from user input or URL parameters. This means there is no current XSS vector. However, if this quiz were ever extended to accept user input, URL parameters, or API responses, the `innerHTML` assignment would become an injection point.

**Why it matters:** While not exploitable today, `innerHTML` with template literals is a code pattern that invites future XSS if the data source changes. Using `textContent` for text nodes and `createElement` for structure would be structurally safer.

**Action:** Consider refactoring to DOM API methods, or add a comment documenting that the data source must remain hardcoded/trusted.

---

## 4. Low / Info findings

### L-1. Facebook domain verification token is public

**Files:** `index.html:18`, `hello.html:17`, `es/index.html:21`, `pt/index.html:21`

```html
<meta name="facebook-domain-verification" content="ddmh1g1aidwgtfxwi6ykr613ivovw1" />
```

This is a Meta domain verification token. It is *designed* to be public in HTML and is not a secret -- it simply proves domain ownership. However, it is worth noting that it is present across multiple pages.

**Action:** No action needed. This is informational only.

### L-2. `surestep-site-upgraded/` contains node_modules in git repo

**File:** `surestep-site-upgraded/` directory

The `surestep-site-upgraded` subdirectory contains a separate git repo with `node_modules/` checked in (99 packages, primarily puppeteer and its dependencies). The `.gitignore` lists `node_modules/` but the directory is present on disk. The `package.json` has a single dependency: `puppeteer@^24.40.0`.

Puppeteer includes a full Chromium binary and has had known CVEs. The `screenshots/` directory and `take-screenshots.mjs` suggest this was a development tool for taking screenshots of the site, not production infrastructure.

**Why it matters:** If this directory were accidentally served or deployed, it would expose a large number of Node.js packages. More importantly, the puppeteer binary could be a target if the container were compromised.

**Action:** Ensure `surestep-site-upgraded/` is excluded from any deployment pipeline. Add it to `.dockerignore` if one is created. Consider removing `node_modules/` from the checked-in state.

### L-3. Sitemap includes internal/test pages

**File:** `sitemap.xml`

The sitemap includes `https://surestepautomation.com/hello` (a landing page variant). The page `welcome.html` has `<meta name="robots" content="noindex, nofollow">` correctly set, but `hello.html` does not have any noindex directive and is listed in the sitemap. Similarly, `surestep-landing-v2.html` is not in the sitemap but is accessible at its URL.

**Why it matters:** Multiple near-identical landing pages can confuse search engines (duplicate content). More relevantly for security, `surestep-landing-v2.html` is an unlisted but accessible page -- if it contained different or outdated content with security implications, it would be a hidden attack surface.

**Action:** Decide which pages should be canonical and add `noindex` to test/variant pages, or remove them from the deployed build.

### L-4. No `.dockerignore` file

**File:** (missing)

There is no `.dockerignore` file. The Dockerfile uses individual `COPY` commands rather than `COPY . .`, which currently prevents `.git`, `.claude`, `node_modules`, and other non-production files from being included. However, this is fragile -- any future refactoring to use a wildcard copy would pull everything in.

**Action:** Create a `.dockerignore` with:

```
.git
.claude
.DS_Store
surestep-site-upgraded
CHANGELOG.md
SECURITY_REVIEW.md
*.png
!apple-touch-icon.png
!og-image.png
!jasper.png
!favicon-*.png
```

### L-5. Calendly and Google Fonts are the only external dependencies -- no SRI

**Files:** `index.html:1057-1062`

The Calendly widget CSS and JS are loaded dynamically without Subresource Integrity (SRI) hashes:

```javascript
css.href = 'https://assets.calendly.com/assets/external/widget.css';
js.src = 'https://assets.calendly.com/assets/external/widget.js';
```

Google Fonts are loaded via `<link>` tags without SRI as well. For Google Fonts, SRI is impractical because Google serves different font files based on the user agent. For Calendly, SRI would break whenever Calendly updates their widget.

**Why it matters:** If `assets.calendly.com` were compromised, malicious JavaScript would execute on the site. This is a supply-chain risk inherent to using any third-party embed. The risk is mitigated by the cookie consent gate -- the script only loads after explicit user acceptance.

**Action:** The cookie consent gate is the correct mitigation here. Adding a Content-Security-Policy header (see H-1) that restricts script sources to `'self'` and `https://assets.calendly.com` provides the additional layer of defense. No further action needed beyond H-1.

---

## 5. (No Critical findings)

No critical findings were identified.

---

## 6. What looks good

- **No secrets in code or git history.** Both repos were clean -- no API keys, tokens, passwords, or credentials found in any file, and `git log --all -p` against sensitive file patterns returned nothing.
- **No third-party analytics or tracking scripts.** There is no Google Analytics, no Facebook Pixel, no tag manager. The privacy-first approach is genuine.
- **Cookie consent properly gates Calendly.** The Calendly embed (the only third-party script) only loads after the user clicks "Accept" on the cookie banner. If rejected, the widget never loads and a manual booking link is shown instead.
- **All inline JavaScript is minimal and safe.** No `eval()`, no `document.write()`. The `innerHTML` usage is limited and operates on hardcoded data only.
- **No forms or server-side processing.** The site collects zero user input. All CTAs link to external services (Calendly, WhatsApp, email).
- **Proper `noindex` on non-public pages.** `welcome.html` and `404.html` correctly set `<meta name="robots" content="noindex">`.
- **External links on main pages use `rel="noopener noreferrer"`.** The production `index.html`, blog, case studies, and legal pages all correctly attribute external links.
- **Legal pages are complete.** Privacy policy, terms of service, and data deletion pages are thorough and appropriate for a B2B automation business processing WhatsApp data.
- **Structured data is valid.** `application/ld+json` blocks on the homepage provide Organization and FAQPage schema correctly.
- **Git history is clean.** No deleted `.env` files, no accidentally committed secrets, no sensitive data in any commit.
- **Selective COPY in Dockerfile.** By listing individual files rather than using `COPY . .`, the build avoids accidentally bundling `.git`, `node_modules`, or development files.

---

## 7. "Before you ship" checklist

- [ ] 1. **Add security headers to nginx.conf** -- X-Frame-Options, CSP, HSTS, X-Content-Type-Options, Referrer-Policy, Permissions-Policy (see H-1)
- [ ] 2. **Block dotfile access in nginx.conf** -- Add `location ~ /\. { deny all; return 404; }` (see H-2)
- [ ] 3. **Run nginx as non-root user in Dockerfile** -- Switch to `USER nginx` after adjusting permissions (see M-1)
- [ ] 4. **Add `rel="noopener noreferrer"` to all `target="_blank"` links** -- Fix hello.html, welcome.html, surestep-landing-v2.html (see M-2)
- [ ] 5. **Create a `.dockerignore` file** -- Prevent accidental inclusion of .git, .claude, node_modules in future builds (see L-4)
- [ ] 6. **Audit which landing page variants should be deployed** -- Decide whether hello.html, welcome.html, and surestep-landing-v2.html should remain in production or be removed/noindexed (see L-3)
- [ ] 7. **Ensure `surestep-site-upgraded/` is excluded from deployment** -- This development directory should not be deployed
- [ ] 8. **Test the CSP header** -- After adding CSP, verify Calendly embed and Google Fonts still load correctly
- [ ] 9. **Run an SSL/TLS test** -- Verify HTTPS configuration at the hosting layer (Railway or wherever the container runs) using ssllabs.com
- [ ] 10. **Consider removing `surestep-landing-v2.html` from build** -- It duplicates hello.html content and is accessible but unlisted
