-- Model output persistence and EMA fields for stress calibration.

alter table public.wellbeing_entries
  add column if not exists stress_now integer,
  add column if not exists fatigue integer,
  add column if not exists wellness integer;

create table if not exists public.health_model_outputs (
  id bigserial primary key,
  subject_id text not null references public.user_private_subjects (subject_id) on delete cascade,
  model_id text not null,
  model_version text not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  score double precision,
  confidence double precision not null default 0,
  status text not null,
  source text,
  reason text,
  reason_codes jsonb not null default '[]'::jsonb,
  data_quality jsonb not null default '{}'::jsonb,
  features jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique (subject_id, model_id, model_version, window_start, window_end)
);

create index if not exists idx_health_model_outputs_subject_time
  on public.health_model_outputs (subject_id, window_end desc);

create index if not exists idx_health_model_outputs_subject_model
  on public.health_model_outputs (subject_id, model_id, window_end desc);

alter table public.health_model_outputs enable row level security;

drop policy if exists health_model_outputs_by_subject_owner on public.health_model_outputs;
create policy health_model_outputs_by_subject_owner
on public.health_model_outputs
for all
to authenticated
using (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = health_model_outputs.subject_id
      and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.user_private_subjects s
    where s.subject_id = health_model_outputs.subject_id
      and s.user_id = auth.uid()
  )
);

grant select, insert, update, delete on public.health_model_outputs to authenticated;
grant usage, select on all sequences in schema public to authenticated;
