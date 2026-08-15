-- سوق DZ: RLS hardening (run in Supabase SQL editor)
-- Review against your exact schema before production deployment.

alter table public.profiles enable row level security;
alter table public.orders enable row level security;
alter table public.reviews enable row level security;
alter table public.notifications enable row level security;
alter table public.complaints enable row level security;

-- Profiles: public-safe read, owner update.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- Orders: buyer/provider can read their own orders. Clients create only as themselves.
drop policy if exists orders_select_participant on public.orders;
create policy orders_select_participant on public.orders for select using (auth.uid() = buyer_id or auth.uid() = provider_id);
drop policy if exists orders_insert_buyer on public.orders;
create policy orders_insert_buyer on public.orders for insert with check (auth.uid() = buyer_id);

-- Reviews: only participants can read; reviewer must be buyer/provider. Production should also enforce completed order via trigger/function.
drop policy if exists reviews_select_participant on public.reviews;
create policy reviews_select_participant on public.reviews for select using (auth.uid() = reviewer_id or auth.uid() = reviewee_id);
drop policy if exists reviews_insert_own on public.reviews;
create policy reviews_insert_own on public.reviews for insert with check (auth.uid() = reviewer_id);

-- Notifications: private to recipient.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications for select using (auth.uid() = user_id);
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Complaints: private to the authenticated complainant; admins can be added via a SECURITY DEFINER admin function.
drop policy if exists complaints_select_own on public.complaints;
create policy complaints_select_own on public.complaints for select using (auth.uid() = user_id);
drop policy if exists complaints_insert_own on public.complaints;
create policy complaints_insert_own on public.complaints for insert with check (auth.uid() = user_id);

-- Important: do not expose service_role in the browser. Admin moderation and status transitions
-- should be performed through trusted server code / SECURITY DEFINER functions with explicit checks.
