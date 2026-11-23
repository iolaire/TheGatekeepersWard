# Gatekeeper's Ward: Demo Video (Remotion)

1920x1080, 30 fps, about 2:47. Everything is self-contained in this folder and reads the real captures in `../assets/deepseek-harness/` and `../assets/qoder/`. Nothing in the Swift sources or `.kiro/` is touched.

## Setup (once)

```bash
cd docs/demo/remotion
npm install
npm run prepare:assets   # makes 1440p proxies of the 4K .mov captures, copies stills and art
npm run audio:scratch    # macOS `say` narration, one WAV per scene, plus durations
```

Needs Node 20+, `ffmpeg` and macOS (`say`, `afinfo`).

## Preview and render

```bash
npm run dev          # Remotion Studio
npm run render:draft # fast 960x540 proxy -> out/gatekeepers-ward-demo-draft.mp4
npm run render       # full 1920x1080 -> out/gatekeepers-ward-demo.mp4
```

**Preview image at rest.** The poster is the splash card at 0:02 (frame 60). Both render scripts attach it to the MP4 as cover art (stream copy, no re-encode), and `npm run poster` writes `out/poster.png` (1920x1080) for a web `<video poster>` or an upload thumbnail. To embed it in an existing MP4 without re-rendering: `bash scripts/make-poster.sh out/<file>.mp4`. Change the frame with `POSTER_FRAME=<n>`. The video itself still starts on dark and keeps its transitions. Players differ: some show the cover art, others show the first frame, and YouTube or Devpost pick their own thumbnail unless you upload `poster.png`.

Render at low resolution while iterating, then render full-res to finalize. `render:draft` uses `--scale=0.5` (half the pixels, same composition) and a higher CRF, so it encodes roughly twice as fast.

Generated and large files are gitignored: `node_modules/`, `out/`, `public/audio/`, `public/clips/`, `public/img/`.

## Drop in your final narration

Edit `NARRATION_MODE` in `src/audioConfig.ts`.

**Option A: one recording per scene** (`"perScene"`)
1. Record each scene from `VOICEOVER.md`. Save as `public/audio/final/<scene-id>.wav`, for example `scene-01-intro.wav`.
2. Run `npm run audio:measure -- final`. This writes the clip lengths to `src/generated/durations.final.json`.
3. Set `NARRATION_MODE = "perScene"`.

Scene lengths follow your clips (plus 0.4 s lead-in and 0.8 s tail).

**Option B: one master recording** (`"master"`)
1. Save it as `public/audio/final-narration.wav`.
2. In `MASTER_TIMINGS` (same file), set the start second and length of each scene inside the recording.
3. Set `NARRATION_MODE = "master"`.

Then run `npm run dev` to check sync and `npm run render`.

Keep the total under 3:00. `npm run render` prints the frame count; divide by 30. The scratch cut is 4505 frames (150.2 s).

## Layout

| Path | Purpose |
|---|---|
| `src/narration.json` | Spoken text, impact point and visual cues per scene (single source for the scratch voice and `VOICEOVER.md`) |
| `src/audioConfig.ts` | Audio mode, per-scene timing, padding |
| `src/theme.ts` | Palette (Obsidian `#0E1013`, Violet `#8B5CF6`, Amber `#F59E0B`, Crimson `#E63946`) and fonts |
| `src/components/` | `Background`, glass `Card`, `Mono`, `Badge`, `Caption`, `ScreenClip` |
| `src/scenes/` | One component per scene |
| `scripts/` | `prepare-assets.sh`, `generate-scratch-vo.sh`, `measure-audio.mjs` |
| `VOICEOVER.md` | Timed script with scene IDs and visual cues. **Generated** from `src/narration.json`: run `npm run voiceover:sync` (also runs after `npm run audio:scratch`); `npm run voiceover:check` fails if it is out of date |

## Notes

- Scratch voice: `VO_VOICE=Daniel VO_RATE=160 npm run audio:scratch` to try another voice or rate.
- Clip trims: `scripts/prepare-assets.sh` (baseline from 15 s, Ward from 8 s of the source captures). Delete `public/clips/*.mp4` and re-run it to change them.
- No music and no stock assets. The mascot and gate art are the project's Gemini-generated SVGs from `docs/Planning/Styles/` (see `docs/ai-asset-licensing.md`).
- The synthetic scratch voice is a draft. If a synthetic voice stays in the final cut, check the contest rules and disclose it.
- The repo link on the last scene is a placeholder. Edit `src/scenes/Scene05Outro.tsx`.
