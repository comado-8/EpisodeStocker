# 運用更新PRテンプレート（コマンド付き）

## 1) 作業ブランチ作成
```bash
cd /Users/yumiko/development/EpisodeStocker/EpisodeStocker
git checkout main
git pull origin main
git checkout -b chore/unit-test-ops-update
```

## 2) 変更をステージング
```bash
git add docs/unit-test
```

## 3) コミット
```bash
git commit -m "docs: 単体テスト運用ドキュメントを日本語化しPhase2草案を追加"
```

## 4) push
```bash
git push -u origin chore/unit-test-ops-update
```

## 5) PRタイトル例
- `docs: 単体テスト運用ドキュメントを日本語化しPhase2草案を追加`

## 6) PR本文テンプレート（貼り付け用）
```md
## 概要
- `EpisodeStocker/docs/unit-test/` の運用ドキュメントを日本語化
- Phase 1運用チェックリストの進捗を更新
- `coverage-summary.md` を `results/*.md` / `defects.md` に反映
- Phase 2閾値案 (`phase2-threshold-draft.md`) を追加

## 変更ファイル
- `docs/unit-test/ci-gate-rules.md`
- `docs/unit-test/coverage-baseline.md`
- `docs/unit-test/phase1-rollout-checklist.md`
- `docs/unit-test/phase1-stabilization-log.md` (new)
- `docs/unit-test/phase2-threshold-draft.md` (new)
- `docs/unit-test/pr-ops-template.md` (new)
- `docs/unit-test/results/*.md`

## 確認事項
- ドキュメント正本は `EpisodeStocker/docs/unit-test/`
- CI設定やアプリコードには影響なし（ドキュメント更新中心）

## 次アクション
- 安定化ログを2〜3PR分ためる
- Phase 2 docs先行PRで閾値合意後、CI実装へ進む
```
