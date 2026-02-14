# Defects / Blockers

## 2026-02-14 (Coverage Baseline Run)

- FAIL: 0
- BLOCKED: 0
- xcresult: `/tmp/episode-unit-tests-phase1-final.xcresult`

## 2026-02-13 (Remediation Run)

| ID | ステータス | 内容 | 対応 |
|---|---|---|---|
| FAIL-001 | RESOLVED | `EpisodeLifecycleTests.testSoftDeleteEpisodeAlsoSoftDeletesUnlockLogs` | `isDeleted`衝突回避のため SwiftDataモデルの削除フラグを `isSoftDeleted` に変更し、関連ロジックを更新 |
| FAIL-002 | RESOLVED | `PersistenceUpsertTests.testUpsertTagReusesExistingAndRevivesDeleted` | `upsertTag` 復活時に `isSoftDeleted=false` と `deletedAt=nil` を確実に反映 |
| FAIL-003 | RESOLVED | `UnlockLogLifecycleTests.testSoftDeleteUnlockLogMarksFlags` | `isSoftDeleted` への統一で soft delete 状態反映を安定化 |
| FAIL-004 | RESOLVED | `TagRelationTests.testRestoreTagRelinksOnlyNonDeletedEpisodes` | `Tag` に `@Relationship(inverse: \Episode.tags)` を追加し、復元対象リンクを安定化 |
| FAIL-005 | RESOLVED | `TagRelationTests.testSoftDeleteTagUnlinksOnlyActiveEpisodes` | 同上（Tag/Episodeの多対多関係を明示化） |

## 実行証跡
- 全件PASS実行: `/Users/yumiko/Library/Developer/Xcode/DerivedData/EpisodeStocker-euwbeebtjfvsfycxelxoxfzllkbe/Logs/Test/Test-EpisodeStocker-2026.02.13_23-33-35-+0900.xcresult`
- 修正確認実行: `/Users/yumiko/Library/Developer/Xcode/DerivedData/EpisodeStocker-euwbeebtjfvsfycxelxoxfzllkbe/Logs/Test/Test-EpisodeStocker-2026.02.13_23-32-54-+0900.xcresult`
