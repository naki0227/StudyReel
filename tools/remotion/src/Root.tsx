import React from 'react';
import { Composition } from 'remotion';
import { Intro, INTRO_FRAMES } from './Intro';

// 縦 1080×1920・30fps。言語は --props '{"lang":"en"}' で切り替える
export const Root: React.FC = () => (
  <Composition
    id="Intro"
    component={Intro}
    durationInFrames={INTRO_FRAMES}
    fps={30}
    width={1080}
    height={1920}
    defaultProps={{ lang: 'ja' as const }}
  />
);
