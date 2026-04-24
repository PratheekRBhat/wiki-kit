#!/usr/bin/env bash
# prepare.sh — backfill missing body content for clipped sources.
#
# For each .md source under raw/, this script inspects the frontmatter's
# `source_type` and backfills whatever the web clipper couldn't capture:
#
#   article   no-op (body is already complete at clip time)
#   paper     downloads the arXiv PDF next to the clipped MD
#   talk      appends a transcript under the '## Transcript' section
#
# Requires: curl (for papers), yt-dlp (for talks, via youtube_transcript.sh).

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

force=0

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [-f] [PATH...]

Backfills body content for clipped sources in raw/. Acts based on each
file's source_type frontmatter:

  article    no-op (the body is complete at clip time)
  paper      downloads the arXiv PDF next to the clipped MD
  talk       appends a transcript under '## Transcript'

PATH can be one or more .md files, directories (scanned recursively), or
omitted entirely — with no args the script processes every .md under
raw/ that isn't already marked ingested: true.

Options:
  -f    Force re-fetch (overwrite existing PDFs, replace existing transcripts).
  -h    Show this help.

Examples:
  $(basename "$0")
  $(basename "$0") raw/talks/talk-iceberg.md
  $(basename "$0") raw/papers
  $(basename "$0") -f raw/talks/talk-iceberg.md
EOF
}

while getopts "fh" opt; do
  case "$opt" in
    f) force=1 ;;
    h) print_usage; exit 0 ;;
    *) print_usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# Output helpers — plain ASCII prefixes, no color (keeps output clean in logs
# and pipes).
log()  { echo "• $*"; }
ok()   { echo "  ok    $*"; }
skip() { echo "  skip  $*"; }
fail() { echo "  error $*" >&2; }

# Extract a simple frontmatter scalar by key. Handles `key: value` and
# `key: "value"` within the first --- ... --- block. Returns empty if
# missing.
fm_get() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { in_fm = 0 }
    /^---[[:space:]]*$/ {
      if (in_fm) exit
      in_fm = 1; next
    }
    in_fm && $0 ~ "^" k "[[:space:]]*:" {
      sub("^" k "[[:space:]]*:[[:space:]]*", "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$file"
}

is_ingested() {
  [[ "$(fm_get "$1" "ingested")" == "true" ]]
}

# ---------------- per-type handlers ----------------

prepare_paper() {
  local file="$1"
  local arxiv_id pdf
  arxiv_id=$(fm_get "$file" "arxiv_id")
  if [[ -z "$arxiv_id" ]]; then
    fail "$file — missing 'arxiv_id' in frontmatter"
    return 1
  fi
  pdf="${file%.md}.pdf"
  if [[ -f "$pdf" && $force -eq 0 ]]; then
    skip "$file — PDF already exists ($(basename "$pdf"))"
    return 0
  fi
  if curl -sSL --fail -o "$pdf" "https://arxiv.org/pdf/${arxiv_id}"; then
    ok "$file — downloaded $(basename "$pdf")"
    return 0
  else
    rm -f "$pdf"
    fail "$file — arXiv PDF fetch failed (arxiv_id=$arxiv_id)"
    return 1
  fi
}

# Returns 0 if the '## Transcript' section already has meaningful content
# (anything beyond the template placeholder). Returns non-zero otherwise.
talk_has_transcript() {
  awk '
    /^## Transcript[[:space:]]*$/ { in_t = 1; next }
    in_t && /^## /               { exit !found }
    in_t && NF && !/^_Paste transcript/ { found = 1 }
    END                          { exit !found }
  ' "$1"
}

prepare_talk() {
  local file="$1"
  local url
  url=$(fm_get "$file" "url")
  if [[ -z "$url" ]]; then
    fail "$file — missing 'url' in frontmatter"
    return 1
  fi

  if talk_has_transcript "$file" && [[ $force -eq 0 ]]; then
    skip "$file — transcript already present"
    return 0
  fi

  local tmp rewritten
  tmp=$(mktemp)
  rewritten=$(mktemp)

  # Fetch first (don't touch the source MD unless we got something).
  if ! "$SCRIPT_DIR/youtube_transcript.sh" "$url" > "$tmp"; then
    rm -f "$tmp" "$rewritten"
    fail "$file — youtube_transcript.sh failed"
    return 1
  fi

  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp" "$rewritten"
    fail "$file — transcript came back empty"
    return 1
  fi

  # Replace any existing body under '## Transcript' (placeholder or otherwise)
  # with the freshly fetched transcript. If the section doesn't exist, append
  # it at the end as a safety net.
  awk -v tfile="$tmp" '
    BEGIN { injected = 0 }
    /^## Transcript[[:space:]]*$/ && !injected {
      print
      print ""
      while ((getline line < tfile) > 0) print line
      close(tfile)
      in_t = 1
      injected = 1
      next
    }
    in_t && /^## / { in_t = 0 }
    in_t           { next }
                   { print }
    END {
      if (!injected) {
        print ""
        print "## Transcript"
        print ""
        while ((getline line < tfile) > 0) print line
        close(tfile)
      }
    }
  ' "$file" > "$rewritten"

  mv "$rewritten" "$file"
  rm -f "$tmp"
  ok "$file — transcript appended"
  return 0
}

# ---------------- main ----------------

declare -a files=()
auto_discover=0

if [[ $# -eq 0 ]]; then
  auto_discover=1
  while IFS= read -r -d '' f; do files+=("$f"); done \
    < <(find "$REPO_ROOT/raw" -type f -name '*.md' ! -name 'README.md' -print0 2>/dev/null)
else
  for arg in "$@"; do
    if [[ -d "$arg" ]]; then
      while IFS= read -r -d '' f; do files+=("$f"); done \
        < <(find "$arg" -type f -name '*.md' ! -name 'README.md' -print0)
    elif [[ -f "$arg" ]]; then
      files+=("$arg")
    else
      fail "not a file or directory: $arg"
    fi
  done
fi

if [[ ${#files[@]} -eq 0 ]]; then
  fail "no source files found"
  exit 1
fi

processed=0
skipped=0
failed=0

for file in "${files[@]}"; do
  source_type=$(fm_get "$file" "source_type")

  if [[ -z "$source_type" ]]; then
    skip "$file — no source_type"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ $auto_discover -eq 1 ]] && is_ingested "$file"; then
    skip "$file — already ingested"
    skipped=$((skipped + 1))
    continue
  fi

  log "$source_type: $file"

  case "$source_type" in
    article)
      skip "$file — article body already complete at clip time"
      skipped=$((skipped + 1))
      ;;
    paper)
      if prepare_paper "$file"; then
        processed=$((processed + 1))
      else
        failed=$((failed + 1))
      fi
      ;;
    talk)
      if prepare_talk "$file"; then
        processed=$((processed + 1))
      else
        failed=$((failed + 1))
      fi
      ;;
    *)
      skip "$file — unknown source_type '$source_type'"
      skipped=$((skipped + 1))
      ;;
  esac
done

echo ""
echo "summary: processed=$processed skipped=$skipped failed=$failed"
exit $(( failed > 0 ? 1 : 0 ))
