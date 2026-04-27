---
name: snitchmd
description: Convert a web page to clean Markdown when raw HTML is too noisy for the context window, the page is JS-rendered, or it's blocked by anti-bot checks. Returns Markdown ready to paste into a prompt, note, or RAG pipeline.
---

# snitchmd

## When to use this skill

Pick `snitchmd` over a plain HTTP fetch when **any** of these is true:

- the page renders content via JavaScript (SPA, dashboards, docs sites);
- the page is gated by Cloudflare, reCAPTCHA, or similar anti-bot checks;
- the raw HTML is far larger than the actual content you care about.

If none of these apply, a plain `curl` or built-in fetch is cheaper.

## Decision tree

1. **First call — always default.**

   ```text
   web_fetch_snitchmd({ "url": "https://example.com" })
   ```

2. **Result is empty or stub-like →** the page is still loading. Add `wait_seconds`, or `wait_for_selector` if you know the element.

   ```text
   web_fetch_snitchmd({ "url": "https://example.com", "wait_seconds": 5 })
   web_fetch_snitchmd({ "url": "https://example.com", "wait_for_selector": ".pricing-card" })
   ```

3. **Result is full of nav, footers, cookie banners, or related links →** use precision mode.

   ```text
   web_fetch_snitchmd({ "url": "https://example.com", "extraction_mode": "precision" })
   ```

4. **Result is missing a table, pricing card, or docs block →** use recall mode.

   ```text
   web_fetch_snitchmd({ "url": "https://example.com", "extraction_mode": "recall" })
   ```

5. **Page is huge and you only need the top →** set `max_chars`.

## Done criteria

You have Markdown that:

- contains the content the user actually asked about,
- fits in the context budget,
- doesn't include the site's chrome (nav, footer, cookies).

## Stop rule

If two adjustments don't get there, fall back to a different approach — don't keep tuning flags.

## Notes

Docker must be available. The tool uses `syabro/snitchmd:latest` by default. Set `SNITCHMD_IMAGE` to use another image tag.
