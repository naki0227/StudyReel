// StudyReel のアプリ紹介 PV（2.0 時点）。アップデートの紹介ではなく、はじめて見る人向け（NEW の札は付けない）。
// 顔を隠して撮る → 休憩つきの集中 → 編集と時刻の飾り → クエストとジェム → 1年の草。画面は Remotion の中で描く（アプリと同じ色と形）
// Intro19 の場面を土台にしている（Intro19 は 1.9 の紹介としてそのまま残す）
import React from 'react';
import { AbsoluteFill, Audio, Img, OffthreadVideo, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { TransitionSeries, springTiming } from '@remotion/transitions';
import { fade } from '@remotion/transitions/fade';
import { slide } from '@remotion/transitions/slide';
import { C, Chip, F, Fonts, Grid, Phone, Sub, Tape, Title, useSpring } from './ui';
import type { Lang } from './copy';
import { COPY20 } from './copy20';

type P = { lang: Lang };

const DUR = [165, 150, 165, 165, 165, 150, 120];
const T = 14;
export const INTRO20_FRAMES = DUR.reduce((a, b) => a + b, 0) - T * (DUR.length - 1);
const START = DUR.map((_, i) => DUR.slice(0, i).reduce((a, b) => a + b, 0) - i * T);

const VIDEO = 'assets/study-timelapse.mp4';
const VIDEO_MOSAIC = 'assets/study-timelapse-mosaic.mp4';
const timing = springTiming({ config: { damping: 200 }, durationInFrames: T });
const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
const easeOut = (p: number) => 1 - Math.pow(1 - p, 3);

const titleProps = (lang: Lang) => (lang === 'en' ? { font: F.corm, size: 90 } : { font: F.mincho, size: 76 });

// 「1　顔を隠して撮る」の札（NEW つき）
const Badge: React.FC<{ no: number; text: string; isNew?: boolean; delay?: number; dark?: boolean }> = ({ no, text, isNew, delay = 0, dark }) => {
  const s = useSpring(delay);
  return (
    <div style={{ display: 'flex', justifyContent: 'center', transform: `translateY(${(1 - s) * 20}px)`, opacity: s }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '10px 28px 10px 12px', borderRadius: 999,
        background: dark ? 'rgba(255,255,255,.92)' : C.soft, fontFamily: F.zen, fontSize: 30, color: C.deep, letterSpacing: '.04em' }}>
        <span style={{ width: 46, height: 46, borderRadius: '50%', background: C.deep, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: F.corm, fontSize: 32 }}>{no}</span>
        {text}
        {isNew ? <span style={{ fontFamily: F.corm, fontSize: 24, letterSpacing: '.18em', color: '#fff', background: C.deep, borderRadius: 999, padding: '2px 14px' }}>NEW</span> : null}
      </div>
    </div>
  );
};

const Caption: React.FC<{ lang: Lang; no: number; lines: string[]; sub: string; isNew?: boolean }> = ({ lang, no, lines, sub, isNew }) => (
  <div style={{ position: 'absolute', left: 0, right: 0, top: 130 }}>
    <Badge no={no} text={COPY20[lang].sec[no - 1]} isNew={isNew} delay={4} />
    <div style={{ height: 26 }} />
    <Title lines={lines} delay={8} {...titleProps(lang)} />
    <Sub text={sub} delay={20} />
  </div>
);

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
  const c = COPY20[lang];
  const frame = useCurrentFrame();
  // 名前は最初のコマから出しておく（投稿のサムネイルが白くならないように）
  const head = useSpring(-30);
  return (
    <AbsoluteFill>
      <div style={{ position: 'absolute', top: 300, left: 0, right: 0, textAlign: 'center', fontFamily: F.zen, fontSize: 38, color: C.sub, letterSpacing: '.14em', opacity: head }}>{c.kind}</div>
      <Tape color={C.tapeYellow} style={{ left: 465, top: 370, transform: `rotate(-6deg) scaleX(${head})` }} />
      <div style={{ position: 'absolute', top: 400, left: 0, right: 0, textAlign: 'center', fontFamily: F.mincho, fontSize: 140, color: C.ink, opacity: head }}>StudyReel</div>
      <div style={{ position: 'absolute', top: 610, left: 0, right: 0, textAlign: 'center', fontFamily: lang === 'en' ? F.corm : F.mincho, fontSize: lang === 'en' ? 72 : 62, color: C.ink, letterSpacing: '.06em', opacity: head }}>{c.can}</div>
      <div style={{ position: 'absolute', top: 780, left: 100, right: 100 }}>
        {c.agenda.map((text, i) => <AgendaRow key={i} no={i + 1} text={text} isNew={false} delay={12 + i * 10} lang={lang} lit={frame > 135 && i === 0} />)}
      </div>
    </AbsoluteFill>
  );
};

