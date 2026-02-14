# Phase 2 docs先行PRテンプレート

## 目的
Phase 2（閾値運用）の仕様合意を、CI実装より先にドキュメントだけで行う。

## 1) 作業ブランチ作成
```bash
cd /path/to/EpisodeStocker
git checkout main
git pull origin main
git checkout -b docs/phase2-threshold-agreement
```

## 2) 変更対象（最小セット）
- `docs/unit-test/phase2-threshold-draft.md`
- `docs/unit-test/phase1-rollout-checklist.md`（進捗更新がある場合）
- `docs/unit-test/phase1-stabilization-log.md`（追記がある場合）

## 3) ステージングとコミット
```bash
git add docs/unit-test/phase2-threshold-draft.md docs/unit-test/phase1-rollout-checklist.md docs/unit-test/phase1-stabilization-log.md
git commit -m "docs: Phase2カバレッジ閾値運用案を確定"
git push -u origin docs/phase2-threshold-agreement
```

## 4) PRタイトル例
- `docs: Phase2カバレッジ閾値運用案を確定`

## 5) PR本文テンプレート
```md
## 概要
- Phase 2（閾値運用）の仕様をドキュメントで確定
- ロジック対象パターン、閾値、例外運用、段階導入スケジュールを明文化
- CI実装は本PRでは行わない（次PRで対応）

## 変更点
- `docs/unit-test/phase2-threshold-draft.md`
- （必要に応じて）`docs/unit-test/phase1-rollout-checklist.md`
- （必要に応じて）`docs/unit-test/phase1-stabilization-log.md`

## 合意したい項目
1. overall logic coverage: `>= 85.00%`
2. changed-files logic coverage: `>= 80.00%`
3. 例外運用（Issue/Owner/失効日必須）
4. 段階導入（Week1 report-only → Week2 changed-files必須 → Week3 overall必須）

## 本PRの非対象
- `.github/workflows/episode-unit-tests.yml` のCI実装変更
- 閾値fail条件の実コード化
```

## 6) マージ後の次PR
- ブランチ例: `ci/phase2-threshold-gate`
- 対象: `.github/workflows/episode-unit-tests.yml`
- 目的: 上記合意内容をCIに実装
