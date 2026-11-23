import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { Background } from "../components/Background";
import { Badge, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

const s = (sec: number) => Math.round(sec * 30);

export const Scene05Outro: React.FC<{ frames: number }> = ({ frames }) => {
  const fade = useSceneFade(frames);
  return (
    <AbsoluteFill style={{ opacity: fade, alignItems: "center" }}>
      <Background accent="amber" />
      <Reveal style={{ position: "absolute", top: 50 }}>
        <Img src={staticFile("img/castle_gate_spirits.svg")} style={{ width: 360, height: 250 }} />
      </Reveal>
      <div style={{ position: "absolute", top: 330, textAlign: "center", width: "100%" }}>
        <Reveal delay={s(1)}>
          <Heading size={72}>Built for Kiroween 2026 with Kiro</Heading>
        </Reveal>
        <Reveal delay={s(2)} style={{ display: "flex", gap: 20, justifyContent: "center", marginTop: 36 }}>
          <Badge color={theme.violet} size={30}>Spec-driven development</Badge>
          <Badge color={theme.violet} size={30}>Agent hooks</Badge>
          <Badge color={theme.violet} size={30}>Property-based testing</Badge>
        </Reveal>
        <Reveal delay={s(6.5)} style={{ display: "flex", justifyContent: "center", marginTop: 44 }}>
          <Mono size={32} color={theme.text}>
            github.com/iolaire/TheGatekeepersWard   [repo link placeholder]
          </Mono>
        </Reveal>
        <Reveal delay={s(6.9)} style={{ marginTop: 20 }}>
          <div style={{ fontFamily: theme.fontSans, fontSize: 28, color: theme.textDim }}>
            Open source &middot; Apache 2.0
          </div>
        </Reveal>
      </div>
      <Reveal delay={s(8.5)} style={{ position: "absolute", bottom: 230, textAlign: "center", width: "100%" }}>
        <div style={{ fontFamily: theme.fontSans, fontSize: 40, color: theme.text }}>
          The commands behind a pop-up, finally visible.
        </div>
      </Reveal>
      <Reveal delay={s(12.9)} style={{ position: "absolute", bottom: 90, textAlign: "center", width: "100%" }}>
        <div style={{ fontFamily: theme.fontSans, fontSize: 54, fontWeight: 700, color: theme.amber }}>
          &ldquo;Know who knocks before you drop the castle gates.&rdquo;
        </div>
      </Reveal>
    </AbsoluteFill>
  );
};