const AgendaRow: React.FC<{ no: number; text: string; isNew: boolean; delay: number; lang: Lang; lit: boolean }> = ({ no, text, isNew, delay, lang, lit }) => {
  const s = useSpring(delay, { damping: 14 });
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 28, background: '#fff', borderRadius: 30, padding: '28px 36px', marginBottom: 22,
      boxShadow: lit ? `0 0 0 4px ${C.deep}, 0 18px 40px rgba(46,58,70,.14)` : '0 14px 34px rgba(46,58,70,.10)',
      transform: `translateX(${(1 - s) * -80}px)`, opacity: s }}>
      <span style={{ width: 62, height: 62, flex: 'none', borderRadius: '50%', background: C.soft, color: C.deep, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: F.corm, fontSize: 42 }}>{no}</span>
      <span style={{ fontFamily: lang === 'en' ? F.zenR : F.zen, fontSize: 38, color: C.ink }}>{text}</span>
      {isNew ? <span style={{ marginLeft: 'auto', fontFamily: F.corm, fontSize: 24, letterSpacing: '.18em', color: '#fff', background: C.deep, borderRadius: 999, padding: '4px 14px' }}>NEW</span> : null}
    </div>
  );
};

// 1: モザイク（線が横切って、そのまま → モザイクに変わる）
const Mosaic: React.FC<P> = ({ lang }) => {
  const c = COPY20[lang].mosaic;
  const frame = useCurrentFrame();
  const enter = useSpring(4, { damping: 18 });
  const x = interpolate(frame, [36, 72], [100, 0], { ...clamp, easing: (p) => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2) });
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
        <div style={{ position: 'absolute', left: 30, bottom: 22, fontFamily: F.cormI, fontSize: 36, color: C.ink }}>Tue 11/3 · 2h 25m</div>
        <div style={{ position: 'absolute', right: 30, bottom: 20, fontFamily: F.zen, fontSize: 30, color: '#fff', background: x < 50 ? C.deep : C.sub, borderRadius: 999, padding: '6px 20px' }}>{x < 50 ? c.after : c.before}</div>
      </div>
    </AbsoluteFill>
  );
};

