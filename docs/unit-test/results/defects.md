# Defects / Blockers

## 2026-02-14 (CI Coverage Gate / follow-up)

- FAIL: 0
- BLOCKED: 0
- 実行元: GitHub Actions `episode-unit-tests`
- 証跡: `episode-unit-tests-artifacts (1)/coverage-summary.md`

## 2026-02-14 (CI Coverage Gate)

- FAIL: 0
- BLOCKED: 0
- 実行元: GitHub Actions `episode-unit-tests`
- 証跡: `episode-unit-tests-artifacts/coverage-summary.md`

## 2026-02-14 (Coverage Baseline Run)

- FAIL: 0
- BLOCKED: 0
- xcresult: `<RESULT_BUNDLE_PATH>`

## 2026-02-13 (Remediation Run)

| ID | ステータス | 内容 | 対応 |
|---|---|---|---|
| FAIL-001 | RESOLVED | `EpisodeLifecycleTests.testSoftDeleteEpisodeAlsoSoftDeletesUnlockLogs` | `isDeleted`衝突回避のため SwiftDataモデルの削除フラグを `isSoftDeleted` に変更し、関連ロジックを更新 |
| FAIL-002 | RESOLVED | `PersistenceUpsertTests.testUpsertTagReusesExistingAndRevivesDeleted` | `upsertTag` 復活時に `isSoftDeleted=false` と `deletedAt=nil` を確実に反映 |
| FAIL-003 | RESOLVED | `UnlockLogLifecycleTests.testSoftDeleteUnlockLogMarksFlags` | `isSoftDeleted` への統一で soft delete 状態反映を安定化 |
| FAIL-004 | RESOLVED | `TagRelationTests.testRestoreTagRelinksOnlyNonDeletedEpisodes` | `Tag` に `@Relationship(inverse: \Episode.tags)` を追加し、復元対象リンクを安定化 |
| FAIL-005 | RESOLVED | `TagRelationTests.testSoftDeleteTagUnlinksOnlyActiveEpisodes` | 同上（Tag/Episodeの多対多関係を明示化） |

## 実行証跡
- 全件PASS実行: `coverage-summary.md`（GitHub Actions artifact: `episode-unit-tests-artifacts`）
- 修正確認実行: `coverage-summary.md`（GitHub Actions artifact: `episode-unit-tests-artifacts`）
