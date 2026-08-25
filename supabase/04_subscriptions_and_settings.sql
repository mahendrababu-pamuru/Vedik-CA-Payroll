-- Subscription cycles, self-service trial registration and organisation settings.
-- Run after supabase/02_auth_tenancy.sql.
alter table subscriptions drop constraint if exists subscriptions_plan_check;
update subscriptions set plan=case plan when 'starter' then 'monthly' when 'professional' then 'quarterly' when 'enterprise' then 'annual' else plan end;
alter table subscriptions add constraint subscriptions_plan_check check(plan in('trial','monthly','quarterly','annual'));
alter table subscriptions add column if not exists amount numeric(12,2) not null default 0;
alter table subscriptions add column if not exists activated_at timestamptz;

create table if not exists subscription_prices(
  billing_cycle text primary key check(billing_cycle in('monthly','quarterly','annual')),
  amount numeric(12,2) not null check(amount>=0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
insert into subscription_prices(billing_cycle,amount) values('monthly',0),('quarterly',0),('annual',0) on conflict do nothing;

create table if not exists organisation_settings(
  tenant_id uuid primary key references tenants(id) on delete cascade,
  legal_name text,
  trade_name text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  pincode text,
  phone text,
  email text,
  website text,
  pan text,
  gstin text,
  pf_code text,
  esi_code text,
  bank_name text,
  bank_account text,
  ifsc text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table subscription_prices enable row level security;
alter table organisation_settings enable row level security;
drop policy if exists prices_read on subscription_prices;
create policy prices_read on subscription_prices for select to authenticated using(true);
drop policy if exists prices_admin on subscription_prices;
create policy prices_admin on subscription_prices for all to authenticated using(is_platform_admin()) with check(is_platform_admin());
drop policy if exists organisation_settings_access on organisation_settings;
create policy organisation_settings_access on organisation_settings for all to authenticated
using(is_platform_admin() or tenant_role(tenant_id)='vendor_admin')
with check(is_platform_admin() or tenant_role(tenant_id)='vendor_admin');

create or replace function provision_payroll_trial_user()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_tenant uuid;
  v_firm text;
  v_name text;
begin
  if coalesce((new.raw_user_meta_data->>'self_registered')::boolean,false) is not true then
    return new;
  end if;
  v_firm:=trim(coalesce(new.raw_user_meta_data->>'firm_name',''));
  v_name:=trim(coalesce(new.raw_user_meta_data->>'full_name',''));
  if v_firm='' then raise exception 'Organisation name is required'; end if;
  if exists(select 1 from tenants where lower(owner_email)=lower(new.email)) then
    raise exception 'A payroll organisation already exists for this email';
  end if;
  insert into tenants(name,owner_email,status) values(v_firm,lower(new.email),'active') returning id into v_tenant;
  insert into subscriptions(tenant_id,plan,valid_from,valid_to,status,amount,activated_at)
  values(v_tenant,'trial',current_date,(current_date+interval '1 month')::date,'active',0,now());
  insert into user_profiles(user_id,full_name,email) values(new.id,v_name,lower(new.email))
  on conflict(user_id) do update set full_name=excluded.full_name,email=excluded.email;
  insert into tenant_members(tenant_id,user_id,role,status) values(v_tenant,new.id,'vendor_admin','active');
  insert into roles(tenant_id,role_name,full_access,permissions) values
    (v_tenant,'vendor_admin',true,'[]'::jsonb),
    (v_tenant,'payroll_manager',false,'["staff","attendance","loans","payroll","reports","settings"]'::jsonb),
    (v_tenant,'payroll_user',false,'["staff","attendance","payroll"]'::jsonb),
    (v_tenant,'viewer',false,'["reports"]'::jsonb);
  insert into organisation_settings(tenant_id,legal_name,trade_name,email,updated_by)
  values(v_tenant,v_firm,v_firm,lower(new.email),new.id);
  return new;
end;
$$;
drop trigger if exists payroll_trial_after_signup on auth.users;
create trigger payroll_trial_after_signup after insert on auth.users
for each row execute function provision_payroll_trial_user();
