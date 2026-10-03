-- 教育管家｜Supabase 首次完整迁移
-- 生成于 2026-10-03
-- 说明：生产数据库应通过 Supabase migration 执行，避免直接修改远端结构。

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


-- ============================================================
-- Education OS 第一版完整数据库扩展
-- 平台级：账号 / 家庭成员 / 权限 / 日历 / 学期 / 路径 / DSA /
-- 提醒通知 / 审计 / 报表视图 / Supabase RLS
-- ============================================================

-- 1. 登录用户与家庭成员
create table if not exists app_users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique,
  display_name text,
  email text,
  phone text,
  status text not null default 'active' check (status in ('active','inactive')),
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  user_id uuid not null references app_users(id) on delete cascade,
  relationship text,
  role_code text not null default 'member',
  is_primary boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive','invited')),
  invited_at timestamptz,
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(family_id,user_id)
);

create table if not exists roles (
  code text primary key,
  name text not null,
  description text
);

create table if not exists permissions (
  code text primary key,
  name text not null,
  description text
);

create table if not exists role_permissions (
  role_code text not null references roles(code) on delete cascade,
  permission_code text not null references permissions(code) on delete cascade,
  primary key(role_code,permission_code)
);

insert into roles(code,name,description) values
('owner','家庭管理员','管理家庭全部资料与权限'),
('parent','家长','管理家庭日常教育与事务'),
('caregiver','照护成员','负责接送及家庭日常事务'),
('viewer','查看成员','仅查看授权家庭信息'),
('member','家庭成员','基础家庭成员权限')
on conflict(code) do update set name=excluded.name,description=excluded.description;

insert into permissions(code,name,description) values
('family.view','查看家庭','查看家庭基本资料'),
('family.manage','管理家庭','修改家庭设置与成员'),
('student.view','查看学生','查看学生档案'),
('student.manage','管理学生','维护学生档案与学年'),
('education.manage','管理教育','课程、老师、课时包、反馈'),
('transport.manage','管理接送','司机、车辆、接送任务'),
('academic.manage','管理学业','目标、成绩、学习记录'),
('finance.view','查看费用','查看家庭费用'),
('finance.manage','管理费用','维护家庭费用'),
('calendar.manage','管理日历','维护家庭日历'),
('dsa.manage','管理升学规划','维护学校与DSA规划'),
('task.manage','管理任务','维护家庭任务与待处理'),
('report.view','查看报告','查看家庭报告'),
('audit.view','查看审计','查看操作记录')
on conflict(code) do update set name=excluded.name,description=excluded.description;

insert into role_permissions(role_code,permission_code)
select 'owner',code from permissions
on conflict do nothing;

insert into role_permissions(role_code,permission_code)
select 'parent',code from permissions where code not in ('audit.view')
on conflict do nothing;

insert into role_permissions(role_code,permission_code)
select 'caregiver',code from permissions where code in
('family.view','student.view','transport.manage','calendar.manage','task.manage')
on conflict do nothing;

insert into role_permissions(role_code,permission_code)
select 'viewer',code from permissions where code in
('family.view','student.view','finance.view','report.view')
on conflict do nothing;

insert into role_permissions(role_code,permission_code)
select 'member',code from permissions where code in
('family.view','student.view','calendar.manage','task.manage')
on conflict do nothing;

-- 2. 教育路径 / 年级 / 学期
create table if not exists education_pathways (
  id uuid primary key default gen_random_uuid(),
  education_level text not null check (education_level in ('primary','secondary','jc')),
  pathway_code text not null,
  pathway_name text not null,
  grade_start text,
  grade_end text,
  description text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  unique(education_level,pathway_code)
);

create table if not exists grade_master (
  id uuid primary key default gen_random_uuid(),
  education_level text not null check (education_level in ('primary','secondary','jc')),
  grade_code text not null,
  grade_name text not null,
  pathway_code text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  unique(education_level,grade_code,pathway_code)
);

create table if not exists academic_terms (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete cascade,
  academic_year_label text not null,
  term_code text not null,
  term_name text not null,
  start_date date not null,
  end_date date not null,
  source text default '家庭设置',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(family_id,academic_year_label,term_code)
);

create table if not exists school_calendar_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete cascade,
  academic_year_label text,
  event_date date not null,
  end_date date,
  event_type text not null,
  title text not null,
  description text,
  is_school_day boolean,
  source text default '家庭设置',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. 家庭统一日历
