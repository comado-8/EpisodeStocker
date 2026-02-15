# Phase 2 強制化ログ

## 目的
Phase 2（閾値強制）の運用結果を、週次モード切替ごとに追跡する。

## 記録ルール
- 証跡は `coverage-summary.md`（GitHub Actions artifact: `episode-unit-tests-artifacts`）を正本とする。
- ローカル環境依存パスは記載しない。
- モード切替PRごとに1行追加する。

## 記録
| 日付 (JST) | フェーズ | モード | overall logic | changed-files | baseline gate | 判定 | メモ |
|---|---|---|---:|---:|---|---|---|
| 2026-02-14 | Week 1 | `report-only` | 95.14 | n/a (`(none)`) | PASS | PASS | 導入確認（閾値はレポートのみ） |
| 2026-02-14 | Week 2 | `enforce-changed-files` | 95.14 | n/a (`(none)`) | PASS | PASS | changed-files閾値強制を有効化 |
| 2026-02-14 | Week 3 | `enforce-all` | 95.14 | n/a (`(none)`) | PASS | PASS | overall logic閾値強制を有効化 |
| 2026-02-15 | Week 2 検証 | `enforce-changed-files` | 94.22 | 0.00 (`ios/Services/StorageService.swift`) | n/a (replay) | FAIL (expected) | 意図的にchanged-files閾値違反を作成し、ゲート失敗を確認 |
| 2026-02-15 | Week 3 検証 | `enforce-all` | 94.22 | n/a (`(none)`) | n/a (replay) | FAIL (expected) | overall logic閾値を95.00へ一時引き上げ、ゲート失敗を確認 |

## 現在の運用状態
- 現行モード: `enforce-all`
- 閾値:
  - `PHASE2_OVERALL_LOGIC_THRESHOLD=85.00`
  - `PHASE2_CHANGED_FILES_THRESHOLD=80.00`

## 2026-02-15 検証メモ
- 検証方法: CI `Coverage Threshold Gate (Phase 2)` と同等ロジックのreplayで負荷をかけずにFAIL挙動を確認。
- Week 2 検証: `enforce-changed-files` で changed-files 1件（`StorageService.swift` 0.00%）を入力し、`enforced_failures=1` / 終了コード `1` を確認。
- Week 3 検証: `enforce-all` で changed-files なし、overall logic閾値を `95.00` として `overall=94.22` の閾値違反を作り、`enforced_failures=1` / 終了コード `1` を確認。

## 次回追記テンプレート
| 日付 (JST) | フェーズ | モード | overall logic | changed-files | baseline gate | 判定 | メモ |
|---|---|---|---:|---:|---|---|---|
| YYYY-MM-DD | Week N | `mode` | xx.xx | xx.xx / n/a | PASS/FAIL | PASS/FAIL | 補足 |
