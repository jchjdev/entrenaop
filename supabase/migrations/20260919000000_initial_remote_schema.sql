-- Reconstructed from the production catalog on 2026-09-19.
--
-- This is the repository baseline for fresh local environments. The production
-- project already contains these objects, so this migration must be marked as
-- applied before any later migration is pushed there. Do not execute this file
-- directly against the existing production database.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  role text not null default 'free',
  fecha_nacimiento date,
  genero text,
  peso_kg numeric,
  altura_cm integer,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint profiles_role_check
    check (role in ('free', 'premium', 'seguimiento', 'admin')),
  constraint profiles_genero_check
    check (genero in ('masculino', 'femenino', 'otro'))
);

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  video_url text,
  thumbnail_url text,
  muscle_groups text[],
  equipment text[],
  difficulty text,
  exercise_type text,
  is_public boolean default true,
  created_by uuid references public.profiles (id),
  created_at timestamptz default now()
);

create table public.routines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  thumbnail_url text,
  routine_type text,
  workout_type text,
  difficulty text,
  estimated_duration_min integer,
  is_public boolean default false,
  requires_premium boolean default false,
  created_by uuid references public.profiles (id),
  assigned_to uuid references public.profiles (id),
  created_at timestamptz default now()
);

create table public.routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid references public.routines (id) on delete cascade,
  exercise_id uuid references public.exercises (id),
  order_index integer not null,
  sets integer,
  reps integer,
  duration_seconds integer,
  weight_kg numeric,
  rest_seconds integer,
  notes text
);

create table public.session_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id),
  routine_id uuid references public.routines (id),
  completed_at timestamptz default now(),
  duration_min integer,
  completed boolean default false,
  rpe integer,
  mood text,
  notes text,
  external_source text,
  constraint session_logs_rpe_check check (rpe between 1 and 10)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.session_logs enable row level security;

-- The remote policies are intentionally not reproduced here. They overlap and
-- allow users to update the legacy role field. The following migration defines
-- the complete, hardened access model from a deny-by-default state.
