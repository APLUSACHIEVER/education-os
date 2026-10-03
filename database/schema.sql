-- 教育管家｜家庭教育管理平台
-- 数据库第一版：PostgreSQL / Supabase 兼容
-- 原则：家庭隔离、学生按学年管理、Master 与交易数据分离、所有业务记录可追溯

create extension if not exists pgcrypto;

create table if not exists families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  primary_contact_name text,
  primary_contact_phone text,
  primary_contact_email text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists family_settings (
  family_id uuid primary key references families(id) on delete cascade,
  timezone text not null default 'Asia/Singapore',
  currency text not null default 'SGD',
  language text not null default 'zh-CN',
  week_starts_on int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  preferred_name text,
  date_of_birth date,
  gender text,
  nationality text,
  status text not null default 'active' check (status in ('active','inactive','archived')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists student_contacts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  name text not null,
  relationship text,
  phone text,
  email text,
  is_primary boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists academic_years (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  year_label text not null,
  start_date date not null,
  end_date date not null,
  education_level text not null check (education_level in ('primary','secondary','jc')),
  grade_code text not null,
  pathway text,
  school_name text,
  school_type text,
  class_name text,
  is_current boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(student_id, year_label)
);

create table if not exists subject_master (
  id uuid primary key default gen_random_uuid(),
  education_level text not null check (education_level in ('primary','secondary','jc')),
  subject_code text not null,
  subject_name text not null,
  subject_group text,
  curriculum_pathway text,
  level_code text,
  is_moe_supported boolean not null default true,
  is_active boolean not null default true,
  sort_order int not null default 0,
  notes text,
  unique(education_level, subject_code)
);

create table if not exists student_subjects (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  subject_id uuid not null references subject_master(id),
  subject_name_snapshot text not null,
  level_code text,
  teacher_name text,
  weekly_frequency text,
  teaching_mode text,
  tuition_course_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(academic_year_id, subject_id)
);

create table if not exists schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  school_type text,
  education_level text,
  planning_area text,
  status text not null default 'active',
  notes text,
  unique(name)
);

create table if not exists student_school_history (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id) on delete cascade,
  school_id uuid references schools(id),
  school_name_snapshot text not null,
  school_type text,
  admission_route text,
  notes text
);

create table if not exists teachers (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  subjects text[],
  teaching_mode text,
  status text not null default 'active' check (status in ('active','inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id),
  academic_year_id uuid references academic_years(id),
  subject_id uuid references subject_master(id),
  teacher_id uuid references teachers(id),
  name text not null,
  course_type text,
  mode text,
  weekly_schedule text,
  start_date date,
  end_date date,
  duration_hours numeric(8,2),
  status text not null default '已安排',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists packages (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id),
  course_id uuid references courses(id),
  name text not null,
  total_hours numeric(8,2) not null default 0,
  used_hours numeric(8,2) not null default 0,
  total_amount numeric(12,2),
  start_date date,
  expiry_date date,
  status text not null default '进行中',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (used_hours >= 0 and used_hours <= total_hours)
);

create table if not exists lessons (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  course_id uuid references courses(id),
  package_id uuid references packages(id),
  student_id uuid not null references students(id),
  teacher_id uuid references teachers(id),
  subject_id uuid references subject_master(id),
  lesson_date date not null,
  start_time time,
  duration_hours numeric(6,2) not null default 1,
  status text not null default '已安排',
  planned boolean not null default false,
  note text,
  completed_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists teacher_feedback (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  course_id uuid references courses(id),
  lesson_id uuid references lessons(id),
  student_id uuid not null references students(id),
  teacher_id uuid references teachers(id),
  feedback_date date not null default current_date,
  status text not null default '待跟进' check (status in ('待跟进','待同步','已同步','已处理')),
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists drivers (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  phone text,
  license_info text,
  status text not null default 'active',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists vehicles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  name text not null,
  registration_no text,
  vehicle_type text,
  capacity int,
  status text not null default 'active',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists transport_tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id),
  driver_id uuid references drivers(id),
  vehicle_id uuid references vehicles(id),
  related_lesson_id uuid references lessons(id),
  task_date date not null,
  pickup_time time,
  pickup_location text,
  dropoff_location text,
  direction text,
  status text not null default '待执行',
  temporary boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists temporary_arrangements (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id),
  arrangement_date date not null,
  start_time time,
  end_time time,
  type text not null,
  description text not null,
  driver_id uuid references drivers(id),
  vehicle_id uuid references vehicles(id),
  status text not null default '待执行',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists conflicts (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id),
  conflict_type text not null,
  severity text not null default '一般',
  conflict_date date,
  start_time time,
  end_time time,
  description text not null,
  source_type text,
  source_id text,
  is_auto_detected boolean not null default false,
  status text not null default '待处理',
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id),
  course_id uuid references courses(id),
  feedback_id uuid references teacher_feedback(id),
  name text not null,
  due_date date,
  status text not null default '待处理',
  priority text not null default '一般',
  source text,
  note text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists academic_goals (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id),
  academic_year_id uuid references academic_years(id),
  subject_id uuid references subject_master(id),
  title text not null,
  target text,
  due_date date,
  status text not null default '进行中',
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists assessments (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id),
  academic_year_id uuid references academic_years(id),
  subject_id uuid references subject_master(id),
  assessment_date date not null,
  assessment_type text,
  assessment_name text,
  score numeric(8,2),
  grade text,
  level text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists progress_records (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id),
  academic_year_id uuid references academic_years(id),
  subject_id uuid references subject_master(id),
  course_id uuid references courses(id),
  feedback_id uuid references teacher_feedback(id),
  record_date date not null default current_date,
  level text,
  note text not null,
  source text,
  created_at timestamptz not null default now()
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id),
  academic_year_id uuid references academic_years(id),
  course_id uuid references courses(id),
  lesson_id uuid references lessons(id),
  category text,
  description text,
  amount numeric(12,2) not null default 0,
  payment_date date not null default current_date,
  status text not null default '待支付',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists activities (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id),
  name text not null,
  activity_type text,
  activity_date date,
  start_time time,
  end_time time,
  location text,
  status text not null default '已安排',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_students_family on students(family_id);
create index if not exists idx_academic_years_student on academic_years(student_id);
create index if not exists idx_student_subjects_year on student_subjects(academic_year_id);
create index if not exists idx_courses_student on courses(student_id);
create index if not exists idx_lessons_date on lessons(lesson_date);
create index if not exists idx_lessons_student on lessons(student_id);
create index if not exists idx_transport_date on transport_tasks(task_date);
create index if not exists idx_transport_student on transport_tasks(student_id);
create index if not exists idx_conflicts_status on conflicts(status);
create index if not exists idx_tasks_status_due on tasks(status,due_date);
create index if not exists idx_feedback_status on teacher_feedback(status);
create index if not exists idx_payments_date on payments(payment_date);
create index if not exists idx_progress_student_date on progress_records(student_id,record_date);
create index if not exists idx_assessments_student_date on assessments(student_id,assessment_date);

-- 业务关系：
-- 家庭 → 学生 → 学年 → 学科
-- 学生 → 课程 → 课次 → 费用 / 教师反馈 → 学业记录 / 待处理任务
-- 学生 → 接送任务 ← 司机 / 车辆
-- 课程 / 接送 / 临时安排 → 冲突
-- 上述记录共同组成学生时间线与家庭报告
