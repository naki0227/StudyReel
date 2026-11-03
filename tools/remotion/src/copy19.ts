// 1.9 時点の紹介 PV の文言。宣伝文句らしくしない。友達に「このアプリこういうの」と話すくらいの言い方で
import type { Lang } from './copy';

export const COPY19 = {
  ja: {
    kind: '勉強記録アプリ', can: 'でできること',
    agenda: ['顔を隠して勉強を撮る', '休憩つきで集中する', '1年分を色で残す', '親や塾に勉強時間だけ見せる'],
    sec: ['顔を隠して撮る', '休憩つきで集中', '1年分を色で残す', '親や塾に見せる'],
    mosaic: { t: ['顔はモザイクで', '隠せます'], s: '顔を出さずに、そのまま勉強垢に載せられる', before: 'そのまま', after: 'モザイク' },
    pomo: { t: ['25分やったら', '5分休憩'], s: '休憩の間は撮影も止まる。動画には集中した時間だけ', rest: '休憩', round: '1回目の集中、おつかれさまでした', hint: 'スマホから少し離れて、遠くを見たり水を飲んだりしましょう', siri: '「StudyReelで勉強を始める」' },
    year: { t: ['1年分が', '色で埋まっていく'], s: 'カードにして、そのまま投稿できる', head: '今年 勉強した日', unit: '日', total: '合計 412時間', streak: '週に1日休んでも、連続は途切れない', tag: '#勉強垢' },
    watch: { t: ['親や塾の先生に', '勉強時間だけ見せる'], s: '動画や写真は見せない。いつでも止められる', name: 'ゆう', now: 'いま勉強中', today: '今日', week: '今週', streak: '連続', streakVal: '12日', todayVal: '2時間25分', weekVal: '14時間10分', scan: 'QRコードを読むだけ', days: ['月', '火', '水', '木', '金', '土', '日'] },
    end: { kind: '勉強記録アプリ', store: 'App Store で無料', points: ['タイムラプス', '顔にモザイク', 'ポモドーロ', '1年の草', '親・塾に共有'], langs: '日本語 · English · 한국어 · 中文' },
  },
  en: {
    kind: 'A study log app', can: 'Here’s what it does',
    agenda: ['Film yourself, face hidden', 'Focus with breaks', 'See your whole year', 'Show parents just your time'],
    sec: ['Face hidden', 'Focus with breaks', 'Your whole year', 'Share with parents'],
    mosaic: { t: ['Your face gets', 'a mosaic'], s: 'Post your study videos without showing your face', before: 'As shot', after: 'Mosaic' },
    pomo: { t: ['25 minutes on,', '5 minutes off'], s: 'Filming pauses on breaks, so the video is all focus', rest: 'Break', round: 'Focus session 1 done. Nice work', hint: 'Step away from your phone — look out the window or grab some water', siri: '“Start studying with StudyReel”' },
    year: { t: ['Watch your year', 'fill in'], s: 'Post it as a card', head: 'Days studied this year', unit: ' days', total: '412 h in total', streak: 'One rest day a week won’t break your streak', tag: '#studygram' },
    watch: { t: ['Show a parent or tutor', 'just your study time'], s: 'No videos or photos. Stop anytime', name: 'Yu', now: 'Studying now', today: 'Today', week: 'This week', streak: 'Streak', streakVal: '12 days', todayVal: '2h 25m', weekVal: '14h 10m', scan: 'Just scan their QR code', days: ['M', 'T', 'W', 'T', 'F', 'S', 'S'] },
    end: { kind: 'A study log app', store: 'Free on the App Store', points: ['Time-lapse', 'Face mosaic', 'Pomodoro', 'Your year', 'Share with parents'], langs: '日本語 · English · 한국어 · 中文' },
  },
} satisfies Record<Lang, unknown>;
