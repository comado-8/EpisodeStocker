# 単体テスト実施計画（EpisodeStocker / XCTest）

## 概要
- 目的: 既存実装済み機能のうち、ロジック中心の単体テストを整備し、第三者が追跡可能な形式で結果を蓄積する。
- 方針: `XCTest` に統一し、機能単位でテスト結果を `docs/unit-test/results/` に記録する。
- 対象: `SwiftDataPersistence`、`SuggestionRepository`、`SuggestionManagerViewModel`、`SeedData`、`AppRouter`、`Episode.isUnlocked`。
- 非対象: SwiftUI の見た目・レイアウト検証（UIテスト/スナップショット）。

## 公開API / インターフェース変更
- アプリ本体の公開API変更は行わない。
- テスト基盤として以下を追加する。
1. `EpisodeStocker/EpisodeStockerTests/Support/TestModelContainerFactory.swift`
2. `EpisodeStocker/EpisodeStockerTests/Support/Eventually.swift`
3. `docs/unit-test/templates/result-template.md`

## 実施ステップ
1. テスト配置の正規化
2. ドキュメント基盤の作成
3. テスト共通基盤の作成
4. 機能別テストの実装
5. Xcodeで実行し結果を記録
6. 第三者レビュー可能状態に整備

## テストスイートとシナリオ
| Suite | 対象ファイル | 主シナリオ |
|---|---|---|
| `PersistenceNormalizationTests` | `SwiftDataPersistence` | `normalizeName`/`normalizeTagName` のtrim・`#`除去・空文字除外・小文字化 |
| `PersistenceUpsertTests` | `ModelContext` upsert群 | 同名再利用、論理削除からの復活、重複入力除去 |
| `EpisodeLifecycleTests` | `createEpisode`/`updateEpisode`/`softDeleteEpisode` | 作成反映、更新時`updatedAt`、論理削除時のUnlockLog連動 |
| `UnlockLogLifecycleTests` | `createUnlockLog`/`updateUnlockLog`/`softDeleteUnlockLog` | 追加・更新・論理削除、親Episode紐付け |
| `TagRelationTests` | `softDeleteTag`/`restoreTag` | 紐付け解除、復元時再紐付け、削除済みEpisode除外 |
| `SeedDataTests` | `SeedData.seedIfNeeded` | 初回投入、再実行時重複なし |
| `SuggestionRepositoryTests` | `InMemorySuggestionRepository` | fetch条件、ソート、upsert、softDelete/restore、usage更新 |
| `SuggestionManagerViewModelTests` | `SuggestionManagerViewModel` | query変更再取得、削除表示切替、undo動作 |
| `EpisodeModelTests` | `Episode.isUnlocked` | `unlockDate` の nil/過去/未来判定 |
| `AppRouterTests` | `AppRouter` | push/pop の経路更新 |

## 結果記録フォーマット（機能単位）
- 見出し: 実施日、実施者、ブランチ、コミット、Xcode版、実行先（Simulator/実機）。
- サマリ: `PASS/FAIL/BLOCKED` 件数。
- ケース表: `Case ID / 対象 / 手順 / 期待値 / 実結果 / 判定 / 証跡`。
- 不具合欄: 事象、再現手順、暫定回避、修正PRリンク。
- 追記ルール: 新しい実行結果を同一ファイル先頭に追加（時系列逆順）。

## 受け入れ基準
1. 上記10スイートが Xcode の `EpisodeStockerTests` で実行可能。
2. テスト結果が `docs/unit-test/results/*.md` に機能単位で記録済み。
3. 失敗ケースは `defects.md` と相互リンクされ、第三者が再現可能。
4. 既存機能のP0観点（作成/更新/論理削除/復元/検索）が網羅される。

## 前提・デフォルト
- 単体テスト範囲は「ロジック中心」。
- テスト基盤は `XCTest` に統一。
- 結果整理は「機能単位」。
- 配置先は `docs/unit-test/`。
- 既存の `SuggestionRepositoryTests` はターゲット配下へ移動して一本化。
