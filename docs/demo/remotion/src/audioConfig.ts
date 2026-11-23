import { staticFile } from "remotion";
import narration from "./narration.json";
import scratchDurations from "./generated/durations.scratch.json";
import finalDurations from "./generated/durations.final.json";
import { FPS } from "./theme";

/**
 * Narration wiring. Change NARRATION_MODE (or run with the env var
 * NARRATION_MODE read by the studio's --props) to swap audio sources:
 *
 *  "scratch"   macOS `say` clips   public/audio/scratch/<scene-id>.wav
 *  "perScene"  your recordings     public/audio/final/<scene-id>.wav
 *  "master"    one long recording  public/audio/final-narration.wav
 *
 * Per-scene durations come from `npm run audio:measure -- final` (writes
 * src/generated/durations.final.json). In master mode, set the scene
 * start/length seconds in MASTER_TIMINGS below.
 */
export type NarrationMode = "scratch" | "perScene" | "master";
export const NARRATION_MODE = "scratch" as NarrationMode;

export const MASTER_FILE = "audio/final-narration.wav";

/** Master mode only: seconds into the master file where each scene starts, and its length. */
export const MASTER_TIMINGS: Record<string, { start: number; length: number }> = {
  "scene-01-intro": { start: 0, length: 26 },
  "scene-02-baseline": { start: 26, length: 20 },
  "scene-03-ward": { start: 46, length: 56 },
  "scene-04-how": { start: 102, length: 29 },
  "scene-05-outro": { start: 131, length: 18 },
};

/** Silence before the voice starts and after it ends, in seconds. */
export const LEAD_SECONDS = 0.4;
export const TAIL_SECONDS = 0.8;

export type SceneTiming = {
  id: string;
  title: string;
  text: string;
  /** Narration length in seconds. */
  voiceSeconds: number;
  /** Frames the scene occupies, including padding. */
  frames: number;
  leadFrames: number;
  /** staticFile path of the audio, and where to start inside it (frames). */
  audioSrc: string;
  audioStartFromFrames: number;
};

const voiceSecondsFor = (id: string): number => {
  if (NARRATION_MODE === "master") return MASTER_TIMINGS[id].length;
  if (NARRATION_MODE === "perScene") {
    const d = (finalDurations as Record<string, number>)[id];
    if (d === undefined) {
      throw new Error(`Run "npm run audio:measure -- final" first (no duration for ${id}).`);
    }
    return d;
  }
  return (scratchDurations as Record<string, number>)[id];
};

export const sceneTimings: SceneTiming[] = narration.map((s) => {
  const voiceSeconds = voiceSecondsFor(s.id);
  const leadFrames = Math.round(LEAD_SECONDS * FPS);
  const frames = Math.ceil((LEAD_SECONDS + voiceSeconds + TAIL_SECONDS) * FPS);
  const audioSrc =
    NARRATION_MODE === "scratch"
      ? staticFile(`audio/scratch/${s.id}.wav`)
      : NARRATION_MODE === "perScene"
        ? staticFile(`audio/final/${s.id}.wav`)
        : staticFile(MASTER_FILE);
  const audioStartFromFrames =
    NARRATION_MODE === "master" ? Math.round(MASTER_TIMINGS[s.id].start * FPS) : 0;
  return { ...s, voiceSeconds, frames, leadFrames, audioSrc, audioStartFromFrames };
});

export const totalFrames = sceneTimings.reduce((a, s) => a + s.frames, 0);
