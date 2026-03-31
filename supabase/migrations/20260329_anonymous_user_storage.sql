-- Anonymous user storage model for MediAI.
-- Purpose:
-- 1) keep health/wellbeing/onboarding data out of auth.user_metadata,
-- 2) store domain data in dedicated tables,
-- 3) avoid direct account IDs in domain tables by using subject_id.

create table if not exists public.user_private_subjects (
  subject_id text primary key,
  user_id uuid not null unique references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.onboarding_profiles (
  subject_id text primary key references public.user_private_subjects (subject_id) on delete cascade,
  recorded_at timestamptz,
  first_name text,
  last_name text,
  age integer,
  sex text,
  height_cm double precision,
  weight_kg double precision,
  blood_pressure_systolic integer,
  blood_pressure_diastolic integer,
  glucose integer,
  temperature_c double precision,
  symptoms text[] not null default '{}'::text[],
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.wellbeing_entries (
  id bigserial primary key,
  subject_id text not null references public.user_private_subjects (subject_id) on delete cascade,
  entry_date date not null,
  mood text not null,
  tags text[] not null default '{}'::text[],
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (subject_id, entry_date)
);

create table if not exists public.health_source_connections (
  subject_id text not null references public.user_private_subjects (subject_id) on delete cascade,
  source_id text not null,
  is_connected boolean not null default true,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (subject_id, source_id)
);

create table if not exists public.health_metric_samples (
  id bigserial primary key,
  subject_id text not null references public.user_private_subjects (subject_id) on delete cascade,
  sample_id text not null,
  metric_type text not null,
  value double precision not null,
  unit text not null,
  observed_at timestamptz not null,
  source_id text not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (subject_id, sample_id)
);

create index if not exists idx_wellbeing_entries_subject_date
  on public.wellbeing_entries (subject_id, entry_date desc);

create index if not exists idx_health_metric_samples_subject_time
  on public.health_metric_samples (subject_id, observed_at desc);

create index if not exists idx_health_metric_samples_subject_type
  on public.health_metric_samples (subject_id, metric_type);

alter table public.user_private_subjects enable row level security;
alter table public.onboarding_profiles enable row level security;
alter table public.wellbeing_entries enable row level security;
alter table public.health_source_connections enable row level security;
alter table public.health_metric_samples enable row level security;

drop policy if exists subjects_owner_only on public.user_private_subjects;
create policy subjects_owner_only
on public.user_private_subjects
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists onboarding_by_subject_owner on public.onboarding_profiles;
create policy onboarding_by_subject_owner
on public.onboarding_profiles
for all
to authenticated
using (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = onboarding_profiles.subject_id
      and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = onboarding_profiles.subject_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists wellbeing_by_subject_owner on public.wellbeing_entries;
create policy wellbeing_by_subject_owner
on public.wellbeing_entries
for all
to authenticated
using (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = wellbeing_entries.subject_id
      and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = wellbeing_entries.subject_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists health_connections_by_subject_owner on public.health_source_connections;
create policy health_connections_by_subject_owner
on public.health_source_connections
for all
to authenticated
using (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = health_source_connections.subject_id
      and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = health_source_connections.subject_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists health_samples_by_subject_owner on public.health_metric_samples;
create policy health_samples_by_subject_owner
on public.health_metric_samples
for all
to authenticated
using (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = health_metric_samples.subject_id
      and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = health_metric_samples.subject_id
      and s.user_id = auth.uid()
  )
);

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.user_private_subjects to authenticated;
grant select, insert, update, delete on public.onboarding_profiles to authenticated;
grant select, insert, update, delete on public.wellbeing_entries to authenticated;
grant select, insert, update, delete on public.health_source_connections to authenticated;
grant select, insert, update, delete on public.health_metric_samples to authenticated;
grant usage, select on all sequences in schema public to authenticated;
