# StudyReel 市場・ユーザーの声 調査レポート

調査日: 2026-10-25 / 調査方法: App Store 公式ページ、App Store レビュー RSS（`https://itunes.apple.com/{国}/rss/customerreviews/page={n}/id={id}/sortby=mostrecent/json`）、iTunes Search API、Web 検索・記事本文の取得。

> 注意: App Store のレビューは RSS で取得できた直近分（1アプリあたり最大約100件）だけを見ています。appfigures / Sensor Tower / AppTweak の公開ページはログインが必要なものが多く、今回はレビュー本文の取得には使っていません。数字の出どころはそれぞれの項目に書きました。

---

## 0. 競合の現状（2026-10 時点、iTunes Search API）

| アプリ | 国 | 評価数 | 価格 | 備考 |
|---|---|---|---|---|
| StudyReel (id6756177589) | JP | 1 | 無料＋Pro 月¥300／年¥2,000、1週間トライアル | Pro: ロゴなし動画、フォント、顔スタンプ、BGM4曲、テーマ色、週比較 |
| FocusLapse (id6756807803) | JP | 220（4.6） | 完全無料・広告なし・アカウント不要 | 9言語対応。US ストアでは評価8件 |
| Latent (id6788947658) | US | 194（4.9） | 無料 | ポモドーロ、カメラオフ、ヒートマップ、友達フィード、kudos |
| Focus Labs: Study Timelapse (id6760441355) | US | 5 | 無料 | 新規参入 |
| 勉強タイムラプス時計 (id6768336180) / StudyLapse (id6790072440) | JP | 2 / 0 | 無料 | 新規参入が続いています |
| Studyplus | JP | 340,538 | 無料＋「有料版 ベーシック」¥600／¥4,800 | 累計会員1,000万人超（2025年6月） |
| 集中（id1387759250） | JP | 133,338 | 無料 | |
| StudyCast | JP | 13,714 | 無料 | 自習室ルーム、AI 質問 |
| YPT / 열품타 | KR 48,432 / JP 5,046 / US 1,775 | 無料＋月¥400〜¥800、年¥5,000、Unlock Apps ¥150 など | |
| Forest | JP 10,753 / KR 15,965 | 無料＋Plus 月¥680、年¥3,690〜¥4,100、クリスタル課金 | 2025年12月に買い切りからサブスクへ移行 |
| Study Bunny | US 21,835 | 無料（広告多め） | |
| Focus Town | JP 1,704 | 無料＋課金 | どうぶつの森風の見た目 |

出典: https://apps.apple.com/jp/app/id6756177589 , https://apps.apple.com/jp/app/id6756807803 , https://apps.apple.com/us/app/id6788947658 , https://apps.apple.com/jp/app/id1441909643 , https://apps.apple.com/jp/app/id505410049 , https://apps.apple.com/jp/app/id866450515 , iTunes Search API（https://itunes.apple.com/search?term=study%20timelapse&country=us&entity=software）

**ポイント:** 「勉強タイムラプス」は2026年に入ってから新しいアプリが次々に出ている分野です。FocusLapse は「無料・広告なし・データ収集なし・日本製」で信頼を得ています。Latent は SNS 型の友達機能で伸びています。StudyReel の独自の強みは、どちらにもない**自動顔モザイク**です。

---

## 1. ユーザーの声（レビューの原文引用）

### 1-1. 顔を隠したい（StudyReel の中心機能に需要があるという証拠）
- FocusLapse ★5「ダウンロードをして良かった」（中3の受験生、2026-10-11）: 「たまに顔が写っていたりしていてそこだけが困ります。…顔が写らないようにモザイクをつけられるようにしてくれれば嬉しいです。」
- FocusLapse ★5「いい‼️‼️‼️けど…」（2026-09-01）: 「顔にモザイクがかかるようにしてくれると嬉しいです😭…写真に入れようとしたら自分の顔がふっっつーに写ってるのが…違和感でしかなくて」
- Bilibili の study with me 配信では「顔を出さずに勉強する」スタイルが主流とされています（中国 SA 圏の分析記事、2021-09）: https://www.woshipm.com/it/5129472.html
- 出典（FocusLapse レビュー）: https://itunes.apple.com/jp/rss/customerreviews/page=1/id=6756807803/sortby=mostrecent/json

→ 一番大きい競合のユーザーが、**StudyReel がすでに持っている機能**を求めています。まだ伝わっていないだけなので、ストアページと SNS でこの点をはっきり打ち出すのが最優先です。

