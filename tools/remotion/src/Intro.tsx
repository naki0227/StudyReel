// StudyReel の紹介 PV（1.8 時点）。アプリを知らない人に「何ができるアプリか」を、最初に目次で見せてから順に紹介する
import React from 'react';
import { AbsoluteFill, Audio, Img, OffthreadVideo, Sequence, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { TransitionSeries, springTiming } from '@remotion/transitions';
import { fade } from '@remotion/transitions/fade';
import { slide } from '@remotion/transitions/slide';
import { C, Chip, F, Fonts, Grid, Phone, Section, Sub, Tape, Title, useSpring } from './ui';
import { COPY, Lang, screen } from './copy';

type P = { lang: Lang };

// 場面の長さ（フレーム）と、つなぎ目の重なり
const DUR = [165, 150, 135, 150, 150, 135, 120, 120];
const T = 14;
export const INTRO_FRAMES = DUR.reduce((a, b) => a + b, 0) - T * (DUR.length - 1);
const START = DUR.map((_, i) => DUR.slice(0, i).reduce((a, b) => a + b, 0) - i * T);
// 場面 → 目次の何番目か（0 は目次、7 は終わり）
const SECTION_OF = [0, 1, 1, 2, 3, 4, 4, 0];

const VIDEO = 'assets/study-timelapse.mp4';
const VIDEO_MOSAIC = 'assets/study-timelapse-mosaic.mp4';
const timing = springTiming({ config: { damping: 200 }, durationInFrames: T });
const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;

const titleProps = (lang: Lang) => (lang === 'en' ? { font: F.corm, size: 92 } : { font: F.mincho, size: 76 });

// 上の見出しのかたまり（札・見出し・説明）
const Caption: React.FC<{ lang: Lang; no: number; lines: string[]; sub: string; isNew?: boolean; dark?: boolean }> = ({ lang, no, lines, sub, isNew, dark }) => (
  <div style={{ position: 'absolute', left: 0, right: 0, top: 130 }}>
    <Section no={no} text={COPY[lang].sec[no - 1]} isNew={isNew} delay={4} dark={dark} />
    <div style={{ height: 26 }} />
    <Title lines={lines} delay={8} {...titleProps(lang)} color={dark ? '#fff' : C.ink} shadow={dark} />
    <Sub text={sub} delay={20} color={dark ? 'rgba(255,255,255,.92)' : C.sub} />
  </div>
);

// 画面が下からばねで上がってくる
const Rise: React.FC<{ delay?: number; top?: number; children: React.ReactNode; tilt?: number }> = ({ delay = 6, top = 600, children, tilt = 0 }) => {
  const s = useSpring(delay, { damping: 18, stiffness: 90 });
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top, display: 'flex', justifyContent: 'center',
      transform: `translateY(${(1 - s) * 500}px) rotate(${(1 - s) * tilt}deg)`, opacity: Math.min(1, s * 2) }}>
      {children}
    </div>
  );
};

// 0: 目次
const Agenda: React.FC<P> = ({ lang }) => {
  const c = COPY[lang];
  const frame = useCurrentFrame();
  const head = useSpring(2);
  const logo = useSpring(8);
  const can = useSpring(18);
  return (
    <AbsoluteFill>
      <div style={{ position: 'absolute', top: 400, left: 0, right: 0, textAlign: 'center', fontFamily: F.zen, fontSize: 38, color: C.sub, letterSpacing: '.14em', opacity: head, transform: `translateY(${(1 - head) * 20}px)` }}>{c.kind}</div>
      <Tape color={C.tapeYellow} style={{ left: 465, top: 470, transform: `rotate(-6deg) scaleX(${logo})` }} />
      <div style={{ position: 'absolute', top: 500, left: 0, right: 0, textAlign: 'center', fontFamily: F.mincho, fontSize: 140, color: C.ink, opacity: logo, transform: `translateY(${(1 - logo) * 40}px)` }}>StudyReel</div>
      <div style={{ position: 'absolute', top: 710, left: 0, right: 0, textAlign: 'center', fontFamily: lang === 'en' ? F.corm : F.mincho, fontSize: lang === 'en' ? 72 : 62, color: C.ink, letterSpacing: '.06em', opacity: can }}>{c.can}</div>
      <div style={{ position: 'absolute', top: 880, left: 120, right: 120 }}>
        {c.agenda.map((text, i) => (
          <AgendaRow key={i} no={i + 1} text={text} isNew={i === 2} delay={34 + i * 12} lang={lang} lit={frame > 132 && i === 0} />
        ))}
      </div>
    </AbsoluteFill>
  );
};

