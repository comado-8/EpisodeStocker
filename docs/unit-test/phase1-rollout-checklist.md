# Phase 1 カバレッジ運用開始チェックリスト

## 対象
- `EpisodeStockerTests` に対して、Phase 1（baseline低下禁止）ゲートを導入し運用する。

## 1. PRバンドル（リポジトリ側）
- [x] 以下を1PRに含める:
  - `.github/workflows/episode-unit-tests.yml`
  - `EpisodeStockerTests/ViewModels/SuggestionManagerViewModelTests.swift`
  - `docs/unit-test/coverage-baseline.md`
  - `docs/unit-test/ci-gate-rules.md`
  - `docs/unit-test/results/*.md`

## 2. ブランチ保護確認（GitHub手動）
- [x] `Settings > Branches > main rule` を開く
- [x] 必須チェックに `episode-unit-tests` が含まれていることを確認
- [x] 必須チェック失敗時にマージ不可であることを確認

## 3. ダミーPR検証（手動）
- [x] `main` 向けにno-op PRを作成
- [x] `episode-unit-tests` が実行されることを確認
- [x] artifactに以下があることを確認:
  - `episode-unit-tests.xcresult`
  - `coverage-summary.md`

## 4. 回帰FAIL検証
- [x] ローカル疑似再現（baselineを意図的に上げる）でFAIL確認済み
- [ ] 任意: 実際に1ファイルのカバレッジを下げる小PRでCI FAILを確認

## 5. ドキュメント正本
- [x] 正本を `EpisodeStocker/docs/unit-test/` に統一
- [x] 毎回このパスを更新する運用に切替

## 6. 安定化期間
- [x] 導入後2〜3PRを追跡
- [x] 各PRで以下を確認:
  - `EpisodeStockerTests` がグリーン
  - coverage baseline gate がグリーン
  - 進捗: `3/3` PR確認済み（Phase 1導入PR + docs先行PR + Phase 2 CI report-only PR）
- [x] 安定化2件目のPRを記録（`phase1-stabilization-log.md`）
- [x] 安定化3件目のPRを記録（`phase1-stabilization-log.md`）
- [x] 3/3達成後、本セクションを完了に更新

## 7. 次フェーズ準備
- [x] Phase 2閾値案のドラフト作成
  - 全体目標
  - 変更ファイル目標
  - 例外ポリシー
- [x] docs先行のPhase 2 PRを作成して合意を取る（`phase2-docs-pr-template.md` を使用）
- [x] 合意後、CIに閾値ゲートを実装する（まず `report-only` モード）

## 8. 次アクション（Phase 2 強制化）
- [x] Week 2: `PHASE2_MODE=enforce-changed-files` に切替えるPRを作成
- [ ] Week 2: changed-files閾値違反を意図的に作り、CIがFAILすることを確認
- [ ] Week 3: `PHASE2_MODE=enforce-all` に切替えるPRを作成
- [ ] Week 3: overall logic閾値違反でCIがFAILすることを確認
