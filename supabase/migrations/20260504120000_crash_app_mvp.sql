create extension if not exists "pgcrypto";

create type public.user_role as enum ('owner', 'employee');
create type public.booking_status as enum (
  'draft',
  'pending',
  'awaitingPayment',
  'confirmed',
  'active',
  'completed',
  'cancelled'
);
create type public.payment_status as enum (
  'draft',
  'awaitingPayment',
  'authorized',
  'paid',
  'failed',
  'refunded'
);
create type public.stripe_account_status as enum (
  'not_started',
  'onboarding',
  'enabled',
  'restricted'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  first_name text not null,
  last_name text not null,
  country_of_birth text not null,
  date_of_birth date not null,
  user_type public.user_role not null,
  company text,
  badge_number text,
  avatar_base64 text,
  is_subscribed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text not null,
  location text not null,
  nearest_airport text not null,
  owner_name text not null,
  owner_email text not null,
  image_urls jsonb not null default '[]'::jsonb,
  bed_type text not null,
  price numeric(12,2) not null check (price >= 0),
  click_count integer not null default 0 check (click_count >= 0),
  rooms jsonb not null default '[]'::jsonb,
  amenities jsonb not null default '[]'::jsonb,
  house_rules jsonb not null default '[]'::jsonb,
  services jsonb not null default '[]'::jsonb,
  checkout_charges jsonb not null default '[]'::jsonb,
  minimum_stay_nights integer not null default 1 check (minimum_stay_nights > 0),
  distance_to_airport_miles numeric(8,2),
  latitude numeric(9,6),
  longitude numeric(9,6),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  crashpad_id uuid not null references public.listings(id) on delete restrict,
  crashpad_name text not null,
  owner_email text not null,
  guest_id uuid not null references public.profiles(id) on delete restrict,
  guest_name text not null,
  guest_email text not null,
  check_in_date timestamptz not null,
  check_out_date timestamptz not null,
  guest_count integer not null check (guest_count > 0),
  payment_summary jsonb not null,
  status public.booking_status not null default 'pending',
  checkout_report jsonb,
  owner_checkout_note text,
  checkout_charge_payment_status public.payment_status not null default 'draft',
  assigned_room_id text,
  assigned_room_name text,
  assigned_bed_id text,
  assigned_bed_label text,
  assignment_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_valid_dates check (check_out_date > check_in_date)
);