const AgendaRow: React.FC<{ no: number; text: string; isNew: boolean; delay: number; lang: Lang; lit: boolean }> = ({ no, text, isNew, delay, lang, lit }) => {
  const s = useSpring(delay, { damping: 14 });
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 30, background: '#fff', borderRadius: 30, padding: '30px 40px', marginBottom: 24,
      boxShadow: lit ? `0 0 0 4px ${C.deep}, 0 18px 40px rgba(46,58,70,.14)` : '0 14px 34px rgba(46,58,70,.10)',
      transform: `translateX(${(1 - s) * -80}px)`, opacity: s,
    }}>
      <span style={{ width: 64, height: 64, flex: 'none', borderRadius: '50%', background: C.soft, color: C.deep, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: F.corm, fontSize: 44 }}>{no}</span>
      <span style={{ fontFamily: lang === 'en' ? F.zenR : F.zen, fontSize: 40, color: C.ink }}>{text}</span>
      {isNew ? <span style={{ marginLeft: 'auto', fontFamily: F.corm, fontSize: 26, letterSpacing: '.18em', color: '#fff', background: C.deep, borderRadius: 999, padding: '4px 16px' }}>NEW</span> : null}
    </div>
  );
};

// 1: 録画（タイムラプスの動画を、録画中の画面として見せる）
const Record: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].rec;
  const frame = useCurrentFrame();
  const sec = interpolate(frame, [10, DUR[1]], [0, 5 * 3600], clamp);
  const pad = (n: number) => String(Math.floor(n)).padStart(2, '0');
  const blink = Math.floor(frame / 15) % 2 === 0;
  const badge = useSpring(40);
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={1} lines={c.t} sub={c.s} />
      <Rise top={620} tilt={-5}>
        <Phone>
          <OffthreadVideo src={staticFile(VIDEO)} muted playbackRate={1.45} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          <div style={{ position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 24px', borderRadius: 14, background: 'rgba(40,36,32,.55)', backdropFilter: 'blur(14px)', color: '#fff', fontFamily: F.zen, fontSize: 34 }}>
              <span style={{ width: 14, height: 14, borderRadius: '50%', background: C.red, opacity: blink ? 1 : 0.25 }} />
              {`${Math.floor(sec / 3600)}:${pad((sec % 3600) / 60)}:${pad(sec % 60)}`}
            </div>
          </div>
          <div style={{ position: 'absolute', bottom: 70, left: '50%', marginLeft: -62, width: 124, height: 124, borderRadius: '50%', border: '8px solid rgba(255,255,255,.92)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ width: 46, height: 46, borderRadius: 10, background: C.red }} />
          </div>
        </Phone>
      </Rise>
      <Chip style={{ right: 60, top: 1020, transform: `scale(${badge}) rotate(4deg)`, opacity: badge }}>⏩ {c.speed}</Chip>
    </AbsoluteFill>
  );
};

// 2: モザイク（線が横切って、そのまま → モザイクに変わる）
const Mosaic: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].mosaic;
  const frame = useCurrentFrame();
  const enter = useSpring(4, { damping: 18 });
  const x = interpolate(frame, [36, 70], [100, 0], { ...clamp, easing: (p) => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2) });
  const W = 640, H = W * 1920 / 1080;
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={1} lines={c.t} sub={c.s} />
      <div style={{ position: 'absolute', left: (1080 - W - 44) / 2, top: 600, background: '#fff', padding: '22px 22px 80px', boxShadow: '0 30px 70px rgba(46,58,70,.24)',
        transform: `translateY(${(1 - enter) * 300}px) rotate(${-2 + (1 - enter) * -4}deg)`, opacity: enter }}>
        <Tape color={C.tapePink} style={{ left: W / 2 - 50, top: -22, transform: 'rotate(-4deg)' }} />
        <div style={{ position: 'relative', width: W, height: H, overflow: 'hidden' }}>
          <OffthreadVideo src={staticFile(VIDEO)} muted startFrom={20} style={{ position: 'absolute', width: '100%', height: '100%', objectFit: 'cover' }} />
          <div style={{ position: 'absolute', inset: 0, clipPath: `inset(0 0 0 ${x}%)` }}>
            <OffthreadVideo src={staticFile(VIDEO_MOSAIC)} muted startFrom={20} style={{ position: 'absolute', width: '100%', height: '100%', objectFit: 'cover' }} />
          </div>
          {x > 0 && x < 100 ? <div style={{ position: 'absolute', top: 0, bottom: 0, left: `${x}%`, width: 6, marginLeft: -3, background: '#fff', boxShadow: '0 0 20px rgba(0,0,0,.35)' }} /> : null}
        </div>
        <div style={{ position: 'absolute', left: 30, bottom: 22, fontFamily: F.cormI, fontSize: 36, color: C.ink }}>Tue 10/14 · 2h 25m</div>
        <div style={{ position: 'absolute', right: 30, bottom: 20, fontFamily: F.zen, fontSize: 30, color: '#fff', background: x < 50 ? C.deep : C.sub, borderRadius: 999, padding: '6px 20px' }}>{x < 50 ? c.after : c.before}</div>
      </div>
    </AbsoluteFill>
  );
};

