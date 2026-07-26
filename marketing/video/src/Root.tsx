import React from 'react';
import {Composition} from 'remotion';
import {WatchdogPreview} from './Video';

export const RemotionRoot: React.FC = () => (
  <Composition
    id="WatchdogPreview"
    component={WatchdogPreview}
    durationInFrames={720}
    fps={30}
    width={1920}
    height={1080}
  />
);
