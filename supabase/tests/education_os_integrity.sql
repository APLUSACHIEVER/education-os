-- 教育管家｜数据库完整性检查
-- 运行后确认所有业务表存在、RLS 开启、核心视图存在。

select tablename, rowsecurity
from pg_tables
where schemaname='public'
order by tablename;

select tablename, policyname, cmd, roles
from pg_policies
where schemaname='public'
order by tablename, policyname;

select table_name, table_type
from information_schema.tables
where table_schema='public'
  and table_name in (
    'families','family_settings','students','student_contacts','academic_years','subject_master',
    'student_subjects','schools','student_school_history','teachers','courses','packages','lessons',
    'teacher_feedback','drivers','vehicles','transport_tasks','temporary_arrangements','conflicts','tasks',
    'academic_goals','assessments','progress_records','payments','activities','app_users','family_members',
    'roles','permissions','role_permissions','education_pathways','grade_master','academic_terms',
    'school_calendar_events','calendar_events','school_options','dsa_plans','dsa_activities','reminders',
    'notifications','audit_logs','file_assets','sync_checkpoints','legacy_data_snapshots'
  )
order by table_name;

select table_name
from information_schema.views
where table_schema='public'
  and table_name in ('v_student_timeline','v_package_balance','v_family_monthly_finance','v_family_dashboard')
order by table_name;


-- Auth → 家庭绑定函数与执行权限
select routine_name
from information_schema.routines
where routine_schema='public'
  and routine_name in (
    'education_os_current_app_user_id',
    'education_os_current_family_ids',
    'education_os_auth_context',
    'education_os_create_family'
  )
order by routine_name;

select routine_name, grantee, privilege_type
from information_schema.routine_privileges
where specific_schema='public'
  and routine_name in (
    'education_os_current_app_user_id',
    'education_os_current_family_ids',
    'education_os_auth_context',
    'education_os_create_family'
  )
  and grantee='authenticated'
order by routine_name, privilege_type;

-- 家庭账号绑定完整性
select
  (select count(*) from public.app_users where auth_user_id is not null) as bound_app_users,
  (select count(*) from public.family_members where status='active') as active_family_members;
