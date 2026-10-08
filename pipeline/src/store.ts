import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Edition } from "./schema.ts";

// Only this job writes to the database, with the secret key from GitHub secrets. The app
// reads with the publishable key, which row-level security limits to SELECT on editions.

export function connect(): SupabaseClient {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_SECRET_KEY must be set (or pass --dry-run)");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

export async function editionExists(db: SupabaseClient, date: string): Promise<boolean> {
  const { count, error } = await db.from("editions").select("edition_date", { count: "exact", head: true }).eq("edition_date", date);
  if (error) throw new Error(`Checking for today's edition failed: ${error.message}`);
  return (count ?? 0) > 0;
}

export async function saveEdition(db: SupabaseClient, edition: Edition): Promise<void> {
  const { error } = await db.from("editions").upsert(
    {
      edition_date: edition.date,
      number: edition.number,
      big_story: edition.big_story.text,
      content: edition,
      schema_version: edition.schema_version,
      model: edition.model,
      published_at: new Date().toISOString(),
    },
    { onConflict: "edition_date" },
  );
  if (error) throw new Error(`Saving the edition failed: ${error.message}`);
}

export interface RunLog {
  edition_date: string;
  trigger: string;
  attempt: number;
  status: "succeeded" | "failed" | "skipped";
  error?: string | null;
  model?: string | null;
  usage?: Record<string, unknown> | null;
  warnings?: string[] | null;
  started_at: string;
}

/** Best effort: a broken log table must never hide the real outcome. */
export async function logRun(db: SupabaseClient | null, run: RunLog): Promise<void> {
  if (!db) return;
  const { error } = await db.from("generation_runs").insert({ ...run, finished_at: new Date().toISOString() });
  if (error) console.warn(`Couldn't write the run log: ${error.message}`);
}
