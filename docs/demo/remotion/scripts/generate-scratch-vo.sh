#!/usr/bin/env bash
# Generates scratch narration with the built-in macOS `say` command,
# one WAV per scene, then measures durations into src/generated/durations.json.
# Usage: scripts/generate-scratch-vo.sh   (env: VO_VOICE=Samantha VO_RATE=156)
set -euo pipefail
cd "$(dirname "$0")/.."

VOICE="${VO_VOICE:-Samantha}"   # alternative: Daniel
RATE="${VO_RATE:-156}"          # words per minute
OUT="public/audio/scratch"

command -v say >/dev/null || { echo "macOS 'say' not found" >&2; exit 1; }
mkdir -p "$OUT"

node -e '
const n = require("./src/narration.json");
for (const s of n) console.log(s.id + "\t" + s.text);
' | while IFS=$'\t' read -r id text; do
  echo "say -> $OUT/$id.wav ($VOICE, $RATE wpm)"
  say -v "$VOICE" -r "$RATE" -o "$OUT/$id.wav" --data-format=LEI16@44100 "$text"
done

node scripts/measure-audio.mjs scratch
