#!/usr/bin/env bash
# Renders the poster still (the splash card at 0:02) and, optionally, attaches
# it to an existing MP4 as cover art without re-encoding the video.
#   scripts/make-poster.sh                 -> out/poster.png (full 1920x1080)
#   scripts/make-poster.sh <video.mp4>     -> also embeds the poster in the MP4
# POSTER_FRAME defaults to 60 (2.0 s at 30 fps).
set -euo pipefail
cd "$(dirname "$0")/.."
FRAME="${POSTER_FRAME:-60}"
POSTER="out/poster.png"
mkdir -p out

if [ ! -f "$POSTER" ] || [ -n "${POSTER_FORCE:-}" ] || [ src/scenes/SceneSplash.tsx -nt "$POSTER" ]; then
  npx remotion still GatekeepersWardDemo --frame="$FRAME" --concurrency=1 "$POSTER" >/dev/null
  echo "poster: $POSTER (frame $FRAME)"
fi

if [ $# -ge 1 ]; then
  VIDEO="$1"
  [ -f "$VIDEO" ] || { echo "no such file: $VIDEO" >&2; exit 1; }
  TMP="${VIDEO%.mp4}.cover.tmp.mp4"
  # Copy all streams, then attach the poster as cover art (stream copy: no re-encode).
  ffmpeg -loglevel error -y -i "$VIDEO" -i "$POSTER" -map 0 -map 1 -c copy \
    -disposition:v:1 attached_pic -movflags +faststart "$TMP"
  mv "$TMP" "$VIDEO"
  echo "cover art embedded: $VIDEO"
fi
