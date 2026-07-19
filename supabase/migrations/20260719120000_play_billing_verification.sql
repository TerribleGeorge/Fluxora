alter table public.business_subscriptions
  add column if not exists provider_product_id text,
  add column if not exists provider_order_id text,
  add column if not exists last_verified_at timestamptz;
