alter table public.health_metric_samples
  add column if not exists interval_start_at timestamptz,
  add column if not exists interval_end_at timestamptz;

update public.health_metric_samples
set interval_end_at = observed_at
where interval_end_at is null;

create index if not exists idx_health_metric_samples_subject_interval_end
  on public.health_metric_samples (subject_id, interval_end_at desc);
