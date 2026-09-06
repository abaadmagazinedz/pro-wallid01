-- WALID / Supabase schema
create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  section_id uuid not null references public.sections(id) on delete cascade,
  gender text not null default 'ذكر' check (gender in ('ذكر','أنثى')),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  date date not null,
  status text not null check (status in ('حاضر','غائب','متأخر','معذور')),
  unique(student_id,date)
);

create table if not exists public.grades (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  activity text not null,
  score numeric(5,2) not null check (score >= 0 and score <= 20),
  created_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sport text,
  activity_date date,
  notes text,
  created_at timestamptz not null default now()
);

-- بعد إنشاء الجداول، فعّل RLS ثم أنشئ سياسات الوصول حسب طريقة تسجيل الدخول التي ستستخدمها.
