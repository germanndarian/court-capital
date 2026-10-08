-- Court & Capital database.
-- Safe to run more than once. Paste setup.sql (this file plus the seed editions) into
-- Supabase → SQL Editor → New query → Run.

-- One row per published edition. `content` holds the whole edition as JSON
-- (pipeline/src/schema.ts → Edition); the other columns make listing cheap.
create table if not exists public.editions (
  id uuid primary key default gen_random_uuid(),
  edition_date date not null unique,
  number integer not null,
  big_story text not null,
  content jsonb not null,
  schema_version integer not null default 1,
  model text,
  published_at timestamptz not null default now()
);

create index if not exists editions_by_date on public.editions (edition_date desc);

-- Every generation attempt, for debugging. Not visible to the app.
create table if not exists public.generation_runs (
  id bigint generated always as identity primary key,
  edition_date date not null,
  trigger text not null,
  attempt integer not null,
  status text not null check (status in ('succeeded', 'failed', 'skipped')),
  error text,
  model text,
  usage jsonb,
  warnings jsonb,
  started_at timestamptz not null,
  finished_at timestamptz not null default now()
);

create index if not exists generation_runs_by_date on public.generation_runs (edition_date desc, finished_at desc);

-- Access. The app uses the publishable (anon) key: it may read editions and nothing else.
-- The pipeline uses the secret (service role) key, which bypasses row-level security.
alter table public.editions enable row level security;
alter table public.generation_runs enable row level security;

drop policy if exists "Anyone can read editions" on public.editions;
create policy "Anyone can read editions" on public.editions
  for select to anon, authenticated
  using (true);

revoke all on public.editions from anon, authenticated;
grant select on public.editions to anon, authenticated;
revoke all on public.generation_runs from anon, authenticated;

grant all on public.editions to service_role;
grant all on public.generation_runs to service_role;
