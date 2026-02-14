# Phase 2 閾値運用ドラフト

## 目的
「baseline非回帰」運用から、明示的な閾値ゲート運用へ移行する。

## スコープ
- CI対象は引き続き `EpisodeStockerTests`。
- 分母はロジック中心のまま（`ios/Views/**` はゲート対象外）。

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

## 未決事項
- 「ロジックファイル」の対象パターン確定
- PRサイズが小さい場合の免除有無
- 生成コードの除外有無
