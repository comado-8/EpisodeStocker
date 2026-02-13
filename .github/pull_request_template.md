## Summary
- What changed and why.

## Scope
- [ ] Code
- [ ] Tests
- [ ] Docs

## Checklist
- [ ] I ran `EpisodeStockerTests` locally
- [ ] `episode-unit-tests` is green on this PR
- [ ] No secrets or local-only files were added
- [ ] Related docs were updated if needed

## Validation
- Test command:
  - `xcodebuild test -project EpisodeStocker.xcodeproj -scheme EpisodeStocker -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:EpisodeStockerTests`

## Related
- Issue: #
