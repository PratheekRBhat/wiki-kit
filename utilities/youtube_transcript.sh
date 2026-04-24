#!/usr/bin/env bash
# youtube_transcript.sh — fetch and clean a YouTube video's auto-generated
# transcript, emitting readable markdown on stdout.
#
# Typical workflow after clipping a YouTube Talk via Web Clipper:
#
#   utilities/youtube_transcript.sh "https://youtu.be/..." \
#     >> raw/talks/talk-<whatever>.md
#
# Requires: yt-dlp  (install: brew install yt-dlp)

set -euo pipefail

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [-l LANG] <youtube-url>

Fetches YouTube's auto-generated captions, strips VTT/SRT cruft, and prints
a clean line-per-cue transcript on stdout. Pipe it into a file or paste it
under a talk's '## Transcript' section.

Options:
  -l LANG    Subtitle language code (default: en). Try "en-US" or another
             code if the default fails.
  -h         Show this help.

Examples:
  $(basename "$0") "https://www.youtube.com/watch?v=TsmhRZElPvM"
  $(basename "$0") "..." >> raw/talks/talk-iceberg.md
  $(basename "$0") "..." | pbcopy

Limitations:
  - Relies on YouTube's auto-generated captions. For higher quality, use
    Whisper against the downloaded audio instead (out of scope for this
    script).
  - Some videos (live, age-restricted, region-locked) may have no
    captions available; the script exits non-zero with an error.
EOF
}

lang="en"
while getopts "l:h" opt; do
  case "$opt" in
    l) lang="$OPTARG" ;;
    h) print_usage; exit 0 ;;
    *) print_usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  echo "error: missing YouTube URL" >&2
  print_usage >&2
  exit 1
fi

url="$1"

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "error: yt-dlp not installed. run 'brew install yt-dlp'." >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# --convert-subs srt normalises the messy VTT auto-caption format into a
# consistent SRT that's easier to strip with awk. --sub-langs tries a few
# common variants since YouTube's labelling isn't consistent.
if ! yt-dlp \
  --quiet \
  --no-warnings \
  --skip-download \
  --write-auto-sub \
  --sub-langs "${lang}.*,${lang}" \
  --sub-format vtt \
  --convert-subs srt \
  -o "${tmpdir}/%(id)s.%(ext)s" \
  "$url"; then
  echo "error: yt-dlp failed. verify the URL and that the video has captions." >&2
  exit 3
fi

srt_file=$(find "$tmpdir" -maxdepth 1 -name "*.srt" | head -n 1 || true)

if [[ -z "$srt_file" || ! -f "$srt_file" ]]; then
  echo "error: no subtitles found for language '$lang'. try another language code." >&2
  exit 2
fi

# Strip SRT scaffolding (cue numbers, timestamp lines, blank lines), then
# strip inline timing tags and dedup consecutive identical lines. YouTube's
# auto-captions emit rolling-window duplicates; the consecutive-dedup catches
# most of the repetition after SRT conversion.
sed -E 's/\r$//' "$srt_file" \
  | awk '
      /^WEBVTT/          { next }
      /^Kind:/           { next }
      /^Language:/       { next }
      /^NOTE /           { next }
      /^[0-9]+$/         { next }
      /-->/              { next }
      /^$/               { next }
      {
        gsub(/<[^>]*>/, "")
        gsub(/^[ \t]+|[ \t]+$/, "")
        if ($0 == "")    { next }
        if ($0 == prev)  { next }
        print $0
        prev = $0
      }
    '
