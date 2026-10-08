import { readFile } from "node:fs/promises";
import Anthropic from "@anthropic-ai/sdk";
import type {
  BetaContentBlock,
  BetaMessage,
  BetaMessageParam,
  BetaTool,
  BetaToolResultBlockParam,
  BetaToolUnion,
} from "@anthropic-ai/sdk/resources/beta/messages/messages";
import { editionNumber, longDate, previousWeekday, volume } from "./calendar.ts";
import { formatQuote, orderQuotes, UNITS, type MarketSnapshot } from "./markets.ts";
import { Edition, EditionDraft, FOOTER, SECTION_KEYS, SECTIONS, strictToolSchema, type Quote } from "./schema.ts";
import { checkDraft, collectUrls, keepVerifiedSources, readingMinutes, storyWords } from "./validate.ts";

export const MODEL = process.env.CLAUDE_MODEL ?? "claude-opus-5-5";
const EFFORT = (process.env.CLAUDE_EFFORT ?? "high") as "low" | "medium" | "high" | "xhigh" | "max";
const PROMPT_PATH = new URL("../../prompts/edition.md", import.meta.url);

/** Turns the model may take to fix problems with what it published. */
const MAX_CORRECTIONS = 2;
/** Times the model may finish without publishing before the attempt fails. */
const MAX_NUDGES = 1;

export class GenerationError extends Error {}

export interface GenerationResult {
  edition: Edition;
  usage: Record<string, unknown>;
  warnings: string[];
}

async function buildSystemPrompt(date: string, markets: MarketSnapshot): Promise<string> {
  const template = await readFile(PROMPT_PATH, "utf8");
  const instructions = template.replace(/<!--[\s\S]*?-->\s*/, "");
  const lines = markets.quotes.length ? orderQuotes(markets.quotes).map((quote) => `- ${formatQuote(quote)}`) : [];
  if (markets.asOf) lines.unshift(`At the close on ${longDate(markets.asOf)}:`);
  if (markets.missing.length) {
    lines.push(
      `- Missing today: ${markets.missing.join(", ")}. Look up their latest closing level and change on the day, and fill them in \`markets\` when you publish.`,
    );
  } else {
    lines.push("(Leave `markets` null when you publish.)");
  }
  return instructions
    .replaceAll("{{DATE}}", longDate(date))
    .replaceAll("{{DATE_ISO}}", date)
    .replaceAll("{{SINCE}}", `${longDate(previousWeekday(date))}, 05:00 Zürich time`)
    .replaceAll("{{MARKETS}}", lines.join("\n"));
}

const tools: BetaToolUnion[] = [
  { type: "web_search_20260209", name: "web_search", max_uses: 40 },
  { type: "web_fetch_20260209", name: "web_fetch", max_uses: 25, max_content_tokens: 20_000 },
  {
    name: "publish_edition",
    description:
      "Publish the finished edition. Call it once, after your research is complete, with every section and story. If it returns problems, fix them and call it again.",
    strict: true,
    input_schema: strictToolSchema(EditionDraft) as BetaTool["input_schema"],
  },
];

function toolUse(message: BetaMessage) {
  return message.content.find(
    (block): block is Extract<BetaContentBlock, { type: "tool_use" }> => block.type === "tool_use" && block.name === "publish_edition",
  );
}

function addUsage(total: Record<string, number>, usage: BetaMessage["usage"]) {
  for (const [key, value] of Object.entries(usage)) {
    if (typeof value === "number") total[key] = (total[key] ?? 0) + value;
  }
  const searches = usage.server_tool_use?.web_search_requests ?? 0;
  const fetches = usage.server_tool_use?.web_fetch_requests ?? 0;
  total.web_search_requests = (total.web_search_requests ?? 0) + searches;
  total.web_fetch_requests = (total.web_fetch_requests ?? 0) + fetches;
}

/** Researches and writes one edition. Throws GenerationError when the result can't be used. */
// A research turn can run for many minutes; streaming keeps the connection alive, and the
// timeout is the backstop for a stalled one.
const defaultClient = () => new Anthropic({ timeout: 20 * 60 * 1000, maxRetries: 3 });

