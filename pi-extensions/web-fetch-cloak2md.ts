import { StringEnum, Type } from "@mariozechner/pi-ai";
import { defineTool, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";

const IMAGE = process.env.CLOAK2MD_IMAGE || "syabro/cloak2md:latest";
const DEFAULT_PAGE_TIMEOUT_SECONDS = 45;
const DEFAULT_MAX_CHARS = 40_000;

type Params = {
	url: string;
	wait_seconds?: number;
	wait_for_selector?: string;
	extraction_mode?: "default" | "precision" | "recall";
	timeout_seconds?: number;
	max_chars?: number;
};

type DockerResult = {
	code: number;
	stdout: string;
	stderr: string;
	error?: string;
};

type Cloak2MdPayload = {
	url: string;
	final_url: string;
	title?: string;
	page_title?: string;
	page_type?: string | null;
	quality?: number | null;
	chars: number;
	markdown: string;
};

function tail(text: string, max = 2000) {
	return text.length <= max ? text : text.slice(text.length - max);
}

function runDocker(args: string[], timeoutMs: number, signal?: AbortSignal): Promise<DockerResult> {
	return new Promise((resolve) => {
		const child = execFile(
			"docker",
			args,
			{
				timeout: timeoutMs,
				maxBuffer: 64 * 1024 * 1024,
				env: process.env,
				signal,
			},
			(error, stdout, stderr) => {
				const nodeError = error as NodeJS.ErrnoException | null;
				resolve({
					code: typeof nodeError?.code === "number" ? nodeError.code : nodeError ? 1 : 0,
					stdout: String(stdout || ""),
					stderr: String(stderr || ""),
					error: nodeError?.message,
				});
			},
		);

		child.on("error", (error) => {
			resolve({ code: 1, stdout: "", stderr: "", error: error.message });
		});
	});
}

function parsePayload(stdout: string): Cloak2MdPayload {
	try {
		return JSON.parse(stdout) as Cloak2MdPayload;
	} catch {
		const start = stdout.indexOf("{");
		const end = stdout.lastIndexOf("}");
		if (start >= 0 && end > start) {
			return JSON.parse(stdout.slice(start, end + 1)) as Cloak2MdPayload;
		}
		throw new Error("cloak2md returned non-JSON output");
	}
}

const webFetchCloak2MdTool = defineTool({
	name: "web_fetch_cloak2md",
	label: "Web Fetch Cloak2MD",
	description:
		"Convert a web page to clean Markdown. Use when (a) the page is JS-rendered and a plain fetch returns an empty shell, (b) the site is gated by Cloudflare or other anti-bot checks, or (c) raw HTML is too noisy for the context window. Returns Markdown ready to paste into a prompt, note, or RAG pipeline. If none of those apply, a plain HTTP fetch is cheaper.",
	promptSnippet:
		"web_fetch_cloak2md → web page to clean Markdown when JS-rendered, anti-bot-gated, or HTML too noisy.",
	promptGuidelines: [
		"Pick web_fetch_cloak2md only if the page is JS-rendered, anti-bot-gated, or its raw HTML is too noisy for the context window. Otherwise use a plain HTTP fetch.",
		"Always start with default extraction. Switch modes based on the symptom, not the URL.",
		"Symptom → action: empty or stub output → wait_seconds, or wait_for_selector if the element is known; noisy output (nav, footer, cookies, related links) → extraction_mode='precision'; missing content (tables, pricing cards, docs blocks) → extraction_mode='recall'; page is huge and only the top is needed → set max_chars.",
		"Stop after two adjustments. If you still don't have the content, the page is the wrong target for this tool — fall back rather than keep tuning.",
	],
	parameters: Type.Object({
		url: Type.String({ description: "URL to render and extract" }),
		wait_seconds: Type.Optional(Type.Number({ description: "Extra seconds to wait before extraction when content is missing" })),
		wait_for_selector: Type.Optional(Type.String({ description: "CSS selector to wait for when a specific page area is required" })),
		extraction_mode: Type.Optional(StringEnum(["default", "precision", "recall"] as const, {
			description: "Extraction mode. Use precision for noisy output, recall for missing content.",
		})),
		timeout_seconds: Type.Optional(Type.Number({ description: "Page load timeout in seconds. Default: 45" })),
		max_chars: Type.Optional(Type.Number({ description: "Maximum Markdown characters returned. Default: 40000" })),
	}),
	async execute(_toolCallId, params: Params, signal, onUpdate) {
		const pageTimeout = params.timeout_seconds ?? DEFAULT_PAGE_TIMEOUT_SECONDS;
		const waitSeconds = params.wait_seconds ?? 0;
		const maxChars = params.max_chars ?? DEFAULT_MAX_CHARS;
		const args = ["run", "--rm", "-i", IMAGE, "--json", params.url, "--timeout", String(pageTimeout)];

		if (params.wait_seconds !== undefined) args.push("--wait", String(params.wait_seconds));
		if (params.wait_for_selector) args.push("--wait-for-selector", params.wait_for_selector);
		if (params.extraction_mode === "precision") args.push("--favor-precision");
		if (params.extraction_mode === "recall") args.push("--favor-recall");

		onUpdate?.({ content: [{ type: "text", text: `web_fetch_cloak2md: rendering ${params.url}` }] });

		const processTimeoutMs = Math.max(180_000, (pageTimeout + waitSeconds + 60) * 1000);
		const result = await runDocker(args, processTimeoutMs, signal);
		if (result.code !== 0) {
			return {
				content: [{ type: "text", text: `web_fetch_cloak2md failed\n${tail(result.stderr || result.stdout || result.error || "unknown error")}` }],
				isError: true,
				details: { code: result.code, stderr: result.stderr, stdout: tail(result.stdout), error: result.error },
			};
		}

		let payload: Cloak2MdPayload;
		try {
			payload = parsePayload(result.stdout);
		} catch (error) {
			return {
				content: [{ type: "text", text: `${error instanceof Error ? error.message : String(error)}\n${tail(result.stdout)}\n${tail(result.stderr)}` }],
				isError: true,
				details: { stdout: tail(result.stdout), stderr: result.stderr },
			};
		}

		const markdown = payload.markdown || "";
		const truncated = markdown.length > maxChars;
		const shown = truncated ? `${markdown.slice(0, maxChars)}\n\n[truncated]` : markdown;
		const header = [
			`title: ${payload.title || payload.page_title || ""}`,
			`url: ${payload.final_url || payload.url}`,
			`quality: ${payload.quality ?? "unknown"}`,
			truncated ? `returned: ${maxChars}/${markdown.length} chars` : `chars: ${markdown.length}`,
		].join("\n");

		return {
			content: [{ type: "text", text: `${header}\n\n${shown}` }],
			details: {
				url: payload.url,
				final_url: payload.final_url,
				title: payload.title,
				page_title: payload.page_title,
				page_type: payload.page_type,
				quality: payload.quality,
				chars: payload.chars,
				truncated,
			},
		};
	},
});

export default function (pi: ExtensionAPI) {
	pi.registerTool(webFetchCloak2MdTool);
}
