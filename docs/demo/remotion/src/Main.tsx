import React from "react";
import { Audio, Sequence } from "remotion";
import { NARRATION_MODE, sceneTimings } from "./audioConfig";
import { Scene01Intro } from "./scenes/Scene01Intro";
import { Scene02Baseline } from "./scenes/Scene02Baseline";
import { Scene03Ward } from "./scenes/Scene03Ward";
import { Scene04How } from "./scenes/Scene04How";
import { Scene05Outro } from "./scenes/Scene05Outro";

const scenes: Record<string, React.FC<{ frames: number }>> = {
  "scene-01-intro": Scene01Intro,
  "scene-02-baseline": Scene02Baseline,
  "scene-03-ward": Scene03Ward,
  "scene-04-how": Scene04How,
  "scene-05-outro": Scene05Outro,
};

export const Main: React.FC = () => {
  let from = 0;
  return (
    <>
      {sceneTimings.map((t) => {
        const Scene = scenes[t.id];
        const start = from;
        from += t.frames;
        const voiceFrames = Math.ceil(t.voiceSeconds * 30);
        return (
          <Sequence key={t.id} from={start} durationInFrames={t.frames} name={t.id}>
            <Scene frames={t.frames} />
            <Sequence from={t.leadFrames} durationInFrames={voiceFrames} name={`${t.id} audio (${NARRATION_MODE})`}>
              <Audio
                src={t.audioSrc}
                startFrom={t.audioStartFromFrames}
                endAt={t.audioStartFromFrames + voiceFrames}
              />
            </Sequence>
          </Sequence>
        );
      })}
    </>
  );
};