// 3: 目標（ホームの D-day のところに寄って、点数アップのカードを出す）
const Goal: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].goal;
  const frame = useCurrentFrame();
  const zoom = interpolate(frame, [34, 70], [1, 1.32], { ...clamp, easing: (p) => 1 - Math.pow(1 - p, 3) });
  const card = useSpring(78, { damping: 13 });
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={2} lines={c.t} sub={c.s} />
      <Rise top={640}>
        <div style={{ transform: `scale(${zoom})`, transformOrigin: '50% 12%' }}>
          <Phone><Img src={staticFile(screen(lang, 'home18-photo.png'))} style={{ width: '100%' }} /></Phone>
        </div>
      </Rise>
      <div style={{ position: 'absolute', right: 50, top: 1180, width: 420, borderRadius: 30, overflow: 'hidden', boxShadow: '0 30px 70px rgba(46,58,70,.3)',
        transform: `translateY(${(1 - card) * 200}px) rotate(${6 - (1 - card) * 10}deg) scale(${0.7 + card * 0.3})`, opacity: Math.min(1, card * 1.5) }}>
        <Img src={staticFile(screen(lang, 'card-scoreup.png'))} style={{ width: '100%', display: 'block' }} />
      </div>
    </AbsoluteFill>
  );
};

// 4: 勉強仲間（スタンプが飛んでくる）
const Buddies: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].buddies;
  const frame = useCurrentFrame();
  const spots = [{ left: 40, top: 980, rot: -4 }, { left: 600, top: 1260, rot: 3 }, { left: 70, top: 1600, rot: -2 }];
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={3} lines={c.t} sub={c.s} isNew />
      <Rise top={640}><Phone><Img src={staticFile(screen(lang, 'buddies.png'))} style={{ width: '100%' }} /></Phone></Rise>
      {c.stamps.map((text, i) => <Stamp key={i} text={text} from={c.from[i]} delay={44 + i * 16} {...spots[i]} wobble={Math.sin((frame - i * 10) / 9) * 6} />)}
    </AbsoluteFill>
  );
};

