-- 教育管家｜Supabase Auth → 家庭账号绑定
-- 浏览器只使用 publishable key；Auth JWT 负责 authenticated 身份，RLS 决定 family_id 数据范围。

create unique index if not exists idx_app_users_auth_user
on public.app_users(auth_user_id)
where auth_user_id is not null;

create or replace function public.education_os_current_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.app_users
  where auth_user_id = auth.uid()
    and status = 'active'
  limit 1
$$;

create or replace function public.education_os_current_family_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select fm.family_id
  from public.family_members fm
  join public.app_users au on au.id = fm.user_id
  where au.auth_user_id = auth.uid()
    and au.status = 'active'
    and fm.status = 'active'
$$;

revoke all on function public.education_os_current_app_user_id() from public;
revoke all on function public.education_os_current_family_ids() from public;
grant execute on function public.education_os_current_app_user_id() to authenticated;
grant execute on function public.education_os_current_family_ids() to authenticated;

-- 让前端不再依赖手工填写 family_id：
-- 登录后通过 Auth 用户身份查找 app_users，再得到 family_members.family_id。
-- 新用户的首次建家庭/绑定流程建议由受保护的后端 Edge Function 完成，
-- 不在浏览器放置 secret/service_role key。
