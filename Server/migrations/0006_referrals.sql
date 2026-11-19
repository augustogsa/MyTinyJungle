-- Referral links: mytinyjungle.com/r/<code>. A new account (≤7 days old) redeems a friend's code once;
-- both get 30 days of Plus, granted as a server entitlement. A referrer earns at most 12 rewards a year.
alter table users
  add column referral_code text unique,
  add column referred_by uuid references users(id) on delete set null,
  add column referred_at timestamptz;
alter table entitlements drop constraint entitlements_store_check;
alter table entitlements add constraint entitlements_store_check check (store in ('app_store', 'play', 'referral'));