// 2: ポモドーロ。集中が 25:00 になったら、映像が止まって休憩の画面が上がってくる。最後に Siri から始める吹き出し
const Pomodoro: React.FC<P> = ({ lang }) => {
  const c = COPY20[lang].pomo;
  const frame = useCurrentFrame();
  const BREAK = 66;
  const focus = Math.min(25 * 60, 24 * 60 + 40 + Math.floor(interpolate(frame, [8, BREAK], [0, 20], clamp)));
  const onBreak = frame >= BREAK;
  const card = useSpring(BREAK + 2, { damping: 15, stiffness: 110 });
  const rest = Math.max(0, 5 * 60 - Math.floor(interpolate(frame, [BREAK + 10, DUR[2]], [0, 40], clamp)));
  const siri = useSpring(118, { damping: 12 });
  const mmss = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={2} lines={c.t} sub={c.s} />
      <Rise top={620} tilt={-4}>
        <Phone>
          {onBreak
            ? <Img src={staticFile('assets/tl-noon.jpg')} style={{ width: '100%', height: '100%', objectFit: 'cover', filter: 'brightness(.6)' }} />
            : <OffthreadVideo src={staticFile(VIDEO)} muted startFrom={60} playbackRate={1.3} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
          <div style={{ position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 24px', borderRadius: 14, background: 'rgba(40,36,32,.55)', color: '#fff', fontFamily: F.zen, fontSize: 34 }}>
              <span style={{ width: 14, height: 14, borderRadius: '50%', background: onBreak ? '#5AC8FA' : C.red }} />
              {mmss(focus)}<span style={{ fontSize: 24, opacity: 0.8 }}>· 25/5</span>
            </div>
          </div>
          <div style={{ position: 'absolute', left: 40, right: 40, top: 420, background: '#F3F6F9', borderRadius: 34, padding: '34px 30px', textAlign: 'center',
            transform: `translateY(${(1 - card) * 700}px)`, opacity: onBreak ? 1 : 0, boxShadow: '0 30px 60px rgba(0,0,0,.35)' }}>
            <div style={{ fontFamily: F.zenR, fontSize: 24, color: C.sub }}>{c.round}</div>
            <div style={{ fontFamily: F.mincho, fontSize: 40, color: C.ink, marginTop: 10 }}>{c.rest}</div>
            <div style={{ fontFamily: F.mincho, fontSize: 96, color: C.ink, lineHeight: 1.1 }}>{mmss(rest)}</div>
            <div style={{ fontFamily: F.zenR, fontSize: 24, color: C.sub, lineHeight: 1.5, marginTop: 8 }}>{c.hint}</div>
          </div>
        </Phone>
      </Rise>
      <Chip style={{ left: '50%', top: 1760, transform: `translateX(-50%) scale(${siri})`, opacity: siri, fontSize: 34 }}>
        <span style={{ fontSize: 34 }}>🎙</span>{c.siri}
      </Chip>
    </AbsoluteFill>
  );
};

// 5: 1年の草。左から週ごとに色が埋まり、勉強した日数が数え上がる
const cellLevel = (week: number, day: number) => {
  const r = Math.abs(Math.sin(week * 12.9898 + day * 78.233) * 43758.5453) % 1;
  // 秋に向けて増えていく
  const trend = week / 52;
  if (r < 0.42 - trend * 0.22) return 0;
  return Math.min(4, 1 + Math.floor(r * 3 + trend * 1.6));
};
const LEVEL = ['#E3E9EF', 'rgba(158,195,226,.45)', 'rgba(158,195,226,.75)', C.acc, C.deep];

const Year: React.FC<P> = ({ lang }) => {
  const c = COPY20[lang].year;
  const frame = useCurrentFrame();
  const enter = useSpring(4, { damping: 18 });
  const weeks = 44; // 11月はじめまで
  const shown = interpolate(frame, [20, 100], [0, weeks], { ...clamp, easing: easeOut });
  const days = Math.round(interpolate(frame, [20, 100], [0, 186], { ...clamp, easing: easeOut }));
  const streak = useSpring(108, { damping: 12 });
  const tag = useSpring(122, { damping: 12 });
  const cell = 13, gap = 2.6;
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={5} lines={c.t} sub={c.s} />
      <div style={{ position: 'absolute', left: 80, right: 80, top: 640, height: 900, background: '#fff', padding: 50, boxShadow: '0 30px 70px rgba(46,58,70,.22)',
        transform: `translateY(${(1 - enter) * 300}px) rotate(${1.5 - (1 - enter) * 4}deg)`, opacity: enter, display: 'flex', flexDirection: 'column' }}>
        <Tape color={C.tapeBlue} style={{ left: 320, top: -22, transform: 'rotate(3deg)' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ fontFamily: F.mincho, fontSize: 34, color: C.deep }}>StudyReel</span>
          <span style={{ fontFamily: F.zenR, fontSize: 28, color: C.sub }}>2026</span>
        </div>
        <div style={{ marginTop: 90, fontFamily: F.zenR, fontSize: 30, color: C.sub }}>{c.head}</div>
        <div style={{ fontFamily: F.mincho, fontSize: 150, color: C.ink, lineHeight: 1.05 }}>{days}<span style={{ fontSize: 64 }}>{c.unit}</span></div>
        <div style={{ fontFamily: F.zen, fontSize: 32, color: C.ink, opacity: interpolate(frame, [90, 104], [0, 1], clamp) }}>{c.total}</div>
        <div style={{ marginTop: 70, display: 'flex', gap }}>
          {Array.from({ length: 53 }, (_, w) => (
            <div key={w} style={{ display: 'flex', flexDirection: 'column', gap }}>
              {Array.from({ length: 7 }, (_, d) => {
                const on = w < shown;
                const level = w < weeks ? cellLevel(w, d) : 0;
                return <div key={d} style={{ width: cell, height: cell, borderRadius: 3, background: on ? LEVEL[level] : LEVEL[0], transform: on ? 'scale(1)' : 'scale(.85)' }} />;
              })}
            </div>
          ))}
        </div>
        <div style={{ marginTop: 'auto', fontFamily: F.zenR, fontSize: 26, color: C.sub }}>{c.tag} #StudyReel</div>
      </div>
      <Chip style={{ left: 60, top: 1600, transform: `scale(${streak}) rotate(-3deg)`, opacity: streak, fontSize: 30 }}>🌱 {c.streak}</Chip>
      <Chip style={{ right: 70, top: 600, transform: `scale(${tag}) rotate(5deg)`, opacity: tag }}>{c.tag}</Chip>
    </AbsoluteFill>
  );
};

// 3: 編集と時刻の飾り。タイムラプスの上の時刻が、いつもの → 色 → 飾り → 手書きの数字 と変わっていく
const Edit: React.FC<P> = ({ lang }) => {
  const c = COPY20[lang].edit;
  const frame = useCurrentFrame();
  const step = Math.min(3, Math.max(0, Math.floor((frame - 30) / 28)));
  const pop = useSpring(30 + step * 28, { damping: 11 });
  const looks = [
    { font: F.zen, color: '#fff', badge: '', bg: 'rgba(40,36,32,.45)' },
    { font: F.zen, color: '#F6E2A8', badge: '', bg: 'rgba(40,36,32,.45)' },
    { font: F.mincho, color: '#fff', badge: '★', bg: 'rgba(94,141,184,.85)' },
    { font: F.cormI, color: '#2E3A46', badge: '✏️', bg: 'rgba(255,255,255,.92)' },
  ];
  const look = looks[step];
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={3} lines={c.t} sub={c.s} />
      <Rise top={590} tilt={3}>
        <Phone width={540}>
          <OffthreadVideo src={staticFile(VIDEO_MOSAIC)} muted startFrom={40} playbackRate={1.2}
            style={{ width: '100%', height: '100%', objectFit: 'cover', filter: step >= 1 ? 'saturate(1.25) contrast(1.05)' : undefined }} />
          <div style={{ position: 'absolute', left: 34, bottom: 96, transform: `scale(${0.9 + 0.1 * pop})`, transformOrigin: 'left bottom' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 26px', borderRadius: 18, background: look.bg, color: look.color, fontFamily: look.font, fontSize: 56 }}>
              {look.badge ? <span style={{ fontSize: 40 }}>{look.badge}</span> : null}2:25:10
            </div>
          </div>
          <div style={{ position: 'absolute', left: 30, right: 30, bottom: 30, display: 'flex', gap: 12, justifyContent: 'center' }}>
            {c.tools.map((t, i) => (
              <span key={t} style={{ fontFamily: F.zen, fontSize: 24, color: '#fff', background: i === Math.min(2, Math.floor(frame / 40)) ? C.deep : 'rgba(40,36,32,.55)', borderRadius: 999, padding: '8px 20px' }}>{t}</span>
            ))}
          </div>
        </Phone>
      </Rise>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 1800, display: 'flex', gap: 14, justifyContent: 'center' }}>
        {c.styles.map((t, i) => (
          <span key={t} style={{ fontFamily: F.zen, fontSize: 28, borderRadius: 999, padding: '10px 24px',
            color: i === step ? '#fff' : C.deep, background: i === step ? C.deep : '#fff', boxShadow: '0 10px 24px rgba(46,58,70,.12)' }}>{t}</span>
        ))}
      </div>
    </AbsoluteFill>
  );
};