### 1-2. 録画が止まる・保存時の不具合・クラッシュ（長時間録画が信頼できるか）
- FocusLapse ★3「小さなバグ？がきになる」（2026-10-16）: 「撮影の終了後、保存が完了しました！と出たあと、どこもタップできなくなります。…アナログ時計③を選択しているのに、累計の勉強時間が入っておらず…せっかく長時間勉強してあとから見返した際にガッカリします。」
- FocusLapse ★4「録画の再開はどうすればいいですか？」（2026-02-14）: 「録画中に別のアプリを開いた際、録画は停止されますが、再びこのアプリを開いた後、どう操作すれば録画を再開できますか？」
- FocusLapse ★5（2026-09-01）: 「動画を撮ってる途中に自分がもうやーめた‼️…違うアプリを起動してしまうんです」（離脱を防ぐ仕組みがほしいという要望）
- Lapse It ★1「Buggy and unreliable」（2026-10-17）: "I was looking for a time lapse app capable of pausing for me to take breaks… It'll randomly force close itself without warning, so it didn't record a good chunk footage."
- Lapse It ★1「Crashed at the last moment」: "The app crashed at the very last moment and didn't save the project… 5 hours of work lost"
- Lapse It ★1「Don't trust it for over 5 min」: "Timed out after 5 min. The app shut down."
- Timelapse by ReeLapse ★1（2025-05）: "on a timelapse with over an hour of footage it just deleted everything when I tried to save it."
- TomoStudy ★1（2026-10-18）: 「iPadで表示してますが、今日だけでカメラをオンにしてすぐに10回以上フリーズしました。」
- 出典: https://itunes.apple.com/us/rss/customerreviews/page=1/id=539108382/sortby=mostrecent/json , https://itunes.apple.com/us/rss/customerreviews/page=1/id=6476781335/sortby=mostrecent/json , https://itunes.apple.com/jp/rss/customerreviews/page=1/id=6747420037/sortby=mostrecent/json

→ **長時間録画を最後まで確実に保存できること**が、このジャンルで一番の不満の原因になっています。途中経過の自動保存、クラッシュ後の復旧、離脱後のワンタップ再開が評価の差になります。

### 1-3. 発熱・バッテリー
- Studyplus ★5（2026-10-02）: 「測ってる時に画面つけてたらスマホがめっちゃ熱くなるから、そこ直してほしいです。」
- Focus Town ★4「Phone Overheats」（2026-08-19）: "uses a lot of my battery and makes my phone overheat."
- Focus Town ★5（2026-07-28）: 「充電の減りがはやいT᎔T」
- StudyCast ★4（2026-10-09）: 「スリープ時に鳴りません。デバイスがスリープをしないように設定すると、充電の減りが早くなる」
- 逆に良い評価の例: Latent ★5 "doesn't take up any storage or for the most part your battery"、★5 "it saves battery too!"
- 出典: https://itunes.apple.com/jp/rss/customerreviews/page=1/id=505410049/sortby=mostrecent/json , https://itunes.apple.com/jp/rss/customerreviews/page=1/id=6758457625/sortby=mostrecent/json , https://itunes.apple.com/us/rss/customerreviews/page=1/id=6788947658/sortby=mostrecent/json

→ Latent は「バッテリーと容量に優しい」と**レビューに書かれて**います。StudyReel も熱・電池・容量への配慮を機能として作り、文言でも伝えるべきです。

### 1-4. 容量
- Lapse It ★2「Can't delete videos」: "Videos take up a lot of space and are hard to delete."
- Lapse It ★3: "Great app but takes a lot of storage… after 7 videos, under 5 minutes, it too[k]…"
- FocusLapse ★5「神！」: 「タイムラプスをiPhoneのカメラロールに保存しなくてもアプリ内で集中時間と共に確認できるので便利」

### 1-5. 動画の長さ・倍率・時計の表示
- FocusLapse ★5「子供の自走に最適」（親、2026-07-24）: 「iPhone標準のカメラについているタイムラプスでは30分の学習でも…3時間の学習でも倍率が変わって同じ30秒前後の動画になってしまいます…60倍にすれば1分が1秒で実時間をそのまま動画時間に換算でき」
- FocusLapse ★5「まじでいい！」: 「2時間のやつを2分とにまとめれるからまじで最高！」
- FocusLapse ★4「結構良い」: 「時計？みたいなやつを…個人的にはいらないかな…時計もオンオフ機能があれば良いな」
- FocusLapse ★5「助かる」: 「後から記録したタイマーのデザインを変更できたら便利」
- FocusLapse ★5「広角カメラ」: 「広角に出来ないんですか？」
- ReeLapse ★3: "The native Apple Time Lapse feature will only let you shoot 30 second videos in automatic settings."
- Lapse It ★1「Why the logo」: "there is a 'lapse it' logo… I don't like the logo it looks trash."（無料版の透かしが嫌われている例）

