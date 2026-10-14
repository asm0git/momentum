CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  expires_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS calendar_ics_feeds (
  session_id TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('canvas', 'google', 'outlook')),
  remote_user_id TEXT NOT NULL,
  encrypted_feed_url TEXT NOT NULL,
  last_sync_time TEXT,
  PRIMARY KEY (session_id, provider)
);
