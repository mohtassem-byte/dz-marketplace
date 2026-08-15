create extension if not exists pgcrypto;

create type public.user_role as enum ('client','freelancer','seller','admin');
create type public.project_status as enum ('open','in_progress','completed','cancelled');
create type public.order_status as enum ('pending','in_progress','delivered','completed','cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.user_role not null default 'client',
  bio text,
  wilaya text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  kind text not null default 'service' check (kind in ('service','product','both')),
  created_at timestamptz not null default now()
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  title text not null,
  description text not null,
  price_dzd integer not null check (price_dzd >= 0),
  delivery_days integer not null default 7 check (delivery_days > 0),
  wilaya text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  title text not null,
  description text not null,
  budget_dzd integer check (budget_dzd >= 0),
  deadline_days integer check (deadline_days > 0),
  wilaya text,
  status public.project_status not null default 'open',
  created_at timestamptz not null default now()
);

create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  freelancer_id uuid not null references public.profiles(id) on delete cascade,
  amount_dzd integer not null check (amount_dzd >= 0),
  delivery_days integer not null check (delivery_days > 0),
  message text not null,
  created_at timestamptz not null default now(),
  unique(project_id, freelancer_id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  title text not null,
  description text not null,
  price_dzd integer not null check (price_dzd >= 0),
  stock integer not null default 0 check (stock >= 0),
  wilaya text,
  delivery_available boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  provider_id uuid references public.profiles(id) on delete set null,
  total_dzd integer not null check (total_dzd >= 0),
  platform_fee_dzd integer not null default 0 check (platform_fee_dzd >= 0),
  status public.order_status not null default 'pending',
  created_at timestamptz not null default now(),
  check ((service_id is not null) or (product_id is not null))
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique(order_id, reviewer_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.projects(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid references public.conversations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (conversation_id,user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index services_provider_idx on public.services(provider_id);
create index projects_client_status_idx on public.projects(client_id,status);
create index proposals_project_idx on public.proposals(project_id);
create index products_seller_idx on public.products(seller_id);
create index orders_buyer_idx on public.orders(buyer_id);
create index messages_conversation_idx on public.messages(conversation_id,created_at);

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.services enable row level security;
alter table public.projects enable row level security;
alter table public.proposals enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.reviews enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "profiles readable" on public.profiles for select using (true);
create policy "own profile insert" on public.profiles for insert with check (auth.uid() = id);
create policy "own profile update" on public.profiles for update using (auth.uid() = id);
create policy "categories readable" on public.categories for select using (true);
create policy "active services readable" on public.services for select using (is_active or provider_id = auth.uid());
create policy "providers manage services" on public.services for all using (provider_id = auth.uid()) with check (provider_id = auth.uid());
create policy "open projects readable" on public.projects for select using (status = 'open' or client_id = auth.uid());
create policy "clients create projects" on public.projects for insert with check (client_id = auth.uid());
create policy "clients update projects" on public.projects for update using (client_id = auth.uid());
create policy "freelancers create proposals" on public.proposals for insert with check (freelancer_id = auth.uid());
create policy "proposal participants read" on public.proposals for select using (freelancer_id = auth.uid() or exists (select 1 from public.projects p where p.id = project_id and p.client_id = auth.uid()));
create policy "active products readable" on public.products for select using (is_active or seller_id = auth.uid());
create policy "sellers manage products" on public.products for all using (seller_id = auth.uid()) with check (seller_id = auth.uid());
create policy "order participants read" on public.orders for select using (buyer_id = auth.uid() or provider_id = auth.uid());
create policy "buyers create orders" on public.orders for insert with check (buyer_id = auth.uid());
create policy "order participants update" on public.orders for update using (buyer_id = auth.uid() or provider_id = auth.uid());
create policy "reviews readable" on public.reviews for select using (true);
create policy "reviewer creates review" on public.reviews for insert with check (reviewer_id = auth.uid());
create policy "conversation members read" on public.conversations for select using (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid()));
create policy "members read membership" on public.conversation_members for select using (user_id = auth.uid());
create policy "members read messages" on public.messages for select using (exists (select 1 from public.conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid()));
create policy "members send messages" on public.messages for insert with check (sender_id = auth.uid() and exists (select 1 from public.conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid()));

insert into public.categories(name,slug,kind) values
('برمجة وتطوير','programming','service'),('تصميم وإبداع','design','service'),('تسويق وإعلانات','marketing','service'),('تصوير وفيديو','photo-video','service'),('كتابة وترجمة','writing-translation','service'),('خدمات محلية','local-services','both'),('إلكترونيات','electronics','product'),('منزل ومطبخ','home','product')
on conflict (slug) do nothing;
