-- External toilet data sync support tables and columns.
-- Apply after reviewing against the current production schema.

begin;

alter table daeddong."TOILET"
  add column if not exists external_source text,
  add column if not exists external_id text,
  add column if not exists source_updated_at timestamptz,
  add column if not exists last_synced_at timestamptz,
  add column if not exists is_active boolean not null default true;

create unique index if not exists toilet_external_source_external_id_key
  on daeddong."TOILET" (external_source, external_id)
  where external_source is not null and external_id is not null;

create index if not exists toilet_is_active_idx
  on daeddong."TOILET" (is_active);

create table if not exists daeddong.toilet_import_runs (
  id bigint generated always as identity primary key,
  source text not null,
  status text not null check (status in ('running', 'success', 'failed')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  fetched_count integer not null default 0,
  upserted_count integer not null default 0,
  deactivated_count integer not null default 0,
  error_message text,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists daeddong.toilet_import_raw (
  id bigint generated always as identity primary key,
  run_id bigint not null references daeddong.toilet_import_runs(id) on delete cascade,
  source text not null,
  external_id text,
  payload jsonb not null,
  fetched_at timestamptz not null default now()
);

create index if not exists toilet_import_raw_run_id_idx
  on daeddong.toilet_import_raw (run_id);

create index if not exists toilet_import_raw_source_external_id_idx
  on daeddong.toilet_import_raw (source, external_id);

create table if not exists daeddong.toilet_change_history (
  id bigint generated always as identity primary key,
  run_id bigint references daeddong.toilet_import_runs(id) on delete set null,
  toilet_seq integer references daeddong."TOILET"(seq) on delete set null,
  external_source text not null,
  external_id text,
  change_type text not null check (change_type in ('insert', 'update', 'deactivate', 'reactivate')),
  before_data jsonb,
  after_data jsonb,
  changed_at timestamptz not null default now()
);

create index if not exists toilet_change_history_run_id_idx
  on daeddong.toilet_change_history (run_id);

create index if not exists toilet_change_history_source_external_id_idx
  on daeddong.toilet_change_history (external_source, external_id);

commit;
