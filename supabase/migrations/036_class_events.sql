-- 학급 공유 일정: 같은 학년/반 사용자끼리만 조회 가능한 일정
create table if not exists public.class_events (
  id uuid primary key default uuid_generate_v4(),
  grade smallint not null check (grade between 1 and 3),
  class_number smallint not null check (class_number between 1 and 10),
  title text not null,
  description text,
  start_at timestamptz not null,
  end_at timestamptz,
  all_day boolean not null default false,
  created_by_user_id uuid not null references auth.users(id) on delete cascade,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_events_valid_range check (end_at is null or end_at > start_at)
);

create index if not exists idx_class_events_grade_class_start_at
  on public.class_events(grade, class_number, start_at);

create index if not exists idx_class_events_created_by_user_id
  on public.class_events(created_by_user_id);

alter table public.class_events enable row level security;

create policy "Classmates can read class events"
  on public.class_events for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where user_id = auth.uid()
        and grade = class_events.grade
        and class_number = class_events.class_number
    )
  );

create policy "Users can insert class events for own class"
  on public.class_events for insert
  to authenticated
  with check (
    auth.uid() = created_by_user_id
    and exists (
      select 1
      from public.profiles
      where user_id = auth.uid()
        and id = created_by_profile_id
        and grade = class_events.grade
        and class_number = class_events.class_number
    )
  );

create policy "Creators or admins can update class events"
  on public.class_events for update
  to authenticated
  using (
    auth.uid() = created_by_user_id
    or exists (
      select 1
      from public.profiles
      where user_id = auth.uid()
        and role = 'admin'
    )
  )
  with check (
    auth.uid() = created_by_user_id
    or exists (
      select 1
      from public.profiles
      where user_id = auth.uid()
        and role = 'admin'
    )
  );

create policy "Creators or admins can delete class events"
  on public.class_events for delete
  to authenticated
  using (
    auth.uid() = created_by_user_id
    or exists (
      select 1
      from public.profiles
      where user_id = auth.uid()
        and role = 'admin'
    )
  );

create trigger class_events_updated_at
  before update on public.class_events
  for each row
  execute function public.set_updated_at();