### 1-6. 音・BGM
- StudyCast ★4（2026-08-11）: 「BGM機能の提案をしたところ…数日後に即反映してくれた」／★5（2026-07-13）: 「勉強用のbgmを足して欲しいです」
- Focus Town ★3: 「曲が少ない。パソコンの音や筆記音もバックグラウンド再生されるようになって欲しい。」
- Study Bunny ★4: "there is no sound and you'll have to unlock music from coins"、★3: "I also don't like that it pauses my music."
- Forest JP ★1: 「bgm買えなくなり改悪。毎月の課金金額も高すぎる。」
- YPT JP ★3: 「音楽を聴きながらできなくなりました…開いたまま電源を落とすと消えてしまいます」
- YPT KR ★3: MacBook で YPT を起動していると AirPods の音が途切れるという報告
→ 環境音は**ユーザーの音楽アプリと同時に鳴らせること**（audio session の mix 設定）が必須です。基本の数曲は無料にしておくのが無難です。

### 1-7. 横画面・iPad
- Studyplus ★4「iPhoneでも横画面になって欲しい」: 「横置きにしてタイマーを確認したい この点のみ不満」
- Forest JP ★4「横画面対応して欲しい」: 「タイマー起動中に横画面に対応いていないこと」
- Studyplus ★4: 「iPadでアプリが立ち上がらないです」
- Forest JP ★1: 「iPhoneだとアプリブロック無料なのにiPadだと有料になるのはなぜだ」
- TomoStudy: 「スマホを手元に置きたくないのでiPadで表示してます」（iPad を勉強中のカメラとして使う需要）
- FocusLapse ★5: 「撮影中カメラの向いてる向きが変えれない」

### 1-8. ポモドーロ・休憩
- YPT JP ★4「ポモドーロ機能」: 「ポモドーロ終了後アラーム音をならすような機能…複数回ポモドーロを繰り返した後の長い休憩の設定 自動で休み時間に切り替わる機能」
- YPT JP ★3: 「apple watchでの計測(課金コンテンツ)はカウントアップタイマー形式のみで、カウントダウンやポモドーロ機能が使えません」
- Forest JP ★1: 「フォーカスが終わったあとちゃんと通知音とかバイブとかなるようにしてほしい(あるいは休憩時間が勝手に始まるようにする)」
- Lapse It ★1: "looking for a time lapse app capable of pausing for me to take breaks"（休憩中は録画を止めたいという需要。計画中の機能と一致しています）

### 1-9. 手動記録・カメラなしの記録
- YPT JP ★4/★3/★4（2026-09〜10、3件）: 「手動入力もグループ内で反映させてくれたら嬉しいです。学校での勉強などでスマホが使えない時は記録ができない」「グループ長をやってるのですが、ほんとはやっているかも知れない人を退会させたくない」
- YPT KR ★3: 朝4時50分からの勉強が前日分として記録されるという報告（「1日の区切り」を自分で設定したい）。Studyplus ★4 にも「1日の区切りを自分で設定できると」とあります。
- Focus Town ★4: "a feature that lets me log my records later on!"

### 1-10. 友達・仲間機能
- Latent ★2「How?」: "How do I get the code if I don't know any friends who use the app?"
- YPT JP ★5: 「グループに一人も入ってこないのが悲しい😭」
- Latent ★5: "makes me want to study and beat the people in my groups times"
- Studyplus ★5: 「友達が勉強してるのがわかるので自分もやらなきゃ！」／★4: 「友達同士で勉強時間のランキングが見られると」
- Studyplus ★5: 「達成報告がプロフィールのすぐ下に出る仕様に変わってしまって、自分が落ちたのに他の子は受かった英検とかがすぐ出てきてしんどい」（比較されすぎる疲れ）
- 台湾の報道（天下雜誌 換日線）: YPT の勉強グループに最低勉強時間があり、「沒上線會被踢群（オンラインにならないとグループから外される）」というプレッシャーが不安につながっているとのことです: https://crossing.cw.com.tw/article/15062
- FocusLapse ★5「まじでいい！」: 「みんなで取ってグルラ（グループLINE）に送るようになってからめっちゃモチベ上がった！」→ **10秒モザイク動画を仲間に送る**計画を後押しする行動がすでに見られます。

### 1-11. 広告・課金への反発
- Study Bunny（直近の★1〜★4が多数）: "There's so many ads"、"I will literally pay to get rid of the ads."、"every time I open the app, there's an ad."
- YPT US ★1: "full ads right on the front page every time I open it. It completely ruins my focus"／YPT JP ★1: 「課金して広告を消せるようにして欲しい」／★4: 「アプリロックが有料になっちゃって」
- Forest US ★1「Stop asking for money」: "a lot of users are probably students who [shouldn't] be pressured into paying… Trend analysis as tags aren't exactly special features that should be behind a paywall."／★1: "pop ups after pop ups"／JP ★1: 「有料で買ったのにさらにサブスクを要求される」
- Forest・YPT・Focus Town・Study Bunny で「AI 生成の絵や広告が嫌だ」というレビューが複数あります（Forest US ★3 "Too much AI"、YPT KR ★4「Ai디자인 좀 구림」、Focus Town ★3 "AI infested"）。
- Lilo ★1: "Bro imma student who got no cards. Yet I wanna challenge my friends without paying."
- 出典: https://itunes.apple.com/us/rss/customerreviews/page=1/id=1478345385/sortby=mostrecent/json , https://itunes.apple.com/us/rss/customerreviews/page=1/id=866450515/sortby=mostrecent/json , https://itunes.apple.com/jp/rss/customerreviews/page=1/id=1441909643/sortby=mostrecent/json , https://itunes.apple.com/us/rss/customerreviews/page=1/id=6752133930/sortby=mostrecent/json

