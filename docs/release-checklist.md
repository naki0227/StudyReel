# Release Checklist

Current target version in the project:

- Version: `1.3`
- Build: `205`

## Before Archive

1. Run the app on a real device.
2. Open the paywall and confirm monthly and yearly plans appear.
3. Confirm Pro-locked stats are locked before purchase.
4. Confirm `Restore Purchases` is visible.
5. Check Japanese and English once.

## Archive

1. Open `StudyTimerAndVideo.xcodeproj` in Xcode.
2. Select `Any iOS Device (arm64)` or your physical iPhone.
3. Choose `Product > Archive`.
4. Wait for Organizer to open.

## Upload

1. In Organizer, select the latest archive.
2. Click `Distribute App`.
3. Choose `App Store Connect`.
4. Choose `Upload`.
5. Keep automatic signing defaults unless Xcode shows a specific problem.
6. Finish the upload.

## App Store Connect

1. Open the new app version.
2. In `アプリ内購入とサブスクリプション`, add:
   - `StudyReel Pro Monthly`
   - `StudyReel Pro Yearly`
3. Save the version page.
4. Submit the app version for review.

## Good Release Notes Draft

- JA:
  `英語対応を進め、学習統計と記録まわりを改善しました。StudyReel Pro に対応し、より深い学習分析を使えるようになりました。`
- EN:
  `Improved English support, study statistics, and session flows. StudyReel Pro is now supported for deeper study insights.`
