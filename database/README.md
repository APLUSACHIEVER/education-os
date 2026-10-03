# 教育管家｜数据库第一版完整状态

本目录现在是 **Education OS 第一版完整数据库基线**，目标数据库为 PostgreSQL / Supabase。

## 当前状态

数据库已经覆盖四层：

1. **家庭基础层**
   - families / family_settings
   - app_users / family_members
   - roles / permissions / role_permissions

2. **教育主数据层**
   - education_pathways / grade_master / subject_master
   - schools
   - academic_terms / school_calendar_events

3. **家庭业务层**
   - students / student_contacts
   - academic_years / student_subjects / student_school_history
   - teachers / courses / packages / lessons / teacher_feedback
   - drivers / vehicles / transport_tasks / temporary_arrangements / conflicts
   - tasks / academic_goals / assessments / progress_records
   - payments / activities / calendar_events
   - school_options / dsa_plans / dsa_activities
   - reminders / notifications / file_assets

4. **平台治理与报表层**
   - audit_logs / sync_checkpoints / legacy_data_snapshots
   - v_student_timeline
   - v_package_balance
   - v_family_monthly_finance
   - v_family_dashboard
   - updated_at 自动维护
   - Supabase RLS 家庭隔离

## 新加坡教育路径

- Primary：P1–P6
- Secondary：S1–S4
- Secondary Full SBB：G1 / G2 / G3 作为学科能力层级
- Secondary IP
- Secondary Mainstream PG3 / PG2 / PG1
- JC1–JC2
- **不建立 POLY / MI 模块**

学生实际就读学校记录在 academic year / school history；schools 表作为公共 Master，后续可补官方学校资料。

## 前端迁移策略

当前网页仍以 localStorage 为运行主数据源，避免在没有真实数据库连接时破坏现有功能。

已加入 `database/data-access.js`，提供数据库配置、连接状态、本地数据快照备份、同步入口，以及数据库未配置时的 localStorage 兼容。

迁移顺序：

**localStorage → 本地快照桥接 → 家庭/学生 → 教育管理 → 接送/冲突 → 学业 → 费用 → 日历/DSA → 报表 → 完全数据库化**

## Supabase 部署

执行 `schema.sql`，然后执行 `seed.sql`。

数据库启用后，需要建立 Supabase Auth 用户，并把对应 `auth_user_id` 映射到：

`app_users → family_members → families`

浏览器端只使用 publishable key，不把 secret key / service-role key 放进网页。

RLS 已按家庭隔离设计；上线前还需要在 Supabase Data API 中授予客户端所需的最小权限。

## 第二阶段：真实数据库接入

当前尚未绑定具体 Supabase Project，也尚未建立实际 Auth 登录、localStorage ID → 数据库 UUID 的全量映射，以及所有页面的异步数据库 CRUD。

这些是生产接入工作，不是数据库结构缺失。