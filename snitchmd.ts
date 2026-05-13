#!/usr/bin/env bun
// snitchmd — render a URL with CloakBrowser and extract clean Markdown via rs-trafilatura.

import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const CACHE_DIR = process.env.SNITCHMD_CACHE_DIR ?? "/cache";
const TRAFILATURA_BIN = process.env.SNITCHMD_TRAFILATURA_BIN ?? "/usr/local/bin/extract_stdin";

const HELP_TEXT = `Usage: snitchmd URL [options]

Render a web page with CloakBrowser, then convert the HTML to Markdown.

Options:
  --json                       Output JSON with metadata and markdown
  --html-output FILE           Also save rendered HTML to this file
  --no-cache                   Bypass the on-disk cache (forces a fresh fetch)
  --timeout SECONDS            Page load timeout (default: 45)
  --wait SECONDS               Extra wait after page load (default: 0)
  --wait-until STATE           Playwright goto wait condition; one of
                               commit | domcontentloaded | load | networkidle
                               (default: domcontentloaded)
  --wait-for-selector CSS      Wait for a CSS selector before extraction
  --headful                    Run headed Chromium under Xvfb instead of headless
  --humanize                   Enable CloakBrowser human-like mouse/keyboard/scroll
  --proxy URL                  Proxy URL (http://user:pass@host:8080 or socks5://...)
  --timezone IANA              IANA timezone fingerprint (e.g. Europe/Berlin)
  --locale TAG                 Browser locale (e.g. en-US)
  --include-links              Preserve links in extracted Markdown
  --include-images             Include image references in extracted Markdown
  --favor-precision            Prefer less boilerplate, even if some content is lost
                               (mutually exclusive with --favor-recall)
  --favor-recall               Prefer more content, even if some boilerplate remains
                               (mutually exclusive with --favor-precision)
  --max-chars N                Truncate Markdown output to at most N characters
                               (appends "\\n\\n[truncated]"). Default: no limit.
  -h, --help                   Show this message and exit
`;

type Args = {
  url: string;
  json: boolean;
  htmlOutput?: string;
  noCache: boolean;
  timeout: number;
  wait: number;
  waitUntil: "commit" | "domcontentloaded" | "load" | "networkidle";
  waitForSelector?: string;
  headful: boolean;
  humanize: boolean;
  proxy?: string;
  timezone?: string;
  locale?: string;
  includeLinks: boolean;
  includeImages: boolean;
  favorPrecision: boolean;
  favorRecall: boolean;
  maxChars?: number;
};

const CACHE_KEY_FIELDS: (keyof Args)[] = [
  "url", "wait", "waitUntil", "waitForSelector", "headful", "humanize",
  "proxy", "timezone", "locale", "includeLinks", "includeImages",
  "favorPrecision", "favorRecall",
];

const WAIT_UNTIL_VALUES = new Set(["commit", "domcontentloaded", "load", "networkidle"]);

function bail(msg: string, code = 2): never {
  process.stderr.write(`snitchmd: ${msg}\n`);
  process.exit(code);
}

function positiveInt(flag: string, raw: string | undefined): number {
  if (raw === undefined) bail(`${flag} requires a value`);
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0) bail(`${flag} must be a non-negative integer (got ${JSON.stringify(raw)})`);
  return n;
}

function requiredString(flag: string, raw: string | undefined): string {
  if (raw === undefined || raw === "") bail(`${flag} requires a value`);
  return raw;
}

function parseArgs(argv: string[]): Args {
  const args: any = {
    json: false,
    noCache: false,
    timeout: 45,
    wait: 0,
    waitUntil: "domcontentloaded",
    headful: false,
    humanize: false,
    includeLinks: false,
    includeImages: false,
    favorPrecision: false,
    favorRecall: false,
  };
  let i = 0;
  while (i < argv.length) {
    const a = argv[i];
    const take = () => argv[++i];
    switch (a) {
      case "--json": args.json = true; break;
      case "--html-output": args.htmlOutput = requiredString(a, take()); break;
      case "--no-cache": args.noCache = true; break;
      case "--timeout": args.timeout = positiveInt(a, take()); break;
      case "--wait": args.wait = positiveInt(a, take()); break;
      case "--wait-until": {
        const v = requiredString(a, take());
        if (!WAIT_UNTIL_VALUES.has(v)) bail(`--wait-until must be one of ${[...WAIT_UNTIL_VALUES].join(", ")} (got ${JSON.stringify(v)})`);
        args.waitUntil = v;
        break;
      }
      case "--wait-for-selector": args.waitForSelector = requiredString(a, take()); break;
      case "--headful": args.headful = true; break;
      case "--humanize": args.humanize = true; break;
      case "--proxy": args.proxy = requiredString(a, take()); break;
      case "--timezone": args.timezone = requiredString(a, take()); break;
      case "--locale": args.locale = requiredString(a, take()); break;
      case "--include-links": args.includeLinks = true; break;
      case "--include-images": args.includeImages = true; break;
      case "--favor-precision": args.favorPrecision = true; break;
      case "--favor-recall": args.favorRecall = true; break;
      case "--max-chars": args.maxChars = positiveInt(a, take()); break;
      case "-h": case "--help":
        process.stdout.write(HELP_TEXT);
        process.exit(0);
      default:
        if (a.startsWith("-")) bail(`unknown option: ${a}`);
        if (args.url) bail(`unexpected positional argument: ${a}`);
        args.url = a;
    }
    i++;
  }
  if (!args.url) bail("URL is required (run with --help for usage)");
  if (args.favorPrecision && args.favorRecall) {
    bail("--favor-precision and --favor-recall are mutually exclusive");
  }
  return args as Args;
}

