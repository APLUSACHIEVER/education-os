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
