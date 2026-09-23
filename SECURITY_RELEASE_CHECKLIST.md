# LELA Security Release Checklist

## Required Railway variables
- `ADMIN_PATH`: 24-128 random URL-safe characters.
- `ADMIN_USERNAME`: admin username.
- `ADMIN_PASSWORD`: 12+ characters with uppercase, lowercase, number, and symbol.
- `JWT_SECRET`: 32+ random characters; never commit this value.
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (server-only; never expose to the browser)
- `REDIS_URL` (strongly recommended for shared rate limits/session revocation)
- `ALLOWED_ORIGINS`: comma-separated browser origins allowed to open the WebSocket.

## Behavior
- `/admin`, `/admin/`, and `/admin/index.html` return 404.
- The private admin route is controlled only by `ADMIN_PATH`.
- Admin JWTs are short-lived and have revocation + session-version checks.
- Failed admin login attempts are rate-limited, using Redis when available.
- Password/role/reset/delete actions invalidate existing admin sessions.
- Admin pages/API use `Cache-Control: no-store` and hardened security headers.
- Production refuses to start if critical secrets or the Supabase server key are missing.
- WebSocket connections reject unapproved browser origins in production.
- Ad uploads are capped and limited to approved image/video types.
