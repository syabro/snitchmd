#!/usr/bin/env bash
# Runs snitchmd over docs/sites.md: the tls.peet.ws fingerprint check (section 1)
# and the real sites (section 3). Bot detectors (section 2) are checked by hand.
# Usage: scripts/test-sites [path/to/snitchmd]
# Writes tmp/test-sites/<date>.tsv. DataDome sites go last, one request per URL;
# nytimes.com gets two (the front page and /athletic/), and DataDome counts per domain.
set -euo pipefail

bin="${1:-snitchmd}"
root="$(cd "$(dirname "$0")/.." && pwd)"
doc="$root/docs/sites.md"
out_dir="$root/tmp/test-sites"
mkdir -p "$out_dir"
out="$out_dir/$(date +%Y-%m-%d).tsv"

expected_ja4=t13d2013h2_a09f3c656075_7f0f34a4126d
expected_akamai=c52879e43202aeb92740be6e8c86ea96

echo "fingerprint:"
fp="$("$bin" --no-cache --dump html https://tls.peet.ws/api/all 2>/dev/null || true)"
ja4="$(grep -o '"ja4": *"[^"]*"' <<<"$fp" | cut -d'"' -f4 || true)"
akamai="$(grep -o '"akamai_fingerprint_hash": *"[^"]*"' <<<"$fp" | cut -d'"' -f4 || true)"
[[ "$ja4" == "$expected_ja4" ]] && echo "  ja4 ok" || echo "  ja4 MISMATCH: $ja4"
[[ "$akamai" == "$expected_akamai" ]] && echo "  akamai ok" || echo "  akamai MISMATCH: $akamai"

# Section 3 rows: | URL | Protection | Result |
rows="$(awk '/^## 3\./{on=1; next} /^## /{on=0} on && /^\| https/' "$doc" \
  | awk -F'|' '{gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); print $2 "\t" $3}')"
ordered="$(grep -v -F DataDome <<<"$rows"; grep -F DataDome <<<"$rows" || true)"

printf 'site\turl\texit\tquality\tchars\ttitle\tstart\n' >"$out"
while IFS=$'\t' read -r url _protection; do
  site="${url#https://}"; site="${site#www.}"; site="${site%/}"
  [[ -z "$url" ]] && continue
  set +e
  json="$("$bin" --no-cache --json "$url" 2>/dev/null </dev/null)"
  code=$?
  set -e
  quality="$(jq -r '.quality // ""' <<<"$json" 2>/dev/null || true)"
  chars="$(jq -r '.chars // ""' <<<"$json" 2>/dev/null || true)"
  title="$(jq -r '.title // ""' <<<"$json" 2>/dev/null | tr '\t\n' '  ' || true)"
  start="$(jq -r '(.markdown // "")[0:200]' <<<"$json" 2>/dev/null | tr '\t\n' '  ' || true)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$site" "$url" "$code" "$quality" "$chars" "$title" "$start" >>"$out"
  printf '%-40s exit=%-3s quality=%-5s chars=%s\n' "$site" "$code" "$quality" "$chars"
done <<<"$ordered"

echo "written: $out"
