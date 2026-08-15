-- Run once in Supabase SQL Editor after 02_auth_tenancy.sql.
alter table public.advances add column if not exists payment_mode text;
alter table public.advances add column if not exists payment_reference text;
