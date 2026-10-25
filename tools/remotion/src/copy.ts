// 宣伝文句らしくしない。友達に「このアプリこういうの」と話すくらいの言い方で
export type Lang = 'ja' | 'en';

export const COPY = {
  ja: {
    kind: '勉強記録アプリ', can: 'でできること',
    agenda: ['勉強してるところを撮る', '試験までの日数と点数を見る', '友達と勉強時間を見せ合う', '1週間分をVlogにして投稿'],
    sec: ['勉強してるところを撮る', '試験までの日数と点数', '友達と見せ合う', 'Vlogにして投稿'],
    rec: { t: ['スマホを立てて', 'スタート押すだけ'], s: '3時間やっても、数十秒のタイムラプスになる', speed: '自動で早送り' },
    mosaic: { t: ['顔はモザイクで', '隠せます'], s: '撮ったあとに位置も直せる', before: 'そのまま', after: 'モザイク' },
    goal: { t: ['試験まであと何日か', 'すぐわかる'], s: '過去問の点数も残しておける' },
    buddies: { t: ['友達がいま勉強してるか', 'わかる'], s: '今日の勉強時間を見せ合って、スタンプも送れる',
      stamps: ['🔥 がんばれ', '✨ すごい', '👏 おつかれ'], from: ['はると', 'みお'] },
    vlog: { t: ['1週間分が', '1本のVlogに'], s: 'BGMも選べる' },
    share: { t: ['勉強時間はカードにして', 'そのまま投稿'], s: '今日の分でも、今週の分でも', tag: '#勉強垢' },
    end: { kind: '勉強記録アプリ', store: 'App Store で無料', points: ['タイムラプス', '顔にモザイク', '試験までの日数', '勉強仲間'] },
  },
  en: {
    kind: 'A study log app', can: 'Here’s what it does',
    agenda: ['Film yourself studying', 'Count down to your exam', 'Share study time with friends', 'Turn your week into a vlog'],
    sec: ['Film yourself studying', 'Count down to your exam', 'Study with friends', 'Turn it into a vlog'],
    rec: { t: ['Prop up your phone', 'and hit start'], s: 'Three hours turns into a few seconds of time-lapse', speed: 'Sped up for you' },
    mosaic: { t: ['Your face gets', 'a mosaic'], s: 'You can move it after recording', before: 'As shot', after: 'Mosaic' },
    goal: { t: ['See how many days', 'are left'], s: 'Keep your past-paper scores too' },
    buddies: { t: ['See when your friends', 'are studying'], s: 'Compare today’s time and send them a stamp',
      stamps: ['🔥 Keep going', '✨ Nice', '👏 Good job'], from: ['Haruto', 'Mio'] },
    vlog: { t: ['A whole week', 'in one vlog'], s: 'Pick the music too' },
    share: { t: ['Post your study time', 'as a card'], s: 'Today’s or the whole week’s', tag: '#studygram' },
    end: { kind: 'A study log app', store: 'Free on the App Store', points: ['Time-lapse', 'Face mosaic', 'Exam countdown', 'Study Buddies'] },
  },
};

// 画面のスクショ。英語は assets/en/
export const screen = (lang: Lang, name: string) => (lang === 'ja' ? `assets/${name}` : `assets/en/${name}`);
