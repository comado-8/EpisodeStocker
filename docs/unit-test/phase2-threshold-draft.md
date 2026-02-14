# Phase 2 閾値運用ドラフト

## 目的
「baseline非回帰」運用から、明示的な閾値ゲート運用へ移行する。

## スコープ
- CI対象は引き続き `EpisodeStockerTests`。
- 分母はロジック中心のまま（`ios/Views/**` はゲート対象外）。

## ロジック対象パターン（確定）
- include:
  - `ios/Services/**/*.swift`
  - `ios/ViewModels/**/*.swift`
  - `ios/Models/**/*.swift`
- exclude:
  - `ios/Views/**`
  - `EpisodeStockerTests/**`
  - `EpisodeStockerUITests/**`
  - `docs/**`

## 閾値案
1. ロジック全体カバレッジ: `>= 85.00%`
2. 変更ファイル（ロジック）のカバレッジ: `>= 80.00%`
3. Phase 1のbaseline指標は引き続き `>= baseline`

## 失敗条件
- 変更対象ロジックファイルが80.00%未満
- ロジック全体が85.00%未満
- カバレッジレポート欠落または解析失敗
- Phase 1指標のbaseline回帰

## 例外ポリシー
- 一時例外を許可する場合は必須:
  - Issue ID
  - Owner
  - 失効日
  - 理由と緩和策
- 失効後の例外はCI失敗として扱う。

## CIフロー案
1. `-enableCodeCoverage YES` でテスト実行
2. `xccov` でカバレッジ抽出
3. Phase 1 baselineチェック適用
4. Phase 2閾値チェック適用
5. `coverage-summary.md` と changed-files summary をartifact保存

## 段階導入案
1. Week 1: レポートのみ（failさせない）
2. Week 2: changed-files >= 80.00% を必須化
3. Week 3: overall logic >= 85.00% を必須化

## 実装状況
- CIにはPhase 2判定ステップを追加済み。
- 現在は `PHASE2_MODE=enforce-changed-files` で運用中。
- `enforce-changed-files` では、変更対象ロジックファイルの閾値違反と解析エラー（parse fail）をCI失敗として扱う。

## 追加運用ルール（確定）
- PRサイズが小さい場合の免除: なし（最初は一律適用）
- 生成コードの除外:
  - 現時点では生成コードなし（対象外設定は不要）
  - 将来 `Generated/` 等を導入した場合は除外対象へ追加する

## 次の実行タスク（確定）
1. Week 2: `PHASE2_MODE=enforce-changed-files` を有効化
2. Week 2: changed-files閾値違反のFAIL挙動を検証
3. Week 3: `PHASE2_MODE=enforce-all` を有効化
4. Week 3: overall logic閾値違反のFAIL挙動を検証