### 1-12. 親の利用
- FocusLapse ★5（親）: 「小学生の子供たちが喜んで動画を撮りながら学習に取り組み、学習した成果を後から誇らしげに動画で見せてくれるので、監視してなくても集中して学習に向かう事ができるようになりました。」
- StudyCast ★5（親）: 「娘が…塾のお友達にもこのアプリを教えて一緒にルーム（部屋）を作って」
→ StudyReel の保護者・塾への共有機能には需要があります。ただし「監視」ではなく「子どもが誇らしく見せる」という見せ方が受けています。

---

## 2. 勉強垢・study with me の投稿文化

### 日本
- 週刊アスキー（2021-12-28）「高校生に大人気の『タイムラプス勉強法』が凄い！」: 手元・ノート・**時計を画角に入れる**のが基本の型です。Instagram・TikTok で人気で、投稿5.5万件以上、TikTok で880万回以上再生とのことです。Discord や通話で友達と一緒に勉強する文化にも触れています。 https://weekly.ascii.jp/elem/000/004/078/4078895/
- 週刊アスキー（2023-01-25）: 「ちょっと前に中高生の間で流行った」と過去形で書かれています。撮影中はスマホを触れないことと、記録として残ることが効果の理由とされています。 https://weekly.ascii.jp/elem/000/004/121/4121878/
- 週刊アスキー（2020）: TikTok の「#勉強垢」が3億3000万回再生、「#男子勉強垢」が270万回再生。スマホを固定して撮り、デジタルやアナログの時計を映して時間の流れを見せるのが定番です。男子はモノトーンでシンプルな画づくりが多いとされています。 https://weekly.ascii.jp/elem/000/004/010/4010781/
- 進学ネット（高校生エディター54人へのアンケート）: タイムラプス勉強法を「知ってる」61.1%、そのうち「やったことがある」25.9%。 https://shingakunet.com/journal/exam/20201003000006/
- 朝日学生新聞社×アルクテラスの調査（2017、中高生1,328人）: 3割が勉強専用アカウントを持っています。使い道は「質問」「記録」「モチベーション」。 https://resemom.jp/release/prtimes/20170731/33851.html
- Studyplus は累計会員1,000万人を突破（2025年6月末）。Studyplus トレンド研究所の調査では、消費のきっかけになった SNS は中学生が YouTube、高校生が Instagram でした。 https://dime.jp/genre/1398474/
- レビューの言葉づかい: 「よそゆきの自分」「監視されている感じ」「夜に上がっているようなタイムラプス動画」（FocusLapse）。US では "lock in"、"performative or… accountable"（Latent）。**見られている感覚**と**人に見せられる自分**の2つが動機になっています。

### よく見る型（複数の情報源からの整理）
- 画角: 真上か斜め上から、手元・ノート・時計を映します。顔は映さないか切ります。
- 長さ: 1〜3時間を15〜60秒（Reels/TikTok）か1〜2分（LINE・YouTube Shorts）にまとめます。「2時間→2分」（60倍）は換算しやすいので好まれます。
- 画面に重ねる情報: 経過時間か累計の勉強時間、日付、科目、「Day ◯」「受験まであと◯日」。
- YouTube の study with me: 50分集中＋10分休憩のポモドーロにタイマーを重ね、雨音・lo-fi・鳥の声、または「音楽なし」の版を出すのが定番です（例: "4-HOUR POMODORO STUDY WITH ME / 50/10 Pomodoro (with timer) / Birds Chirping, No Music"）。 https://videohighlight.com/v/n0CSlkPybTc , https://gridfiti.com/best-study-with-me-videos/
- 起源: 韓国の「공방（공부 방송＝勉強配信）」とされています。 https://arcadiaquill.com/28991/features/the-rise-of-study-with-me-videos

