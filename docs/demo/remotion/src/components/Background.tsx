import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { theme } from "../theme";

/** Reusable Obsidian Slate backdrop: drifting violet/amber glows, faint grid, vignette. */
export const Background: React.FC<{ accent?: "violet" | "amber" | "crimson" }> = ({
  accent = "violet",
}) => {
  const frame = useCurrentFrame();
  const drift = interpolate(frame % 600, [0, 300, 600], [0, 40, 0]);
  const accentColor = theme[accent];
  return (
    <AbsoluteFill style={{ backgroundColor: theme.obsidian }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(900px 600px at ${20 + drift / 4}% ${15 + drift / 8}%, ${accentColor}33, transparent 70%),
                       radial-gradient(800px 560px at ${85 - drift / 4}% 90%, ${theme.amber}1f, transparent 70%)`,
        }}
      />
      <AbsoluteFill
        style={{
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px)",
          backgroundSize: "64px 64px",
          backgroundPosition: `${drift}px ${drift / 2}px`,
        }}
      />
      <AbsoluteFill
        style={{ background: "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.55) 100%)" }}
      />
    </AbsoluteFill>
  );
};
