# Persistence Feature Results

## 実施情報（最新）
- 実施日: 2026-02-14 18:37 JST
- 実施者: Codex
- ブランチ: `main`
- コミット: `d0bd63f`（実行時HEAD）
- Xcode: `26.2 (17C52)`
- 実行先: iOS Simulator `iPhone 16 (id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5)`
- 実行コマンド: `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:EpisodeStockerTests -enableCodeCoverage YES -resultBundlePath /tmp/episode-unit-tests-phase1-final.xcresult`

## サマリ（最新）
- PASS: 17
- FAIL: 0
- BLOCKED: 0
- Coverage:
  - `SwiftDataPersistence.swift 94.04% (300/319)`
  - `SeedData.swift 95.65% (22/23)`

## ケース結果（最新）
| Case ID | 対象 | 期待値 | 実結果 | 判定 | 証跡 |
|---|---|---|---|---|---|
| PERSIST-001 | Persistence系6スイート | 作成/更新/削除/復元/検索/seedの仕様を満たす | 17/17 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence` |

## 不具合・課題（最新）
- なし（既知FAIL-001〜005は解消済み）。
- xcresult: `/tmp/episode-unit-tests-phase1-final.xcresult`

## 実施情報（前回）
- 実施日: 2026-02-13 23:33 JST
- 実施者: Codex
- ブランチ: `main`
- コミット: `665d419`（実行時HEAD）
- Xcode: `26.2 (17C52)`
- 実行先: iOS Simulator `iPhone 16 (id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5)`
- 実行コマンド: `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:EpisodeStockerTests`

## サマリ
- PASS: 17
- FAIL: 0
- BLOCKED: 0

## ケース結果
| Case ID | 対象 | 期待値 | 実結果 | 判定 | 証跡 |
|---|---|---|---|---|---|
| PERSIST-001 | PersistenceNormalizationTests | 正規化ロジックが仕様どおり | 4/4 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence/PersistenceNormalizationTests.swift` |
| PERSIST-002 | PersistenceUpsertTests | upsert/復活/重複排除を満たす | 3/3 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence/PersistenceUpsertTests.swift` |
| PERSIST-003 | EpisodeLifecycleTests | 作成/更新/削除の仕様を満たす | 3/3 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence/EpisodeLifecycleTests.swift` |
| PERSIST-004 | UnlockLogLifecycleTests | 解禁ログ追加/更新/削除を満たす | 3/3 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence/UnlockLogLifecycleTests.swift` |
| PERSIST-005 | TagRelationTests | タグ紐付け解除/復元が仕様どおり | 2/2 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence/TagRelationTests.swift` |
| PERSIST-006 | SeedDataTests | 初回投入と重複防止を満たす | 2/2 pass | PASS | `EpisodeStocker/EpisodeStockerTests/Persistence/SeedDataTests.swift` |

## 不具合・課題
- FAIL-001〜FAIL-005 は解消済み（`docs/unit-test/results/defects.md` 参照）。
- xcresult: `/Users/yumiko/Library/Developer/Xcode/DerivedData/EpisodeStocker-euwbeebtjfvsfycxelxoxfzllkbe/Logs/Test/Test-EpisodeStocker-2026.02.13_23-33-35-+0900.xcresult`