const Stamp: React.FC<{ text: string; from?: string; delay: number; left: number; top: number; rot: number; wobble: number }> = ({ text, from, delay, left, top, rot, wobble }) => {
  const s = useSpring(delay, { damping: 10, stiffness: 160 });
  return (
    <Chip style={{ left, top: top + wobble, transform: `scale(${s}) rotate(${rot}deg)`, opacity: Math.min(1, s * 2) }}>
      {text}{from ? <span style={{ fontFamily: F.cormI, fontSize: 30, color: C.sub }}>from {from}</span> : null}
    </Chip>
  );
};

// 5: Vlog（1週間ぶんを速いカットで → ぼかした映像の上に Vlog の画面）
const Vlog: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].vlog;
  const frame = useCurrentFrame();
  const CUT = 9;
  const starts = [10, 60, 100, 130, 170, 195];
  const days = [['Mon 10/13', '2h 25m'], ['Tue 10/14', '1h 50m'], ['Wed 10/15', '3h 05m'], ['Thu 10/16', '2h 10m'], ['Fri 10/17', '1h 35m'], ['Sat 10/18', '4h 20m']];
  const cutsEnd = CUT * starts.length;
  const k = Math.min(starts.length - 1, Math.floor(frame / CUT));
  const blur = interpolate(frame, [cutsEnd - 4, cutsEnd + 10], [0, 22], clamp);
  return (
    <AbsoluteFill style={{ background: '#000' }}>
      {starts.map((st, i) => (
        <Sequence key={i} from={i * CUT} durationInFrames={i === starts.length - 1 ? DUR[5] : CUT} layout="none">
          <AbsoluteFill style={{ filter: `blur(${blur}px) brightness(${1 - blur / 60})`, transform: `scale(${1.04 + blur / 300})` }}>
            <OffthreadVideo src={staticFile(VIDEO)} muted startFrom={st} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          </AbsoluteFill>
        </Sequence>
      ))}
      <AbsoluteFill style={{ background: 'linear-gradient(rgba(20,26,32,.6), rgba(20,26,32,0) 45%)' }} />
      {frame < cutsEnd ? (
        <div style={{ position: 'absolute', left: 70, bottom: 150, color: '#fff', textShadow: '0 2px 18px rgba(0,0,0,.45)' }}>
          <div style={{ fontFamily: F.cormI, fontSize: 70 }}>{days[k][0]}</div>
          <div style={{ fontFamily: F.zen, fontSize: 36, opacity: 0.9 }}>{days[k][1]}</div>
        </div>
      ) : null}
      <Caption lang={lang} no={4} lines={c.t} sub={c.s} dark />
      <Rise top={680} delay={cutsEnd}><Phone width={600}><Img src={staticFile(screen(lang, 'vlog-photo.png'))} style={{ width: '100%' }} /></Phone></Rise>
    </AbsoluteFill>
  );
};

// 6: 共有（カードの画面と、ハッシュタグ）
const Share: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].share;
  const frame = useCurrentFrame();
  const tags = [{ text: c.tag, left: 50, top: 900, rot: -5 }, { text: '#studywithme', left: 700, top: 1100, rot: 4 }, { text: '#StudyReel', left: 80, top: 1580, rot: -3 }];
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={4} lines={c.t} sub={c.s} />
      <Rise top={640}><Phone><Img src={staticFile(screen(lang, 'share-photo.png'))} style={{ width: '100%' }} /></Phone></Rise>
      {tags.map((t, i) => <Stamp key={i} text={t.text} delay={36 + i * 10} left={t.left} top={t.top} rot={t.rot} wobble={Math.sin((frame - i * 8) / 10) * 6} />)}
    </AbsoluteFill>
  );
};

