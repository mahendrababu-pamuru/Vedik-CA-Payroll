-- Run AFTER schema.sql and AFTER creating the platform-admin user in Supabase Authentication.
create table if not exists tenants(id uuid primary key default gen_random_uuid(),name text not null,owner_email text,status text not null default 'active' check(status in('active','suspended','cancelled')),created_at timestamptz default now());
create table if not exists user_profiles(user_id uuid primary key references auth.users(id) on delete cascade,full_name text,email text,created_at timestamptz default now());
create table if not exists platform_admins(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz default now());
create table if not exists tenant_members(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references tenants(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,role text not null default 'employee',status text not null default 'active' check(status in('active','inactive')),created_at timestamptz default now(),unique(tenant_id,user_id));
create table if not exists roles(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references tenants(id) on delete cascade,role_name text not null,full_access boolean default false,permissions jsonb not null default '[]',created_at timestamptz default now(),unique(tenant_id,role_name));
create table if not exists subscriptions(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references tenants(id) on delete cascade,plan text not null default 'trial' check(plan in('trial','starter','professional','enterprise')),valid_from date not null default current_date,valid_to date,status text not null default 'active' check(status in('active','expired','cancelled')),max_users int not null default 5,created_at timestamptz default now());

alter table employees add column if not exists tenant_id uuid references tenants(id) on delete cascade;
alter table payroll_runs add column if not exists tenant_id uuid references tenants(id) on delete cascade;
alter table audit_log add column if not exists tenant_id uuid references tenants(id) on delete cascade;
create index if not exists tenant_members_user_idx on tenant_members(user_id);
create index if not exists employees_tenant_idx on employees(tenant_id);
create index if not exists payroll_runs_tenant_idx on payroll_runs(tenant_id);

create or replace function is_platform_admin() returns boolean language sql security definer set search_path=public stable as $$select exists(select 1 from platform_admins where user_id=auth.uid())$$;
create or replace function is_tenant_member(p_tenant uuid) returns boolean language sql security definer set search_path=public stable as $$select exists(select 1 from tenant_members where tenant_id=p_tenant and user_id=auth.uid() and status='active')$$;
create or replace function tenant_role(p_tenant uuid) returns text language sql security definer set search_path=public stable as $$select role from tenant_members where tenant_id=p_tenant and user_id=auth.uid() and status='active' limit 1$$;

alter table tenants enable row level security;alter table user_profiles enable row level security;alter table platform_admins enable row level security;alter table tenant_members enable row level security;alter table roles enable row level security;alter table subscriptions enable row level security;
drop policy if exists tenants_read on tenants;create policy tenants_read on tenants for select to authenticated using(is_platform_admin() or is_tenant_member(id));
drop policy if exists tenants_admin on tenants;create policy tenants_admin on tenants for all to authenticated using(is_platform_admin()) with check(is_platform_admin());
drop policy if exists members_read on tenant_members;create policy members_read on tenant_members for select to authenticated using(is_platform_admin() or is_tenant_member(tenant_id));
drop policy if exists members_manage on tenant_members;create policy members_manage on tenant_members for all to authenticated using(is_platform_admin() or tenant_role(tenant_id)='vendor_admin') with check(is_platform_admin() or tenant_role(tenant_id)='vendor_admin');
drop policy if exists roles_read on roles;create policy roles_read on roles for select to authenticated using(is_platform_admin() or is_tenant_member(tenant_id));
drop policy if exists roles_manage on roles;create policy roles_manage on roles for all to authenticated using(is_platform_admin() or tenant_role(tenant_id)='vendor_admin') with check(is_platform_admin() or tenant_role(tenant_id)='vendor_admin');
drop policy if exists subscriptions_read on subscriptions;create policy subscriptions_read on subscriptions for select to authenticated using(is_platform_admin() or is_tenant_member(tenant_id));
drop policy if exists subscriptions_admin on subscriptions;create policy subscriptions_admin on subscriptions for all to authenticated using(is_platform_admin()) with check(is_platform_admin());
drop policy if exists profiles_read on user_profiles;create policy profiles_read on user_profiles for select to authenticated using(user_id=auth.uid() or is_platform_admin() or exists(select 1 from tenant_members mine join tenant_members theirs on mine.tenant_id=theirs.tenant_id where mine.user_id=auth.uid() and theirs.user_id=user_profiles.user_id));
drop policy if exists profiles_self on user_profiles;create policy profiles_self on user_profiles for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

-- Bootstrap the platform administrator. The Auth user must already exist.
insert into platform_admins(user_id) select id from auth.users where lower(email)=lower('suni.tpt@gmail.com') on conflict do nothing;

-- Apply tenant isolation to payroll domain tables.
drop policy if exists employees_tenant_access on employees;create policy employees_tenant_access on employees for all to authenticated using(is_platform_admin() or is_tenant_member(tenant_id)) with check(is_platform_admin() or is_tenant_member(tenant_id));
drop policy if exists payroll_runs_tenant_access on payroll_runs;create policy payroll_runs_tenant_access on payroll_runs for all to authenticated using(is_platform_admin() or is_tenant_member(tenant_id)) with check(is_platform_admin() or is_tenant_member(tenant_id));
