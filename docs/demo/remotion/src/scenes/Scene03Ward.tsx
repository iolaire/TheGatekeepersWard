import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Background } from "../components/Background";
import { ScreenClip } from "../components/ScreenClip";
import { Badge, Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

const s = (sec: number) => Math.round(sec * 30);

const Label: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ fontFamily: theme.fontSans, fontSize: 22, color: theme.textDim, marginBottom: 8, letterSpacing: 1 }}>
    {children}
  </div>
);

export const Scene03Ward: React.FC<{ frames: number }> = ({ frames }) => {
  const frame = useCurrentFrame();
  const fade = useSceneFade(frames);
  // Clip (real recording) first, then the still pair frame takes over once the clip has ended.
  const stillOpacity = interpolate(frame, [s(12.4), s(13.4)], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background />
      <div style={{ position: "absolute", left: 80, top: 56 }}>
        <Reveal>
          <Heading size={52}>With Gatekeeper&rsquo;s Ward</Heading>
          <div style={{ fontFamily: theme.fontMono, fontSize: 24, color: theme.textDim, marginTop: 8 }}>
            real capture &middot; same pop-up, same Mac
          </div>
        </Reveal>
      </div>

      <div style={{ position: "absolute", left: 80, top: 200, width: 1080, height: 760 }}>
        <ScreenClip
          file="ward.mp4"
          clipSeconds={12.4}
          width={1080}
          height={760}
          zoom={1.75}
          focusX={0.54}
          focusY={0.45}
          label="DeepSeek Harness + Gatekeeper's Ward"
        />
        <div
          style={{
            position: "absolute",
            inset: 0,
            opacity: stillOpacity,
            background: theme.obsidianRaised,
            border: `2px solid ${theme.glassBorder}`,
            borderRadius: 18,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Img
            src={staticFile("img/ward-pair.png")}
            style={{ maxWidth: "96%", maxHeight: "96%", borderRadius: 10 }}
          />
        </div>
      </div>

      <div style={{ position: "absolute", right: 70, top: 56, width: 640, display: "grid", gap: 14 }}>
        <Reveal delay={s(5.6)} from="right">
          <Card style={{ padding: 20 }}>
            <Label>WHAT IT WANTS</Label>
            <div style={{ fontSize: 34, color: theme.amber, fontWeight: 700 }}>Your Desktop folder</div>
            <Mono size={18} color={theme.textDim} style={{ marginTop: 10 }}>kTCCServiceSystemPolicyDesktopFolder</Mono>
          </Card>
        </Reveal>
        <Reveal delay={s(8.7)} from="right">
          <Card style={{ padding: 20 }}>
            <Label>WHO STARTED IT, STEP BY STEP</Label>
            <Mono size={22} color={theme.text}>
              DeepSeek Harness (40189){"\n"}
              {"  "}&rarr; DeepSeek Harness (40723){"\n"}
              {"    "}&rarr; bash (45203){"\n"}
              {"      "}&rarr; ls (45204)
            </Mono>
          </Card>
        </Reveal>
        <Reveal delay={s(11.8)} from="right">
          <Card style={{ padding: 20 }}>
            <Label>WHAT IT RUNS, AND WHERE</Label>
            <Mono size={24}>$ ls -1 /Users/iolaire/Desktop</Mono>
            <div style={{ fontFamily: theme.fontMono, fontSize: 20, color: theme.textDim, marginTop: 10 }}>
              cwd: /Volumes/Gold/Vegr&uacute;n
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(18)} from="right">
          <Card style={{ padding: 20 }} border={theme.crimson}>
            <Label>WARNING SIGNS</Label>
            <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
              {[".env", ".pem", "id_rsa", "curl", "base64"].map((t) => (
                <Badge key={t} size={20}>{t}</Badge>
              ))}
            </div>
          </Card>
        </Reveal>
        <Reveal delay={s(22.1)} from="right">
          <Card style={{ padding: 20, boxShadow: `0 0 40px ${theme.violet}55` }} border={theme.violet}>
            <div style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 8 }}>
              <Badge color={theme.violet} size={20}>Informs only</Badge>
              <Badge color={theme.amber} size={20}>Never blocks</Badge>
            </div>
            <div style={{ fontSize: 26, lineHeight: 1.3 }}>
              You still choose <b>Allow</b> or <b>Don&rsquo;t Allow</b> yourself.
            </div>
          </Card>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};