// 4: クエストとジェム。チェックが1つずつ付いてジェムがたまり、最後に時刻の飾りと交換する
const Quest: React.FC<P> = ({ lang }) => {
  const c = COPY20[lang].quest;
  const frame = useCurrentFrame();
  const enter = useSpring(6, { damping: 18 });
  const doneAt = [34, 50, 66, 82];
  const done = doneAt.filter((f) => frame >= f).length;
  const gems = 20 + done * 10 - (frame >= 128 ? 30 : 0);
  const card = useSpring(98, { damping: 14 });
  const owned = frame >= 128;
  return (
    <AbsoluteFill>
      <Caption lang={lang} no={4} lines={c.t} sub={c.s} />
      <div style={{ position: 'absolute', left: 100, right: 100, top: 640, background: '#fff', borderRadius: 40, padding: '38px 42px', boxShadow: '0 30px 70px rgba(46,58,70,.20)',
        transform: `translateY(${(1 - enter) * 400}px)`, opacity: enter }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontFamily: F.mincho, fontSize: 44, color: C.ink }}>{c.head}</span>
          <span style={{ fontFamily: F.zen, fontSize: 34, color: C.deep, background: C.soft, borderRadius: 999, padding: '8px 22px' }}>💎 {gems} {c.gems}</span>
        </div>
        {c.items.map((t, i) => {
          const on = frame >= doneAt[i];
          const tick = useSpring(doneAt[i], { damping: 10 });
          return (
            <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 22, marginTop: 30, paddingTop: 26, borderTop: `2px solid ${C.line}` }}>
              <span style={{ width: 48, height: 48, flex: 'none', borderRadius: '50%', border: `3px solid ${on ? C.deep : C.line}`, background: on ? C.deep : '#fff',
                color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 30, transform: `scale(${on ? 0.8 + 0.2 * tick : 1})` }}>{on ? '✓' : ''}</span>
              <span style={{ fontFamily: lang === 'en' ? F.zenR : F.zen, fontSize: 34, color: on ? C.sub : C.ink, textDecoration: on ? 'line-through' : 'none' }}>{t}</span>
              <span style={{ marginLeft: 'auto', fontFamily: F.zen, fontSize: 30, color: C.deep, opacity: on ? 1 : 0.5 }}>+10</span>
            </div>
          );
        })}
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 1450, display: 'flex', justifyContent: 'center', transform: `scale(${card})`, opacity: card }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 24, background: '#fff', borderRadius: 30, padding: '24px 34px', boxShadow: '0 18px 40px rgba(46,58,70,.18)' }}>
          <span style={{ fontSize: 46, color: '#fff', background: C.deep, borderRadius: 16, padding: '6px 16px', fontFamily: F.mincho }}>★ 2:25</span>
          <div>
            <div style={{ fontFamily: F.zen, fontSize: 32, color: C.ink }}>{c.reward}</div>
            <div style={{ fontFamily: F.zen, fontSize: 28, color: owned ? '#34A853' : C.deep, marginTop: 4 }}>{owned ? `✓ ${c.owned}` : c.exchange}</div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// 6: 終わり
