import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Background } from "../components/Background";
import { Badge, Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

// Seconds into the scene, matched to the narration (see VOICEOVER.md).
const s = (sec: number) => Math.round(sec * 30);

const Label: React.FC<{ children: React.ReactNode; color?: string }> = ({
  children,
  color = theme.textDim,
}) => (
  <div style={{ fontFamily: theme.fontSans, fontSize: 22, color, marginBottom: 12, letterSpacing: 1.5 }}>
    {children}
  </div>
);

export const Scene04aInsight: React.FC<{ frames: number }> = ({ frames }) => {
  const frame = useCurrentFrame();
  const fade = useSceneFade(frames);
  const pulse = interpolate(Math.sin(frame / 9), [-1, 1], [0.5, 1]);
  const bridge = interpolate(frame, [s(22.9), s(24.7)], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background accent="amber" />
      <div style={{ position: "absolute", left: 90, top: 56 }}>
        <Reveal delay={s(0.6)}>
          <Heading size={60}>The insight</Heading>
        </Reveal>
      </div>

      {/* Two worlds */}
      <div style={{ position: "absolute", left: 90, top: 170, width: 720 }}>
        <Reveal delay={s(2)} from="left">
          <Card border={theme.amber}>
            <Label color={theme.amber}>COMMAND LINE &middot; where AI helpers work</Label>
            <Mono size={26} color={theme.text}>
              $ ls -1 ~/Desktop{"\n"}$ rg AWS_SECRET ~/Documents{"\n"}$ curl -d @.env &hellip;
            </Mono>
          </Card>
        </Reveal>
      </div>
      <div style={{ position: "absolute", right: 90, top: 170, width: 720 }}>
        <Reveal delay={s(6.3)} from="right">
          <Card border={theme.violet}>
            <Label color={theme.violet}>THE VISUAL MAC &middot; where you decide</Label>
            <div style={{ fontSize: 28, lineHeight: 1.35 }}>
              &ldquo;DeepSeek Harness&rdquo; would like to access files in your Desktop folder.
            </div>
            <div style={{ display: "flex", gap: 14, marginTop: 16 }}>
              <Mono size={24} color={theme.textDim}>Don&rsquo;t Allow</Mono>
              <Mono size={24} color={theme.text}>Allow</Mono>
            </div>
          </Card>
        </Reveal>
      </div>

      {/* The gap between them */}
      <div
        style={{
          position: "absolute",
          left: 810,
          width: 300,
          top: 230,
          textAlign: "center",
        }}
      >
        <Reveal delay={s(9.2)}>
          <div style={{ opacity: 0.5 + pulse * 0.5 }}>
            <Badge color={theme.crimson} size={26}>Command lost</Badge>
          </div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 64, color: theme.crimson, marginTop: 10 }}>?</div>
        </Reveal>
      </div>

      {/* Two routes across the gap */}
      <div style={{ position: "absolute", left: 90, top: 520, width: 860 }}>
        <Reveal delay={s(11.2)} from="left">
          <Card border={theme.crimson}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Label color={theme.crimson}>THE USUAL ROUTE</Label>
              <Badge color={theme.crimson} size={20}>Heavy</Badge>
            </div>
            <div style={{ fontSize: 30, lineHeight: 1.5 }}>
              Apple&rsquo;s restricted security tools<br />
              Special Apple permission<br />
              A system-level add-on
            </div>
            <div style={{ fontSize: 24, color: theme.textDim, marginTop: 10 }}>
              And a quick command is gone before anyone can look.
            </div>
          </Card>
        </Reveal>
      </div>
      <div style={{ position: "absolute", right: 90, top: 520, width: 860 }}>
        <Reveal delay={s(17.4)} from="right">
          <Card border={theme.violet} style={{ boxShadow: `0 0 ${50 * pulse}px ${theme.violet}66` }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Label color={theme.violet}>OUR ROUTE</Label>
              <Badge color={theme.amber} size={20}>App paused</Badge>
            </div>
            <div style={{ fontSize: 30, lineHeight: 1.5 }}>
              A pop-up opens. Your Mac <b style={{ color: theme.amber }}>pauses the app</b> that asked.
            </div>
            <Mono size={24} color={theme.violet} style={{ marginTop: 12 }}>
              the command, who started it, and where: read live
            </Mono>
          </Card>
        </Reveal>
      </div>

      {/* Payoff */}
      <div
        style={{
          position: "absolute",
          left: 90,
          right: 90,
          bottom: 70,
          textAlign: "center",
          opacity: bridge,
          transform: `translateY(${(1 - bridge) * 20}px)`,
        }}
      >
        <div
          style={{
            display: "inline-block",
            fontFamily: theme.fontSans,
            fontWeight: 800,
            fontSize: 50,
            color: theme.amber,
            background: "rgba(14,16,19,0.88)",
            border: `1.5px solid ${theme.amber}`,
            borderRadius: 16,
            padding: "14px 36px",
            boxShadow: `0 0 40px ${theme.amber}44`,
          }}
        >
          The command line, inside the visual Mac.
        </div>
      </div>
    </AbsoluteFill>
  );
};