create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  payer_id uuid not null references public.profiles(id) on delete restrict,
  owner_id uuid not null references public.profiles(id) on delete restrict,
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  amount_cents integer not null check (amount_cents >= 0),
  platform_fee_cents integer not null check (platform_fee_cents >= 0),
  owner_payout_cents integer not null check (owner_payout_cents >= 0),
  status public.payment_status not null default 'awaitingPayment',
  purpose text not null default 'booking',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stripe_accounts (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  stripe_account_id text not null unique,
  status public.stripe_account_status not null default 'onboarding',
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subscription_records (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  stripe_customer_id text not null unique,
  stripe_subscription_id text unique,
  status text not null default 'incomplete',
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  crashpad_id uuid not null references public.listings(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  employee_name text not null,
  comment text not null,
  rating numeric(2,1) not null check (rating >= 1 and rating <= 5),
  created_at timestamptz not null default now()
);

create table public.message_threads (
  id uuid primary key default gen_random_uuid(),
  crashpad_id uuid not null references public.listings(id) on delete cascade,
  crashpad_name text not null,
  guest_id uuid not null references public.profiles(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  last_activity timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (crashpad_id, guest_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index profiles_email_idx on public.profiles (email);
create index listings_owner_id_idx on public.listings (owner_id);
create index listings_airport_idx on public.listings (nearest_airport);
create index bookings_guest_id_idx on public.bookings (guest_id);
create index bookings_crashpad_status_dates_idx
  on public.bookings (crashpad_id, status, check_in_date, check_out_date);
create index bookings_owner_email_status_idx on public.bookings (owner_email, status);
create index payment_records_booking_id_idx on public.payment_records (booking_id);
create index reviews_crashpad_created_idx on public.reviews (crashpad_id, created_at desc);
create index message_threads_guest_owner_idx on public.message_threads (guest_id, owner_id);
create index messages_thread_created_idx on public.messages (thread_id, created_at);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

create trigger listings_touch_updated_at
before update on public.listings
for each row execute function public.touch_updated_at();

create trigger bookings_touch_updated_at
before update on public.bookings
for each row execute function public.touch_updated_at();

create trigger payment_records_touch_updated_at
before update on public.payment_records
for each row execute function public.touch_updated_at();

create trigger stripe_accounts_touch_updated_at
before update on public.stripe_accounts
for each row execute function public.touch_updated_at();

create trigger subscription_records_touch_updated_at
before update on public.subscription_records
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    first_name,
    last_name,
    country_of_birth,
    date_of_birth,
    user_type,
    company,
    badge_number
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'country_of_birth', ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date, date '1990-01-01'),
    coalesce(new.raw_user_meta_data ->> 'user_type', 'employee')::public.user_role,
    new.raw_user_meta_data ->> 'company',
    new.raw_user_meta_data ->> 'badge_number'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.bookings enable row level security;
alter table public.payment_records enable row level security;
alter table public.stripe_accounts enable row level security;
alter table public.subscription_records enable row level security;
alter table public.reviews enable row level security;
alter table public.message_threads enable row level security;
alter table public.messages enable row level security;

create policy "profiles_select_own_or_listing_counterparty"
on public.profiles for select
using (
  id = auth.uid()
  or exists (
    select 1 from public.listings l
    where l.owner_id = profiles.id
  )
);

create policy "profiles_insert_own"
on public.profiles for insert
with check (id = auth.uid());

create policy "profiles_update_own"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid());

create policy "listings_public_read"
on public.listings for select
using (true);

create policy "listings_owner_insert"
on public.listings for insert
with check (owner_id = auth.uid());

create policy "listings_owner_update"
on public.listings for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "listings_owner_delete"
on public.listings for delete
using (owner_id = auth.uid());

create policy "bookings_read_guest_or_owner"
on public.bookings for select
using (
  guest_id = auth.uid()
  or exists (
    select 1 from public.listings l
    where l.id = bookings.crashpad_id
    and l.owner_id = auth.uid()
  )
);

create policy "bookings_guest_insert"
on public.bookings for insert
with check (guest_id = auth.uid());

create policy "bookings_guest_or_owner_update"
on public.bookings for update
using (
  guest_id = auth.uid()
  or exists (
    select 1 from public.listings l
    where l.id = bookings.crashpad_id
    and l.owner_id = auth.uid()
  )
)
with check (
  guest_id = auth.uid()
  or exists (
    select 1 from public.listings l
    where l.id = bookings.crashpad_id
    and l.owner_id = auth.uid()
  )
);

create policy "payments_read_counterparties"
on public.payment_records for select
using (payer_id = auth.uid() or owner_id = auth.uid());

create policy "stripe_accounts_owner_read"
on public.stripe_accounts for select
using (owner_id = auth.uid());

create policy "subscription_records_owner_read"
on public.subscription_records for select
using (user_id = auth.uid());

create policy "reviews_public_read"
on public.reviews for select
using (true);

create policy "reviews_employee_insert"
on public.reviews for insert
with check (employee_id = auth.uid());

create policy "threads_read_counterparties"
on public.message_threads for select
using (guest_id = auth.uid() or owner_id = auth.uid());

create policy "threads_guest_insert"
on public.message_threads for insert
with check (guest_id = auth.uid());

create policy "messages_read_thread_counterparties"
on public.messages for select
using (
  exists (
    select 1 from public.message_threads t
    where t.id = messages.thread_id
    and (t.guest_id = auth.uid() or t.owner_id = auth.uid())
  )
);

create policy "messages_insert_thread_counterparties"
on public.messages for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.message_threads t
    where t.id = messages.thread_id
    and (t.guest_id = auth.uid() or t.owner_id = auth.uid())
  )
);

insert into storage.buckets (id, name, public)
values
  ('listing-images', 'listing-images', true),
  ('avatars', 'avatars', true),
  ('checkout-photos', 'checkout-photos', false)
on conflict (id) do nothing;

create policy "public_listing_images_read"
on storage.objects for select
using (bucket_id = 'listing-images');

create policy "owners_write_listing_images"
on storage.objects for insert
with check (
  bucket_id = 'listing-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "owners_update_listing_images"
on storage.objects for update
using (
  bucket_id = 'listing-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "public_avatars_read"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "users_write_own_avatar"
on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "checkout_photos_counterparty_read"
on storage.objects for select
using (
  bucket_id = 'checkout-photos'
  and exists (
    select 1
    from public.bookings b
    where b.id::text = (storage.foldername(name))[1]
    and (
      b.guest_id = auth.uid()
      or exists (
        select 1 from public.listings l
        where l.id = b.crashpad_id
        and l.owner_id = auth.uid()
      )
    )
  )
);

create policy "guests_write_checkout_photos"
on storage.objects for insert
with check (
  bucket_id = 'checkout-photos'
  and exists (
    select 1
    from public.bookings b
    where b.id::text = (storage.foldername(name))[1]
    and b.guest_id = auth.uid()
  )
);
