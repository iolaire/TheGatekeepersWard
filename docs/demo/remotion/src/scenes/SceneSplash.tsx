import React from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { theme } from "../theme";

/**
 * Silent splash / title card shown at the very start of the video, before any
 * narration. The ghost mascot rises out of the gate, the wordmark lights up,
 * then the whole card fades to hand off to Scene 1.
 */
export const SceneSplash: React.FC<{ frames: number }> = ({ frames }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const rise = spring({ frame, fps, config: { damping: 200 }, durationInFrames: 30 });
  const float = Math.sin(frame / 16) * 12;
  const titleP = spring({ frame: frame - 14, fps, config: { damping: 200 }, durationInFrames: 26 });
  const taglineP = spring({ frame: frame - 30, fps, config: { damping: 200 }, durationInFrames: 24 });
  const glow = interpolate(Math.sin(frame / 12), [-1, 1], [0.45, 1]);
  const fadeOut = interpolate(frame, [frames - 16, frames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ opacity: fadeOut, alignItems: "center", justifyContent: "center" }}>
      <Background />
      <div style={{ textAlign: "center", transform: `translateY(${-20}px)` }}>
        <Img
          src={staticFile("img/castle_gate_spirits.svg")}
          style={{
            width: 520,
            height: 360,
            opacity: rise,
            transform: `translateY(${(1 - rise) * 60 + float}px)`,
            filter: `drop-shadow(0 0 ${44 * glow}px ${theme.violet})`,
          }}
        />
        <div
          style={{
            marginTop: 10,
            opacity: titleP,
            transform: `scale(${0.9 + titleP * 0.1})`,
            fontFamily: theme.fontSans,
            fontWeight: 800,
            fontSize: 132,
            letterSpacing: -2,
            color: theme.text,
            textShadow: `0 0 ${60 * glow}px ${theme.violet}`,
          }}
        >
          Gatekeeper&rsquo;s Ward
        </div>
        <div
          style={{
            marginTop: 26,
            opacity: taglineP,
            fontFamily: theme.fontSans,
            fontSize: 42,
            color: theme.amber,
          }}
        >
          Know who knocks before you drop the castle gates.
        </div>
      </div>
    </AbsoluteFill>
  );
};
