# Unit Test Operation Rules (CI Gate)

Source of truth: `docs/unit-test/`

## Purpose
- Keep `EpisodeStockerTests` always green and prevent regressions in persistence/search/router logic.

## Local Rule
1. Before pushing, run:
   - `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -only-testing:EpisodeStockerTests`
   - `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'id=76667AA1-DC1C-4AC6-8228-0AE06DE290B5' -only-testing:EpisodeStockerTests -enableCodeCoverage YES -resultBundlePath /tmp/episode-unit-tests-coverage.xcresult`
2. If any test fails, do not merge. Fix code or test data first.
3. Record the run result in `docs/unit-test/results/*.md`.

## CI Gate (Required)
1. CI runs `EpisodeStockerTests` only.
2. Merge condition:
   - Test exit code is `0`.
   - `FAIL = 0`.
   - No skipped test without ticket (`XCTSkip` requires issue link).
3. If CI fails, PR is blocked.

## Coverage Rule (Phased)
- Phase 1 (now): establish baseline coverage and do not decrease it.
- Baseline source of truth (CI): `docs/unit-test/coverage-baseline.md`
- Denominator rule: logic-focused metrics only (exclude `ios/Views/**` from gate metrics).
- Phase 1 fail condition:
  - Any gate metric current coverage `<` baseline coverage.
  - Baseline metric cannot be extracted from `xccov` output.
- Phase 2: enforce threshold (recommended: overall >= 70%, changed files >= 80%).

## Phase 1 Gate Metrics
- `SwiftDataPersistence.swift`
- `InMemorySuggestionRepository.swift`
- `SuggestionManagerViewModel.swift`
- `SeedData.swift`
- `AppRouter.swift`
- `Episode.swift`
- `EpisodeStocker.app` (informational only, not a blocking metric in Phase 1)

## Exception Handling
- Flaky tests are allowed only with:
  - issue/ticket ID,
  - expiry date,
  - owner.
- Expired exceptions are treated as CI failures.
