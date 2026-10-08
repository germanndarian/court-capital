import { z } from "zod";

// Two shapes:
// - EditionDraft: what Claude hands back through the publish_edition tool.
// - Edition: what is stored in Supabase (editions.content) and read by the app. The job
//   adds the date, numbering, market figures, section titles and reading times.

export const REGIONS = ["US", "CH", "EU", "UK", "ASIA", "GLOBAL"] as const;
export const SECTION_KEYS = ["corporate_law", "finance", "ai"] as const;
export const MARKET_NAMES = ["S&P 500", "Nasdaq", "SMI", "US 10Y", "USD/CHF", "Brent"] as const;

export const SECTIONS = {
  corporate_law: { numeral: "I", title: "Corporate Law", note: "US focus" },
  finance: { numeral: "II", title: "Finance", note: "US & Swiss markets" },
  ai: { numeral: "III", title: "AI", note: "Quick hits" },
} as const;

export const FOOTER = "compiled by Claude from public reporting · not financial or legal advice";

const Region = z.enum(REGIONS).describe("Where the story happens: US, CH, EU, UK, ASIA or GLOBAL");

const WhoIsWho = z.object({
  name: z.string().describe("A company, court, agency or person named in the story, e.g. \"SEC\""),
  description: z.string().describe("What it is in a few plain words, e.g. \"US stock-market regulator\""),
});

const Source = z.object({
  outlet: z.string().describe("Publication name, e.g. \"Bloomberg Law\" or \"Reuters via Investing.com\""),
  url: z.string().describe("The article URL exactly as it appeared in your search or fetch results"),
});

export const StoryDraft = z.object({
  id: z.string().describe("Short kebab-case slug, unique in this edition, e.g. \"fed-minutes\""),
  headline: z.string().describe("Says what actually happened. No teasers, no questions."),
  region: Region,
  whos_who: z.array(WhoIsWho).describe("Every company, court, agency or person in the story"),
  body: z
    .string()
    .describe(
      "2–4 sentences of facts, numbers and dates, in your own words. Explain technical terms inline in italic parentheses: *(stepped aside from the case)*",
    ),
  why_it_matters: z.string().nullable().describe("1–2 sentences. May be null only for AI quick hits."),
  plain_words: z.array(z.string()).describe("Exactly 3 short, simple sentences"),
  sources: z.array(Source).describe("1–4 outlets you actually read for this story"),
});

export const MarketFallback = z.object({
  name: z.enum(MARKET_NAMES),
  level: z.number().describe("Closing level; for US 10Y the yield in percent, e.g. 5.36"),
  change: z.number().describe("Change on the day: percent for indices, FX and Brent; basis points for US 10Y"),
});

export const EditionDraft = z.object({
  big_story: z.object({
    text: z.string().describe("One sentence: the single most important development, stated plainly"),
    story_id: z.string().describe("The id of the story below that covers it"),
  }),
  sections: z
    .array(
      z.object({
        key: z.enum(SECTION_KEYS),
        stories: z.array(StoryDraft),
      }),
    )
    .describe("Exactly three sections in this order: corporate_law, finance, ai"),
  markets: z
    .array(MarketFallback)
    .nullable()
    .describe("Only when the instructions say market data is missing; otherwise null"),
});

export type EditionDraft = z.infer<typeof EditionDraft>;
export type StoryDraft = z.infer<typeof StoryDraft>;

// MARK: - Stored edition

export const Quote = z.object({
  name: z.enum(MARKET_NAMES),
  level: z.number(),
  change: z.number(),
  change_unit: z.enum(["percent", "bp"]),
  unit: z.enum(["index", "yield", "fx", "usd"]),
});

export const Story = StoryDraft.extend({
  why_it_matters: z.string().min(1).nullable(),
  plain_words: z.array(z.string().min(1)).length(3),
  sources: z
    .array(Source.extend({ url: z.url() }))
    .min(1)
    .max(4),
  whos_who: z.array(WhoIsWho).min(1),
  reading_minutes: z.number().int().positive(),
});

export const Section = z.object({
  key: z.enum(SECTION_KEYS),
  numeral: z.string(),
  title: z.string(),
  note: z.string(),
  stories: z.array(Story).min(1),
});

export const Edition = z.object({
  schema_version: z.literal(1),
  date: z.iso.date(),
  number: z.number().int().positive(),
  volume: z.number().int().positive(),
  big_story: z.object({ text: z.string().min(1), story_id: z.string().nullable() }),
  markets: z.object({ as_of: z.iso.date(), quotes: z.array(Quote) }),
  sections: z.array(Section).length(3),
  reading_minutes: z.number().int().positive(),
  footer: z.string(),
  model: z.string(),
  generated_at: z.iso.datetime({ offset: true }),
});

export type Quote = z.infer<typeof Quote>;
export type Story = z.infer<typeof Story>;
export type Edition = z.infer<typeof Edition>;

/**
 * JSON Schema for a strict tool. Strict tools accept a subset of JSON Schema: every
 * object closed and fully required, and no length or range constraints (those are
 * checked in code after the call).
 */
export function strictToolSchema(schema: z.ZodType): Record<string, unknown> {
  const json = z.toJSONSchema(schema, { target: "draft-2020-12", io: "input" }) as Record<string, unknown>;
  const unsupported = new Set(["$schema", "minLength", "maxLength", "minItems", "maxItems", "minimum", "maximum", "pattern", "format"]);
  const visit = (node: unknown): unknown => {
    if (Array.isArray(node)) return node.map(visit);
    if (!node || typeof node !== "object") return node;
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(node)) {
      if (!unsupported.has(key)) result[key] = visit(value);
    }
    if (result.type === "object" && result.properties) {
      result.additionalProperties = false;
      result.required = Object.keys(result.properties as object);
    }
    return result;
  };
  return visit(json) as Record<string, unknown>;
}
