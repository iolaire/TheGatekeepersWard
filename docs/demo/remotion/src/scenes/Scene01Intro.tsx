import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Background } from "../components/Background";
import { Badge, Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

const s = (sec: number) => Math.round(sec * 30);

export const Scene01Intro: React.FC<{ frames: number }> = ({ frames }) => {
  const frame = useCurrentFrame();
  const fade = useSceneFade(frames);
  const float = Math.sin(frame / 18) * 10;
  const glow = interpolate(Math.sin(frame / 14), [-1, 1], [0.4, 0.9]);
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background />
      {/* Left: title */}
      <div style={{ position: "absolute", left: 110, top: 150, width: 820 }}>
        <Reveal>
          <Img
            src={staticFile("img/solo_spirit.svg")}
            style={{
              width: 190,
              height: 214,
              transform: `translateY(${float}px)`,
              filter: `drop-shadow(0 0 ${30 * glow}px ${theme.violet})`,
            }}
          />
        </Reveal>
        <Reveal delay={8} style={{ marginTop: 28 }}>
          <Heading size={92}>Gatekeeper&rsquo;s Ward</Heading>
        </Reveal>
        <Reveal delay={20} style={{ marginTop: 22 }}>
          <div style={{ fontFamily: theme.fontSans, fontSize: 38, color: theme.amber }}>
            Know who knocks before you drop the castle gates.
          </div>
        </Reveal>
        <Reveal delay={30} style={{ marginTop: 30 }}>
          <Badge color={theme.violet}>Kiroween 2026</Badge>
        </Reveal>
      </div>

      {/* Right: the problem, revealed in step with the narration */}
      <div style={{ position: "absolute", right: 110, top: 120, width: 800, display: "grid", gap: 22 }}>
        <Reveal delay={s(3.8)} from="right">
          <Card border={theme.crimson}>
            <div style={{ fontSize: 30, lineHeight: 1.35 }}>
              &ldquo;Some App&rdquo; would like to access files in your Desktop folder.
            </div>
            <div style={{ display: "flex", gap: 14, marginTop: 18 }}>
              <Mono size={26} color={theme.textDim}>Don&rsquo;t Allow</Mono>
              <Mono size={26} color={theme.text}>Allow</Mono>
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(7.1)} from="right">
          <Card border={theme.crimson}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <span style={{ fontSize: 30 }}>What is it about to do?</span>
              <Badge color={theme.crimson}>Unknown</Badge>
            </div>
            <Mono size={26} color={theme.crimson} style={{ marginTop: 14 }}>
              $ ???
            </Mono>
            <div style={{ fontSize: 26, color: theme.textDim, marginTop: 14 }}>
              One blind click can expose Desktop, Documents, Contacts, Camera.
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(17.8)} from="right">
          <Card border={theme.amber}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <span style={{ fontSize: 28 }}>Apple: better controls are coming</span>
              <Badge color={theme.amber}>Still in beta</Badge>
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(22.4)} from="right">
          <Card border={theme.violet} style={{ boxShadow: `0 0 50px ${theme.violet}55` }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <span style={{ fontSize: 28 }}>Gatekeeper&rsquo;s Ward fills the gap</span>
              <Badge color={theme.violet}>Today</Badge>
            </div>
          </Card>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};
