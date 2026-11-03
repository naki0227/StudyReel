// YouTube ショート・リール・TikTok 用の縦動画（1080×1920・30fps・10〜13秒）。1本に1つのことだけ言う。
// 最初のコマで何の動画か分かるように、見出しは0フレーム目から出しておく。
// 下の 380px と右の 160px は各アプリのボタンや説明文に隠れるので、大事な文字を置かない
import React from 'react';
import { AbsoluteFill, Audio, OffthreadVideo, Sequence, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { C, F, Fonts, Grid, Tape, useSpring } from './ui';

export type ShortKind = 'timelapse' | 'mosaic' | 'year';
type P = { kind: ShortKind };

const VIDEO = 'assets/study-timelapse.mp4';
const VIDEO_MOSAIC = 'assets/study-timelapse-mosaic.mp4';
const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
const easeOut = (p: number) => 1 - Math.pow(1 - p, 3);

// 本編の長さ（このあとに 3 秒の終わりの画面）
const BODY: Record<ShortKind, number> = { timelapse: 212, mosaic: 212, year: 180 };
const END = 90;
export const shortFrames = (kind: ShortKind) => BODY[kind] + END;

const HOOK: Record<ShortKind, string[]> = {
  timelapse: ['2時間25分の勉強を', '7秒で'],
  mosaic: ['勉強垢、', '顔を出さずに載せたい'],
  year: ['今年いちばん', '勉強した月は？'],
};

// 上に出す大きな見出し（白い帯）。最初から出ている
const Hook: React.FC<{ lines: string[]; dark?: boolean }> = ({ lines, dark }) => (
  <div style={{ position: 'absolute', top: 170, left: 70, right: 160, display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 14 }}>
    {lines.map((l, i) => (
      <span key={i} style={{ fontFamily: F.zen, fontSize: 70, lineHeight: 1.25, color: dark ? C.ink : C.ink, background: '#fff', padding: '8px 26px', borderRadius: 18,
        boxShadow: '0 10px 30px rgba(0,0,0,.18)' }}>{l}</span>
    ))}
  </div>
);

// 下寄りの小さな札
const Note: React.FC<{ text: string; delay: number; top?: number }> = ({ text, delay, top = 1330 }) => {
  const s = useSpring(delay, { damping: 12 });
  return (
    <div style={{ position: 'absolute', top, left: 70, transform: `scale(${s})`, transformOrigin: 'left center', opacity: s }}>
      <span style={{ fontFamily: F.zen, fontSize: 44, color: '#fff', background: C.deep, padding: '14px 30px', borderRadius: 999, boxShadow: '0 12px 30px rgba(0,0,0,.25)' }}>{text}</span>
    </div>
  );
};

// 1. 2時間25分がそのまま早送りで流れ、時間が数え上がる
const Timelapse: React.FC = () => {
  const frame = useCurrentFrame();
  const sec = Math.floor(interpolate(frame, [0, BODY.timelapse - 10], [0, 2 * 3600 + 25 * 60], clamp));
  const hh = Math.floor(sec / 3600), mm = Math.floor((sec % 3600) / 60), ss = sec % 60;
  return (
    <AbsoluteFill style={{ background: '#000' }}>
      <OffthreadVideo src={staticFile(VIDEO_MOSAIC)} muted style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
      <AbsoluteFill style={{ background: 'linear-gradient(rgba(0,0,0,.25), transparent 30%, transparent 60%, rgba(0,0,0,.35))' }} />
      <Hook lines={HOOK.timelapse} />
      <div style={{ position: 'absolute', top: 1060, left: 70, display: 'flex', alignItems: 'center', gap: 18, padding: '14px 32px', borderRadius: 22, background: 'rgba(40,36,32,.6)' }}>
        <span style={{ width: 22, height: 22, borderRadius: '50%', background: C.red, opacity: 0.55 + 0.45 * Math.abs(Math.sin(frame / 8)) }} />
        <span style={{ fontFamily: F.mincho, fontSize: 96, color: '#fff', fontVariantNumeric: 'tabular-nums' }}>
          {hh}:{String(mm).padStart(2, '0')}:{String(ss).padStart(2, '0')}
        </span>
      </div>
      <Note text="顔は自動でモザイク" delay={70} top={1250} />
    </AbsoluteFill>
  );
};

// 2. そのまま → 線が横切ってモザイクに
const Mosaic: React.FC = () => {
  const frame = useCurrentFrame();
  const x = interpolate(frame, [40, 90], [100, 0], { ...clamp, easing: (p) => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2) });
  return (
    <AbsoluteFill style={{ background: '#000' }}>
      <OffthreadVideo src={staticFile(VIDEO)} muted style={{ position: 'absolute', width: '100%', height: '100%', objectFit: 'cover' }} />
      <div style={{ position: 'absolute', inset: 0, clipPath: `inset(0 0 0 ${x}%)` }}>
        <OffthreadVideo src={staticFile(VIDEO_MOSAIC)} muted style={{ position: 'absolute', width: '100%', height: '100%', objectFit: 'cover' }} />
      </div>
      {x > 0 && x < 100 ? <div style={{ position: 'absolute', top: 0, bottom: 0, left: `${x}%`, width: 8, marginLeft: -4, background: '#fff', boxShadow: '0 0 24px rgba(0,0,0,.4)' }} /> : null}
      <AbsoluteFill style={{ background: 'linear-gradient(rgba(0,0,0,.25), transparent 30%)' }} />
      <Hook lines={HOOK.mosaic} />
      <Note text="撮るだけで、顔にモザイク" delay={96} top={1200} />
      <Note text="そのまま投稿できる" delay={130} top={1310} />
    </AbsoluteFill>
  );
};