function cacheKey(args: Args): string {
  // maxChars and output flags are intentionally excluded — same fetch+extract,
  // different presentation.
  const blob: Record<string, unknown> = {};
  for (const k of CACHE_KEY_FIELDS) blob[k] = args[k];
  return createHash("sha256").update(JSON.stringify(blob)).digest("hex");
}

function cacheGet(key: string): any | null {
  const path = join(CACHE_DIR, `${key}.json`);
  if (!existsSync(path)) return null;
  try { return JSON.parse(readFileSync(path, "utf8")); } catch { return null; }
}

function cachePut(key: string, payload: any): void {
  try {
    mkdirSync(CACHE_DIR, { recursive: true });
    writeFileSync(join(CACHE_DIR, `${key}.json`), JSON.stringify(payload), "utf8");
  } catch { /* cache is best-effort */ }
}

async function renderHtml(args: Args): Promise<{ html: string; title: string; url: string }> {
  const { launch } = await import("cloakbrowser");
  const browser = await launch({
    headless: !args.headful,
    proxy: args.proxy ? { server: args.proxy } : undefined,
    timezone: args.timezone,
    locale: args.locale,
    humanize: args.humanize,
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  } as any);
  try {
    const page = await browser.newPage();
    await page.goto(args.url, { waitUntil: args.waitUntil, timeout: args.timeout * 1000 });
    if (args.waitForSelector) {
      await page.waitForSelector(args.waitForSelector, { timeout: args.timeout * 1000 });
    }
    if (args.wait) await page.waitForTimeout(args.wait * 1000);
    return { html: await page.content(), title: await page.title(), url: page.url() };
  } finally {
    await browser.close();
  }
}

function extractMarkdown(html: string, url: string, args: Args): Promise<any> {
  const cliArgs = ["--url", url, "--markdown"];
  if (args.includeLinks) cliArgs.push("--include-links");
  if (args.includeImages) cliArgs.push("--include-images");
  if (args.favorPrecision) cliArgs.push("--favor-precision");
  if (args.favorRecall) cliArgs.push("--favor-recall");
  return new Promise((resolve, reject) => {
    const proc = spawn(TRAFILATURA_BIN, cliArgs, { stdio: ["pipe", "pipe", "inherit"] });
    let out = "";
    proc.stdout.on("data", (d) => { out += d; });
    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code !== 0) return reject(new Error(`extract_stdin exited ${code}`));
      try { resolve(JSON.parse(out)); } catch (e) { reject(e); }
    });
    proc.stdin.write(html);
    proc.stdin.end();
  });
}

function truncate(markdown: string, maxChars: number | undefined): { markdown: string; truncated: boolean } {
  if (maxChars === undefined || markdown.length <= maxChars) {
    return { markdown, truncated: false };
  }
  return { markdown: `${markdown.slice(0, maxChars)}\n\n[truncated]`, truncated: true };
}

function emit(payload: any, args: Args, cached: boolean): void {
  const { markdown, truncated } = truncate(payload.markdown, args.maxChars);
  const shownPayload = truncated
    ? { ...payload, markdown, chars: markdown.length, full_chars: payload.chars, truncated: true }
    : payload;
  if (args.json) process.stdout.write(JSON.stringify(shownPayload, null, 2) + "\n");
  else process.stdout.write(markdown + "\n");
  const tag = cached ? " (cached)" : "";
  const truncTag = truncated ? ` truncated_from=${payload.chars}` : "";
  process.stderr.write(`snitchmd: title=${JSON.stringify(payload.title)} quality=${payload.quality} chars=${shownPayload.chars}${truncTag}${tag}\n`);
}

async function run(): Promise<number> {
  const args = parseArgs(process.argv.slice(2));
  const key = cacheKey(args);

  if (!args.noCache) {
    const cached = cacheGet(key);
    if (cached) { emit(cached, args, true); return 0; }
  }

  try {
    const { html, title: pageTitle, url: finalUrl } = await renderHtml(args);
    if (args.htmlOutput) writeFileSync(args.htmlOutput, html, "utf8");

    const result = await extractMarkdown(html, finalUrl, args);
    const markdown: string = (result.content_markdown || result.main_content || "").trim();
    if (!markdown) {
      process.stderr.write("snitchmd: extraction returned empty content\n");
      return 2;
    }

    const payload = {
      url: args.url,
      final_url: finalUrl,
      title: result.title || pageTitle,
      page_title: pageTitle,
      page_type: result.page_type ?? null,
      quality: result.confidence ?? null,
      chars: markdown.length,
      markdown,
    };

    cachePut(key, payload);
    emit(payload, args, false);
    return 0;
  } catch (exc: any) {
    process.stderr.write(`snitchmd: ${exc?.constructor?.name ?? "Error"}: ${exc?.message ?? exc}\n`);
    return 1;
  }
}

try {
  process.exit(await run());
} catch (exc: any) {
  process.stderr.write(`snitchmd: fatal: ${exc?.message ?? exc}\n`);
  process.exit(1);
}
