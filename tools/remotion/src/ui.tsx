// PV の共通の見た目。アプリの共有カードと同じ、方眼紙・マスキングテープ・淡い青
import React, { useEffect, useState } from 'react';
import { AbsoluteFill, continueRender, delayRender, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';

export const C = {
  paper: '#F7F8FA', ink: '#2E3A46', sub: '#8E9AA6', line: '#E3E9EF',
  acc: '#9EC3E2', soft: '#E1EDF6', deep: '#5E8DB8', red: '#FF3B30',
  tapeYellow: 'rgba(246, 226, 168, .9)', tapePink: 'rgba(242, 203, 208, .9)', tapeBlue: 'rgba(158, 195, 226, .65)',
};

export const F = { mincho: 'Mincho', minchoR: 'MinchoR', zen: 'Zen', zenR: 'ZenR', corm: 'Corm', cormI: 'CormI' };

const fontFaces = `
@font-face { font-family: Mincho; src: url(${staticFile('fonts/ShipporiMincho-SemiBold.ttf')}); }
@font-face { font-family: MinchoR; src: url(${staticFile('fonts/ShipporiMincho-Regular.ttf')}); }
@font-face { font-family: Zen; src: url(${staticFile('fonts/ZenKakuGothicNew-Medium.ttf')}); }
@font-face { font-family: ZenR; src: url(${staticFile('fonts/ZenKakuGothicNew-Regular.ttf')}); }
@font-face { font-family: Corm; src: url(${staticFile('fonts/CormorantGaramond.ttf')}); }
@font-face { font-family: CormI; src: url(${staticFile('fonts/CormorantGaramond-Italic.ttf')}); }
`;

// フォントが読み込まれるまで撮らない
export const Fonts: React.FC = () => {
  const [handle] = useState(() => delayRender('fonts'));
  useEffect(() => {
    Promise.all(Object.values(F).map((f) => document.fonts.load(`40px ${f}`, 'あA'))).then(() => continueRender(handle));
  }, [handle]);
  return <style>{fontFaces}</style>;
};

// 方眼紙。ゆっくり流れる
export const Grid: React.FC = () => {
  const frame = useCurrentFrame();
  const o = (frame * 0.25) % 54;
  return (
    <AbsoluteFill style={{
      backgroundColor: C.paper,
      backgroundImage: `linear-gradient(rgba(227,233,239,.8) 2px, transparent 2px), linear-gradient(90deg, rgba(227,233,239,.8) 2px, transparent 2px)`,
      backgroundSize: '54px 54px', backgroundPosition: `0 ${o}px`,
    }} />
  );
};

// ばねで 0→1（delay はフレーム）
export const useSpring = (delay = 0, config: { damping?: number; mass?: number; stiffness?: number } = {}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping: 16, mass: 0.8, stiffness: 120, ...config } });
};

export const Tape: React.FC<{ color?: string; style?: React.CSSProperties }> = ({ color = C.tapeBlue, style }) => (
  <div style={{
    position: 'absolute', height: 44, width: 150, background: color,
    clipPath: 'polygon(0 0, 3% 12%, 0 25%, 3% 38%, 0 50%, 3% 62%, 0 75%, 3% 88%, 0 100%, 100% 100%, 97% 88%, 100% 75%, 97% 62%, 100% 50%, 97% 38%, 100% 25%, 97% 12%, 100% 0)',
    ...style,
  }} />
);

// 見出し。1行ずつ下からせり上がる（行ごとに少し遅らせる）
export const Title: React.FC<{ lines: string[]; delay?: number; size?: number; color?: string; font?: string; shadow?: boolean }> = ({ lines, delay = 0, size = 78, color = C.ink, font = F.mincho, shadow }) => {
  const frame = useCurrentFrame();
  return (
    <div style={{ textAlign: 'center' }}>
      {lines.map((line, i) => {
        const p = interpolate(frame - delay - i * 5, [0, 16], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: (x) => 1 - Math.pow(1 - x, 3) });
        return (
          <div key={i} style={{ overflow: 'hidden', paddingBottom: 8 }}>
            <div style={{
              fontFamily: font, fontSize: size, lineHeight: 1.3, letterSpacing: '.05em', color,
              transform: `translateY(${(1 - p) * 110}%)`, textShadow: shadow ? '0 2px 24px rgba(0,0,0,.45)' : undefined,
            }}>{line}</div>
          </div>
        );
      })}
    </div>
  );
};

// 「1　勉強してるところを撮る」のような、何番目の紹介かの札
export const Section: React.FC<{ no: number; text: string; isNew?: boolean; delay?: number; dark?: boolean }> = ({ no, text, isNew, delay = 0, dark }) => {
  const s = useSpring(delay);
  return (
    <div style={{ display: 'flex', justifyContent: 'center', transform: `translateY(${(1 - s) * 20}px)`, opacity: s }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 16, padding: '10px 28px 10px 12px', borderRadius: 999,
        background: dark ? 'rgba(255,255,255,.92)' : C.soft, fontFamily: F.zen, fontSize: 30, color: C.deep, letterSpacing: '.04em',
      }}>
        <span style={{ width: 46, height: 46, borderRadius: '50%', background: C.deep, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: F.corm, fontSize: 32 }}>{no}</span>
        {text}
        {isNew ? <span style={{ fontFamily: F.corm, fontSize: 24, letterSpacing: '.18em', color: '#fff', background: C.deep, borderRadius: 999, padding: '2px 14px' }}>NEW</span> : null}
      </div>
    </div>
  );
};

export const Sub: React.FC<{ text: string; delay?: number; color?: string }> = ({ text, delay = 0, color = C.sub }) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame - delay, [0, 14], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  return <div style={{ textAlign: 'center', fontFamily: F.zen, fontSize: 34, color, opacity: o, marginTop: 18, letterSpacing: '.04em' }}>{text}</div>;
};

// 画面の枠（iPhone の角丸と影だけ）。children に画面の中身
export const Phone: React.FC<{ width?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ width = 640, children, style }) => (
  <div style={{
    position: 'relative', width, height: width * 2868 / 1320, borderRadius: width * 0.15, overflow: 'hidden', background: '#000',
    boxShadow: '0 50px 110px rgba(46,58,70,.26), 0 0 0 10px #fff, 0 0 0 11px rgba(46,58,70,.08)', ...style,
  }}>{children}</div>
);

// 白い吹き出し（スタンプやハッシュタグ）
export const Chip: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({ children, style }) => (
  <div style={{
    position: 'absolute', fontFamily: F.zen, fontSize: 36, color: C.deep, background: '#fff', borderRadius: 999, padding: '16px 32px',
    boxShadow: '0 16px 34px rgba(46,58,70,.18)', display: 'flex', alignItems: 'center', gap: 12, whiteSpace: 'nowrap', ...style,
  }}>{children}</div>
);
