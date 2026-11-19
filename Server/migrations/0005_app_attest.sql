-- App Attest: one Secure Enclave key per iOS install, verified by the server.
alter table devices
  add column attest_challenge bytea,
  add column attest_challenge_at timestamptz,
  add column attest_key_id bytea,
  add column attest_pubkey bytea,
  add column attest_counter bigint,
  add column attested_at timestamptz;
