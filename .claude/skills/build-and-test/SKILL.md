---
name: build-and-test
description: Use when you need to build the Court & Capital app, run the unit tests (all or one suite), regenerate the Xcode project with xcodegen, or work out why a build or test failed. Trigger words - build, xcodebuild, test, xcodegen, simulator, failing test, BUILD FAILED.
---

# Build and test

Commands and the output filter are in `AGENTS.md` (Commands). Use them as written; this skill is the routine around them.

## Steps
1. Added or removed Swift files? Run `xcodegen generate` first. Otherwise skip it.
2. Build. Expect `** BUILD SUCCEEDED **`.
3. While working, run only the suite you touched with `-only-testing:CourtCapitalTests/<Suite>` (suite names are listed in `AGENTS.md`).
4. Before finishing, run the full test command once. Expect a line like `Test run with N tests in M suites passed` and `** TEST SUCCEEDED **`.

## Reading failures lean
- Always pipe through the filter from `AGENTS.md`. Never print a whole log.
- On failure, the filter shows `error:` or `✘` lines. Look deeper only then: rerun the same command with the filter replaced by `grep -E "error:|✘" -A3` or `grep -n "<failing test name>"`, and read only those lines.
- Compile errors name a file and line: read that range, not the file.
- Rerun just the failing suite after a fix, then the full run once at the end.

## Gotchas
- The test target compiles its own list of sources (`project.yml`, target `CourtCapitalTests`), not the app. A "cannot find X in scope" error in tests usually means the file defining X is not in that list.
- The first test run on a cold simulator can take several minutes (one full run took about 5 minutes); later runs take seconds. Don't kill and restart it; a killed run only costs more time.
- Tests never reach the real Notion; they use `Tests/NotionStub.swift`. A test that needs a token is wrong.
- Destination is `platform=iOS Simulator,name=iPhone 17 Pro`. If it is missing, check `xcrun simctl list devices available`.

## Checking it worked
The last filtered line is `** BUILD SUCCEEDED **` or `** TEST SUCCEEDED **` and no `✘` lines appeared.
