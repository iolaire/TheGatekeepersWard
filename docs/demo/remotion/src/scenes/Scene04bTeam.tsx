import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { Background } from "../components/Background";
import { Badge, Card, Heading, Mono, Reveal, useSceneFade } from "../components/ui";
import { theme } from "../theme";

// Seconds into the scene, matched to the narration (see VOICEOVER.md).
const s = (sec: number) => Math.round(sec * 30);

const Person: React.FC<{
  photo: string;
  name: string;
  place: string;
  role: string;
  linkedin: string;
  built: string;
  delay: number;
  builtDelay: number;
  color: string;
}> = ({ photo, name, place, role, linkedin, built, delay, builtDelay, color }) => (
  <div style={{ width: 800 }}>
    <Reveal delay={delay}>
      <Card border={color} style={{ display: "flex", gap: 28, alignItems: "center", padding: 30 }}>
        <Img
          src={staticFile(photo)}
          style={{
            width: 190,
            height: 190,
            borderRadius: "50%",
            objectFit: "cover",
            border: `4px solid ${color}`,
            boxShadow: `0 0 36px ${color}77`,
            flexShrink: 0,
          }}
        />
        <div>
          <div style={{ fontSize: 42, fontWeight: 800, letterSpacing: -0.5 }}>{name}</div>
          <div style={{ fontSize: 26, color: theme.amber, marginTop: 6 }}>{place}</div>
          <div style={{ fontSize: 26, color: theme.text, marginTop: 10, lineHeight: 1.3 }}>{role}</div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 18, color: theme.textDim, marginTop: 12 }}>
            {linkedin}
          </div>
        </div>
      </Card>
    </Reveal>
    <Reveal delay={builtDelay} style={{ marginTop: 18 }}>
      <Card border={color} style={{ padding: 22 }}>
        <div style={{ fontSize: 20, color: theme.textDim, letterSpacing: 1.5, marginBottom: 8 }}>BUILT</div>
        <div style={{ fontSize: 28, lineHeight: 1.35 }}>{built}</div>
      </Card>
    </Reveal>
  </div>
);

export const Scene04bTeam: React.FC<{ frames: number }> = ({ frames }) => {
  const fade = useSceneFade(frames);
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Background accent="violet" />
      <div style={{ position: "absolute", left: 90, top: 56 }}>
        <Reveal delay={s(0.6)}>
          <Heading size={60}>Two builders, two time zones</Heading>
        </Reveal>
      </div>

      <div style={{ position: "absolute", left: 90, top: 190 }}>
        <Person
          photo="img/team-dharshaneshwaran.jpg"
          name="Dharshaneshwaran D"
          place="Bengaluru, India"
          role="AI, IoT and creative technology developer. 2D and 3D artist."
          linkedin="linkedin.com/in/dharshaneshwaran"
          built="The first working app: menu bar, permission watcher, process inspector and the Ward panel."
          delay={s(3.5)}
          builtDelay={s(12.3)}
          color={theme.violet}
        />
      </div>
      <div style={{ position: "absolute", right: 90, top: 190 }}>
        <Person
          photo="img/team-iolaire.jpg"
          name="Iolaire McFadden"
          place="Arlington, Virginia, USA"
          role="Former Director of Data Science. Now builds with AI-assisted coding tools."
          linkedin="linkedin.com/in/iolaire-mcfadden-240484"
          built="The tests, the real-device captures, and this demo video."
          delay={s(8.1)}
          builtDelay={s(14.3)}
          color={theme.amber}
        />
      </div>

      <Reveal
        delay={s(17)}
        style={{ position: "absolute", left: 0, right: 0, bottom: 70, textAlign: "center" }}
      >
        <div
          style={{
            display: "inline-flex",
            gap: 18,
            alignItems: "center",
            background: "rgba(14,16,19,0.88)",
            border: `1.5px solid ${theme.glassBorder}`,
            borderRadius: 16,
            padding: "14px 34px",
          }}
        >
          <Badge color={theme.violet} size={22}>Paired with Kiro</Badge>
          <span style={{ fontFamily: theme.fontSans, fontSize: 32, color: theme.text }}>
            Specs first, then code.
          </span>
        </div>
      </Reveal>
    </AbsoluteFill>
  );
};
