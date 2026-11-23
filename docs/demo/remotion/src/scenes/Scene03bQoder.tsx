import React from "react";
import { AbsoluteFill } from "remotion";
import { ScreenClip } from "../components/ScreenClip";
import { Background } from "../components/Background";
import { Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

const s = (sec: number) => Math.round(sec * 30 * 0.83);

const Label: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ fontFamily: theme.fontSans, fontSize: 22, color: theme.textDim, marginBottom: 8, letterSpacing: 1 }}>
    {children}
  </div>
);

/** Second real capture: Qoder's Microphone prompt beside the Fortress HUD (clip, then held on the HUD). */
export const Scene03bQoder: React.FC<{ frames: number }> = ({ frames }) => {
  const fade = useSceneFade(frames);
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background />
      <div style={{ position: "absolute", left: 80, top: 56 }}>
        <Reveal>
          <Heading size={52}>Another AI IDE, another vault</Heading>
          <div style={{ fontFamily: theme.fontMono, fontSize: 24, color: theme.textDim, marginTop: 8 }}>
            real capture &middot; Qoder asks for the Microphone
          </div>
        </Reveal>
      </div>
      <div style={{ position: "absolute", left: 80, top: 200 }}>
        <ScreenClip
          file="qoder.mp4"
          clipSeconds={8}
          width={1080}
          height={780}
          zoom={1.8}
          focusX={0.5}
          focusY={0.4}
          label="Qoder + Gatekeeper's Ward"
        />
      </div>
      <div style={{ position: "absolute", right: 70, top: 200, width: 640, display: "grid", gap: 14 }}>
        <Reveal delay={s(3)} from="right">
          <Card style={{ padding: 20 }}>
            <Label>PERMISSION &amp; TARGET</Label>
            <Mono size={22} color={theme.violet}>kTCCServiceMicrophone</Mono>
            <div style={{ fontSize: 24, marginTop: 8, color: theme.text }}>
              target: <span style={{ color: theme.amber }}>Voice Chamber</span>
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(6)} from="right">
          <Card style={{ padding: 20 }}>
            <Label>COMMAND</Label>
            <Mono size={22} color={theme.text}>$ swift-frontend -interpret &hellip;</Mono>
            <div style={{ fontSize: 22, marginTop: 10, color: theme.textDim, lineHeight: 1.3 }}>
              A <code>swift -e</code> one-liner shows up as the Swift compiler, so it is harder to read.
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(10)} from="right">
          <Card style={{ padding: 20, boxShadow: `0 0 40px ${theme.violet}55` }} border={theme.violet}>
            <Label>LINEAGE STILL NAMES THE SOURCE</Label>
            <Mono size={22} color={theme.text}>
              Qoder (44386){"\n"}
              {"  "}&rarr; Qoder (44767){"\n"}
              {"    "}&rarr; zsh (63090){"\n"}
              {"      "}&rarr; swift-frontend (63093)
            </Mono>
          </Card>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};
