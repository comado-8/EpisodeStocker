# 単体テスト運用ルール（CIゲート）

正本: `docs/unit-test/`

## 目的
- `EpisodeStockerTests` を常時グリーンに保ち、永続化・検索・ルーティングの回帰を防ぐ。

## ローカル実行ルール
1. push前に以下を実行する。
   - `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -only-testing:EpisodeStockerTests`
   - `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -only-testing:EpisodeStockerTests -enableCodeCoverage YES -resultBundlePath /tmp/episode-unit-tests-coverage.xcresult`
2. テスト失敗時はマージしない。コードまたはテストデータを修正する。
3. 実行結果を `docs/unit-test/results/*.md` に記録する。

## 手動実行タイミング
- 手動ローカル実行は次のときだけ行う。
  - PR作成前
  - `coverage-baseline.md` 更新時
  - CI失敗の切り分け時

## CIゲート（必須）
1. CIは `EpisodeStockerTests` のみ実行する。
2. マージ条件:
   - テスト終了コードが `0`
   - `FAIL = 0`
   - チケットなしのskip禁止（`XCTSkip` はissueリンク必須）
3. CI失敗時はPRをブロックする。

## カバレッジルール（段階導入）
- Phase 1（現行）: ベースライン確立 + 低下禁止
- ベースライン正本（CI参照）: `docs/unit-test/coverage-baseline.md`
- 分母ルール: ロジック中心（`ios/Views/**` はゲート対象外）
- Phase 1失敗条件:
  - いずれかのゲート指標で `現在値 < baseline`
  - `xccov` 出力から baseline指標を抽出できない
- Phase 2: 閾値導入（正本はCI変数）。`PHASE2_OVERALL_LOGIC_THRESHOLD=85.00`、`PHASE2_CHANGED_FILES_THRESHOLD=80.00` を基準とする。※「全体 >= 70%」は旧推奨値で、現行は85.00へ更新済み。

## Phase 2 実装モード（CI）
- `PHASE2_MODE=report-only`:
  - 閾値判定をレポート出力のみ行う（失敗にしない）
  - parse failは記録対象のみ（`report-only` ではブロッキングしない）
- `PHASE2_MODE=enforce-changed-files`（現行）:
  - 変更対象ロジックファイルの閾値違反を失敗扱い
  - parse failも失敗扱い
- `PHASE2_MODE=enforce-all`:
  - 変更対象ロジック + overall logic の両方を失敗扱い

## Phase 2 切替順（運用）
1. Week 2: `PHASE2_MODE=enforce-changed-files`
2. Week 3: `PHASE2_MODE=enforce-all`

## 安定化期間
- 導入後2〜3PRを追跡する。
- 各PRの必須確認:
  - `episode-unit-tests` がPASS
  - `coverage-summary.md` artifact が生成されている
  - baseline回帰なし

## Phase 1ゲート指標
- `SwiftDataPersistence.swift`
- `InMemorySuggestionRepository.swift`
- `SuggestionManagerViewModel.swift`
- `SeedData.swift`
- `AppRouter.swift`
- `Episode.swift`
- `EpisodeStocker.app`（情報用。Phase 1ではブロッキング対象外）

## 例外運用
- flaky testを許容する場合は以下を必須とする。
  - issue/ticket ID
  - owner
  - 失効日
- 失効後の例外はCI失敗として扱う。
