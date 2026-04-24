#!/usr/bin/env bash
# whisper.sh — transcribe audio via OpenAI Whisper API.
#
# Accepts a URL (YouTube, podcast RSS, direct audio link — anything yt-dlp
# can fetch) or a local audio file. Audio is re-encoded to 32 kbps mono mp3
# for transcription (Whisper doesn't need high fidelity). Files that still
# exceed Whisper's 25 MB per-request limit are transparently chunked with
# ffmpeg.
#
# Output: a clean line-per-phrase transcript on stdout — same shape as
# youtube_transcript.sh, so this is a drop-in replacement.
#
# Requires: OPENAI_API_KEY env var, curl, ffmpeg, yt-dlp (for URLs).

set -euo pipefail

MAX_BYTES=$((24 * 1024 * 1024))   # Whisper limit is 25 MB; leave headroom.
MODEL="whisper-1"
API_URL="https://api.openai.com/v1/audio/transcriptions"
COST_PER_MIN="0.006"              # USD. Update if OpenAI pricing changes.

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [-l LANG] <url-or-file>

Transcribe audio via OpenAI Whisper API. Input can be a URL (YouTube,
podcast RSS, direct audio link) or a local audio file (mp3/m4a/wav/etc).

Options:
  -l LANG    ISO 639-1 language code (default: auto-detect).
  -h         Show this help.

Environment:
  OPENAI_API_KEY    required. Get one at https://platform.openai.com/.

Dependencies: curl, ffmpeg, yt-dlp (for URL inputs).

Cost: ~\$${COST_PER_MIN}/min (Whisper API pricing). A 45-min talk is ~\$0.27.

Examples:
  $(basename "$0") "https://www.youtube.com/watch?v=..."
  $(basename "$0") ./podcast-episode.mp3
  $(basename "$0") -l es ./spanish-talk.m4a
EOF
}

lang=""
while getopts "l:h" opt; do
  case "$opt" in
    l) lang="$OPTARG" ;;
    h) print_usage; exit 0 ;;
    *) print_usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  echo "error: missing URL or file" >&2
  print_usage >&2
  exit 1
fi

input="$1"

# ---------------- preflight ----------------

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "error: OPENAI_API_KEY not set." >&2
  echo "       Export it in your shell rc, or source a .env.local with the key." >&2
  exit 1
fi

for cmd in curl ffmpeg ffprobe; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: '$cmd' not installed. (brew install ffmpeg covers ffmpeg + ffprobe.)" >&2
    exit 1
  }
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# ---------------- step 1: resolve input to a local audio file ----------------

if [[ "$input" =~ ^https?:// ]]; then
  command -v yt-dlp >/dev/null 2>&1 || {
    echo "error: yt-dlp required for URL inputs (brew install yt-dlp)." >&2
    exit 1
  }
  echo "• downloading audio..." >&2
  if ! yt-dlp \
      --quiet --no-warnings \
      --extract-audio \
      -o "${tmpdir}/raw.%(ext)s" \
      "$input" >&2; then
    echo "error: yt-dlp failed to download audio. verify the URL." >&2
    exit 1
  fi
  raw=$(find "$tmpdir" -maxdepth 1 -name 'raw.*' | head -n 1)
else
  [[ -f "$input" ]] || { echo "error: not a file: $input" >&2; exit 1; }
  raw="$input"
fi

# ---------------- step 2: normalise to 32 kbps mono mp3 ----------------

compressed="$tmpdir/compressed.mp3"
echo "• compressing audio for transcription..." >&2
ffmpeg -hide_banner -loglevel error \
  -i "$raw" \
  -ac 1 -b:a 32k \
  "$compressed"

# Cost estimate (informational; printed to stderr so it doesn't pollute stdout).
duration_sec=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$compressed" 2>/dev/null || echo "0")
if [[ "$duration_sec" != "0" && -n "$duration_sec" ]]; then
  minutes=$(awk "BEGIN { printf \"%.1f\", $duration_sec / 60 }")
  cost=$(awk "BEGIN { printf \"%.3f\", ($duration_sec / 60) * $COST_PER_MIN }")
  echo "• estimated cost: \$${cost} (${minutes} min at \$${COST_PER_MIN}/min)" >&2
fi

# ---------------- step 3: chunk if still > 25 MB ----------------

chunks_dir="$tmpdir/chunks"
mkdir -p "$chunks_dir"

size=$(wc -c < "$compressed" | tr -d ' ')

if (( size > MAX_BYTES )); then
  echo "• chunking audio ($((size / 1024 / 1024)) MB) into 20-minute segments" >&2
  ffmpeg -hide_banner -loglevel error \
    -i "$compressed" \
    -f segment -segment_time 1200 \
    -c copy \
    "$chunks_dir/chunk_%03d.mp3"
else
  cp "$compressed" "$chunks_dir/chunk_000.mp3"
fi

# ---------------- step 4: transcribe each chunk ----------------

srt_combined="$tmpdir/combined.srt"
: > "$srt_combined"

for chunk in "$chunks_dir"/chunk_*.mp3; do
  [[ -f "$chunk" ]] || continue
  echo "• transcribing $(basename "$chunk")..." >&2

  curl_args=(
    -sS -L --fail
    -H "Authorization: Bearer $OPENAI_API_KEY"
    -F "file=@$chunk"
    -F "model=$MODEL"
    -F "response_format=srt"
  )
  [[ -n "$lang" ]] && curl_args+=(-F "language=$lang")

  if ! curl "${curl_args[@]}" "$API_URL" >> "$srt_combined"; then
    echo "error: Whisper API call failed for $(basename "$chunk")." >&2
    echo "       Check OPENAI_API_KEY validity and your rate limits." >&2
    exit 1
  fi
  # Separator between chunks so adjacent cues don't glue together at the seam.
  echo "" >> "$srt_combined"
done

# ---------------- step 5: clean SRT → line-per-phrase transcript ----------------
# Strip SRT scaffolding (cue numbers, timestamp lines, blank lines) and dedupe
# consecutive identical lines. Matches youtube_transcript.sh's output shape.

sed -E 's/\r$//' "$srt_combined" \
  | awk '
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
