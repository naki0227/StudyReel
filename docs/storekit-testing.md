# StoreKit Testing

StudyReel Pro uses these product IDs:

- `com.ni.StudyReel.pro.monthly`
- `com.ni.StudyReel.pro.yearly`

## App Store Connect

1. Open `App Store Connect`.
2. Create a subscription group named `StudyReel Pro`.
3. Add two auto-renewable subscriptions with the product IDs above.
4. Make sure `Agreements, Tax, and Banking` is completed.

Full copy for product names, descriptions, prices, and review notes:

- See [app-store-connect-pro.md](/Users/nagaseibuki/Documents/github-repos/naki0227/StudyReel/docs/app-store-connect-pro.md)

### Suggested price

- Monthly: `300 JPY`
- Yearly: `2,000 JPY`

### Suggested display names

- `StudyReel Pro Monthly`
- `StudyReel Pro Yearly`

### Suggested descriptions

- Monthly:
  `Unlock deeper study stats, subject-based comparisons, and stronger weekly insights with StudyReel Pro.`
- Yearly:
  `Get the full StudyReel Pro experience for a year with deeper stats, subject analysis, and future export and backup features.`

### Suggested Japanese copy

- Monthly:
  `教科別の比較、詳細な統計、週ごとの深い振り返りを StudyReel Pro で使えるようにします。`
- Yearly:
  `詳細な統計、教科別分析、今後の書き出し・バックアップ機能まで、1年分まとめて StudyReel Pro を使えます。`

## Local Development

For simulator and UI checks, the app includes a DEBUG-only Pro simulator:

1. Open the paywall from `Settings > StudyReel Pro` or `studyreel://paywall`.
2. Tap `開発テストを表示`.
3. Tap `開発用にProを有効化`.

This unlock is only for DEBUG builds and is stored locally on the device or simulator.

## Optional Xcode StoreKit Config

If you also want full StoreKit purchase simulation in Xcode:

1. Create a new `StoreKit Configuration File` in Xcode.
2. Add the same two product IDs as subscriptions in the `StudyReel Pro` group.
3. Open `Product > Scheme > Edit Scheme...`.
4. In `Run > Options`, select that StoreKit configuration file.

After that, purchases can be tested in the simulator without using the real App Store.
