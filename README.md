<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/banner-night.jpg">
  <img alt="Court & Capital. A weekday briefing on law, finance and AI, for iPhone." src="docs/readme/banner-day.jpg">
</picture>

<p align="center">
  <img alt="iOS 18+" src="https://img.shields.io/badge/iOS-18%2B-16202F?style=flat-square&labelColor=F4EEE1">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-80602A?style=flat-square&labelColor=F4EEE1">
  <img alt="SwiftUI and WidgetKit" src="https://img.shields.io/badge/SwiftUI-WidgetKit-1E3A2C?style=flat-square&labelColor=F4EEE1">
  <img alt="Fonts: SIL OFL" src="https://img.shields.io/badge/fonts-SIL%20OFL-6F1F2C?style=flat-square&labelColor=F4EEE1">
</p>

<p align="center"><i>Ten stories. Eleven minutes. Every weekday at 6:30 a.m.</i></p>

---

Court & Capital is a morning briefing on law, finance and AI that reads like a newspaper. There's one Big Story, the overnight markets, and a short edition in numbered sections. Every story says who's who, why it matters, and what it means in plain words.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/showcase-night.jpg">
  <img alt="The story, Today and the Archive on iPhone" src="docs/readme/showcase-day.jpg">
</picture>

## ◆ The edition

| | |
| --- | --- |
| **Today** | The masthead with Volume and edition number in Roman numerals, The Big Story, the markets at the previous close, and the day's stories by section, each tagged US, EU or CH. |
| **The story** | Who's who, the facts with a brass drop cap, *Why it matters*, *In plain words*, and sources that open in Safari. |
| **The Archive** | The year's editions bound by month as leather volumes on a shelf. Pull a volume to read its ledger. |
| **Settings** | The weekday morning notification and its delivery time, plus Day, Night or Automatic. |
| **Widgets** | Small and medium on the Home Screen; rectangular, circular and inline on the Lock Screen. |

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/details-night.jpg">
  <img alt="The rest of the story, and Settings" src="docs/readme/details-day.jpg">
</picture>

## ◆ Day and Night

<img alt="The Today screen split diagonally between Day and Night" src="docs/readme/day-and-night.jpg">

Day is the morning paper. Night is the library: racing-green leather, cream type, brass rules, and navy for the plain-words block so it stands apart from the page. Automatic follows the iPhone.

## ◆ On the Home Screen

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/widgets-night.jpg">
  <img alt="The medium and small widgets" src="docs/readme/widgets-day.jpg">
</picture>

The widgets refresh when the 6:30 a.m. edition lands. Tapping one opens Today, and the medium widget's market column jumps straight to the markets.

## ◆ Type

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/type-night.jpg">
  <img alt="The type scale in Playfair Display and Newsreader" src="docs/readme/type-day.jpg">
</picture>

**Playfair Display** sets the masthead and headlines; **Newsreader** sets the body and the letter-spaced labels. Both ship as variable fonts under the SIL Open Font License. The app sets weight and optical size through the font axes, so a 9.5 pt label gets Newsreader's sturdier small-size cut. Every style scales with Dynamic Type.

## ◆ Colour

<img alt="The colour tokens in Day and Night" src="docs/readme/palette.jpg">

Every token resolves per appearance and lives in [`Shared/Theme/Theme.swift`](Shared/Theme/Theme.swift). The paper grain is generated in code, so no texture images ship with the app.

---

## Run it

You need Xcode 26 and an iPhone simulator or device on iOS 18 or later.

```bash
git clone https://github.com/germanndarian/court-capital.git
```

```bash
open court-capital/CourtCapital.xcodeproj
```

Choose the **CourtCapital** scheme and run. To run on your own iPhone, set your team under *Signing & Capabilities* for both targets.

The project file is generated from [`project.yml`](project.yml). After adding or removing files, regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
```

## How it's built

```
CourtCapital/            the app
  App/                   entry point, navigation, appearance, deep links
  Screens/               Today, Story, Archive, Settings
  Components/            masthead, markets strip, story rows, drop cap, tab bar
  Services/              morning notification
CourtCapitalWidgets/     Home Screen and Lock Screen widgets
Shared/                  compiled into both targets
  Theme/                 colour tokens, type scale, paper grain, rules, ornaments
  Model/                 edition, Roman edition calendar, archive, sample edition
  Fonts/                 Playfair Display and Newsreader (SIL OFL)
Tools/                   app icon and README artwork renderers
```

- **Edition numbers** count weekdays since 1 January, so 7 October 2026 is No. CC of Volume I.
- **The drop cap** is a small UIKit text view; SwiftUI can't wrap text around a floated letter.
- **Line heights** match the design exactly on iOS 26 and are approximated on iOS 18 to 25.

### Deep links

| Link | Opens |
| --- | --- |
| `courtcapital://today` | The edition |
| `courtcapital://today/markets` | The edition, at the markets strip |
| `courtcapital://story/<id>` | A story, e.g. `courtcapital://story/boulder` |

### Regenerating the artwork

```bash
swift Tools/render-app-icon.swift
```

```bash
swift Tools/render-readme-art.swift <folder-of-simulator-screenshots>
```

## What's next

- **The edition feed.** Content is the 7 October 2026 sample edition. Only the Boulder story has a full write-up; the others show where feed content will land.
- **Push notifications** carrying each day's Big Story. The current reminder is local and generic.
- **Article links** for sources, which point at each publication's homepage for now.
- **The ivory alternate icon** from the design.

<p align="center">◆ ◆ ◆</p>
<p align="center"><i>End of today's edition</i></p>
