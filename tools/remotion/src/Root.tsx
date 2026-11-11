import React from 'react';
import { Composition, Still } from 'remotion';
import { Intro, INTRO_FRAMES } from './Intro';
import { Intro19, INTRO19_FRAMES } from './Intro19';
import { Intro20, INTRO20_FRAMES } from './Intro20';
import { EventArt, EventKind } from './Events';
import { Short, ShortKind, shortFrames } from './Shorts';

// 縦 1080×1920・30fps。言語は --props '{"lang":"en"}' で切り替える
export const Root: React.FC = () => (
  <>
  <Composition
    id="Intro"
    component={Intro}
    durationInFrames={INTRO_FRAMES}
    fps={30}
    width={1080}
    height={1920}
    defaultProps={{ lang: 'ja' as const }}
  />
  <Composition
    id="Intro19"
    component={Intro19}
    durationInFrames={INTRO19_FRAMES}
    fps={30}
    width={1080}
    height={1920}
    defaultProps={{ lang: 'ja' as const }}
  />
  <Composition
    id="Intro20"
    component={Intro20}
    durationInFrames={INTRO20_FRAMES}
    fps={30}
    width={1080}
    height={1920}
    defaultProps={{ lang: 'ja' as const }}
  />
  {/* ショート動画（縦・10〜13秒）。日本語だけ */}
  {(['timelapse', 'mosaic', 'year'] as ShortKind[]).map((kind) => (
    <Composition key={kind} id={`Short-${kind}`} component={Short} durationInFrames={shortFrames(kind)} fps={30} width={1080} height={1920} defaultProps={{ kind }} />
  ))}
  {/* App 内イベントの画像：--props '{"kind":"kyotsu"}' */}
  <Still id="EventCard" component={EventArt} width={1920} height={1080} defaultProps={{ kind: 'kimatsu' as EventKind }} />
  <Still id="EventDetail" component={EventArt} width={1080} height={1920} defaultProps={{ kind: 'kimatsu' as EventKind, portrait: true }} />
  </>
);