// 3. 1年の草が週ごとに埋まっていく
const cellLevel = (week: number, day: number) => {
  const r = Math.abs(Math.sin(week * 12.9898 + day * 78.233) * 43758.5453) % 1;
  const trend = week / 52;
  if (r < 0.42 - trend * 0.22) return 0;
  return Math.min(4, 1 + Math.floor(r * 3 + trend * 1.6));
};
const LEVEL = ['#E3E9EF', 'rgba(158,195,226,.45)', 'rgba(158,195,226,.75)', C.acc, C.deep];
const MONTHS = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月'];

const Year: React.FC = () => {
  const frame = useCurrentFrame();
  const weeks = 44;
  const shown = interpolate(frame, [10, 120], [0, weeks], { ...clamp, easing: easeOut });
  const days = Math.round(interpolate(frame, [10, 120], [0, 186], { ...clamp, easing: easeOut }));
  const best = useSpring(128, { damping: 12 });
  // 1行が1か月、1マスが1日
  const LEN = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31];
  const cell = 19, gap = 3;
  let doy = 0;
  const rows = MONTHS.map((m, mi) => {
    const first = doy;
    doy += LEN[mi];
    return { m, mi, first };
  });
  const isBest = best > 0.5;
  return (
    <AbsoluteFill>
      <Grid />
      <Hook lines={HOOK.year} dark />
      <div style={{ position: 'absolute', left: 70, right: 160, top: 470, background: '#fff', padding: '44px 46px', borderRadius: 8, boxShadow: '0 30px 70px rgba(46,58,70,.22)', transform: 'rotate(-1deg)' }}>
        <Tape color={C.tapeBlue} style={{ left: 330, top: -22, transform: 'rotate(3deg)' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <span style={{ fontFamily: F.zenR, fontSize: 30, color: C.sub }}>今年 勉強した日</span>
          <span style={{ fontFamily: F.mincho, fontSize: 30, color: C.deep }}>StudyReel</span>
        </div>
        <div style={{ fontFamily: F.mincho, fontSize: 130, color: C.ink, lineHeight: 1.1 }}>{days}<span style={{ fontSize: 56 }}>日</span></div>
        <div style={{ marginTop: 26, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {rows.map(({ m, mi, first }) => (
            <div key={m} style={{ display: 'flex', alignItems: 'center', gap, padding: '4px 6px', borderRadius: 10, marginLeft: -6,
              boxShadow: mi === 9 && isBest ? `0 0 0 3px ${C.deep}` : undefined }}>
              <span style={{ width: 66, fontFamily: F.zenR, fontSize: 24, color: mi === 9 && isBest ? C.deep : C.sub }}>{m}</span>
              {Array.from({ length: LEN[mi] }, (_, d) => {
                const n = first + d;
                const on = n < shown * 7;
                const lv = cellLevel(Math.floor(n / 7), n % 7);
                return <div key={d} style={{ width: cell, height: cell, borderRadius: 5, background: on ? LEVEL[lv] : LEVEL[0] }} />;
              })}
            </div>
          ))}
        </div>
      </div>
      <div style={{ position: 'absolute', top: 1340, left: 70, transform: `scale(${best}) rotate(-2deg)`, transformOrigin: 'left center', opacity: best }}>
        <span style={{ fontFamily: F.zen, fontSize: 44, color: '#fff', background: C.deep, padding: '14px 30px', borderRadius: 999 }}>🌱 勉強した日が色で埋まる</span>
      </div>
    </AbsoluteFill>
  );
};

// 終わり：名前と「App Store で無料」
const End: React.FC<P> = ({ kind }) => {
  const logo = useSpring(2);
  const btn = useSpring(14, { damping: 10 });
  const line: Record<ShortKind, string> = { timelapse: '撮るだけで、勉強がタイムラプスに', mosaic: '顔を出さずに、勉強を撮る', year: '毎日の勉強を、1年の色に' };
  return (
    <AbsoluteFill>
      <Grid />
      <div style={{ position: 'absolute', top: 560, left: 0, right: 0, textAlign: 'center', fontFamily: F.zen, fontSize: 44, color: C.sub, opacity: logo }}>{line[kind]}</div>
      <Tape style={{ left: 465, top: 660, transform: `rotate(5deg) scaleX(${logo})` }} />
      <div style={{ position: 'absolute', top: 690, left: 0, right: 0, textAlign: 'center', fontFamily: F.mincho, fontSize: 150, color: C.ink, opacity: logo, transform: `translateY(${(1 - logo) * 40}px)` }}>StudyReel</div>
      <div style={{ position: 'absolute', top: 920, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <div style={{ fontFamily: F.zen, fontSize: 44, color: '#fff', background: C.deep, borderRadius: 999, padding: '26px 64px', transform: `scale(${btn})`, opacity: Math.min(1, btn * 2) }}>App Store で無料</div>
      </div>
      <div style={{ position: 'absolute', top: 1080, left: 0, right: 0, textAlign: 'center', fontFamily: F.zenR, fontSize: 32, color: C.sub, opacity: logo }}>iPhone · iPad</div>
    </AbsoluteFill>
  );
};

export const Short: React.FC<P> = ({ kind }) => {
  const total = shortFrames(kind);
  const Body = kind === 'timelapse' ? Timelapse : kind === 'mosaic' ? Mosaic : Year;
  const frame = useCurrentFrame();
  const endIn = interpolate(frame, [BODY[kind] - 8, BODY[kind] + 4], [0, 1], clamp);
  return (
    <AbsoluteFill style={{ background: C.paper }}>
      <Fonts />
      <Sequence durationInFrames={BODY[kind] + 4}><Body /></Sequence>
      <Sequence from={BODY[kind] - 8}><AbsoluteFill style={{ opacity: endIn }}><End kind={kind} /></AbsoluteFill></Sequence>
      <Audio src={staticFile('out/bgm-lofi.m4a')} volume={(f) => interpolate(f, [0, 10, total - 30, total], [0.8, 1, 1, 0], clamp)} />
    </AbsoluteFill>
  );
};
