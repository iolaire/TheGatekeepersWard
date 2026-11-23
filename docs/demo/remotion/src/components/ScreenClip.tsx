import React from "react";
import { Freeze, OffthreadVideo, staticFile, useCurrentFrame } from "remotion";
import { FPS, theme } from "../theme";

/**
 * Real screen recording framed in a glass bezel. Zooms into the region of
 * the 16:9 capture that holds the app window (zoomX/zoomY are the focus point
 * as fractions of the frame). Holds the last frame once the clip ends.
 */
export const ScreenClip: React.FC<{
  file: string;
  clipSeconds: number;
  width: number;
  height: number;
  zoom?: number;
  focusX?: number;
  focusY?: number;
  label?: string;
}> = ({ file, clipSeconds, width, height, zoom = 1.7, focusX = 0.5, focusY = 0.45, label }) => {
  const frame = useCurrentFrame();
  const clipFrames = Math.floor(clipSeconds * FPS) - 2;
  const f = Math.min(frame, clipFrames);
  // Source is 16:9; scale so it covers the box at `zoom` and focus on the point.
  const srcW = width * zoom;
  const srcH = srcW * (9 / 16);
  const left = -(focusX * srcW - width / 2);
  const top = -(focusY * srcH - height / 2);
  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: 18,
        overflow: "hidden",
        border: `2px solid ${theme.glassBorder}`,
        boxShadow: "0 24px 70px rgba(0,0,0,0.6)",
        background: "#000",
      }}
    >
      <Freeze frame={f}>
        <div style={{ position: "absolute", left, top, width: srcW, height: srcH }}>
          <OffthreadVideo
            src={staticFile(`clips/${file}`)}
            muted
            style={{ width: "100%", height: "100%" }}
          />
        </div>
      </Freeze>
      {label ? (
        <div
          style={{
            position: "absolute",
            top: 14,
            left: 14,
            fontFamily: theme.fontMono,
            fontSize: 20,
            color: theme.text,
            background: "rgba(14,16,19,0.85)",
            padding: "4px 12px",
            borderRadius: 8,
          }}
        >
          {label}
        </div>
      ) : null}
    </div>
  );
};
