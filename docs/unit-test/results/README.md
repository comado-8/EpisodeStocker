# Results Index

- `feature-persistence.md`: SwiftData永続化関連（正規化、upsert、作成/更新/削除、タグ関係、SeedData）
- `feature-suggestion.md`: サジェストリポジトリ関連
- `feature-viewmodel.md`: ViewModel関連
- `feature-router-model.md`: Router/Episodeモデル関連
- `defects.md`: FAIL/BLOCKEDの横断管理

## 記録ルール
1. 実行結果は各機能ファイルの先頭に追加（新しい順）。
2. FAIL/BLOCKED は `defects.md` に同時登録。
3. 証跡列には、最低1つの再現可能な参照（ログ抜粋、PR、スクリーンショット）を記載。
4. `-enableCodeCoverage YES` 実行時は、対象機能のカバレッジ値も同時記録する。
