-- STEX2 e-Kokurikulum — Supabase/PostgreSQL schema
-- Run this script in Supabase SQL Editor.
-- IMPORTANT: use only the publishable/anon key in the browser; never expose service_role.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'teacher' check (role in ('admin','teacher')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  student_no text,
  form_level text,
  class_name text,
  gender text,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists students_name_idx on public.students(name);

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  position text,
  phone text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit_type text not null check (unit_type in ('Unit Uniform','Kelab & Persatuan','Sukan & Permainan')),
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.unit_students (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  year integer not null default extract(year from now()),
  unique(unit_id,student_id,year)
);

create table if not exists public.unit_teachers (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  role text default 'Guru Penasihat',
  year integer not null default extract(year from now()),
  unique(unit_id,teacher_id,year)
);

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_date date not null,
  category text,
  location text,
  description text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists calendar_date_idx on public.calendar_events(event_date);

create table if not exists public.meetings (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  meeting_date date not null,
  meeting_no integer,
  location text,
  activity_description text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists meetings_date_idx on public.meetings(meeting_date);

create table if not exists public.student_attendance (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status boolean not null default false,
  remark text,
  unique(meeting_id,student_id)
);

create table if not exists public.teacher_attendance (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  status boolean not null default false,
  remark text,
  unique(meeting_id,teacher_id)
);

create table if not exists public.opr (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid references public.meetings(id) on delete set null,
  unit_id uuid not null references public.units(id) on delete cascade,
  activity_date date not null,
  meeting_no integer,
  activity_title text not null,
  objective text,
  activity_description text,
  attendance_count integer default 0,
  teacher_in_charge text,
  photo_urls text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists opr_date_idx on public.opr(activity_date);

create table if not exists public.houses (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  color text,
  created_at timestamptz not null default now()
);

create table if not exists public.house_students (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.houses(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  year integer not null default extract(year from now()),
  unique(house_id,student_id,year)
);

create table if not exists public.house_teachers (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.houses(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  year integer not null default extract(year from now()),
  unique(house_id,teacher_id,year)
);

create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id) on delete set null,
  student_name text,
  activity_name text not null,
  level text,
  achievement text,
  year integer,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- Convenience views for dashboard counts.
create or replace view public.unit_counts as
select u.id,u.name,u.unit_type,u.description,
  coalesce(s.member_count,0)::int as member_count,
  coalesce(g.guru_count,0)::int as guru_count
from public.units u
left join (select unit_id,count(*) member_count from public.unit_students group by unit_id) s on s.unit_id=u.id
left join (select unit_id,count(*) guru_count from public.unit_teachers group by unit_id) g on g.unit_id=u.id;

drop view if exists public.houses_counts cascade;
create view public.houses_counts as
select h.id,h.name,h.color,
  coalesce(s.member_count,0)::int member_count,
  coalesce(t.teacher_count,0)::int teacher_count
from public.houses h
left join (select house_id,count(*) member_count from public.house_students group by house_id) s on s.house_id=h.id
left join (select house_id,count(*) teacher_count from public.house_teachers group by house_id) t on t.house_id=h.id;

-- Expose views through PostgREST; app can keep querying base tables initially.

-- RLS: all signed-in school staff can read and maintain operational data.
-- Tighten these policies later if you want advisor-only editing.
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.teachers enable row level security;
alter table public.units enable row level security;
alter table public.unit_students enable row level security;
alter table public.unit_teachers enable row level security;
alter table public.calendar_events enable row level security;
alter table public.meetings enable row level security;
alter table public.student_attendance enable row level security;
alter table public.teacher_attendance enable row level security;
alter table public.opr enable row level security;
alter table public.houses enable row level security;
alter table public.house_students enable row level security;
alter table public.house_teachers enable row level security;
alter table public.achievements enable row level security;

do $$
declare t text; begin
  foreach t in array array['students','teachers','units','unit_students','unit_teachers','calendar_events','meetings','student_attendance','teacher_attendance','opr','houses','house_students','house_teachers','achievements'] loop
    execute format('drop policy if exists "authenticated_all_%s" on public.%I',t,t);
    execute format('create policy "authenticated_all_%s" on public.%I for all to authenticated using (true) with check (true)',t,t);
  end loop;
end $$;

drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles for select to authenticated using (id=auth.uid());
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

-- API grants for signed-in school staff. RLS remains the main access control layer.
grant select, insert, update, delete on public.students, public.teachers, public.units, public.unit_students, public.unit_teachers, public.calendar_events, public.meetings, public.student_attendance, public.teacher_attendance, public.opr, public.houses, public.house_students, public.house_teachers, public.achievements to authenticated;
grant select on public.unit_counts, public.houses_counts to authenticated;

-- Storage bucket for school activity photos and generated files.
insert into storage.buckets (id,name,public) values ('kokurikulum','kokurikulum',false)
on conflict (id) do nothing;

drop policy if exists kokurikulum_read on storage.objects;
create policy kokurikulum_read on storage.objects for select to authenticated using (bucket_id='kokurikulum');
drop policy if exists kokurikulum_insert on storage.objects;
create policy kokurikulum_insert on storage.objects for insert to authenticated with check (bucket_id='kokurikulum');
drop policy if exists kokurikulum_update on storage.objects;
create policy kokurikulum_update on storage.objects for update to authenticated using (bucket_id='kokurikulum') with check (bucket_id='kokurikulum');
drop policy if exists kokurikulum_delete on storage.objects;
create policy kokurikulum_delete on storage.objects for delete to authenticated using (bucket_id='kokurikulum');

-- Initial six house sports requested for STEX2.
insert into public.houses(name,color) values
('NEPTUNE','Biru'),('MARS','Merah'),('SATURN','Kuning'),('URANUS','Hijau'),('JUPITER','Oren'),('PLUTO','Ungu')
on conflict (name) do update set color=excluded.color;