### ハッシュタグ（地域ごと）
| 地域 | 主なタグ | 根拠 |
|---|---|---|
| JP | #勉強垢 #勉強垢さんと繋がりたい #タイムラプス勉強 #男子勉強垢 #受験生 #studygram #studywithme | アスキー（#勉強垢 3.3億再生） |
| KR | #공스타그램（国内 Instagram の1位ハッシュタグという記事あり） #공스타 #열품타 #공부인증 #캠스터디 #03공스타그램 など生年や学年つき | https://www.careet.net/4 , https://www.allurekorea.com/2022/09/14/새학기부터-갓생러로-살아보자/ |
| TW | #讀書帳 #讀書紀錄 #學測 #統測 #studygram | 104 Podcast（学測生 IG 1.4万フォロワー、統測生 YT 2.7万登録）: https://blog.104.com.tw/?p=185335 |
| CN | #学习打卡 #study account（抖音・快手で累計約47億再生） #studywithme #自习 #SA | https://www.woshipm.com/it/5129472.html |

---

## 3. 韓国・台湾・中国の事情

### 韓国（캠스터디・열품타）
- 열품타（YPT）は2018年11月にリリースされ、KR App Store で評価48,432件と最大手です。科目別ストップウォッチ、自動プランナー、スタディグループ、グループメンバーが勉強中か休憩中かをカメラやアイコンで見る機能があります。 https://apps.apple.com/kr/app/id1441909643 , https://thewiki.kr/w/열카
- 캠스터디: Zoom やグルーミ（Gooroomee）などのビデオ会議で一緒に勉強する文化です。グルーミにはストップウォッチでの記録機能もあります。勉強の YouTube ライブ配信（공부 브이로그）も広まっています。 https://www.localnaeil.com/News/View/646015 , https://m.seoul.co.kr/news/2021/04/19/20210419016003
- 열품타 KR の直近レビューでは「タイムラプスを通じて外から自分を見る視線のような映像を見ることにも誇らしさを感じる」（★5、2026-10-17）とあり、**YPT 自体にタイムラプス機能が入っている**ことがわかります。韓国では、タイムラプスに加えて「顔モザイク」と「仲間への短い動画」で差をつける必要があります。
- 不満の多くは、許可アプリの誤判定、1日の区切りが4時固定であること、グループの手動記録、通知設定のバグ、AI デザインです（KR RSS）。 https://itunes.apple.com/kr/rss/customerreviews/page=1/id=1441909643/sortby=mostrecent/json
- 韓国語のマーケティング語彙: 「갓생」「공스타」「열공」「공부 인증」。

### 台湾
- YPT は図書館が閉まったコロナ禍に台湾の学生の間で広まりました。グループの最低勉強時間による「踢群」のプレッシャーが報じられています（天下雜誌 換日線）。 https://crossing.cw.com.tw/article/15062
- 讀書帳（IG の勉強アカウント）を経営する学測生・統測生は、IG と YouTube を両方使っています。 https://blog.104.com.tw/?p=185335
- 繁体字 UI では「讀書帳」「學測倒數」「讀書紀錄」の言葉を使うと伝わりやすいです。

### 中国本土
- Bilibili の study with me（学习直播）: 2019年に146万時間配信され、CEO が「最も長時間視聴されたライブカテゴリ」と発言しました（China Daily）。2020年3月には配信114万時間、視聴1,820万時間以上。 https://global.chinadaily.com.cn/a/201910/04/WS5d963f0aa310cf3e3556eb55.html , https://www.woshipm.com/it/5129472.html
- 配信者は**顔を出さずに**手元を映す人が多く、視聴者は「云同桌（オンラインの隣の席）」として参加します。動機は監督してもらうこと、仲間探し、誰かと一緒にいる感覚です（学術論文）。 https://deepai.org/publication/from-study-with-me-to-study-with-you-how-activities-of-study-with-me-livestream-on-bilibili-facilitate-srl-community
- 寮や家が狭くうるさいことが、オンライン自習室が受ける背景とされています。 https://www.sixthtone.com/news/1011964
- 中国の番茄钟アプリ「小律」は「延时摄影 Vlog 视频打卡」を中心機能として売っています。**タイムラプスで打卡（勉強の記録を毎日投稿）する形式は中国でも商品として成立**しています。 https://apps.apple.com/cn/app/id6448206193
- 注意: 中国本土の App Store では配信・課金の条件（ICP など）が別にあります。zh-Hans の主な市場は、まず海外にいる中国語話者、シンガポール、マレーシアと考えるのが現実的です。小红书・抖音は日本から運用するのが難しいため、優先度は TW と KR より下です。

---

## 4. 収益化の目安

