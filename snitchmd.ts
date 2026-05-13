#!/usr/bin/env bun
// snitchmd — render a URL with CloakBrowser and extract clean Markdown via rs-trafilatura.

import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const CACHE_DIR = process.env.SNITCHMD_CACHE_DIR ?? "/cache";
const TRAFILATURA_BIN = process.env.SNITCHMD_TRAFILATURA_BIN ?? "/usr/local/bin/extract_stdin";

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
};

const CACHE_KEY_FIELDS: (keyof Args)[] = [
  "url", "wait", "waitUntil", "waitForSelector", "headful", "humanize",
  "proxy", "timezone", "locale", "includeLinks", "includeImages",
  "favorPrecision", "favorRecall",
];

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
      case "--html-output": args.htmlOutput = take(); break;
      case "--no-cache": args.noCache = true; break;
      case "--timeout": args.timeout = parseInt(take(), 10); break;
      case "--wait": args.wait = parseInt(take(), 10); break;
      case "--wait-until": args.waitUntil = take() as Args["waitUntil"]; break;
      case "--wait-for-selector": args.waitForSelector = take(); break;
      case "--headful": args.headful = true; break;
      case "--humanize": args.humanize = true; break;
      case "--proxy": args.proxy = take(); break;
      case "--timezone": args.timezone = take(); break;
      case "--locale": args.locale = take(); break;
      case "--include-links": args.includeLinks = true; break;
      case "--include-images": args.includeImages = true; break;
      case "--favor-precision": args.favorPrecision = true; break;
      case "--favor-recall": args.favorRecall = true; break;
      case "-h": case "--help":
        console.error("Usage: snitchmd URL [options]\nSee --help in source for options.");
        process.exit(0);
      default:
        if (a.startsWith("-")) { console.error(`unknown option: ${a}`); process.exit(2); }
        args.url = a;
    }
    i++;
  }
  if (!args.url) { console.error("snitchmd: URL is required"); process.exit(2); }
  if (args.favorPrecision && args.favorRecall) {
    console.error("snitchmd: --favor-precision and --favor-recall are mutually exclusive");
    process.exit(2);
  }
  return args as Args;
}

function cacheKey(args: Args): string {
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
  } catch { /* swallow — cache is best-effort */ }
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

function emit(payload: any, args: Args, cached: boolean): void {
  if (args.json) process.stdout.write(JSON.stringify(payload, null, 2) + "\n");
  else process.stdout.write(payload.markdown + "\n");
  const tag = cached ? " (cached)" : "";
  process.stderr.write(`snitchmd: title=${JSON.stringify(payload.title)} quality=${payload.quality} chars=${payload.chars}${tag}\n`);
}

async function main(): Promise<number> {
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
      title: result.title ?? pageTitle,
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

process.exit(await main());
