import { mkdir, writeFile } from "node:fs/promises";
import { parseArgs } from "node:util";
import type { SupabaseClient } from "@supabase/supabase-js";
import { isWeekday, longDate, zurichNow } from "./calendar.ts";
import { generateEdition, MODEL } from "./generate.ts";
import { fetchMarkets } from "./markets.ts";
import { connect, editionExists, logRun, saveEdition } from "./store.ts";

// Runs twice every weekday morning (02:15 and 03:15 UTC) so that one run lands at 04:15 in
// Zürich whatever the season. A run only generates when today's edition doesn't exist yet,
// so the second run either skips or catches up after a failed first run.
//
//   npm run generate                  scheduled behaviour
//   npm run generate -- --force       regenerate and replace today's edition
//   npm run generate -- --dry-run     generate into out/edition.json without saving
//   npm run generate -- --date 2026-10-08

const { values: options } = parseArgs({
  options: {
    force: { type: "boolean", default: false },
    "dry-run": { type: "boolean", default: false },
    date: { type: "string" },
  },
});

const trigger = process.env.TRIGGER ?? "manual";
const dryRun = options["dry-run"] ?? false;
const RETRY_DELAY_MS = 60_000;

async function main(): Promise<number> {
  const now = zurichNow();
  const date = options.date ?? now.date;
  console.log(`Court & Capital · ${longDate(date)} · ${trigger}${dryRun ? " · dry run" : ""} · ${MODEL}`);
  console.log(`Zürich time now: ${now.date} ${String(now.hour).padStart(2, "0")}:${String(now.minute).padStart(2, "0")}`);

  if (!isWeekday(date) && !dryRun) {
    console.log("No edition on weekends. (Use --dry-run to test on a weekend.)");
    return 0;
  }

  const db: SupabaseClient | null = dryRun ? null : connect();
  if (db && !options.force && (await editionExists(db, date))) {
    console.log("Today's edition is already published. Nothing to do. (Use --force to replace it.)");
    return 0;
  }

  const markets = await fetchMarkets(date);
  console.log(`Markets as of ${markets.asOf ?? "unknown"}: ${markets.quotes.length} fetched, missing: ${markets.missing.join(", ") || "none"}`);

  // One attempt plus one retry, as the brief asks. Each failure is logged to generation_runs.
  for (let attempt = 1; attempt <= 2; attempt++) {
    const startedAt = new Date().toISOString();
    try {
      const { edition, usage, warnings } = await generateEdition(date, markets);
      warnings.forEach((warning) => console.warn(`Warning: ${warning}`));
      console.log(`Usage: ${JSON.stringify(usage)}`);

      await mkdir("out", { recursive: true });
      await writeFile("out/edition.json", JSON.stringify(edition, null, 2));
      if (db) {
        await saveEdition(db, edition);
        await logRun(db, { edition_date: date, trigger, attempt, status: "succeeded", model: MODEL, usage, warnings, started_at: startedAt });
      }
      const stories = edition.sections.reduce((sum, section) => sum + section.stories.length, 0);
      console.log(`${dryRun ? "Generated (not saved)" : "Published"}: No. ${edition.number}, ${stories} stories, ${edition.reading_minutes} min read`);
      return 0;
    } catch (error) {
      const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
      console.error(`Attempt ${attempt} failed: ${message}`);
      await logRun(db, { edition_date: date, trigger, attempt, status: "failed", error: message, model: MODEL, started_at: startedAt });
      if (attempt < 2) {
        console.log(`Retrying in ${RETRY_DELAY_MS / 1000} seconds…`);
        await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
      }
    }
  }
  console.error("Both attempts failed. The app keeps showing the last good edition.");
  return 1;
}

process.exitCode = await main();
