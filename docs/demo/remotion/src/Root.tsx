import React from "react";
import { Composition } from "remotion";
import { totalFrames } from "./audioConfig";
import { Main } from "./Main";
import { FPS, HEIGHT, WIDTH } from "./theme";

export const Root: React.FC = () => (
  <Composition
    id="GatekeepersWardDemo"
    component={Main}
    durationInFrames={totalFrames}
    fps={FPS}
    width={WIDTH}
    height={HEIGHT}
  />
);
