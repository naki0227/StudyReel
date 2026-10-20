// 時刻 t（秒）から見た目を決めるための小さな道具。アニメーションはすべて seek(t) で計算し直す（CSS アニメは使わない）
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const ease = {
  out: (p) => 1 - Math.pow(1 - p, 3),
  in: (p) => p * p * p,
  inOut: (p) => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2),
  outBack: (p) => { const c = 1.4; return 1 + (c + 1) * Math.pow(p - 1, 3) + c * Math.pow(p - 1, 2); },
  linear: (p) => p,
};
// start から dur 秒かけて 0→1
const seg = (t, start, dur, fn = ease.out) => fn(clamp((t - start) / dur));
// start〜end のあいだ見える。入りと出で fade
const window_ = (t, start, end, fadeIn = 0.4, fadeOut = 0.4) =>
  clamp((t - start) / fadeIn) * clamp((end - t) / fadeOut);
const lerp = (a, b, p) => a + (b - a) * p;
const mix = (t, keys, fn = ease.inOut) => {
  // keys: [[time, value], ...] を線で結ぶ
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    if (t <= keys[i][0]) {
      const [t0, v0] = keys[i - 1], [t1, v1] = keys[i];
      return lerp(v0, v1, fn((t - t0) / (t1 - t0)));
    }
  }
  return keys[keys.length - 1][1];
};
const $ = (id) => document.getElementById(id);
const set = (el, { x = 0, y = 0, s = 1, r = 0, o = 1 } = {}) => {
  el.style.transform = `translate(${x}px, ${y}px) scale(${s}) rotate(${r}deg)`;
  el.style.opacity = o;
};
// .shot は中央基準なので translate(-50%,-50%) を足す
const setShot = (el, { x = 0, y = 0, s = 1, r = 0, o = 1 } = {}) => {
  el.style.transform = `translate(calc(-50% + ${x}px), calc(-50% + ${y}px)) scale(${s}) rotate(${r}deg)`;
  el.style.opacity = o;
};
const pad2 = (n) => String(Math.floor(n)).padStart(2, '0');
const mmss = (sec) => `${pad2(sec / 60)}:${pad2(sec % 60)}`;