export async function generateEdition(date: string, markets: MarketSnapshot, client = defaultClient()): Promise<GenerationResult> {
  const system = await buildSystemPrompt(date, markets);
  const messages: BetaMessageParam[] = [
    { role: "user", content: `Write the edition for ${longDate(date)}, then call publish_edition.` },
  ];
  const seenUrls = new Set<string>();
  const usage: Record<string, number> = {};
  const warnings: string[] = [];
  let corrections = 0;
  let nudges = 0;

  for (let turn = 0; turn < 30; turn++) {
    const stream = client.beta.messages.stream({
      model: MODEL,
      max_tokens: 64_000,
      thinking: { type: "adaptive" },
      output_config: { effort: EFFORT },
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system,
      tools,
      messages,
    });
    const message = await stream.finalMessage();
    addUsage(usage, message.usage);
    for (const url of collectUrls(message.content)) seenUrls.add(url);
    console.log(`Turn ${turn + 1}: ${message.stop_reason}, ${message.usage.output_tokens} output tokens, ${seenUrls.size} source URLs seen`);

    if (message.stop_reason === "refusal") {
      throw new GenerationError(`Model declined (${message.stop_details?.category ?? "no category"}): ${message.stop_details?.explanation ?? ""}`);
    }
    if (message.stop_reason === "max_tokens") throw new GenerationError("Ran out of output tokens before publishing");

    messages.push({ role: "assistant", content: message.content });
    if (message.stop_reason === "pause_turn") continue;

    const call = toolUse(message);
    if (!call) {
      if (nudges++ >= MAX_NUDGES) throw new GenerationError("Finished without calling publish_edition");
      messages.push({ role: "user", content: "Please publish the edition now by calling publish_edition." });
      continue;
    }

    const parsed = EditionDraft.safeParse(call.input);
    const problems = parsed.success ? checkDraft(parsed.data) : parsed.error.issues.map((issue) => `${issue.path.join(".")}: ${issue.message}`);
    if (!parsed.success || problems.length) {
      if (corrections++ >= MAX_CORRECTIONS) throw new GenerationError(`Edition still invalid after corrections: ${problems.join("; ")}`);
      console.log(`publish_edition rejected: ${problems.join("; ")}`);
      const result: BetaToolResultBlockParam = {
        type: "tool_result",
        tool_use_id: call.id,
        is_error: true,
        content: `Not published. Fix these problems and call publish_edition again:\n- ${problems.join("\n- ")}`,
      };
      messages.push({ role: "user", content: [result] });
      continue;
    }

    const edition = assembleEdition(date, parsed.data, markets, { seenUrls, warnings, model: MODEL });
    return { edition, usage, warnings };
  }
  throw new GenerationError("Too many turns without a publishable edition");
}

export interface AssembleOptions {
  /** URLs seen in search and fetch results; null skips the check (seed editions). */
  seenUrls: Set<string> | null;
  warnings: string[];
  model: string;
  generatedAt?: string;
}

/** Adds numbering, market figures, section titles and reading times, then validates. */
export function assembleEdition(date: string, draft: EditionDraft, markets: MarketSnapshot, options: AssembleOptions): Edition {
  const { seenUrls, warnings } = options;
  const sections = SECTION_KEYS.map((key) => {
    const stories = (draft.sections.find((section) => section.key === key)?.stories ?? [])
      .map((story) => (seenUrls ? keepVerifiedSources(story, seenUrls, warnings) : story))
      .filter((story) => story !== null)
      .map((story) => ({ ...story, reading_minutes: readingMinutes(storyWords(story)) }));
    if (!stories.length) throw new GenerationError(`Section ${key} has no stories with verifiable sources`);
    return { key, ...SECTIONS[key], stories };
  });

  const quotes: Quote[] = [...markets.quotes];
  for (const fallback of draft.markets ?? []) {
    if (markets.missing.includes(fallback.name) && !quotes.some((quote) => quote.name === fallback.name)) {
      const unit = UNITS[fallback.name];
      quotes.push({ ...fallback, unit, change_unit: unit === "yield" ? "bp" : "percent" });
      warnings.push(`${fallback.name} figure came from Claude's search, not the market feed`);
    }
  }

  const allStories = sections.flatMap((section) => section.stories);
  const storyId = allStories.some((story) => story.id === draft.big_story.story_id) ? draft.big_story.story_id : null;
  const edition = {
    schema_version: 1 as const,
    date,
    number: editionNumber(date),
    volume: volume(date),
    big_story: { text: draft.big_story.text, story_id: storyId },
    markets: { as_of: markets.asOf ?? previousWeekday(date), quotes: orderQuotes(quotes) },
    sections,
    reading_minutes: readingMinutes(allStories.reduce((sum, story) => sum + storyWords(story), 0)),
    footer: FOOTER,
    model: options.model,
    generated_at: options.generatedAt ?? new Date().toISOString(),
  };
  const checked = Edition.safeParse(edition);
  if (!checked.success) throw new GenerationError(`Assembled edition is invalid: ${checked.error.message}`);
  return checked.data;
}
