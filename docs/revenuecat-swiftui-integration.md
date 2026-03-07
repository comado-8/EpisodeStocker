# RevenueCat SwiftUI Integration (EpisodeStocker)

このドキュメントは、EpisodeStocker への RevenueCat 統合手順と実装ポイントをまとめたものです。

## 1. Swift Package を追加

Xcode で `EpisodeStocker.xcodeproj` を開き、以下を追加:

1. `File` > `Add Package Dependencies...`
2. URL: `https://github.com/RevenueCat/purchases-ios-spm.git`
3. `Up to Next Major Version` を選択
4. Product に `RevenueCat` と `RevenueCatUI` を追加
5. Target は `EpisodeStocker` を選択

公式: <https://www.revenuecat.com/docs/getting-started/installation/ios#install-via-swift-package-manager>

## 2. RevenueCat Dashboard 側の設定

1. Entitlement を作成: `EpisodeStocker Pro`
2. Products を作成:
   - Monthly: App Store product ID `comado.studio.episodestocker.pro.monthly`
   - Yearly: App Store product ID `comado.studio.episodestocker.pro.yearly`
3. Offering を作成:
   - Offering ID: `default`
   - Package:
     - `monthly` -> Monthly product
     - `yearly` -> Yearly product
4. Paywall を作成し `default` Offering に紐付け
5. 必要に応じて Customer Center を有効化

## 3. API キー設定

公開 SDK キーはコード直書きせず、以下の優先順で解決します。

1. 実行時環境変数 `REVENUECAT_API_KEY`
2. `Info.plist` 注入値 `REVENUECAT_API_KEY`（`xcconfig` 経由）

平文ファイルを置きたくない場合は、`xcconfig` は空にしたまま `Scheme > Run > Environment Variables` で `REVENUECAT_API_KEY` を注入できます。
ただし、Scheme の環境変数は **Xcode から起動したローカル実行時のみ有効** で、Archive / TestFlight / App Store ビルドには含まれません。
本番配布向けには `xcconfig` / Build Configuration / `Info.plist` 注入などのビルド時設定、または安全なキー管理を使って注入してください。
必要なら値は macOS Keychain で管理し、起動前に環境変数へ読み込む運用にします。
`xcconfig` を使う場合の手順:

1. `Config/RevenueCat.xcconfig.example` をコピーして以下を作成:
   - `Config/RevenueCat.Debug.xcconfig`
   - `Config/RevenueCat.Release.xcconfig`
2. 各ファイルで `REVENUECAT_API_KEY` を設定:

```xcconfig
REVENUECAT_API_KEY = your_revenuecat_public_sdk_key
```

3. `EpisodeStocker` target の Debug/Release は以下の base config を利用:
   - `Config/RevenueCat.Debug.base.xcconfig`
   - `Config/RevenueCat.Release.base.xcconfig`
4. `Info.plist` には `INFOPLIST_KEY_REVENUECAT_API_KEY = $(REVENUECAT_API_KEY)` で注入
5. `RevenueCat.Debug.xcconfig` / `RevenueCat.Release.xcconfig` は Git 非管理（`.gitignore` 済み）
6. CI は GitHub Secrets に登録して注入:
   - `REVENUECAT_API_KEY_DEBUG`
   - `REVENUECAT_API_KEY_RELEASE`

`ios/Services/RevenueCatConfig.swift` は「環境変数 → Bundle.main」の順で取得:

```swift
enum RevenueCatConfig {
    static let apiKeyInfoPlistKey = "REVENUECAT_API_KEY"
    static var publicAPIKey: String { ... }
    static let proEntitlementID = "EpisodeStocker Pro"
    static let defaultOfferingID = "default"
    static let monthlyPackageID = "monthly"
    static let yearlyPackageID = "yearly"
}
```

## 4. 初期化（App 起動時）

`ios/Services/RevenueCatBootstrap.swift` と `ios/EpisodeStockerApp.swift` で起動時に configure:

```swift
RevenueCatBootstrap.configureIfNeeded()
```

## 5. 課金サービス実装（SubscriptionService）

`ios/Services/RevenueCatSubscriptionService.swift`:

- `getOfferings()` で monthly/yearly を取得
- `purchase(package:)` で購入
- `restorePurchases()` で復元
- `getCustomerInfo()` で顧客情報取得
- Entitlement `EpisodeStocker Pro` で `SubscriptionStatus` を判定

`ios/Services/SubscriptionServiceFactory.swift`:

```swift
enum SubscriptionServiceFactory {
    static func makeService() -> SubscriptionService {
        #if canImport(RevenueCat)
        if RevenueCatConfig.hasPublicAPIKey {
            RevenueCatBootstrap.configureIfNeeded()
            return RevenueCatSubscriptionService()
        }
        #endif
        return StoreKitSubscriptionService()
    }
}
```

`#if canImport(RevenueCat)` はコンパイル時ガードであり、ランタイムON/OFFではありません。
この実装では「RevenueCatモジュールが利用可能」かつ「`REVENUECAT_API_KEY` が設定済み」のときだけ RevenueCat を使い、キー未設定時は StoreKit 実装へフォールバックします。

## 6. SwiftUI 連携

### 6.1 サブスク画面
`ios/Views/SettingsView.swift` (`SubscriptionSettingsView`):

- 月額/年額購入
- 復元
- RevenueCat Paywall 表示（`PaywallView`）
- Customer Center 表示（`CustomerCenterView`）

### 6.2 Entitlement チェック（EpisodeStocker Pro）
`ios/ViewModels/PremiumAccessViewModel.swift`:

- 起動時に `fetchStatus()`
- `hasAccess(to:)` で有料機能を判定
- 無料プランの 50 件制限もここで判定

## 7. エラーハンドリング方針

- Offering 不在: `offeringNotFound`
- Product 不在: `productNotFound(productID:)`
- 顧客情報欠落: `customerInfoUnavailable`
- 購入キャンセル: `userCancelled`
- 購入保留: `pending`

UI では `errorMessage` に表示し、購入失敗時の理由をユーザーに返す。

## 8. ベストプラクティス

1. API キーは `xcconfig + CI Secret` で注入し、コードへ直書きしない。
2. 権限制御は `Entitlement` ベースで統一する。
3. 購入後・復元後は必ず `CustomerInfo` から状態を再評価する。
4. Paywall と Customer Center の導線は設定画面に常設する。
5. SDK 未導入時に壊れないよう `#if canImport(RevenueCat)` を使う。

## 9. 参考リンク

- Installation: <https://www.revenuecat.com/docs/getting-started/installation/ios#install-via-swift-package-manager>
- Purchases / CustomerInfo: <https://www.revenuecat.com/docs/customers/customer-info>
- Paywalls: <https://www.revenuecat.com/docs/tools/paywalls>
- Customer Center: <https://www.revenuecat.com/docs/tools/customer-center>
