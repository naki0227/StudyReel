# StoreKit Testing

StudyReel Pro uses these product IDs:

- `com.ni.StudyReel.pro.monthly`（自動更新・1週間無料）
- `com.ni.StudyReel.pro.yearly`（自動更新・1週間無料）
- `com.ni.StudyReel.pro.lifetime`（非消耗型）

## App Store Connect

1. Open `App Store Connect`.
2. Create a subscription group named `StudyReel Pro`.
3. Add the monthly and yearly auto-renewable subscriptions and the lifetime non-consumable with the product IDs above.
4. Make sure `Agreements, Tax, and Banking` is completed.

Full copy for product names, descriptions, prices, and review notes:

- See [app-store-connect-pro.md](app-store-connect-pro.md)

## Local Development

For simulator and UI checks, the app includes a DEBUG-only Pro simulator:

1. Open the paywall from `Settings > StudyReel Pro` or `studyreel://paywall`.
2. Tap `開発テストを表示`.
3. Tap `開発用にProを有効化`.

This unlock is only for DEBUG builds and is stored locally on the device or simulator.

## Optional Xcode StoreKit Config

If you also want full StoreKit purchase simulation in Xcode:

1. Create a new `StoreKit Configuration File` in Xcode.
2. Add the monthly and yearly IDs as subscriptions in the `StudyReel Pro` group (with a 1-week free introductory offer), and the lifetime ID as a non-consumable.
3. Open `Product > Scheme > Edit Scheme...`.
4. In `Run > Options`, select that StoreKit configuration file.

After that, purchases can be tested in the simulator without using the real App Store.