create table if not exists calendar_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id) on delete cascade,
  academic_year_id uuid references academic_years(id) on delete set null,
  event_type text not null,
  title text not null,
  description text,
  event_date date not null,
  start_time time,
  end_time time,
  all_day boolean not null default false,
  location text,
  status text not null default '已安排',
  priority text not null default '一般',
  source_type text,
  source_id uuid,
  repeat_rule jsonb,
  reminder_minutes int[],
  created_by uuid references app_users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. DSA / 学校规划
create table if not exists school_options (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  school_id uuid references schools(id) on delete set null,
  school_name text not null,
  school_type text,
  education_level text,
  pathway text,
  priority int,
  status text not null default '观察',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists dsa_plans (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  target_year text,
  target_level text,
  talent_area text,
  target_school_id uuid references schools(id) on delete set null,
  target_school_name text,
  status text not null default '规划中',
  target_result text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists dsa_activities (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  dsa_plan_id uuid references dsa_plans(id) on delete cascade,
  activity_date date,
  activity_type text not null,
  title text not null,
  institution text,
  result text,
  evidence text,
  next_action text,
  status text not null default '计划中',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5. 提醒 / 通知
create table if not exists reminders (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id) on delete cascade,
  source_type text,
  source_id uuid,
  reminder_type text not null,
  title text not null,
  message text,
  remind_at timestamptz not null,
  status text not null default '待发送' check (status in ('待发送','已发送','已读','已取消')),
  priority text not null default '一般',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  user_id uuid references app_users(id) on delete cascade,
  student_id uuid references students(id) on delete cascade,
  type text not null,
  title text not null,
  message text,
  source_type text,
  source_id uuid,
  status text not null default '未读' check (status in ('未读','已读','已归档')),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

-- 6. 操作审计
create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete set null,
  user_id uuid references app_users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_data jsonb,
  new_data jsonb,
  request_id text,
  created_at timestamptz not null default now()
);

-- 7. 数据附件元数据（实际文件可由对象存储保存）
create table if not exists file_assets (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  student_id uuid references students(id) on delete cascade,
  entity_type text,
  entity_id uuid,
  file_name text not null,
  storage_path text not null,
  mime_type text,
  file_size bigint,
  category text,
  uploaded_by uuid references app_users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- 8. 数据版本 / 同步状态
create table if not exists sync_checkpoints (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  device_key text not null,
  entity_name text not null,
  last_synced_at timestamptz,
  last_local_version bigint default 0,
  last_remote_version bigint default 0,
  status text not null default '正常',
  error_message text,
  updated_at timestamptz not null default now(),
  unique(family_id,device_key,entity_name)
);

-- 9. 统一更新时间触发器
create or replace function education_os_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'families','family_settings','students','academic_years','student_subjects',
    'teachers','courses','packages','lessons','teacher_feedback','drivers','vehicles',
    'transport_tasks','temporary_arrangements','conflicts','tasks','academic_goals',
    'assessments','progress_records','payments','activities','app_users','family_members',
    'academic_terms','school_calendar_events','calendar_events','school_options',
    'dsa_plans','dsa_activities','reminders','notifications','file_assets','sync_checkpoints'
  ] loop
    execute format('drop trigger if exists %I on %I', 'trg_touch_'||t, t);
    execute format('create trigger %I before update on %I for each row execute function education_os_touch_updated_at()', 'trg_touch_'||t, t);
  end loop;
end $$;

-- 10. 完整索引
create index if not exists idx_family_members_family on family_members(family_id);
create index if not exists idx_family_members_user on family_members(user_id);
create index if not exists idx_calendar_family_date on calendar_events(family_id,event_date,start_time);
create index if not exists idx_terms_family_date on academic_terms(family_id,start_date,end_date);
create index if not exists idx_school_calendar_date on school_calendar_events(family_id,event_date);
create index if not exists idx_school_options_family on school_options(family_id,status);
create index if not exists idx_dsa_student on dsa_plans(student_id,status);
create index if not exists idx_dsa_activities_plan on dsa_activities(dsa_plan_id,activity_date);
create index if not exists idx_reminders_due on reminders(family_id,status,remind_at);
create index if not exists idx_notifications_user on notifications(user_id,status,created_at);
create index if not exists idx_audit_family_date on audit_logs(family_id,created_at);
create index if not exists idx_files_entity on file_assets(entity_type,entity_id);
create index if not exists idx_sync_family on sync_checkpoints(family_id,entity_name);

-- 11. 第一版核心报表视图
create or replace view v_student_timeline as
select family_id,student_id,lesson_date as event_date,start_time as event_time,
       '课程'::text as event_type,coalesce(note,'课程安排') as title,
       id as source_id,'lessons'::text as source_table
from lessons
union all
select family_id,student_id,task_date,pickup_time,
       '接送',coalesce(direction,'接送任务'),id,'transport_tasks'
from transport_tasks
union all
select family_id,student_id,feedback_date,null,
       '教师反馈',left(content,160),id,'teacher_feedback'
from teacher_feedback
union all
select family_id,student_id,assessment_date,null,
       '成绩',coalesce(assessment_name,assessment_type,'成绩记录'),id,'assessments'
from assessments
union all
select family_id,student_id,record_date,null,
       '学习记录',left(note,160),id,'progress_records'
from progress_records
union all
select family_id,student_id,due_date,null,
       '家庭任务',name,id,'tasks'
from tasks
where due_date is not null
union all
select family_id,student_id,event_date,start_time,
       event_type,title,id,'calendar_events'
from calendar_events;

create or replace view v_package_balance as
select p.*,
       greatest(coalesce(p.total_hours,0)-coalesce(p.used_hours,0),0) as remaining_hours,
       case
         when greatest(coalesce(p.total_hours,0)-coalesce(p.used_hours,0),0)=0 then '已用完'
         when greatest(coalesce(p.total_hours,0)-coalesce(p.used_hours,0),0)<=4 then '预警'
         else '正常'
       end as balance_status
from packages p;

create or replace view v_family_monthly_finance as
select family_id,
       date_trunc('month',payment_date)::date as month,
       count(*) as payment_count,
       coalesce(sum(case when status <> '已取消' then amount else 0 end),0) as total_amount,
       coalesce(sum(case when status = '已支付' then amount else 0 end),0) as paid_amount,
       coalesce(sum(case when status = '待支付' then amount else 0 end),0) as unpaid_amount
from payments
group by family_id,date_trunc('month',payment_date);

create or replace view v_family_dashboard as
select f.id as family_id,
       f.name as family_name,
       (select count(*) from students s where s.family_id=f.id and s.status='active') as student_count,
       (select count(*) from courses c where c.family_id=f.id and c.status <> '已结束') as active_course_count,
       (select count(*) from lessons l where l.family_id=f.id and l.lesson_date=current_date and l.status <> '已取消') as today_lesson_count,
       (select count(*) from transport_tasks t where t.family_id=f.id and t.task_date=current_date and t.status <> '已取消') as today_transport_count,
       (select count(*) from tasks t where t.family_id=f.id and t.status <> '已完成') as pending_task_count,
       (select count(*) from conflicts c where c.family_id=f.id and c.status <> '已处理') as pending_conflict_count,
       (select count(*) from teacher_feedback tf where tf.family_id=f.id and tf.status not in ('已同步','已处理')) as pending_feedback_count,
       (select coalesce(sum(p.amount),0) from payments p where p.family_id=f.id and p.status <> '已取消' and date_trunc('month',p.payment_date)=date_trunc('month',current_date)) as current_month_spend
from families f;

-- 12. Supabase RLS 基础层
-- 默认关闭，部署到 Supabase 时执行本段即可启用。
-- family_members 作为家庭隔离入口。
alter table families enable row level security;
alter table family_settings enable row level security;
alter table students enable row level security;
alter table teachers enable row level security;
alter table courses enable row level security;
alter table packages enable row level security;
alter table lessons enable row level security;
alter table teacher_feedback enable row level security;
alter table drivers enable row level security;
alter table vehicles enable row level security;
alter table transport_tasks enable row level security;
alter table temporary_arrangements enable row level security;
alter table conflicts enable row level security;
alter table tasks enable row level security;
alter table academic_goals enable row level security;
alter table assessments enable row level security;
alter table progress_records enable row level security;
alter table payments enable row level security;
alter table activities enable row level security;
alter table family_members enable row level security;
alter table calendar_events enable row level security;
alter table school_options enable row level security;
alter table dsa_plans enable row level security;
alter table dsa_activities enable row level security;
alter table reminders enable row level security;
alter table notifications enable row level security;
alter table audit_logs enable row level security;
alter table file_assets enable row level security;
alter table sync_checkpoints enable row level security;

create or replace function education_os_has_family_access(target_family uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from family_members fm
    join app_users au on au.id=fm.user_id
    where fm.family_id=target_family
      and fm.status='active'
      and au.auth_user_id=auth.uid()
  );
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'families','family_settings','students','teachers','courses','packages','lessons',
    'teacher_feedback','drivers','vehicles','transport_tasks','temporary_arrangements',
    'conflicts','tasks','academic_goals','assessments','progress_records','payments',
    'activities','family_members','calendar_events','school_options','dsa_plans',
    'dsa_activities','reminders','notifications','audit_logs','file_assets','sync_checkpoints'
  ] loop
    execute format('drop policy if exists %I on %I', 'family_access_'||t, t);
    execute format(
      'create policy %I on %I for all using (education_os_has_family_access(family_id)) with check (education_os_has_family_access(family_id))',
      'family_access_'||t,t
    );
  end loop;
end $$;

-- 13. 说明：student_contacts / academic_years / student_subjects / schools /
-- student_school_history / subject_master 等通过学生或 Master 关系访问。
-- subject_master 为公共 Master，不按家庭隔离。
-- schools 为公共学校 Master，可逐步补充官方学校资料。


-- 14. 渐进式迁移桥接：保留现有 localStorage 数据快照，避免一次性切换造成数据损失
create table if not exists legacy_data_snapshots (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families(id) on delete cascade,
  device_key text not null,
  snapshot_version bigint not null default 1,
  data jsonb not null,
  captured_at timestamptz not null default now(),
  unique(family_id,device_key,snapshot_version)
);

create index if not exists idx_legacy_snapshot_family on legacy_data_snapshots(family_id,captured_at desc);
alter table legacy_data_snapshots enable row level security;
drop policy if exists family_access_legacy_data_snapshots on legacy_data_snapshots;
create policy family_access_legacy_data_snapshots on legacy_data_snapshots
for all using (education_os_has_family_access(family_id))
with check (education_os_has_family_access(family_id));


-- 15. 从属表 RLS：通过学生 / 学年反查家庭，避免绕过家庭隔离
alter table student_contacts enable row level security;
alter table academic_years enable row level security;
alter table student_subjects enable row level security;
alter table student_school_history enable row level security;

drop policy if exists family_access_student_contacts on student_contacts;
create policy family_access_student_contacts on student_contacts
for all using (
  exists(select 1 from students s
         where s.id=student_contacts.student_id
           and education_os_has_family_access(s.family_id))
) with check (
  exists(select 1 from students s
         where s.id=student_contacts.student_id
           and education_os_has_family_access(s.family_id))
);

drop policy if exists family_access_academic_years on academic_years;
create policy family_access_academic_years on academic_years
for all using (
  exists(select 1 from students s
         where s.id=academic_years.student_id
           and education_os_has_family_access(s.family_id))
) with check (
  exists(select 1 from students s
         where s.id=academic_years.student_id
           and education_os_has_family_access(s.family_id))
);

drop policy if exists family_access_student_subjects on student_subjects;
create policy family_access_student_subjects on student_subjects
for all using (
  exists(select 1 from academic_years ay
         join students s on s.id=ay.student_id
         where ay.id=student_subjects.academic_year_id
           and education_os_has_family_access(s.family_id))
) with check (
  exists(select 1 from academic_years ay
         join students s on s.id=ay.student_id
         where ay.id=student_subjects.academic_year_id
           and education_os_has_family_access(s.family_id))
);

drop policy if exists family_access_student_school_history on student_school_history;
create policy family_access_student_school_history on student_school_history
for all using (
  exists(select 1 from academic_years ay
         join students s on s.id=ay.student_id
         where ay.id=student_school_history.academic_year_id
           and education_os_has_family_access(s.family_id))
) with check (
  exists(select 1 from academic_years ay
         join students s on s.id=ay.student_id
         where ay.id=student_school_history.academic_year_id
           and education_os_has_family_access(s.family_id))
);


-- 16. Supabase 安全加固：仅 authenticated，视图跟随 RLS
create or replace function education_os_has_family_access(target_family uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.family_members fm
    join public.app_users au on au.id=fm.user_id
    where fm.family_id=target_family
      and fm.status='active'
      and au.auth_user_id=(select auth.uid())
  );
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'families','family_settings','students','teachers','courses','packages','lessons',
    'teacher_feedback','drivers','vehicles','transport_tasks','temporary_arrangements',
    'conflicts','tasks','academic_goals','assessments','progress_records','payments',
    'activities','family_members','calendar_events','school_options','dsa_plans',
    'dsa_activities','reminders','notifications','audit_logs','file_assets',
    'sync_checkpoints','legacy_data_snapshots'
  ] loop
    execute format('drop policy if exists %I on %I','family_access_'||t,t);
    execute format('drop policy if exists %I on %I','family_select_'||t,t);
    execute format('drop policy if exists %I on %I','family_insert_'||t,t);
    execute format('drop policy if exists %I on %I','family_update_'||t,t);
    execute format('drop policy if exists %I on %I','family_delete_'||t,t);

    execute format(
      'create policy %I on %I for select to authenticated using ((select public.education_os_has_family_access(family_id)))',
      'family_select_'||t,t
    );
    execute format(
      'create policy %I on %I for insert to authenticated with check ((select public.education_os_has_family_access(family_id)))',
      'family_insert_'||t,t
    );
    execute format(
      'create policy %I on %I for update to authenticated using ((select public.education_os_has_family_access(family_id))) with check ((select public.education_os_has_family_access(family_id)))',
      'family_update_'||t,t
    );
    execute format(
      'create policy %I on %I for delete to authenticated using ((select public.education_os_has_family_access(family_id)))',
      'family_delete_'||t,t
    );
  end loop;
