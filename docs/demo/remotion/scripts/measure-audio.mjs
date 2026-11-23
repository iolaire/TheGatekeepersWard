// Measures narration clip durations with `afinfo` and writes src/generated/durations.json.
// Usage: node scripts/measure-audio.mjs [scratch|final]
// "final" measures public/audio/final/<scene-id>.wav (per-scene recordings).
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";

const dir = process.argv[2] ?? "scratch";
const narration = JSON.parse(readFileSync("src/narration.json", "utf8"));
const out = {};
for (const s of narration) {
  const file = `public/audio/${dir}/${s.id}.wav`;
  if (!existsSync(file)) {
    console.warn(`missing: ${file}`);
    continue;
  }
  const info = execFileSync("afinfo", [file], { encoding: "utf8" });
  const m = info.match(/estimated duration:\s*([\d.]+)/);
  if (!m) throw new Error(`no duration for ${file}`);
  out[s.id] = Number(Number(m[1]).toFixed(3));
  console.log(`${s.id}: ${out[s.id]}s`);
}
mkdirSync("src/generated", { recursive: true });
writeFileSync(`src/generated/durations.${dir}.json`, JSON.stringify(out, null, 2) + "\n");
