#!/usr/bin/env bash
# Builds light 1440p H.264 proxies of the 4K captures and copies stills/art
# into public/ (all gitignored). Source files are never modified.
set -euo pipefail
cd "$(dirname "$0")/.."
A="../assets/deepseek-harness"
mkdir -p public/clips public/img

proxy() { # name src start duration
  [ -f "public/clips/$1.mp4" ] && { echo "have $1"; return; }
  ffmpeg -loglevel error -y -ss "$3" -t "$4" -i "$2" -an -r 30 \
    -vf "scale=2560:1440:flags=lanczos" -c:v libx264 -preset medium -crf 26 -pix_fmt yuv420p \
    "public/clips/$1.mp4"
  echo "made $1"
}
# baseline: Apple prompt appears ~20s in; start at 15s
proxy baseline "$A/baseline_deepseek_harness_desktop_flow.mov" 15 10.4
# ward: HUD appears ~14s in; start at 8s
proxy ward "$A/ward_deepseek_harness_desktop_flow.mov" 8 15.4

cp "$A/baseline_deepseek_harness_desktop_prompt.png" public/img/baseline-prompt.png
cp "$A/ward_deepseek_harness_desktop_pair.png" public/img/ward-pair.png
cp "$A/ward_deepseek_harness_desktop_hud.png" public/img/ward-hud.png
cp ../../Planning/Styles/solo_spirit.svg public/img/solo_spirit.svg
cp ../../Planning/Styles/castle_gate_spirits.svg public/img/castle_gate_spirits.svg
echo "assets ready"
