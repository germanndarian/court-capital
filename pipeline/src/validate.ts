import { SECTION_KEYS, type EditionDraft, type StoryDraft } from "./schema.ts";

/**
 * Editorial rules the tool schema can't express. Returned as problems for the model to fix,
 * so it gets one or two chances before the attempt fails.
 */
export function checkDraft(draft: EditionDraft): string[] {
  const problems: string[] = [];
  const keys = draft.sections.map((section) => section.key);
  if (keys.join() !== SECTION_KEYS.join()) {
    problems.push(`sections must be exactly ${SECTION_KEYS.join(", ")} in that order (got ${keys.join(", ") || "none"})`);
  }
  const ids = new Set<string>();
  for (const section of draft.sections) {
    if (!section.stories.length) problems.push(`section ${section.key} has no stories`);
    for (const story of section.stories) {
      const where = `story "${story.id}"`;
      if (ids.has(story.id)) problems.push(`${where}: id is used twice`);
      ids.add(story.id);
      if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(story.id)) problems.push(`${where}: id must be a kebab-case slug`);
      if (story.plain_words.length !== 3) problems.push(`${where}: plain_words needs exactly 3 sentences (got ${story.plain_words.length})`);
      if (!story.sources.length || story.sources.length > 4) problems.push(`${where}: needs 1–4 sources (got ${story.sources.length})`);
      if (!story.whos_who.length) problems.push(`${where}: whos_who is empty`);
      if (!story.body.trim()) problems.push(`${where}: body is empty`);
      if (story.why_it_matters === null && section.key !== "ai") problems.push(`${where}: why_it_matters is required outside AI quick hits`);
    }
  }
  if (!ids.has(draft.big_story.story_id)) problems.push(`big_story.story_id "${draft.big_story.story_id}" doesn't match any story id`);
  return problems;
}

/** A comparable form of a URL: no scheme, "www.", fragment, trailing slash or tracking parameters. */
export function normalizeUrl(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    return null;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  for (const key of [...url.searchParams.keys()]) {
    if (key.startsWith("utm_") || key === "ref" || key === "guccounter") url.searchParams.delete(key);
  }
  const host = url.hostname.toLowerCase().replace(/^www\./, "");
  const path = url.pathname.replace(/\/+$/, "");
  const query = url.searchParams.toString();
  return `${host}${path}${query ? `?${query}` : ""}`;
}

/** Every URL that appears anywhere in the response: search results, fetched pages, citations. */
export function collectUrls(content: unknown): Set<string> {
  const urls = new Set<string>();
  const visit = (node: unknown) => {
    if (typeof node === "string") {
      if (/^https?:\/\//.test(node)) {
        const normalized = normalizeUrl(node);
        if (normalized) urls.add(normalized);
      }
    } else if (Array.isArray(node)) {
      node.forEach(visit);
    } else if (node && typeof node === "object") {
      Object.values(node).forEach(visit);
    }
  };
  visit(content);
  return urls;
}

/**
 * Keeps only sources whose URL came back from search or fetch, so no invented link reaches
 * the reader. Returns null when nothing verifiable is left and the story has to go.
 */
export function keepVerifiedSources(story: StoryDraft, seenUrls: Set<string>, warnings: string[]): StoryDraft | null {
  const sources = story.sources.filter((source) => {
    const normalized = normalizeUrl(source.url);
    const ok = normalized !== null && seenUrls.has(normalized);
    if (!ok) warnings.push(`Dropped unverified source for "${story.id}": ${source.url}`);
    return ok;
  });
  if (!sources.length) {
    warnings.push(`Dropped story "${story.id}": no verifiable sources`);
    return null;
  }
  return { ...story, sources: sources.slice(0, 4) };
}

export function storyWords(story: StoryDraft): number {
  const text = [
    story.headline,
    ...story.whos_who.map((entry) => `${entry.name} ${entry.description}`),
    story.body,
    story.why_it_matters ?? "",
    ...story.plain_words,
  ].join(" ");
  return text.split(/\s+/).filter(Boolean).length;
}

/** At about 180 words a minute: careful reading, not skimming. */
export function readingMinutes(words: number): number {
  return Math.max(1, Math.round(words / 180));
}
