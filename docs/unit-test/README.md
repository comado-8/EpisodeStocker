# 単体テストドキュメント

このフォルダは EpisodeStocker の単体テスト計画と実施結果を、第三者が追跡できる形で管理するためのドキュメントです。

## 構成
- `plan.md`: 単体テスト実施計画（対象範囲、方針、受け入れ基準）
- `phase1-rollout-checklist.md`: カバレッジPhase 1運用開始チェックリスト
- `phase1-stabilization-log.md`: Phase 1安定化期間（2〜3PR）の追跡ログ
- `phase2-enforcement-log.md`: Phase 2（閾値強制）の週次運用ログ
- `phase2-threshold-draft.md`: Phase 2閾値運用のドラフト
- `phase2-docs-pr-template.md`: Phase 2 docs先行PRテンプレート
- `templates/result-template.md`: 実施結果を記録する標準テンプレート
- `results/`: 機能単位の実施記録

## 運用ルール
1. テスト実行ごとに、該当機能の `results/*.md` 先頭へ結果を追記する（新しい順）。
2. FAIL/BLOCKED は `results/defects.md` にも記録し、相互リンクする。
3. 証跡（Xcodeログ、スクリーンショット、再現手順）を必ず残す。