### 競合の課金（App Store JP の表記）
- Studyplus: 「有料版 ベーシック」¥600（月）／¥4,800（年と推定）。基本機能（記録、教材、グラフ、仲間）は無料です。 https://apps.apple.com/jp/app/id505410049 ／ プレミアムは月¥980という記載もあります（第三者サイト）: https://appmatch.jp/505410049-3/
- YPT: 月¥400／月プレミアム¥800／年¥5,000／6か月券¥2,000／12か月券¥3,000／Unlock Apps ¥150／仮想通貨「炎」。レビューからは、広告の削除、アプリロック、Apple Watch での計測が有料だとわかります。 https://apps.apple.com/jp/app/id1441909643
- Forest: Plus 月¥680、年¥3,690〜¥4,100（早期割引）。Plus の特典はコイン3倍、限定の木、季節の木の先行公開、本物の木の植樹です。2025年12月に買い切りからサブスクに変わり、反発が強く出ています。 https://apps.apple.com/jp/app/id866450515 , https://makeheadway.com/blog/forest-app-review/
- TomoStudy: 無料は1日1時間までで、超えると「勝手に終了した時は萎えます」という声があります。一方で「課金して大正解」という★5もあります。
- **StudyReel の月¥300／年¥2,000 は、競合と比べて安い方**です。値上げよりも、トライアルの見せ方と Pro の中身を良くする方が効果が大きいと考えます。

### 業界の数字
- RevenueCat State of Subscription Apps 2026（Education カテゴリ）: ダウンロードから30日以内にトライアルを始める割合の中央値6.5%。トライアル開始の78.5%がダウンロード当日。有料転換のうち当日分は28.5%（どのカテゴリより低い）。トライアルの50.3%が5〜9日。年額の中央値$44.99（カテゴリで最も高い）、月額の中央値$9.99。14日目のインストールあたり収益$0.30。1年後の課金者あたり実現 LTV $22.82。年額プランを選ぶ人が多い（59〜66%のグループ）。 https://www.revenuecat.com/state-of-subscription-apps-2026-education
- RevenueCat 全カテゴリ: 最初に課金を求めるハードペイウォールは35日目の課金率10.7%で、フリーミアムの2.1%の約5倍です。17日以上のトライアルは42.5%が有料になり、4日以下の25.5%より高いです（5〜9日は37.4%）。3日トライアルの解約の55%は初日に起きます（7日トライアルでは39.8%）。アジア太平洋のトライアルから有料への転換は31.9%。日本向けに縦長スクロールのペイウォールにしたら US 型より20%以上良かったという事例もあります。 https://www.revenuecat.com/state-of-subscription-apps
- Adapty 2026（RocketShip HQ のまとめ）: Education はトライアル開始率64%、トライアルから有料55%、月額中央値$12.99、年額$79.99、年額を選ぶ割合48%。ペイウォールを「価値を感じた直後」に出すとトライアル開始率65%、アプリ起動時だと31%（全カテゴリ）。 https://www.rocketshiphq.com/?p=5390

### 無料と有料の分け方の傾向（レビューから）
- **受け入れられやすい有料機能**: 見た目（テーマ、フォント、キャラ、木の種類）、ロゴを消す、詳しい分析、コイン増加、追加の BGM、植樹のような社会貢献。
- **反発されやすい有料化**: もともと無料だった機能を有料にすること（Forest の許可リスト、YPT のアプリロック）、勉強を邪魔する広告、繰り返し出るポップアップ、友達との競争やチャレンジ（学生はカードを持っていない）、トレンドやタグの基本分析。
- 学生はカードを持っていないことが多いので、**親が払う**（ファミリー共有、保護者向けの価値の説明）か、**年額を一度だけ買う**導線が効きやすいと考えます。

---

## 5. 小さな勉強アプリで効いた伸ばし方

- **クリエイター発の拡散**: Latent のレビューに "i found ts app off of eddie's instagram"（★5、2026-10-13）とあり、Instagram の発信者経由で伸びたことがわかります。Hank Green の Focus Friend は、本人の TikTok 発信を中心に公開1か月で US 無料ランキング1位（2025年8月）になりました。 https://appfigures.com/resources/insights/20250905/amp?f=1 , https://www.ypulse.com/newsfeed/2025/08/26/young-people-are-loving-hank-greens-focus-friend-app-that-encourages-less-screen-time/
- **SNS で知ったという声**: FocusLapse ★4「SNSに通じて入れてみた」、Study Bunny ★5 "shoutout to study to success for introducing me"（YouTuber 経由）。
- **友達内でのクチコミ**: StudyCast「中間テスト後に友達から誘われて」「塾のお友達にもこのアプリを教えて」、Studyplus「友達におすすめされて」。一方で Latent の「招待コードがわからない」は、**招待が前提だと離脱が起きる**ことを示しています。
- **書き出し動画のロゴ（透かし）**: CapCut のエンドカードやテンプレのロゴは拡散の仕組みと説明されることが多いですが、公式の数字はありません。Lapse It ではロゴが嫌われています。小さく上品なロゴやアプリ名、後ろに付ける1秒のカードが落としどころです。 https://www.swellai.com/blog/how-to-get-rid-of-the-capcut-logo
- **App Store のアプリ内イベント（In-App Events）**: 日本の Tao Shopping はイベントが Today タブで紹介され、ダウンロードが10倍になりました。Phiture の検証ではイベント期間中に表示回数と初回ダウンロードが50%以上増えました。同時に5件まで、1件あたり最大4週間、事前告知2週間まで設定できます。 https://www.apptweak.com/en/case-studies/how-tao-shopping-optimized-user-acquisition-with-in-app-events , https://phiture.com/asostack/in-app-events/ , https://kurve.co.uk/ios-in-app-events
- **キャンパスアンバサダー**: a16z は「ネットワーク効果を立ち上げる手段として広告より安い」としています。高校では校内での勧誘がしにくいため、日本では塾や部活単位の「グループ招待」に置き換えるのが現実的です。 https://future.a16z.com/college-ambassador-program-how-to-for-startups/
- **プロダクトページの最適化（PPO）**: 複数の情報源で、スクリーンショット1枚目の訴求のテストが基本の施策とされています。今回は小規模アプリでの公開された数字は見つかりませんでした。

