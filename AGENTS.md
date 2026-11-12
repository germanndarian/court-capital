# Court & Capital: agent guide

Weekday morning briefing on law, finance and AI: a newspaper-style iPhone app with Home Screen and Lock Screen widgets. The edition is written by a Claude scheduled task into Notion; the app reads it read-only into a SwiftData cache. No server.

Full context (state, next steps, rules and decisions): the vault note `~/Documents/Projects/personal-os/projects/Court & Capital/Court & Capital.md`. Read it first when reachable. How the app works and setup: `README.md`.

## Stack
Swift 6, SwiftUI, WidgetKit, SwiftData, XcodeGen (`project.yml`), Notion API (read-only). iOS 18.0+, iPhone only. No third-party dependencies.

## Commands
Run from the repo root. Targets: `CourtCapital`, `CourtCapitalWidgets`, `CourtCapitalTests`; one scheme: `CourtCapital`. The filter keeps output short.

```bash
# Regenerate the Xcode project (after adding or removing Swift files)
xcodegen generate

# Build
xcodebuild build -project CourtCapital.xcodeproj -scheme CourtCapital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|✘|Test run with|\*\* (BUILD|TEST)"

# All tests
xcodebuild test -project CourtCapital.xcodeproj -scheme CourtCapital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|✘|Test run with|\*\* (BUILD|TEST)"

# One test suite
xcodebuild test -project CourtCapital.xcodeproj -scheme CourtCapital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CourtCapitalTests/NotionFeedTests 2>&1 | grep -E "error:|✘|Test run with|\*\* (BUILD|TEST)"
```

Test suites in `Tests/`: DocketTests, EditionStoreTests, HeatmapTests, NotionClientTests, NotionFeedTests, SavedStoriesTests, PauseTests and MarketQuoteTests (both in PauseAndMarketTests.swift). More detail: `.claude/skills/build-and-test`.

## Layout
- `CourtCapital/` the app: `App/` entry point, navigation, deep links; `Data/` SwiftData cache, edition store, Docket, saved stories, background refresh; `Screens/` Today, Story, Docket, Archive, Saved, Markets, Settings; `Components/` masthead, markets strip, story rows, tab bar; `Services/` morning notification, Docket reminders.
- `CourtCapitalWidgets/` Home Screen and Lock Screen widgets.
- `Shared/` compiled into both targets:
  - `Data/` edition feed (`EditionFeed.swift`), `Notion/` client, feed and config, `MarketQuotes.swift` (ETF from Yahoo).
  - `Model/` `Edition.swift` (JSON decoding), `EditionCalendar.swift`, `Archive.swift`, `BodyText.swift`, `SampleEdition.swift`.
  - `Heatmap/` Markets heatmap: stock list JSON, prices, treemap, colour scale.
  - `Theme/` `Theme.swift` colour tokens, `Typography.swift`, `Paper.swift`, `Ornaments.swift`.
  - `Fixtures/` two sample editions in the Data block format. `Fonts/` Playfair Display, Newsreader (SIL OFL).
- `Tests/` unit tests against fakes (`NotionStub.swift`). `Config/` build settings. `Tools/` icon and README artwork renderers. `docs/` README images.
- `project.yml` is the source of truth; `CourtCapital.xcodeproj` is generated from it.

## Conventions and gotchas
- **No trace of AI or Claude in anything the reader sees** in the app or widgets: no "compiled by Claude", no Claude or Anthropic as example text. The app prints its own footer and ignores the edition's `footer` field. Code, comments, README and the vault may mention Claude. AI news content (section III, stories about Anthropic) stays.
- Notion is read-only: the app never writes to it. Nothing from the Docket or Saved goes to Notion.
- Colours only from tokens in `Shared/Theme/Theme.swift`; never hardcode a colour. Fonts: Playfair Display (headlines), Newsreader (body).
- Run `xcodegen generate` after adding or removing Swift files. `CourtCapitalTests` lists its sources by path in `project.yml`: a new file outside `Tests/`, `Shared/Data`, `Shared/Model`, `Shared/Fixtures`, `Shared/Heatmap` must be added there to be tested.
- Tests use fakes and never reach the real Notion (every request goes to `Tests/NotionStub.swift`). Sample editions live in `Shared/Fixtures`.
- Deep links (`courtcapital://`): `today`, `today/markets`, `story/<id>`, `docket`, `markets`.
- Docket (`docket.json`) and Saved (`saved.json`) stay on the iPhone. An unreadable file is set aside, never overwritten.
- Saved stories are matched by edition date + headline, never by story id (ids are positions and shift when the page is edited). A stored copy is never looked up on the Docket by its old id.
- Secrets (`NOTION_TOKEN`, `NOTION_PAGE_ID`, `DEVELOPMENT_TEAM`) live in the gitignored `Config/Secrets.xcconfig`. Never commit or print them.
- The edition is expected ready at 04:30: `EditionCalendar.readyHour` / `readyMinute` in `Shared/Model/EditionCalendar.swift`.
- No backend, no new dependencies.

## Skills
`.claude/skills/`: `build-and-test`, `edition-data` (Data block schema, parser, fixtures), `run-on-iphone` (human step).

## Done means
1. `xcodegen generate` if Swift files were added or removed.
2. Build passes (`** BUILD SUCCEEDED **`).
3. Full test run passes (`** TEST SUCCEEDED **`); new behavior has tests.
4. Every new user-visible string checked for AI/Claude traces.
5. No hardcoded colours, only tokens; no secrets in the diff.
