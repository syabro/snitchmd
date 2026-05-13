//! Reads HTML from stdin, outputs JSON with extracted content to stdout.
//!
//! Forked from rs-trafilatura's `extract_stdin` example to expose the
//! precision/recall/include-images/include-links toggles that the
//! upstream CLI does not surface.

use rs_trafilatura::{extract_with_options, Options};
use serde::Serialize;
use std::io::{self, Read};
use std::process::ExitCode;

#[derive(Serialize)]
struct Output {
    title: Option<String>,
    author: Option<String>,
    date: Option<String>,
    main_content: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    page_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    classification_confidence: Option<f64>,
    confidence: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    content_markdown: Option<String>,
}

struct ParsedArgs {
    url: Option<String>,
    markdown: bool,
    include_links: bool,
    include_images: bool,
    favor_precision: bool,
    favor_recall: bool,
}

fn parse_args() -> Result<ParsedArgs, String> {
    let args: Vec<String> = std::env::args().collect();
    let mut url = None;
    let mut markdown = false;
    let mut include_links = false;
    let mut include_images = false;
    let mut favor_precision = false;
    let mut favor_recall = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--url" => {
                let value = args.get(i + 1).ok_or("--url requires a value".to_string())?;
                url = Some(value.clone());
                i += 2;
            }
            "--markdown" => {
                markdown = true;
                i += 1;
            }
            "--include-links" => {
                include_links = true;
                i += 1;
            }
            "--include-images" => {
                include_images = true;
                i += 1;
            }
            "--favor-precision" => {
                favor_precision = true;
                i += 1;
            }
            "--favor-recall" => {
                favor_recall = true;
                i += 1;
            }
            "-h" | "--help" => {
                eprintln!(
                    "extract_stdin — read HTML on stdin, write JSON extraction to stdout\n\n\
                     Flags:\n\
                     \x20 --url URL          source URL (used for hostname metadata)\n\
                     \x20 --markdown         emit content_markdown alongside main_content\n\
                     \x20 --include-links    preserve links in extraction\n\
                     \x20 --include-images   include image references\n\
                     \x20 --favor-precision  stricter content thresholds\n\
                     \x20 --favor-recall     more lenient content thresholds"
                );
                std::process::exit(0);
            }
            other => return Err(format!("unknown argument: {other}")),
        }
    }

    Ok(ParsedArgs {
        url,
        markdown,
        include_links,
        include_images,
        favor_precision,
        favor_recall,
    })
}

fn main() -> ExitCode {
    let parsed = match parse_args() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("extract_stdin: {e}");
            return ExitCode::from(2);
        }
    };

    let mut html = String::new();
    if let Err(e) = io::stdin().read_to_string(&mut html) {
        eprintln!("extract_stdin: failed to read stdin: {e}");
        return ExitCode::from(1);
    }

    let defaults = Options::default();
    // --markdown forces include_links + include_tables + include_formatting
    // to true (matches the upstream extract_stdin behavior). Explicit
    // --include-links also turns it on outside of markdown mode.
    let options = Options {
        url: parsed.url,
        output_markdown: parsed.markdown,
        include_tables: if parsed.markdown {
            true
        } else {
            defaults.include_tables
        },
        include_links: parsed.markdown || parsed.include_links || defaults.include_links,
        include_formatting: if parsed.markdown {
            true
        } else {
            defaults.include_formatting
        },
        include_images: parsed.include_images || defaults.include_images,
        favor_precision: parsed.favor_precision,
        favor_recall: parsed.favor_recall,
        ..defaults
    };

    let output = match extract_with_options(&html, &options) {
        Ok(r) => Output {
            title: r.metadata.title,
            author: r.metadata.author,
            date: r.metadata.date.map(|d| d.to_rfc3339()),
            main_content: r.content_text,
            page_type: r.metadata.page_type,
            classification_confidence: r.classification_confidence,
            confidence: r.extraction_quality,
            content_markdown: if parsed.markdown {
                r.content_markdown
            } else {
                None
            },
        },
        Err(_) => Output {
            title: None,
            author: None,
            date: None,
            main_content: String::new(),
            page_type: None,
            classification_confidence: None,
            confidence: 0.0,
            content_markdown: None,
        },
    };

    match serde_json::to_string(&output) {
        Ok(json) => {
            println!("{json}");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("extract_stdin: serialization failed: {e}");
            ExitCode::from(1)
        }
    }
}
