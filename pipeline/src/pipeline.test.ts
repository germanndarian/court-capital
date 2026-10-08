import assert from "node:assert/strict";
import { test } from "node:test";
import { editionNumber, isWeekday, longDate, previousWeekday, zurichNow } from "./calendar.ts";
import type { EditionDraft, StoryDraft } from "./schema.ts";
import { checkDraft, collectUrls, keepVerifiedSources, normalizeUrl } from "./validate.ts";

const story = (overrides: Partial<StoryDraft> = {}): StoryDraft => ({
  id: "fed-minutes",
  headline: "Fed minutes show unanimous support for September hike",
  region: "US",
  whos_who: [{ name: "Fed", description: "US central bank" }],
  body: "Minutes released Wednesday confirm a 12–0 vote.",
  why_it_matters: "Borrowing stays expensive.",
  plain_words: ["One.", "Two.", "Three."],
  sources: [{ outlet: "CNBC", url: "https://www.cnbc.com/2026/10/07/fed-minutes.html" }],
  ...overrides,
});

const draft = (stories: Partial<Record<"corporate_law" | "finance" | "ai", StoryDraft[]>> = {}): EditionDraft => ({
  big_story: { text: "The Fed is hiking.", story_id: "fed-minutes" },
  sections: [
    { key: "corporate_law", stories: stories.corporate_law ?? [story({ id: "sec-climate" })] },
    { key: "finance", stories: stories.finance ?? [story()] },
    { key: "ai", stories: stories.ai ?? [story({ id: "gpt-6", why_it_matters: null })] },
  ],
  markets: null,
});

test("edition numbers count weekdays since 1 January", () => {
  assert.equal(editionNumber("2026-01-01"), 1);
  assert.equal(editionNumber("2026-10-07"), 200);
  assert.equal(editionNumber("2026-10-08"), 201);
});

test("weekdays and dates", () => {
  assert.equal(isWeekday("2026-10-10"), false);
  assert.equal(previousWeekday("2026-10-12"), "2026-10-09");
  assert.equal(longDate("2026-10-08"), "Thursday, 8 October 2026");
});

test("Zürich time follows summer and winter time", () => {
  // 02:15 UTC is 04:15 in summer (CEST) and 03:15 in winter (CET).
  assert.equal(zurichNow(new Date("2026-10-08T02:15:00Z")).hour, 4);
  assert.equal(zurichNow(new Date("2026-11-05T02:15:00Z")).hour, 3);
  assert.equal(zurichNow(new Date("2026-11-05T03:15:00Z")).hour, 4);
  assert.equal(zurichNow(new Date("2026-10-08T22:30:00Z")).date, "2026-10-09");
});

test("URLs compare without scheme, www, trailing slash or tracking", () => {
  assert.equal(normalizeUrl("https://www.cnbc.com/a/b/?utm_source=x#top"), "cnbc.com/a/b");
  assert.equal(normalizeUrl("http://cnbc.com/a/b"), "cnbc.com/a/b");
  assert.equal(normalizeUrl("not a url"), null);
});

test("collects URLs from nested search results", () => {
  const content = [
    { type: "web_search_tool_result", content: [{ type: "web_search_result", url: "https://www.law360.com/articles/1", title: "x" }] },
    { type: "text", text: "plain", citations: [{ url: "https://cnbc.com/2026/10/07/fed-minutes.html" }] },
  ];
  assert.deepEqual([...collectUrls(content)].sort(), ["cnbc.com/2026/10/07/fed-minutes.html", "law360.com/articles/1"]);
});

test("drops sources that never appeared in search results", () => {
  const warnings: string[] = [];
  const seen = new Set(["cnbc.com/2026/10/07/fed-minutes.html"]);
  const kept = keepVerifiedSources(
    story({ sources: [...story().sources, { outlet: "Made up", url: "https://example.com/invented" }] }),
    seen,
    warnings,
  );
  assert.equal(kept?.sources.length, 1);
  assert.equal(warnings.length, 1);
  assert.equal(keepVerifiedSources(story(), new Set(), []), null);
});

test("accepts a well-formed draft", () => {
  assert.deepEqual(checkDraft(draft()), []);
});

test("flags editorial problems", () => {
  const problems = checkDraft(
    draft({
      finance: [story({ plain_words: ["Only one."], why_it_matters: null, id: "Not A Slug" })],
    }),
  );
  assert.ok(problems.some((problem) => problem.includes("plain_words")));
  assert.ok(problems.some((problem) => problem.includes("why_it_matters")));
  assert.ok(problems.some((problem) => problem.includes("kebab-case")));
  assert.ok(problems.some((problem) => problem.includes("big_story.story_id")));
});
