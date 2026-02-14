# Phase 1 Coverage Rollout Checklist

## Scope
- Enable and operate Phase 1 coverage gate (baseline non-regression) for `EpisodeStockerTests`.

## 1. PR bundle (repo-side)
- [ ] Include these files in one PR:
  - `.github/workflows/episode-unit-tests.yml`
  - `EpisodeStockerTests/ViewModels/SuggestionManagerViewModelTests.swift`
  - `docs/unit-test/coverage-baseline.md`
  - `docs/unit-test/ci-gate-rules.md`
  - `docs/unit-test/results/*.md`

## 2. Branch protection check (manual on GitHub)
- [ ] Open `Settings > Branches > main rule`
- [ ] Confirm required status checks include `episode-unit-tests`
- [ ] Confirm merge is blocked when required checks are failing

## 3. Dummy PR validation (manual)
- [ ] Create a no-op PR to `main`
- [ ] Confirm `episode-unit-tests` runs
- [ ] Confirm artifacts include:
  - `episode-unit-tests.xcresult`
  - `coverage-summary.md`

## 4. Regression-fail validation
- [ ] Local simulation completed (forced baseline > current): expected fail reproduced
- [ ] Optional PR simulation: intentionally reduce one gate file coverage and confirm CI FAIL

## 5. Documentation source-of-truth
- [ ] Use only `EpisodeStocker/docs/unit-test/` as the canonical docs path
- [ ] Update this path on every test run

## 6. Stabilization window
- [ ] Track first 2-3 PRs after rollout
- [ ] Confirm each PR passes:
  - `EpisodeStockerTests` green
  - coverage baseline gate green

## 7. Next phase prep
- [ ] Draft Phase 2 thresholds:
  - overall coverage target
  - changed-files coverage target
  - exception policy
