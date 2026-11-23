import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";

export const Card: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
  border?: string;
}> = ({ children, style, border = theme.glassBorder }) => (
  <div
    style={{
      background: theme.glass,
      border: `1.5px solid ${border}`,
      borderRadius: 20,
      boxShadow: "0 20px 60px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.06)",
      backdropFilter: "blur(14px)",
      padding: 28,
      color: theme.text,
      fontFamily: theme.fontSans,
      ...style,
    }}
  >
    {children}
  </div>
);

export const Mono: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
  style?: React.CSSProperties;
}> = ({ children, color = theme.amber, size = 30, style }) => (
  <div
    style={{
      fontFamily: theme.fontMono,
      fontSize: size,
      color,
      background: "rgba(0,0,0,0.45)",
      border: "1px solid rgba(255,255,255,0.08)",
      borderRadius: 10,
      padding: "12px 18px",
      whiteSpace: "pre-wrap",
      overflowWrap: "anywhere",
      ...style,
    }}
  >
    {children}
  </div>
);

export const Badge: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
}> = ({ children, color = theme.crimson, size = 24 }) => (
  <span
    style={{
      display: "inline-block",
      fontFamily: theme.fontSans,
      fontWeight: 700,
      fontSize: size,
      letterSpacing: 1,
      whiteSpace: "nowrap",
      textTransform: "uppercase",
      color: "#fff",
      background: color,
      borderRadius: 999,
      padding: "6px 18px",
      boxShadow: `0 0 24px ${color}66`,
    }}
  >
    {children}
  </span>
);

/** Slides/fades children in at `delay` frames (relative to the scene). */
export const Reveal: React.FC<{
  delay?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
  from?: "bottom" | "right" | "left";
}> = ({ delay = 0, children, style, from = "bottom" }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 200 }, durationInFrames: 24 });
  const off = (1 - p) * 40;
  const t =
    from === "bottom" ? `translateY(${off}px)` : from === "right" ? `translateX(${off}px)` : `translateX(${-off}px)`;
  return <div style={{ opacity: p, transform: t, ...style }}>{children}</div>;
};

/** Bottom caption bar. */
export const Caption: React.FC<{ children: React.ReactNode; delay?: number }> = ({
  children,
  delay = 0,
}) => (
  <Reveal
    delay={delay}
    style={{ position: "absolute", left: 120, right: 120, bottom: 48, textAlign: "center" }}
  >
    <div
      style={{
        display: "inline-block",
        background: "rgba(14,16,19,0.88)",
        border: `1px solid ${theme.glassBorder}`,
        borderRadius: 14,
        color: theme.text,
        fontFamily: theme.fontSans,
        fontSize: 34,
        padding: "14px 30px",
      }}
    >
      {children}
    </div>
  </Reveal>
);

export const Heading: React.FC<{ children: React.ReactNode; size?: number; color?: string }> = ({
  children,
  size = 64,
  color = theme.text,
}) => (
  <div
    style={{
      fontFamily: theme.fontSans,
      fontWeight: 800,
      fontSize: size,
      color,
      letterSpacing: -1,
      lineHeight: 1.1,
    }}
  >
    {children}
  </div>
);

/** Fades a scene in and out so cuts are soft. */
export const useSceneFade = (durationInFrames: number, edge = 12): number => {
  const frame = useCurrentFrame();
  return interpolate(frame, [0, edge, durationInFrames - edge, durationInFrames], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
};