// 7: 終わり
const End: React.FC<P> = ({ lang }) => {
  const c = COPY[lang].end;
  const frame = useCurrentFrame();
  const logo = useSpring(4);
  const kind = useSpring(12);
  const btn = useSpring(22, { damping: 10 });
  const pulse = 1 + Math.max(0, Math.sin((frame - 40) / 8)) * 0.03 * (frame > 40 ? 1 : 0);
  return (
    <AbsoluteFill>
      <Tape style={{ left: 465, top: 600, transform: `rotate(5deg) scaleX(${logo})` }} />
      <div style={{ position: 'absolute', top: 630, left: 0, right: 0, textAlign: 'center', fontFamily: F.mincho, fontSize: 140, color: C.ink, opacity: logo, transform: `translateY(${(1 - logo) * 40}px)` }}>StudyReel</div>
      <div style={{ position: 'absolute', top: 830, left: 0, right: 0, textAlign: 'center', fontFamily: F.zen, fontSize: 40, color: C.sub, letterSpacing: '.14em', opacity: kind }}>{c.kind}</div>
      <div style={{ position: 'absolute', top: 960, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <div style={{ fontFamily: F.zen, fontSize: 40, color: '#fff', background: C.deep, borderRadius: 999, padding: '26px 64px', transform: `scale(${btn * pulse})`, opacity: Math.min(1, btn * 2), boxShadow: '0 18px 40px rgba(94,141,184,.35)' }}>{c.store}</div>
      </div>
      <div style={{ position: 'absolute', top: 1110, left: 0, right: 0, textAlign: 'center', fontFamily: F.zenR, fontSize: 30, color: C.sub, opacity: kind }}>iPhone / iPad</div>
      <div style={{ position: 'absolute', top: 1220, left: 120, right: 120, display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 18 }}>
        {c.points.map((p, i) => <Point key={i} text={p} delay={34 + i * 6} />)}
      </div>
    </AbsoluteFill>
  );
};

const Point: React.FC<{ text: string; delay: number }> = ({ text, delay }) => {
  const s = useSpring(delay);
  return <span style={{ fontFamily: F.zen, fontSize: 32, color: C.deep, background: C.soft, borderRadius: 999, padding: '12px 28px', opacity: s, transform: `translateY(${(1 - s) * 16}px)` }}>{text}</span>;
};

// 上の細い4つの目盛り。いま目次の何番目かを示す
const Progress: React.FC = () => {
  const frame = useCurrentFrame();
  const scene = START.reduce((acc, st, i) => (frame >= st + T / 2 ? i : acc), 0);
  const sec = SECTION_OF[scene];
  const o = interpolate(frame, [START[1], START[1] + 10, START[7] - 4, START[7] + 6], [0, 1, 1, 0], clamp);
  return (
    <div style={{ position: 'absolute', top: 60, left: 300, right: 300, display: 'flex', gap: 14, opacity: o }}>
      {[1, 2, 3, 4].map((n) => <div key={n} style={{ flex: 1, height: 8, borderRadius: 999, background: n <= sec ? C.deep : 'rgba(94,141,184,.2)' }} />)}
    </div>
  );
};

export const Intro: React.FC<P> = ({ lang }) => {
  const scenes = [Agenda, Record, Mosaic, Goal, Buddies, Vlog, Share, End];
  const transitions = [fade(), slide({ direction: 'from-right' }), fade(), slide({ direction: 'from-right' }), fade(), slide({ direction: 'from-bottom' }), slide({ direction: 'from-bottom' })];
  return (
    <AbsoluteFill style={{ background: C.paper }}>
      <Fonts />
      <Grid />
      <TransitionSeries>
        {scenes.map((Scene, i) => (
          <React.Fragment key={i}>
            <TransitionSeries.Sequence durationInFrames={DUR[i]}>
              <Scene lang={lang} />
            </TransitionSeries.Sequence>
            {i < scenes.length - 1 ? <TransitionSeries.Transition presentation={transitions[i]} timing={timing} /> : null}
          </React.Fragment>
        ))}
      </TransitionSeries>
      <Progress />
      <Audio src={staticFile('out/bgm-lofi.m4a')} volume={(f) => interpolate(f, [0, 15, INTRO_FRAMES - 45, INTRO_FRAMES], [0, 1, 1, 0], clamp)} />
    </AbsoluteFill>
  );
};
