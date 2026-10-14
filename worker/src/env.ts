export interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  ALLOWED_CANVAS_HOST: string;
  APP_ORIGIN: string;
  TOKEN_ENCRYPTION_KEY: string;
  API_RATE_LIMITER?: RateLimit;
  OAUTH_RATE_LIMITER?: RateLimit;
  SYNC_RATE_LIMITER?: RateLimit;
}
