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
# Optional: OPENAI_API_KEY + ffmpeg (with -w, routes talks through Whisper).

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

force=0
use_whisper=0
dry_run=0

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [-f] [-w] [-n] [PATH...]

Backfills body content for clipped sources in raw/. Acts based on each
file's source_type frontmatter:

  article    no-op (the body is complete at clip time)
  paper      downloads the PDF next to the clipped MD. Tries, in order:
             arxiv_id frontmatter, pdf_url frontmatter, direct-PDF url.
             If <slug>.pdf already exists, skips (honors manual drops).
  talk       appends a transcript under '## Transcript'

PATH can be one or more .md files, directories (scanned recursively), or
omitted entirely — with no args the script processes every .md under
raw/ that isn't already marked ingested: true.

Options:
  -f    Force re-fetch (overwrite existing PDFs, replace existing transcripts).
  -w    Route talk transcripts through Whisper (OpenAI API) instead of
        YouTube auto-captions. Higher quality, costs ~\$0.006/min.
        Requires OPENAI_API_KEY and ffmpeg. See utilities/whisper.sh -h.
  -n    Dry run. Report what would be done without fetching anything.
  -h    Show this help.

Auto-wrap: with no arguments, before the main scan, this script auto-wraps
any manually-dropped PDFs or audio files in raw/{articles,papers,talks}/
that don't have a companion .md. Targeted runs (specific files or dirs)
skip the auto-wrap — run with no args to sweep orphans.

Examples:
  $(basename "$0")
  $(basename "$0") raw/talks/talk-foo.md
  $(basename "$0") raw/papers
  $(basename "$0") -f raw/talks/talk-foo.md
  $(basename "$0") -w raw/talks/talk-dense-accent.md
  $(basename "$0") -n              # preview pending work
EOF
}

while getopts "fwnh" opt; do
  case "$opt" in
    f) force=1 ;;
    w) use_whisper=1 ;;
    n) dry_run=1 ;;
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

# Returns 0 if the given URL points directly at a PDF (path ends in .pdf,
# or a HEAD request reports Content-Type: application/pdf). Cheap heuristic —
# handles the common case, not the publisher-landing-page case.
url_points_at_pdf() {
  local url="$1"
  local path ct
  # Fast path: URL path ends with .pdf (ignoring query string and fragment).
  path="${url%%\?*}"
  path="${path%%#*}"
  [[ "$path" =~ \.pdf$ ]] && return 0
  # Slow path: HEAD request, short timeout so we don't hang on slow servers.
  ct=$(curl -sSLI --fail --max-time 10 "$url" 2>/dev/null \
    | awk -F': ' '/^[Cc]ontent-[Tt]ype:/ { sub(/;.*/, "", $2); sub(/\r$/, "", $2); print $2; exit }')
  [[ "$ct" == "application/pdf" ]]
}