const End: React.FC<P> = ({ lang }) => {
  const c = COPY20[lang].end;
  const frame = useCurrentFrame();
  const logo = useSpring(4);
  const kind = useSpring(12);
  const btn = useSpring(22, { damping: 10 });
  const pulse = frame > 40 ? 1 + Math.max(0, Math.sin((frame - 40) / 8)) * 0.03 : 1;
  return (
    <AbsoluteFill>
      <Tape style={{ left: 465, top: 580, transform: `rotate(5deg) scaleX(${logo})` }} />
      <div style={{ position: 'absolute', top: 610, left: 0, right: 0, textAlign: 'center', fontFamily: F.mincho, fontSize: 140, color: C.ink, opacity: logo, transform: `translateY(${(1 - logo) * 40}px)` }}>StudyReel</div>
      <div style={{ position: 'absolute', top: 810, left: 0, right: 0, textAlign: 'center', fontFamily: F.zen, fontSize: 40, color: C.sub, letterSpacing: '.14em', opacity: kind }}>{c.kind}</div>
      <div style={{ position: 'absolute', top: 940, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <div style={{ fontFamily: F.zen, fontSize: 40, color: '#fff', background: C.deep, borderRadius: 999, padding: '26px 64px', transform: `scale(${btn * pulse})`, opacity: Math.min(1, btn * 2), boxShadow: '0 18px 40px rgba(94,141,184,.35)' }}>{c.store}</div>
      </div>
      <div style={{ position: 'absolute', top: 1090, left: 0, right: 0, textAlign: 'center', fontFamily: F.zenR, fontSize: 30, color: C.sub, opacity: kind }}>iPhone / iPad · {c.langs}</div>
      <div style={{ position: 'absolute', top: 1200, left: 110, right: 110, display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 18 }}>
        {c.points.map((p, i) => <Point key={i} text={p} delay={32 + i * 6} />)}
      </div>
    </AbsoluteFill>
  );
};

const Point: React.FC<{ text: string; delay: number }> = ({ text, delay }) => {
  const s = useSpring(delay);
  return <span style={{ fontFamily: F.zen, fontSize: 32, color: C.deep, background: C.soft, borderRadius: 999, padding: '12px 28px', opacity: s, transform: `translateY(${(1 - s) * 16}px)` }}>{text}</span>;
};

// 上の5つの目盛り。いま目次の何番目か
const Progress: React.FC = () => {
  const frame = useCurrentFrame();
  const scene = START.reduce((acc, st, i) => (frame >= st + T / 2 ? i : acc), 0);
  const sec = scene >= 1 && scene <= 5 ? scene : 0;
  const o = interpolate(frame, [START[1], START[1] + 10, START[6] - 4, START[6] + 6], [0, 1, 1, 0], clamp);
  return (
    <div style={{ position: 'absolute', top: 60, left: 300, right: 300, display: 'flex', gap: 14, opacity: o }}>
      {[1, 2, 3, 4, 5].map((n) => <div key={n} style={{ flex: 1, height: 8, borderRadius: 999, background: n <= sec ? C.deep : 'rgba(94,141,184,.2)' }} />)}
    </div>
  );
};

export const Intro20: React.FC<P> = ({ lang }) => {
  const scenes = [Agenda, Mosaic, Pomodoro, Edit, Quest, Year, End];
  const transitions = [fade(), slide({ direction: 'from-right' }), slide({ direction: 'from-right' }), slide({ direction: 'from-right' }), slide({ direction: 'from-right' }), fade()];
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
      <Audio src={staticFile('out/bgm-lofi.m4a')} volume={(f) => interpolate(f, [0, 15, INTRO20_FRAMES - 45, INTRO20_FRAMES], [0, 1, 1, 0], clamp)} />
    </AbsoluteFill>
  );
};