end $$;

-- 从属表：通过学生 / 学年验证家庭
drop policy if exists family_access_student_contacts on student_contacts;
drop policy if exists family_select_student_contacts on student_contacts;
drop policy if exists family_insert_student_contacts on student_contacts;
drop policy if exists family_update_student_contacts on student_contacts;
drop policy if exists family_delete_student_contacts on student_contacts;

create policy family_select_student_contacts on student_contacts for select to authenticated using (
  exists(select 1 from public.students s where s.id=student_contacts.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_insert_student_contacts on student_contacts for insert to authenticated with check (
  exists(select 1 from public.students s where s.id=student_contacts.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_update_student_contacts on student_contacts for update to authenticated using (
  exists(select 1 from public.students s where s.id=student_contacts.student_id
    and (select public.education_os_has_family_access(s.family_id)))
) with check (
  exists(select 1 from public.students s where s.id=student_contacts.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_delete_student_contacts on student_contacts for delete to authenticated using (
  exists(select 1 from public.students s where s.id=student_contacts.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);

drop policy if exists family_access_academic_years on academic_years;
drop policy if exists family_select_academic_years on academic_years;
drop policy if exists family_insert_academic_years on academic_years;
drop policy if exists family_update_academic_years on academic_years;
drop policy if exists family_delete_academic_years on academic_years;

create policy family_select_academic_years on academic_years for select to authenticated using (
  exists(select 1 from public.students s where s.id=academic_years.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_insert_academic_years on academic_years for insert to authenticated with check (
  exists(select 1 from public.students s where s.id=academic_years.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_update_academic_years on academic_years for update to authenticated using (
  exists(select 1 from public.students s where s.id=academic_years.student_id
    and (select public.education_os_has_family_access(s.family_id)))
) with check (
  exists(select 1 from public.students s where s.id=academic_years.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_delete_academic_years on academic_years for delete to authenticated using (
  exists(select 1 from public.students s where s.id=academic_years.student_id
    and (select public.education_os_has_family_access(s.family_id)))
);

drop policy if exists family_access_student_subjects on student_subjects;
drop policy if exists family_select_student_subjects on student_subjects;
drop policy if exists family_insert_student_subjects on student_subjects;
drop policy if exists family_update_student_subjects on student_subjects;
drop policy if exists family_delete_student_subjects on student_subjects;

create policy family_select_student_subjects on student_subjects for select to authenticated using (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_subjects.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_insert_student_subjects on student_subjects for insert to authenticated with check (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_subjects.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_update_student_subjects on student_subjects for update to authenticated using (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_subjects.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
) with check (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_subjects.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_delete_student_subjects on student_subjects for delete to authenticated using (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_subjects.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);

drop policy if exists family_access_student_school_history on student_school_history;
drop policy if exists family_select_student_school_history on student_school_history;
drop policy if exists family_insert_student_school_history on student_school_history;
drop policy if exists family_update_student_school_history on student_school_history;
drop policy if exists family_delete_student_school_history on student_school_history;

create policy family_select_student_school_history on student_school_history for select to authenticated using (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_school_history.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_insert_student_school_history on student_school_history for insert to authenticated with check (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_school_history.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_update_student_school_history on student_school_history for update to authenticated using (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_school_history.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
) with check (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_school_history.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);
create policy family_delete_student_school_history on student_school_history for delete to authenticated using (
  exists(select 1 from public.academic_years ay join public.students s on s.id=ay.student_id
    where ay.id=student_school_history.academic_year_id
    and (select public.education_os_has_family_access(s.family_id)))
);

-- Master 表：subject_master / schools / roles / permissions 为公共配置，不放入家庭数据。
-- app_users 只通过 Auth / family_members 间接访问。

create or replace view v_student_timeline
with (security_invoker=true)
as
select family_id,student_id,lesson_date as event_date,start_time as event_time,
       '课程'::text as event_type,coalesce(note,'课程安排') as title,
       id as source_id,'lessons'::text as source_table from public.lessons
union all
select family_id,student_id,task_date,pickup_time,'接送',coalesce(direction,'接送任务'),id,'transport_tasks'
from public.transport_tasks
union all
select family_id,student_id,feedback_date,null,'教师反馈',left(content,160),id,'teacher_feedback'
from public.teacher_feedback
union all
select family_id,student_id,assessment_date,null,'成绩',coalesce(assessment_name,assessment_type,'成绩记录'),id,'assessments'
from public.assessments
union all
select family_id,student_id,record_date,null,'学习记录',left(note,160),id,'progress_records'
from public.progress_records
union all
select family_id,student_id,due_date,null,'家庭任务',name,id,'tasks'
from public.tasks where due_date is not null
union all
select family_id,student_id,event_date,start_time,event_type,title,id,'calendar_events'
from public.calendar_events;

create or replace view v_package_balance
with (security_invoker=true)
as
select p.*,greatest(coalesce(p.total_hours,0)-coalesce(p.used_hours,0),0) as remaining_hours,
case when greatest(coalesce(p.total_hours,0)-coalesce(p.used_hours,0),0)=0 then '已用完'
when greatest(coalesce(p.total_hours,0)-coalesce(p.used_hours,0),0)<=4 then '预警' else '正常' end as balance_status
from public.packages p;

create or replace view v_family_monthly_finance
with (security_invoker=true)
as
select family_id,date_trunc('month',payment_date)::date as month,count(*) as payment_count,
coalesce(sum(case when status <> '已取消' then amount else 0 end),0) as total_amount,
coalesce(sum(case when status='已支付' then amount else 0 end),0) as paid_amount,
coalesce(sum(case when status='待支付' then amount else 0 end),0) as unpaid_amount
from public.payments group by family_id,date_trunc('month',payment_date);

create or replace view v_family_dashboard
with (security_invoker=true)
as
select f.id as family_id,f.name as family_name,
(select count(*) from public.students s where s.family_id=f.id and s.status='active') as student_count,
(select count(*) from public.courses c where c.family_id=f.id and c.status <> '已结束') as active_course_count,
(select count(*) from public.lessons l where l.family_id=f.id and l.lesson_date=current_date and l.status <> '已取消') as today_lesson_count,
(select count(*) from public.transport_tasks t where t.family_id=f.id and t.task_date=current_date and t.status <> '已取消') as today_transport_count,
(select count(*) from public.tasks t where t.family_id=f.id and t.status <> '已完成') as pending_task_count,
(select count(*) from public.conflicts c where c.family_id=f.id and c.status <> '已处理') as pending_conflict_count,
(select count(*) from public.teacher_feedback tf where tf.family_id=f.id and tf.status not in ('已同步','已处理')) as pending_feedback_count,
(select coalesce(sum(p.amount),0) from public.payments p where p.family_id=f.id and p.status <> '已取消'
 and date_trunc('month',p.payment_date)=date_trunc('month',current_date)) as current_month_spend
from public.families f;

-- Data API 最小权限：客户端只使用 authenticated + RLS。
grant usage on schema public to authenticated;
grant select,insert,update,delete on
  public.families,public.family_settings,public.students,public.student_contacts,
  public.academic_years,public.student_subjects,public.teachers,public.courses,
  public.packages,public.lessons,public.teacher_feedback,public.drivers,public.vehicles,
  public.transport_tasks,public.temporary_arrangements,public.conflicts,public.tasks,
  public.academic_goals,public.assessments,public.progress_records,public.payments,
  public.activities,public.family_members,public.calendar_events,public.school_options,
  public.dsa_plans,public.dsa_activities,public.reminders,public.notifications,
  public.audit_logs,public.file_assets,public.sync_checkpoints,public.legacy_data_snapshots
to authenticated;
grant select on public.subject_master,public.schools,public.education_pathways,
  public.grade_master,public.roles,public.permissions,public.role_permissions
to authenticated;
grant select on public.v_student_timeline,public.v_package_balance,
  public.v_family_monthly_finance,public.v_family_dashboard to authenticated;


-- Master seed
-- 教育管家｜第一版 Master Seed
-- 不包含真实家庭、学生或财务数据

insert into subject_master
(education_level,subject_code,subject_name,subject_group,curriculum_pathway,level_code,sort_order)
values
('primary','P-ENG','English','语言','Primary','P1-P6',10),
('primary','P-MT','Mother Tongue','语言','Primary','P1-P6',20),
('primary','P-MATH','Mathematics','数学','Primary','P1-P6',30),
('primary','P-SCI','Science','科学','Primary','P3-P6',40),
('primary','P-ART','Art','艺术','Primary','P1-P6',50),
('primary','P-MUSIC','Music','艺术','Primary','P1-P6',60),
('primary','P-PE','Physical Education','体育','Primary','P1-P6',70),
('primary','P-CCE','Character and Citizenship Education','品格与公民教育','Primary','P1-P6',80),
('secondary','SEC-ENG','English','语言','Secondary','S1-S4',10),
('secondary','SEC-MT','Mother Tongue','语言','Secondary','S1-S4',20),
('secondary','SEC-MATH','Mathematics','数学','Secondary','S1-S4',30),
('secondary','SEC-AMATH','Additional Mathematics','数学','Secondary','S1-S4',35),
('secondary','SEC-SCI','Science','科学','Secondary','S1-S4',40),
('secondary','SEC-HUM','Humanities','人文','Secondary','S1-S4',50),
('secondary','SEC-ART','Art','艺术','Secondary','S1-S4',60),
('secondary','SEC-DNT','Design & Technology','设计与工艺','Secondary','S1-S4',70),
('secondary','SEC-FCE','Food & Consumer Education','食品与消费者教育','Secondary','S1-S4',80),
('secondary','SEC-COMPUTING','Computing','计算机','Secondary','S1-S4',90),
('secondary','SEC-ELECTIVE','Elective / Combined Subject','选修 / 组合科目','Secondary','S3-S4',100),
('jc','JC-GP','General Paper','核心','JC','H1/H2',10),
('jc','JC-PW','Project Work','核心','JC','H1/H2',20),
('jc','JC-MT','Mother Tongue','语言','JC','H1',30),
('jc','JC-CLL','Chinese Language & Literature','语言与文学','JC','H1/H2',40),
('jc','JC-MLL','Malay Language & Literature','语言与文学','JC','H1/H2',50),
('jc','JC-TLL','Tamil Language & Literature','语言与文学','JC','H1/H2',60),
('jc','JC-ELL','English Language & Linguistics','语言','JC','H1/H2',70),
('jc','JC-MATH','Mathematics','数学','JC','H1/H2',80),
('jc','JC-FMATH','Further Mathematics','数学','JC','H2',90),
('jc','JC-BIO','Biology','科学','JC','H1/H2',100),
('jc','JC-CHEM','Chemistry','科学','JC','H1/H2',110),
('jc','JC-PHYS','Physics','科学','JC','H1/H2',120),
('jc','JC-COMP','Computing','计算机','JC','H1/H2',130),
('jc','JC-ECON','Economics','人文商科','JC','H1/H2',140),
('jc','JC-GEO','Geography','人文','JC','H1/H2',150),
('jc','JC-HIST','History','人文','JC','H1/H2',160),
('jc','JC-LIT','Literature in English','文学','JC','H1/H2',170),
('jc','JC-CHINA','China Studies','人文','JC','H1/H2',180),
('jc','JC-ART','Art','艺术','JC','H1/H2',190),
('jc','JC-MUSIC','Music','艺术','JC','H1/H2',200),
('jc','JC-TSD','Theatre Studies & Drama','艺术','JC','H1/H2',210),
('jc','JC-POA','Principles of Accounting','商科','JC','H1/H2',220),
('jc','JC-MOB','Management of Business','商科','JC','H1/H2',230)
on conflict (education_level,subject_code) do update set
subject_name=excluded.subject_name,
subject_group=excluded.subject_group,
curriculum_pathway=excluded.curriculum_pathway,
level_code=excluded.level_code,
sort_order=excluded.sort_order,
is_active=true;


-- ============================================================
-- Education OS 第一版 Master：教育路径 / 年级 / Secondary 分流
-- POLY / MI 不纳入本平台路径
-- ============================================================

insert into education_pathways(education_level,pathway_code,pathway_name,grade_start,grade_end,description,sort_order) values
('primary','PRIMARY','小学','P1','P6','新加坡小学阶段',10),
('secondary','SBB','Secondary Full SBB / G1-G3','S1','S4','按学科能力采用 G1/G2/G3',20),
('secondary','IP','Integrated Programme','S1','S4','Integrated Programme 学校路径',30),
('secondary','PG3','Mainstream PG3','S1','S4','Mainstream Post-Secondary Grade 3',40),
('secondary','PG2','Mainstream PG2','S1','S4','Mainstream Post-Secondary Grade 2',50),
('secondary','PG1','Mainstream PG1','S1','S4','Mainstream Post-Secondary Grade 1',60),
('jc','JC','Junior College','JC1','JC2','初级学院阶段',70)
on conflict(education_level,pathway_code) do update set
pathway_name=excluded.pathway_name,grade_start=excluded.grade_start,grade_end=excluded.grade_end,
description=excluded.description,sort_order=excluded.sort_order,is_active=true;

insert into grade_master(education_level,grade_code,grade_name,pathway_code,sort_order) values
('primary','P1','小学一年级','PRIMARY',10),
('primary','P2','小学二年级','PRIMARY',20),
('primary','P3','小学三年级','PRIMARY',30),
('primary','P4','小学四年级','PRIMARY',40),
('primary','P5','小学五年级','PRIMARY',50),
('primary','P6','小学六年级','PRIMARY',60),

('secondary','S1','中学一年级','SBB',10),
('secondary','S2','中学二年级','SBB',20),
('secondary','S3','中学三年级','SBB',30),
('secondary','S4','中学四年级','SBB',40),
('secondary','S1-IP','中学一年级 IP','IP',50),
('secondary','S2-IP','中学二年级 IP','IP',60),
('secondary','S3-IP','中学三年级 IP','IP',70),
('secondary','S4-IP','中学四年级 IP','IP',80),
('secondary','S1-PG3','中学一年级 PG3','PG3',90),
('secondary','S2-PG3','中学二年级 PG3','PG3',100),
('secondary','S3-PG3','中学三年级 PG3','PG3',110),
('secondary','S4-PG3','中学四年级 PG3','PG3',120),
('secondary','S1-PG2','中学一年级 PG2','PG2',130),
('secondary','S2-PG2','中学二年级 PG2','PG2',140),
('secondary','S3-PG2','中学三年级 PG2','PG2',150),
('secondary','S4-PG2','中学四年级 PG2','PG2',160),
('secondary','S1-PG1','中学一年级 PG1','PG1',170),
('secondary','S2-PG1','中学二年级 PG1','PG1',180),
('secondary','S3-PG1','中学三年级 PG1','PG1',190),
('secondary','S4-PG1','中学四年级 PG1','PG1',200),

('jc','JC1','初级学院一年级','JC',10),
('jc','JC2','初级学院二年级','JC',20)
on conflict(education_level,grade_code,pathway_code) do update set
grade_name=excluded.grade_name,sort_order=excluded.sort_order,is_active=true;

-- Secondary Full SBB / G1-G3 是学科层级能力框架，不另造学生学年。
-- 学生具体科目仍由 student_subjects 绑定 subject_master + level_code。

