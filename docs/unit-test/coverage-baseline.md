# カバレッジベースライン（Phase 1）

## ベースライン実行
- 日付: 2026-02-14
- コマンド: `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:EpisodeStockerTests -enableCodeCoverage YES -resultBundlePath /tmp/episode-unit-tests-phase1-final.xcresult`
- 結果バンドル: `/tmp/episode-unit-tests-phase1-final.xcresult`

## 指標
| Metric ID | 対象 | Baseline (%) | Gate |
|---|---|---:|---|
| app_overall | EpisodeStocker.app | 14.45 | no |
| file_swiftdata_persistence | ios/Services/SwiftDataPersistence.swift | 94.04 | yes |
| file_suggestion_repository | ios/Services/InMemorySuggestionRepository.swift | 100.00 | yes |
| file_suggestion_manager_viewmodel | ios/ViewModels/SuggestionManagerViewModel.swift | 100.00 | yes |
| file_seed_data | ios/Services/SeedData.swift | 95.65 | yes |
| file_app_router | ios/ViewModels/AppRouter.swift | 100.00 | yes |
| file_episode_model | ios/Models/Episode.swift | 96.43 | yes |

## 注意
- Phase 1でブロックするのは `Gate=yes` の指標のみ。
- このファイルは「意図的にbaselineを引き上げるとき」だけ更新する。
