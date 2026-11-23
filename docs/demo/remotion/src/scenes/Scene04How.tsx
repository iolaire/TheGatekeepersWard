import React from "react";
import { AbsoluteFill } from "remotion";
import { Background } from "../components/Background";
import { Badge, Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

const s = (sec: number) => Math.round(sec * 30);

const Node: React.FC<{
  delay: number;
  title: string;
  code: string;
  color: string;
}> = ({ delay, title, code, color }) => (
  <Reveal delay={delay} style={{ flex: 1 }}>
    <Card border={color} style={{ height: 250, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
      <div style={{ fontSize: 30, fontWeight: 700 }}>{title}</div>
      <Mono size={21} color={color}>{code}</Mono>
    </Card>
  </Reveal>
);

const Arrow: React.FC<{ delay: number }> = ({ delay }) => (
  <Reveal delay={delay} style={{ alignSelf: "center", fontSize: 48, color: theme.violet, fontFamily: theme.fontMono }}>
    &rarr;
  </Reveal>
);

export const Scene04How: React.FC<{ frames: number }> = ({ frames }) => {
  const fade = useSceneFade(frames);
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background accent="violet" />
      <div style={{ position: "absolute", left: 90, top: 70 }}>
        <Reveal>
          <Heading size={64}>Zero Dark Magic</Heading>
          <div style={{ fontFamily: theme.fontSans, fontSize: 30, color: theme.textDim, marginTop: 10 }}>
            It all runs as a normal app.
          </div>
        </Reveal>
      </div>

      <div style={{ position: "absolute", left: 90, right: 90, top: 270, display: "flex", gap: 14 }}>
        <Node delay={s(0.8)} title="A pop-up appears" code="your Mac pauses the app" color={theme.textDim} />
        <Arrow delay={s(1.8)} />
        <Node delay={s(3.4)} title="We watch the activity log" code={'log stream\n  com.apple.TCC'} color={theme.violet} />
        <Arrow delay={s(5.5)} />
        <Node delay={s(7.3)} title="We read its command" code={"sysctl\n KERN_PROCARGS2"} color={theme.amber} />
        <Arrow delay={s(9.4)} />
        <Node delay={s(9.8)} title="We show it beside the pop-up" code="the Ward panel (Fortress HUD)" color={theme.violet} />
      </div>

      <div style={{ position: "absolute", left: 90, right: 90, top: 640 }}>
        <Reveal delay={s(12)}>
          <div style={{ fontFamily: theme.fontSans, fontSize: 30, color: theme.textDim, marginBottom: 18 }}>
            What we never do
          </div>
        </Reveal>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 18 }}>
          {["System hacks (kernel extensions)", "Turn off protections (SIP)", "Special Apple access", "Security bypasses"].map((t, i) => (
            <Reveal key={t} delay={s(13 + i * 0.9)}>
              <Card border={theme.crimson} style={{ textAlign: "center", padding: 22 }}>
                <Badge size={26}>No</Badge>
                <div style={{ fontSize: 30, marginTop: 14 }}>{t}</div>
              </Card>
            </Reveal>
          ))}
        </div>
      </div>
    </AbsoluteFill>
  );
};
