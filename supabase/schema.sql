-- LIFORA payment portal schema (Supabase / PostgreSQL)
-- Run this in Supabase SQL Editor. Then add your Auth user UUID to public.payment_admins.
create extension if not exists pgcrypto;

create table if not exists public.payment_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null check (char_length(customer_name) between 1 and 100),
  customer_phone text,
  purpose text not null check (char_length(purpose) between 1 and 140),
  amount numeric(12,2) not null check (amount >= 0.01 and amount <= 10000000),
  status text not null default 'pending' check (status in ('pending','paid')),
  transaction_ref text,
  paid_at timestamptz,
  expires_at timestamptz not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create or replace function public.is_payment_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.payment_admins where user_id = auth.uid()) $$;

alter table public.payment_admins enable row level security;
alter table public.payment_requests enable row level security;

drop policy if exists "admins read own admin record" on public.payment_admins;
create policy "admins read own admin record" on public.payment_admins
for select to authenticated using (user_id = auth.uid());

drop policy if exists "admins read payment requests" on public.payment_requests;
create policy "admins read payment requests" on public.payment_requests
for select to authenticated using (public.is_payment_admin());

-- No direct browser inserts or updates. All mutations pass through checked RPCs.
revoke all on public.payment_requests from anon, authenticated;
grant select on public.payment_requests to authenticated;

create or replace function public.create_payment_request(
  p_customer_name text, p_customer_phone text, purpose_text text,
  p_amount numeric, p_expires_at timestamptz
) returns uuid language plpgsql security definer set search_path = public
as $$
declare new_id uuid;
begin
  if not public.is_payment_admin() then raise exception 'Not authorised'; end if;
  if length(trim(p_customer_name)) not between 1 and 100 then raise exception 'Invalid customer name'; end if;
  if length(trim(purpose_text)) not between 1 and 140 then raise exception 'Invalid payment purpose'; end if;
  if p_amount < 0.01 or p_amount > 10000000 then raise exception 'Invalid amount'; end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '31 days' then raise exception 'Invalid expiry'; end if;
  insert into public.payment_requests(customer_name,customer_phone,purpose,amount,expires_at,created_by)
  values(trim(p_customer_name),nullif(trim(p_customer_phone),''),trim(purpose_text),p_amount,p_expires_at,auth.uid())
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.get_payment_request(p_payment_id uuid)
returns table(id uuid, customer_name text, purpose text, amount numeric, status text, expires_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select r.id,r.customer_name,r.purpose,r.amount,
    case when r.status='pending' and r.expires_at < now() then 'expired' else r.status end,
    r.expires_at
  from public.payment_requests r
  where r.id=p_payment_id and r.expires_at > now()
  limit 1
$$;

create or replace function public.mark_payment_paid(p_payment_id uuid,p_transaction_ref text)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_payment_admin() then raise exception 'Not authorised'; end if;
  update public.payment_requests
  set status='paid',transaction_ref=nullif(left(trim(coalesce(p_transaction_ref,'')),120),''),paid_at=now()
  where id=p_payment_id and status='pending';
  if not found then raise exception 'Payment request not found or already updated'; end if;
end $$;

revoke all on function public.create_payment_request(text,text,text,numeric,timestamptz) from public;
revoke all on function public.get_payment_request(uuid) from public;
revoke all on function public.mark_payment_paid(uuid,text) from public;
grant execute on function public.create_payment_request(text,text,text,numeric,timestamptz) to authenticated;
grant execute on function public.get_payment_request(uuid) to anon, authenticated;
grant execute on function public.mark_payment_paid(uuid,text) to authenticated;

-- After creating your first Supabase Auth user, run:
-- insert into public.payment_admins(user_id) values ('YOUR-AUTH-USER-UUID');