---

## 6. StudyReel への提案（優先度順・15項目）

凡例: 【計画中】は計画中の機能と重なるもの、【新規】は計画リストにないもの、【一部】は一部が重なるものです。

1. **「顔が映らない勉強タイムラプス」を App Store・SNS の一番目立つ場所で打ち出し、PPO でテストする**【新規・マーケ】
   根拠: FocusLapse のユーザーが2件、顔モザイクを求めています（1-1）。FocusLapse も Latent もこの機能を持っていません。中国の study with me も顔を出さないのが主流です。スクリーンショット1枚目を「顔モザイク前後」の比較にし、「顔出しなしで勉強垢に投稿」をキャッチコピーにして、「時計重ね」訴求との PPO を回すことを提案します。

2. **長時間録画の信頼性を作り込む（途中経過の自動保存、クラッシュ後の復旧、離脱後のワンタップ再開、保存後のフリーズ対策）**【新規】
   根拠: FocusLapse の保存後フリーズと時計の欠落、Lapse It の「5時間分が消えた」「5分で落ちる」、ReeLapse の「1時間超で全部消えた」、FocusLapse の「再開方法がわからない」（1-2）。数分ごとに区切って書き出しておき、復帰時に「続きから録画」を出す設計にすれば、★1レビューの原因になる事故をなくせます。

3. **ポモドーロ（休憩中は録画を自動で止める）、休憩終了の音とバイブ、長い休憩の設定、休憩への自動切り替え**【計画中】
   根拠: YPT・Forest のレビューで通知音と自動切り替えの要望（1-8）、Lapse It の "pausing for me to take breaks"。YouTube の 50/10 という定番に合わせて、プリセットを25/5・50/10・90/15にすることを提案します。休憩時間を動画上で「☕ 休憩10分」のカードにすると、見た目の演出にもなります。

4. **カメラなしの記録（手動入力・あとから入力）を仲間・グループの集計にも同じ扱いで反映し、1日の区切り時刻を選べるようにする**【計画中＋新規の細部】
   根拠: YPT JP で同じ要望が3件（学校ではスマホを使えない）。YPT KR と Studyplus で1日の区切りの要望。Focus Town の "log my records later"（1-9）。「カメラなし」マークは付けつつ、仲間の画面で不利にならない設計にします。

5. **熱・電池・容量への配慮を機能と文言の両方で用意する**（録画中に画面を暗くする、熱が上がったら自動でフレームを間引く、充電中の警告、元動画の自動削除や容量表示）【新規】
   根拠: Studyplus・Focus Town・StudyCast の発熱や電池の不満、Latent の「容量も電池も食わない」という高評価、Lapse It の容量不満（1-3, 1-4）。ストア文言に「3時間録画でも電池◯%」のような実測値を載せると差別化になります。

6. **9:16 縦型（Reels/TikTok）書き出しのプリセット、「1分→1秒」換算モード、時計の表示切り替えと後からのデザイン変更、累計時間の表示**【新規】
   根拠: FocusLapse の「60倍で実時間換算」「2時間→2分」「時計オンオフ」「後からデザイン変更」の声（1-5）。アスキーによる「時計を映す」定番の型（2章）。15秒・30秒・60秒の長さ指定と自動倍率も入れます。

7. **仲間への「10秒モザイク動画」を LINE などに送りやすい形でも書き出す**【計画中】
   根拠: FocusLapse の「みんなで撮ってグルラに送る」（1-10）。アプリ内の仲間機能だけでなく、LINE や Instagram ストーリーへ直接共有できる形（小さなロゴ入り）にすると、そのまま招待の経路にもなります。

8. **招待コードなしでも仲間が見つかる「公開もくもくルーム」（志望校、試験、学年、言語別）を作る。比較疲れへの配慮もする**【新規】
   根拠: Latent の「友達がいないとコードがない」、YPT の「グループに誰も入ってこない」（1-10）。チャットなし・承認制の安全な設計は保ちつつ、「今同じ試験を勉強している人数」だけを見せる匿名の場を作ります。Studyplus の「達成報告がしんどい」や台湾の「踢群」の不安を踏まえて、最低時間ノルマやランキングは任意にします。

