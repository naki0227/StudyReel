# CI の担当

| ワークフロー | 何を確かめる・作る | いつ走る |
| --- | --- | --- |
| `build.yml` | コンパイルが通るか（署名なし） | すべての PR、main への push |
| `layout-check.yml` | 横向きのセーフエリア、目標まわりの画面（UI テストとスクリーンショット） | 画面の見た目が変わる PR だけ（Views、ContentView、文言、Assets、色・テーマ、デモの中身） |
| `appstore.yml` | App Store の文言・審査提出（PR では dry-run） | `appstore/`、`tools/appstore/` が変わったとき |
| `store-shots.yml` | ストア用スクリーンショット | コミットに `[store-shots]`、または手動 |
| `preview.yml` | App プレビュー動画 | コミットに `[preview]`、または手動 |
| `review-shot.yml` | 審査用スクリーンショット | コミットに `[review-shot]`、または手動 |
| `commercial.yml` | 宣伝用の録画 | コミットに `[commercial]`、または手動 |
| `cloudkit-schema.yml` | `docs/cloudkit/schema.ckdb` を CloudKit の開発環境に取り込む（本番への反映は Console で） | コミットに `[cloudkit-schema]`、または手動 |
| `testflight.yml` | TestFlight へのアップロード | 手動 |
| `certs.yml` | 証明書の整理 | 手動 |

- 中身の処理だけを変えた PR（Models、通信、保存など）は `build.yml` だけが走る。画面の確認はしない
- 画面の確認が要るのに自動で走らないときは、Actions から `Layout check` を手動で動かす
- 撮影系（`[store-shots]` など）はキーワードを付けたときだけ。付けない push では「skipped」になる
