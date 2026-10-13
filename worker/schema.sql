CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS oauth_states (
  state TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  canvas_url TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS canvas_connections (
  session_id TEXT PRIMARY KEY,
  canvas_url TEXT NOT NULL,
  remote_user_id TEXT NOT NULL,
  account_name TEXT NOT NULL,
  account_email TEXT,
  encrypted_access_token TEXT NOT NULL,
  encrypted_refresh_token TEXT,
  access_expires_at INTEGER,
  last_sync_time TEXT
);

CREATE INDEX IF NOT EXISTS idx_oauth_states_expiry ON oauth_states(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS calendar_ics_feeds (
  session_id TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('canvas', 'google', 'outlook')),
  remote_user_id TEXT NOT NULL,
  encrypted_feed_url TEXT NOT NULL,
  last_sync_time TEXT,
  PRIMARY KEY (session_id, provider)
);
