import React from "react";
import { AbsoluteFill } from "remotion";
import { Background } from "../components/Background";
import { ScreenClip } from "../components/ScreenClip";
import { Badge, Caption, Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

const s = (sec: number) => Math.round(sec * 30);

export const Scene02Baseline: React.FC<{ frames: number }> = ({ frames }) => {
  const fade = useSceneFade(frames);
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background accent="crimson" />
      <div style={{ position: "absolute", left: 80, top: 70 }}>
        <Reveal>
          <Heading size={52}>Without the Ward</Heading>
          <div style={{ fontFamily: theme.fontMono, fontSize: 24, color: theme.textDim, marginTop: 8 }}>
            real capture &middot; the normal Mac pop-up
          </div>
        </Reveal>
      </div>
      <div style={{ position: "absolute", left: 80, top: 210 }}>
        <ScreenClip
          file="baseline.mp4"
          clipSeconds={10.4}
          width={1100}
          height={680}
          zoom={1.75}
          focusX={0.5}
          focusY={0.42}
          label="DeepSeek Harness &middot; baseline"
        />
      </div>
      <div style={{ position: "absolute", right: 80, top: 210, width: 600, display: "grid", gap: 22 }}>
        <Reveal delay={s(2.3)} from="right">
          <Card>
            <div style={{ fontSize: 24, color: theme.textDim, marginBottom: 10 }}>Your Mac tells you</div>
            <Mono size={26} color={theme.text}>
              &ldquo;DeepSeek Harness&rdquo; would like to access files in your Desktop folder.
            </Mono>
          </Card>
        </Reveal>
        <Reveal delay={s(6.5)} from="right">
          <Card border={theme.crimson}>
            <div style={{ fontSize: 24, color: theme.textDim, marginBottom: 14 }}>It does not tell you</div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 12 }}>
              <Badge>What it will run</Badge>
              <Badge>Who started it</Badge>
              <Badge>Where it runs</Badge>
              <Badge>Why it asks</Badge>
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(8.1)} from="right">
          <Card border={theme.amber}>
            <div style={{ fontSize: 30, lineHeight: 1.3 }}>
              Harmless listing, or a script copying files out? <b style={{ color: theme.amber }}>You can&rsquo;t tell.</b>
            </div>
          </Card>
        </Reveal>
      </div>
      <Caption delay={s(12.6)}>Allow or Don&rsquo;t Allow, and hope.</Caption>
    </AbsoluteFill>
  );
};
