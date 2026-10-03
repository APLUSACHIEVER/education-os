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

create or replace function public.education_os_auth_context()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'app_user_id', au.id,
    'auth_user_id', au.auth_user_id,
    'display_name', au.display_name,
    'email', au.email,
    'families', coalesce((
      select jsonb_agg(jsonb_build_object(
        'family_id',fm.family_id,
        'role_code',fm.role_code,
        'relationship',fm.relationship,
        'is_primary',fm.is_primary
      ) order by fm.is_primary desc, fm.created_at)
      from family_members fm
      where fm.user_id=au.id and fm.status='active'
    ),'[]'::jsonb)
  )
  from app_users au
  where au.auth_user_id=auth.uid() and au.status='active'
  limit 1
$$;

revoke all on function public.education_os_auth_context() from public;
grant execute on function public.education_os_auth_context() to authenticated;


create or replace function public.education_os_create_family(p_family_name text,p_display_name text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_app_user_id uuid; v_family_id uuid;
begin
  if auth.uid() is null then raise exception '必须先登录家庭账号'; end if;
  if nullif(trim(p_family_name),'') is null then raise exception '家庭名称不能为空'; end if;
  insert into public.app_users(auth_user_id,display_name,email)
  values(auth.uid(),nullif(trim(p_display_name),''),(select email from auth.users where id=auth.uid()))
  on conflict(auth_user_id) do update set display_name=coalesce(excluded.display_name,app_users.display_name),email=coalesce(excluded.email,app_users.email),updated_at=now()
  returning id into v_app_user_id;
  if exists(select 1 from public.family_members where user_id=v_app_user_id and status='active') then
    select family_id into v_family_id from public.family_members where user_id=v_app_user_id and status='active' order by is_primary desc,created_at limit 1;
    return v_family_id;
  end if;
  insert into public.families(name,primary_contact_name,primary_contact_email)
  values(trim(p_family_name),nullif(trim(p_display_name),''),(select email from auth.users where id=auth.uid())) returning id into v_family_id;
  insert into public.family_settings(family_id) values(v_family_id);
  insert into public.family_members(family_id,user_id,relationship,role_code,is_primary,status,joined_at)
  values(v_family_id,v_app_user_id,'家长','owner',true,'active',now());
  return v_family_id;
end $$;
revoke all on function public.education_os_create_family(text,text) from public;
grant execute on function public.education_os_create_family(text,text) to authenticated;
