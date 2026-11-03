// App Store の App 内イベントの画像。カード（横 1920×1080）と詳細ページ（縦 1080×1920）。
// 文字はストアの側に出るので、画像には数字と小さなロゴだけを入れる。写真は顔にモザイクをかけたタイムラプスのコマ
import React from 'react';
import { AbsoluteFill, Img, staticFile } from 'remotion';
import { C, F, Fonts, Tape } from './ui';

export type EventKind = 'kimatsu' | 'kyotsu' | 'pomodoro' | 'shingakki' | 'natsu';
type P = { kind: EventKind; portrait?: boolean };

const PHOTO: Record<EventKind, string> = {
  kimatsu: 'assets/ev-night-mosaic.jpg',
  kyotsu: 'assets/ev-morning-mosaic.jpg',
  pomodoro: 'assets/ev-stretch-mosaic.jpg',
  shingakki: 'assets/ev-morning-mosaic.jpg',
  natsu: 'assets/ev-night-mosaic.jpg',
};

const grid = {
  backgroundColor: C.paper,
  backgroundImage: 'linear-gradient(rgba(227,233,239,.8) 2px, transparent 2px), linear-gradient(90deg, rgba(227,233,239,.8) 2px, transparent 2px)',
  backgroundSize: '54px 54px',
};

const Polaroid: React.FC<{ src: string; w: number; rot: number; style?: React.CSSProperties }> = ({ src, w, rot, style }) => (
  <div style={{ position: 'absolute', background: '#fff', padding: `${w * 0.035}px ${w * 0.035}px ${w * 0.12}px`, boxShadow: '0 30px 70px rgba(46,58,70,.24)', transform: `rotate(${rot}deg)`, ...style }}>
    <Tape color={C.tapePink} style={{ left: w / 2 - 40, top: -22, transform: 'rotate(-4deg)' }} />
    <Img src={staticFile(src)} style={{ width: w, height: w * 16 / 9, objectFit: 'cover', display: 'block' }} />
  </div>
);

const LEVEL = ['#E3E9EF', 'rgba(158,195,226,.45)', 'rgba(158,195,226,.75)', C.acc, C.deep];
const level = (w: number, d: number, fill: number) => {
  if (w >= fill) return 0;
  const r = Math.abs(Math.sin(w * 12.9898 + d * 78.233) * 43758.5453) % 1;
  return r < 0.25 ? 0 : 1 + Math.floor(r * 3.99);
};

const Heat: React.FC<{ weeks: number; fill: number; cell: number }> = ({ weeks, fill, cell }) => (
  <div style={{ display: 'flex', gap: cell * 0.22 }}>
    {Array.from({ length: weeks }, (_, w) => (
      <div key={w} style={{ display: 'flex', flexDirection: 'column', gap: cell * 0.22 }}>
        {Array.from({ length: 7 }, (_, d) => <div key={d} style={{ width: cell, height: cell, borderRadius: cell * 0.22, background: LEVEL[level(w, d, fill)] }} />)}
      </div>
    ))}
  </div>
);

const Card: React.FC<{ children: React.ReactNode; rot?: number; style?: React.CSSProperties }> = ({ children, rot = 2, style }) => (
  <div style={{ position: 'absolute', background: '#fff', borderRadius: 36, padding: 46, boxShadow: '-12px 12px 0 0 rgba(158,195,226,.35), 0 26px 60px rgba(46,58,70,.16)', transform: `rotate(${rot}deg)`, ...style }}>{children}</div>
);

const Logo: React.FC<{ style: React.CSSProperties }> = ({ style }) => (
  <div style={{ position: 'absolute', fontFamily: F.mincho, fontSize: 44, color: C.deep, ...style }}>StudyReel</div>
);

