alter table public.business_subscriptions
  add column if not exists provider_purchase_token_hash text;

create unique index if not exists business_subscriptions_purchase_token_hash_key
  on public.business_subscriptions(provider_purchase_token_hash)
  where provider_purchase_token_hash is not null;
