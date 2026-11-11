// 2.0 時点のアプリ紹介 PV の文言。アップデートの紹介ではなく、はじめて見る人に向けたアプリ紹介。
// 宣伝文句らしくしない。友達に「このアプリこういうの」と話すくらいの言い方で
import type { Lang } from './copy';

export const COPY20 = {
  ja: {
    kind: '勉強記録アプリ', can: 'でできること',
    agenda: ['顔を隠して勉強を撮る', '休憩つきで集中する', '動画を編集して、時刻を飾る', 'クエストでジェムをためる', '1年分を色で残す'],
    sec: ['顔を隠して撮る', '休憩つきで集中', '編集して飾る', 'クエスト', '1年分を色で残す'],
    mosaic: { t: ['顔はモザイクで', '隠せます'], s: '顔を出さずに、そのまま勉強垢に載せられる', before: 'そのまま', after: 'モザイク' },
    pomo: { t: ['25分やったら', '5分休憩'], s: '休憩の間は撮影も止まる。動画には集中した時間だけ', rest: '休憩', round: '1回目の集中、おつかれさまでした', hint: 'スマホから少し離れて、遠くを見たり水を飲んだりしましょう', siri: '「StudyReelで勉強を始める」' },
    edit: { t: ['カットして、', '時刻を飾る'], s: 'フィルターや音楽も。自分で書いた数字でも', tools: ['カット', 'フィルター', 'BGM'], styles: ['いつもの', '色', '飾り', '手書きの数字'] },
    quest: { t: ['クエストで', 'ジェムをためる'], s: 'テーマや時刻の飾りと交換できる', head: 'クエスト', gems: 'ジェム', items: ['1日の目標を決める', '教材を1つ登録する', 'タイムラプスを1本保存する', '3日続けて記録する'], reward: '時刻の飾り：星', exchange: '30 ジェムで交換', owned: '交換しました' },
    year: { t: ['1年分が', '色で埋まっていく'], s: 'カードにして、そのまま投稿できる', head: '今年 勉強した日', unit: '日', total: '合計 412時間', streak: '週に1日休んでも、連続は途切れない', tag: '#勉強垢' },
    end: { kind: '勉強記録アプリ', store: 'App Store で無料', points: ['タイムラプス', '顔にモザイク', 'ポモドーロ', '編集と時刻の飾り', 'クエスト', '1年の草'], langs: '日本語 · English · 한국어 · 中文' },
  },
  en: {
    kind: 'A study log app', can: 'Here’s what it does',
    agenda: ['Film yourself, face hidden', 'Focus with breaks', 'Edit it, style the clock', 'Clear quests, earn gems', 'See your whole year'],
    sec: ['Face hidden', 'Focus with breaks', 'Edit & style', 'Quests', 'Your whole year'],
    mosaic: { t: ['Your face gets', 'a mosaic'], s: 'Post your study videos without showing your face', before: 'As shot', after: 'Mosaic' },
    pomo: { t: ['25 minutes on,', '5 minutes off'], s: 'Filming pauses on breaks, so the video is all focus', rest: 'Break', round: 'Focus session 1 done. Nice work', hint: 'Step away from your phone — look out the window or grab some water', siri: '“Start studying with StudyReel”' },
    edit: { t: ['Trim it,', 'style the clock'], s: 'Filters and music too — even your own handwritten digits', tools: ['Trim', 'Filter', 'Music'], styles: ['Classic', 'Color', 'Decoration', 'Your digits'] },
    quest: { t: ['Clear quests,', 'earn gems'], s: 'Trade them for themes and clock styles', head: 'Quests', gems: 'gems', items: ['Set a daily goal', 'Add a study material', 'Save your first time-lapse', 'Study 3 days in a row'], reward: 'Time decoration: Stars', exchange: 'Exchange for 30 gems', owned: 'Exchanged' },
    year: { t: ['Watch your year', 'fill in'], s: 'Post it as a card', head: 'Days studied this year', unit: ' days', total: '412 h in total', streak: 'One rest day a week won’t break your streak', tag: '#studygram' },
    end: { kind: 'A study log app', store: 'Free on the App Store', points: ['Time-lapse', 'Face mosaic', 'Pomodoro', 'Edit & clock styles', 'Quests', 'Your year'], langs: '日本語 · English · 한국어 · 中文' },
  },
} satisfies Record<Lang, unknown>;
