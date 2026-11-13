---
name: edition-data
description: Use when changing the edition JSON ("Data" block) format, the Notion feed or its parser, the sample editions in Shared/Fixtures, or any field of an edition (stories, markets, sections, footer). Trigger words - Data block, schema, edition JSON, fixtures, EditionDocument, NotionFeed, scheduled task prompt.
---

# Edition data

The Claude scheduled task writes each edition into Notion as a child page titled "Edition ...", ending with a "Data" heading and one JSON code block. The app reads only that JSON.

## Where things are
- Schema and the scheduled-task prompt text: `README.md`, section "3. The Data block in the scheduled task" (the schema is in a collapsed `<details>`). Read it there; don't copy it here.
- Page listing and Data block extraction: `Shared/Data/Notion/NotionFeed.swift` (`pages()`, `documentData(for:)`). It takes the code block under the "Data" heading (also inside a toggle heading), else the page's last JSON code block.
- Decoding and validation: `EditionDocument.decode` in `Shared/Model/Edition.swift`. It throws if `date` is not YYYY-MM-DD or no section has stories. Called from `Shared/Data/EditionFeed.swift`; a bad edition is skipped.
- Samples: `Shared/Fixtures/edition-2026-10-07.json` and `edition-2026-10-08.json`, shown before a token is set. `Shared/Model/SampleEdition.swift` loads them.
- Tests: `Tests/NotionFeedTests.swift` (Data block lookup), `Tests/EditionStoreTests.swift` (store and cache). Run them per `build-and-test`.

## Things the app computes or ignores
Reading time, story counts, edition numbers and story ids are computed by the app. The `footer` field is decoded but never shown (see `AGENTS.md`, no AI trace).

## When the schema changes
Change all of these together:
1. `Shared/Model/Edition.swift`: new fields optional where old editions lack them, so cached editions still decode.
2. Both fixtures in `Shared/Fixtures`, kept valid and complete.
3. Tests for the new or changed field.
4. `README.md` schema block and prompt text.
5. The scheduled-task prompt on claude.ai. Only Darian can update it: put it in the PR's **For you** line with the new schema text to paste.

## Checking it worked
Full test run passes (`build-and-test`), and both fixtures still decode (the sample-edition tests cover them). Remember: a new field in the JSON is useless until the prompt on claude.ai is updated.