prepare_paper() {
  local file="$1"
  local arxiv_id pdf_url url pdf fetch_url source_label
  pdf="${file%.md}.pdf"

  # Already have the PDF? Honor manual drops (paywalled source, friend emailed
  # it to you, publisher landing page not scriptable, etc).
  if [[ -f "$pdf" && $force -eq 0 ]]; then
    skip "$file — PDF already exists ($(basename "$pdf"))"
    return 0
  fi

  # Priority chain: arxiv_id > pdf_url > url (if it points at a PDF).
  arxiv_id=$(fm_get "$file" "arxiv_id")
  pdf_url=$(fm_get "$file" "pdf_url")
  url=$(fm_get "$file" "url")

  if [[ -n "$arxiv_id" ]]; then
    fetch_url="https://arxiv.org/pdf/${arxiv_id}"
    source_label="arxiv_id=$arxiv_id"
  elif [[ -n "$pdf_url" ]]; then
    fetch_url="$pdf_url"
    source_label="pdf_url"
  elif [[ -n "$url" ]] && url_points_at_pdf "$url"; then
    fetch_url="$url"
    source_label="url (direct PDF)"
  else
    fail "$file — no path to PDF. Set 'pdf_url', set 'arxiv_id', or drop the PDF at $(basename "$pdf") manually."
    return 1
  fi

  if (( dry_run )); then
    ok "$file — would download $fetch_url ($source_label)"
    return 0
  fi

  if curl -sSL --fail -o "$pdf" "$fetch_url"; then
    ok "$file — downloaded $(basename "$pdf") via $source_label"
    return 0
  else
    rm -f "$pdf"
    fail "$file — PDF fetch failed ($source_label → $fetch_url)"
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
  local url audio_file input file_dir
  url=$(fm_get "$file" "url")
  audio_file=$(fm_get "$file" "audio_file")

  # audio_file wins when both are set — a local file is the more specific
  # source.
  if [[ -n "$audio_file" ]]; then
    file_dir="$(cd "$(dirname "$file")" && pwd)"
    input="$file_dir/$audio_file"
    if [[ ! -f "$input" ]]; then
      fail "$file — audio_file not found: $input"
      return 1
    fi
  elif [[ -n "$url" ]]; then
    input="$url"
  else
    fail "$file — missing 'url' or 'audio_file' in frontmatter"
    return 1
  fi

  if talk_has_transcript "$file" && [[ $force -eq 0 ]]; then
    skip "$file — transcript already present"
    return 0
  fi

  local transcriber transcriber_name
  # Local audio always goes through Whisper — YouTube auto-captions don't
  # exist for files on disk.
  if [[ -n "$audio_file" ]] || (( use_whisper )); then
    transcriber="$SCRIPT_DIR/whisper.sh"
    transcriber_name="whisper.sh"
  else
    transcriber="$SCRIPT_DIR/youtube_transcript.sh"
    transcriber_name="youtube_transcript.sh"
  fi

  if (( dry_run )); then
    ok "$file — would fetch transcript via $transcriber_name ($(basename "$input"))"
    return 0
  fi

  local tmp rewritten
  tmp=$(mktemp)
  rewritten=$(mktemp)

  # Fetch first (don't touch the source MD unless we got something).
  if ! "$transcriber" "$input" > "$tmp"; then
    rm -f "$tmp" "$rewritten"
    fail "$file — $transcriber_name failed"
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

# ---------------- orphan auto-wrap ----------------
# Before the main scan, catch any non-.md files sitting in raw/articles/,
# raw/papers/, or raw/talks/ that don't have a companion .md. These happen
# when a PDF or audio file is dropped manually (e.g. a paper a friend sent,
# a podcast downloaded by hand). Auto-create a stub .md so downstream steps
# (prepare backfill, ingest, digest) can see them.
#
# raw/book/ is deliberately skipped — books go through reading-companion,
# which seeds its own book-home card.

# Format a file's mtime as YYYY-MM-DD. Handles both macOS (stat -f) and GNU
# (stat -c) without requiring GNU coreutils on Mac.
file_mtime_date() {
  local file="$1"
  if stat -f '%Sm' -t '%Y-%m-%d' "$file" >/dev/null 2>&1; then
    stat -f '%Sm' -t '%Y-%m-%d' "$file"
  else
    date -d "@$(stat -c '%Y' "$file")" +'%Y-%m-%d'
  fi
}

wrap_orphans() {
  local wrapped=0
  local subdir type dir file slug md stub_date fname
  for subdir in articles papers talks; do
    type="${subdir%s}"
    dir="$REPO_ROOT/raw/$subdir"
    [[ -d "$dir" ]] || continue

    while IFS= read -r -d '' file; do
      fname="$(basename "$file")"
      slug="${fname%.*}"
      md="$dir/${slug}.md"
      [[ -f "$md" ]] && continue       # already has a companion MD
      stub_date=$(file_mtime_date "$file")

      case "$type" in
        article)
          cat > "$md" <<EOF
---
source_type: "article"
title: "$slug"
clipped: $stub_date
ingested: false
---

_Wrapped from orphan file: $fname. Edit frontmatter and body as needed._
EOF
          ;;
        paper)
          cat > "$md" <<EOF
---
source_type: "paper"
title: "$slug"
clipped: $stub_date
ingested: false
---

_Wrapped from orphan file: $fname. The file is already on disk alongside this MD; prepare.sh will skip the PDF fetch._
EOF
          ;;
        talk)
          cat > "$md" <<EOF
---
source_type: "talk"
title: "$slug"
audio_file: "$fname"
clipped: $stub_date
ingested: false
---

## Transcript

_Paste transcript here, or run \`utilities/prepare.sh\` to transcribe \`$fname\` via Whisper (requires OPENAI_API_KEY)._
EOF
          ;;
      esac

      echo "• wrapped orphan: $file" >&2
      wrapped=$((wrapped + 1))
    done < <(find "$dir" -maxdepth 1 -type f \
      ! -name '*.md' ! -name 'README.md' ! -name '.gitkeep' ! -name '.DS_Store' \
      -print0 2>/dev/null)
  done
  (( wrapped > 0 )) && echo "• wrapped $wrapped orphan file(s)" >&2
  return 0
}

# Only wrap orphans in auto-discovery mode. When the user targets specific
# files or directories, respect their scope — don't silently create stubs
# elsewhere.
if [[ $# -eq 0 ]]; then
  wrap_orphans
fi

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
if (( dry_run )); then
  echo "dry run — no changes made"
  echo "summary: pending=$processed complete=$skipped failed=$failed"
else
  echo "summary: processed=$processed skipped=$skipped failed=$failed"
fi
exit $(( failed > 0 ? 1 : 0 ))
