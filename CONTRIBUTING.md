# Contributing

## Branch Strategy
- Never push directly to `main`.
- Create a feature branch from `main`.
- Open a pull request to `main`.

## Required Checks
- `episode-unit-tests` must pass before merge.
- Keep PR branch up to date with `main` when requested by branch rules.

## Development Flow
1. Create branch: `feature/<topic>` or `chore/<topic>`.
2. Make changes and commit with clear messages.
3. Run tests locally:
   - `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:EpisodeStockerTests`
4. Push branch and create PR.
5. Merge only after required checks pass.

## Pull Request Scope
- Keep changes focused and small where possible.
- Link related issue when available.
- Update docs for behavior or process changes.
