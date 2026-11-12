---
name: run-on-iphone
description: Use when someone asks to install or run Court & Capital on a real iPhone, or hits signing, Developer Mode, "untrusted developer", DEVELOPMENT_TEAM, or the app stopping after 7 days. A human-run step; agents cannot do it.
---

# Run on iPhone

Agents cannot do this: it needs the physical iPhone, a cable, taps on the phone and Darian's Apple ID in Xcode. Do not try to sign or install. Tell Darian the steps below (source: `README.md`, "Running on your iPhone").

## Steps for Darian
1. Make sure `Config/Secrets.xcconfig` exists (copy of `Config/Secrets.example.xcconfig`, gitignored) with `NOTION_TOKEN`, `NOTION_PAGE_ID` and `DEVELOPMENT_TEAM` (Apple team ID, so signing survives `xcodegen generate`). Never print or commit its values.
2. Connect the iPhone with a cable; first time, unlock it and tap Trust.
3. On the iPhone: Settings, Privacy & Security, Developer Mode, on. It restarts.
4. Open `CourtCapital.xcodeproj`. Under Signing & Capabilities, both targets (CourtCapital and CourtCapitalWidgets) must use his team.
5. Pick the iPhone as run destination and press Cmd+R.
6. First launch is blocked until trusted: Settings, General, VPN & Device Management, his Apple ID, Trust.

## Limits to mention
- Free Apple account: the app stops opening 7 days after the last install. Cached editions and settings survive. Renew by connecting the iPhone, opening the project and pressing Cmd+R again.
- A free account allows 3 sideloaded apps at once; this app uses 2 app IDs (app and widgets).

## Gotchas
- After `xcodegen generate`, signing only holds if `DEVELOPMENT_TEAM` is set in `Config/Secrets.xcconfig`.
- Signing errors on one target usually mean the other target still has no team.

## What an agent can do instead
Check the simulator build passes (`build-and-test`) and put the steps above in the PR's **For you** line only if the change needs a device check.
