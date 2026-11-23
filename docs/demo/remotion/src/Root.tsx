import React from "react";
import { Composition } from "remotion";
import { totalFrames } from "./audioConfig";
import { Main } from "./Main";
import { FPS, HEIGHT, SPLASH_FRAMES, WIDTH } from "./theme";

export const Root: React.FC = () => (
  <Composition
    id="GatekeepersWardDemo"
    component={Main}
    durationInFrames={totalFrames + SPLASH_FRAMES}
    fps={FPS}
    width={WIDTH}
    height={HEIGHT}
  />
);