// 右（縦のときは下）に置く、イベントごとの絵
const Motif: React.FC<{ kind: EventKind }> = ({ kind }) => {
  switch (kind) {
    case 'kimatsu':
      return <Card><Heat weeks={6} fill={4} cell={58} /><div style={{ marginTop: 30, fontFamily: F.mincho, fontSize: 64, color: C.ink }}>28<span style={{ fontSize: 32, color: C.sub }}> / 28</span></div></Card>;
    case 'kyotsu':
      return <Card rot={-2}><div style={{ fontFamily: F.corm, fontSize: 60, color: C.sub }}>D-</div><div style={{ fontFamily: F.mincho, fontSize: 260, lineHeight: 0.95, color: C.ink }}>27</div><div style={{ marginTop: 20, height: 14, width: 420, borderRadius: 999, background: C.line }}><div style={{ height: '100%', width: '72%', borderRadius: 999, background: C.acc }} /></div></Card>;
    case 'pomodoro':
      return (
        <Card rot={2}>
          <svg width="420" height="420" viewBox="0 0 420 420">
            <circle cx="210" cy="210" r="180" fill="none" stroke={C.line} strokeWidth="34" />
            <circle cx="210" cy="210" r="180" fill="none" stroke={C.deep} strokeWidth="34" strokeLinecap="round" strokeDasharray={`${2 * Math.PI * 180 * 0.83} ${2 * Math.PI * 180}`} transform="rotate(-90 210 210)" />
            <circle cx="210" cy="210" r="180" fill="none" stroke="#5AC8FA" strokeWidth="34" strokeLinecap="round" strokeDasharray={`${2 * Math.PI * 180 * 0.15} ${2 * Math.PI * 180}`} strokeDashoffset={-2 * Math.PI * 180 * 0.85} transform="rotate(-90 210 210)" />
            <text x="210" y="238" textAnchor="middle" fontFamily={F.mincho} fontSize="92" fill={C.ink}>25:00</text>
          </svg>
        </Card>
      );
    case 'shingakki':
      return <Card rot={-1.5}><Heat weeks={8} fill={1} cell={52} /><div style={{ marginTop: 26, fontSize: 70 }}>🌱</div></Card>;
    case 'natsu':
      return (
        <div style={{ position: 'absolute', display: 'flex', gap: 18, padding: 22, background: '#1e2328', borderRadius: 24, transform: 'rotate(2deg)', boxShadow: '0 26px 60px rgba(46,58,70,.3)' }}>
          {['assets/ev-morning-mosaic.jpg', 'assets/ev-stretch-mosaic.jpg', 'assets/ev-night-mosaic.jpg'].map((src) => (
            <Img key={src} src={staticFile(src)} style={{ width: 200, height: 356, objectFit: 'cover', borderRadius: 10 }} />
          ))}
        </div>
      );
  }
};

export const EventArt: React.FC<P> = ({ kind, portrait }) => (
  <AbsoluteFill style={grid}>
    <Fonts />
    {portrait ? (
      <>
        <Polaroid src={PHOTO[kind]} w={520} rot={-3} style={{ left: 260, top: 150 }} />
        <div style={{ position: 'absolute', left: 0, right: 0, top: 1180, bottom: 60, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
          <div style={{ transform: 'scale(.92)' }}><MotifBox kind={kind} /></div>
        </div>
        <Logo style={{ right: 90, top: 120 }} />
      </>
    ) : (
      <>
        <Polaroid src={PHOTO[kind]} w={430} rot={-3} style={{ left: 200, top: 80 }} />
        <div style={{ position: 'absolute', left: 780, right: 60, top: 0, bottom: 0, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
          <div style={{ transform: 'scale(1.3)' }}><MotifBox kind={kind} /></div>
        </div>
        <Logo style={{ right: 90, top: 70 }} />
      </>
    )}
  </AbsoluteFill>
);

// Motif は absolute で置くので、大きさを持った箱に入れて並べる
const MotifBox: React.FC<{ kind: EventKind }> = ({ kind }) => {
  const size: Record<EventKind, [number, number]> = { kimatsu: [560, 620], kyotsu: [520, 520], pomodoro: [520, 520], shingakki: [620, 560], natsu: [720, 400] };
  const [w, h] = size[kind];
  return <div style={{ position: 'relative', width: w, height: h }}><div style={{ position: 'absolute', left: 0, top: 0 }}><Motif kind={kind} /></div></div>;
};