9. **年間ヒートマップの共有カード＋月間 vlog＋「受験終了／合格の日」まとめ動画**【計画中（ヒートマップ・月間 vlog）＋新規（受験まとめ）】
   根拠: Latent がヒートマップを持っています。勉強垢の「記録」文化（2章）。FocusLapse 親レビューの「成果を後から誇らしげに見せてくれる」。共通テスト明けや3月の合格発表に合わせた「受験の全記録」動画は、最も拡散されやすい瞬間です。

10. **アプリ内イベントを受験カレンダーに合わせて毎月出す**（定期テスト期間、夏休み100時間チャレンジ、共通テスト直前、英検・TOEIC・資格試験の直前、韓国の수능、台湾の學測）【新規】
    根拠: Tao Shopping が日本で10倍、Phiture の検証で50%以上の伸び、同時5件・最大4週間の枠（5章）。お金がかからないストア露出なので、評価数が1件の今こそ効きます。

11. **環境音（雨、カフェ、図書館、筆記音、lo-fi）をユーザーの音楽と同時に鳴らせるようにし、基本の数曲は無料にする**【計画中】
    根拠: StudyCast と Focus Town の BGM 要望、Study Bunny の「音楽が止まる」「コインで解放」不満、Forest の BGM 有料化への反発、YPT の「音楽を聴きながらできない」（1-6）。録画した動画に環境音を BGM として焼き込めるようにすると、study with me らしい見た目になります。

12. **集中モード、コントロールセンター、Siri、ロック画面、Live Activity からの開始と、終了通知（スリープ中も確実に鳴る）**【計画中】
    根拠: StudyCast の「スリープ時にタイマーが鳴らない」、Forest の「終了時に通知音を」（1-8）。FocusLapse の「途中で別アプリを開いてしまう」には、集中モードとの連携と「離脱したら録画が止まる」ことの可視化で対応します。

13. **横画面と iPad を「勉強カメラ」として使う体験を整える**（iPad で録画して iPhone はしまう、横向き書き出し、広角の0.5倍カメラ）【新規】
    根拠: Studyplus・Forest の横画面要望、TomoStudy の「iPhone を手元に置きたくないので iPad」、FocusLapse の「広角にできないんですか」（1-7, 1-5）。StudyReel はすでに iPad に対応しているので、すぐ打ち出せる差別化です。

14. **課金の方針: 広告は出さない。録画・記録・仲間・顔モザイクという核は無料のまま。Pro は見た目、分析、長尺 vlog、保護者・塾向けに。ペイウォールは最初の動画を保存した直後に出す。年額を前面に出し、親が払う導線を作る**【新規・方針】
    根拠: Study Bunny・YPT・Forest の広告や有料化への強い反発、Lilo の「学生はカードがない」（1-11）。Adapty の「価値を感じた直後に出すとトライアル開始率が65%、起動時だと31%」。RevenueCat の Education は年額が多く、トライアル5〜9日が多数派。17日以上のトライアルの方が有料転換が高いので、今の1週間トライアルと「14日（年額のみ）」を比べるテストを提案します。日本向けには縦長スクロールのペイウォールも試す価値があります。

15. **書き出し動画の小さなロゴ＋1秒のエンドカード（「顔モザイクで撮れる StudyReel」）と、勉強垢クリエイターへの提供・紹介特典**【一部（ロゴを消す機能は既存の Pro 特典）＋新規】
    根拠: Latent が Instagram の発信者経由で伸びたこと、Focus Friend が TikTok で1位になったこと、Lapse It のロゴが「ダサい」と嫌われていること（5章、1-5）。ロゴは小さく上品にし、エンドカードは無料でも外せる形にすると、反発を抑えつつ拡散の経路を残せます。日本・韓国・台湾の勉強垢（フォロワー数千〜数万人）10〜20人に Pro を無償提供し、紹介した人とされた人の両方に Pro 1か月を付けることを提案します。

### 補足（15項目に入れなかったもの）
- **AI 生成の絵や広告は使わない**: Forest、YPT、Focus Town で反発が出ています。手描きやオリジナルのスタンプの方が好まれます。
- **データを集めないことを明記する**: FocusLapse は「データの収集はなしとのことで、安心して使えます。日本製のアプリなのも嬉しい」と評価されています。StudyReel の顔モザイクが端末内で処理されるなら、そのことをストアに書くべきです。
- **ローカライズの言葉**: KR は「공스타 인증용 타임랩스」「얼굴 모자이크」、TW は「讀書帳」「學測倒數」、zh-Hans は「学习打卡」「延时摄影」「不露脸」をキーワードに入れることを提案します。
