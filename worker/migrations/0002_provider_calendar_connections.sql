CREATE TABLE IF NOT EXISTS provider_oauth_states (
  state TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('google', 'outlook')),
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS provider_connections (
  session_id TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('google', 'outlook')),
  remote_user_id TEXT NOT NULL,
  account_name TEXT NOT NULL,
  account_email TEXT,
  encrypted_access_token TEXT NOT NULL,
  encrypted_refresh_token TEXT,
  access_expires_at INTEGER,
  last_sync_time TEXT,
  PRIMARY KEY (session_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_provider_oauth_states_expiry
  ON provider_oauth_states(expires_at);
