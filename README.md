# Court & Capital

A weekday morning briefing on law, finance and AI for iPhone, set like a newspaper: Playfair Display and Newsreader, ivory stock by day, racing-green leather by night.

The SwiftUI app implements the design review in Claude Design ("Court & Capital iPhone App"): the Today edition, the expanded story, the Archive, Settings, Home Screen and Lock Screen widgets, and the app icon.

## Requirements

- Xcode 26 or later
- iOS 18 or later (exact CSS line heights use the iOS 26 API; earlier systems approximate them)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you add or remove files

## Run it

Open `CourtCapital.xcodeproj`, pick the `CourtCapital` scheme and an iPhone simulator, and run. To run on a device, set your team under Signing & Capabilities for both targets.

The project file is generated from `project.yml`. After adding or removing files, regenerate it:

```bash
xcodegen generate
```

## Layout

| Path | What's there |
| --- | --- |
| `CourtCapital/App` | App entry, navigation state, appearance, deep links |
| `CourtCapital/Screens` | Today, Story, Archive, Settings |
| `CourtCapital/Components` | Masthead, markets strip, story rows, drop cap, quote blocks, tab bar |
| `CourtCapital/Services` | Morning notification scheduling |
| `CourtCapitalWidgets` | Small, medium, Lock Screen rectangular, circular and inline widgets |
| `Shared/Theme` | Design tokens: colours, type scale, paper grain, rules and ornaments |
| `Shared/Model` | Edition model, edition calendar (Roman numbering), archive, sample edition |
| `Shared/Fonts` | Playfair Display and Newsreader variable fonts (SIL Open Font License) |
| `Tools/render-app-icon.swift` | Renders the app icon masters: `swift Tools/render-app-icon.swift` |

## Deep links

- `courtcapital://today`: the edition
- `courtcapital://today/markets`: the edition, scrolled to the markets strip
- `courtcapital://story/<id>`: a story, for example `courtcapital://story/boulder`

## Not built yet

- **Edition feed.** Content is the 7 October 2026 sample edition from the design. Only the Boulder story has a full write-up; the others show the placeholder where feed content lands. Earlier archive editions use stand-in headlines.
- **Push notifications.** The morning notification is a local, weekday reminder with generic text. Edition-specific text, as in the design's Lock Screen mock-up, needs a server push.
- **Source links** point at each publication's homepage until the feed supplies article URLs.
- **Ivory alternate icon** from the design is not wired up.
