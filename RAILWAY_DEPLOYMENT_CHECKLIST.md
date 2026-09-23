# Railway Deployment Checklist

## ✅ Pre-Deployment (One-time Setup)

### 1. Generate Secure Secrets
Run locally to generate values for Railway Variables:
```bash
# JWT Secret (32+ chars)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Admin Password (12+ chars, complex)
node -e "console.log(require('crypto').randomBytes(18).toString('base64url'))"

# ADMIN_PATH (24-128 chars, alphanumeric + - _)
node -e "console.log(require('crypto').randomBytes(64).toString('base64url').slice(0, 48))"
```

**Your generated values:**
- `ADMIN_PATH`: `hX8GkoUgxz8hv-4OVvvciAK5DgLV9pqBUR_ZHWywkir6u9tL` (48 chars) ✅

### 2. Required Railway Variables
Go to **Railway → Project → Variables** and add ALL of these:

| Variable | Value | Notes |
|----------|-------|-------|
| `JWT_SECRET` | *[generate above]* | 32+ hex chars |
| `ADMIN_USERNAME` | `your_admin` | Your choice |
| `ADMIN_PASSWORD` | *[generate above]* | 12+ chars |
| `ADMIN_PATH` | `hX8GkoUgxz8hv-4OVvvciAK5DgLV9pqBUR_ZHWywkir6u9tL` | **Use this exact value** |
| `JWT_EXPIRY` | `2h` | Must be 2h, 4h, or 8h |
| `SUPABASE_URL` | `https://xxx.supabase.co` | From Supabase dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` | Service role (NOT anon) |
| `SUPABASE_ADS_BUCKET` | `ad-media` | Optional, for ad uploads |
| `REDIS_URL` | `rediss://...` | Optional, from Redis provider |
| `ALLOWED_ORIGINS` | `https://yourdomain.com` | Optional, comma-separated |
| `NODE_ENV` | `production` | Railway sets this auto |

### 3. Supabase Setup (Required)
1. Create Supabase project
2. Run `schema.sql` in Supabase SQL Editor
3. Create Storage bucket named `ad-media` (public)
4. Get Service Role Key from Settings → API

### 4. Redis Setup (Optional but Recommended)
- Use Upstash, Redis Cloud, or Railway Redis
- Add `REDIS_URL` to Railway Variables

---

## 🚀 Deployment Steps

### Option A: GitHub Integration (Recommended)
1. Push this folder to GitHub
2. Railway → New Project → Deploy from GitHub repo
3. Select this repo, Railway auto-detects `railway.json`
4. Add Variables (step 2 above)
5. Deploy!

### Option B: Railway CLI
```bash
npm i -g @railway/cli
railway login
railway init
railway up
# Then add variables in dashboard
```

---

## ✅ Post-Deployment Verification

### 1. Health Check
```bash
curl https://your-app.railway.app/health
# Should return: {"status":"healthy",...}
```

### 2. Admin Dashboard
Visit: `https://your-app.railway.app/hX8GkoUgxz8hv-4OVvvciAK5DgLV9pqBUR_ZHWywkir6u9tL`

### 3. User App
Visit: `https://your-app.railway.app/`

### 4. Check Logs
- Railway → Deployments → View Logs
- Look for: `LELA WebRTC & Admin Control Center Online`

---

## 🔧 Troubleshooting

| Error | Fix |
|-------|-----|
| `process.exit(1)` / "JWT_SECRET must be set" | Add all required variables in Railway |
| "ADMIN_PATH must be 24-128 chars" | Use the generated value above |
| "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required" | Add Supabase credentials |
| Build fails | Check `nixpacks.toml` has correct Node version |
| WebSocket fails | Add `ALLOWED_ORIGINS` with your domain |
| Port error | Server listens on `process.env.PORT` (Railway sets this) |

---

## 📝 Files Modified for Railway

| File | Change |
|------|--------|
| `railway.json` | Fixed JSON parsing (removed BOM/hidden chars) |
| `nixpacks.toml` | Added install/build/start phases |
| `package.json` | Fixed build script message |
| `server.cjs` | Added `/health` endpoint |
| `.env.example` | Created reference for required variables |
| `RAILWAY_DEPLOYMENT_CHECKLIST.md` | This file |

---

## 🔐 Security Notes

- **Never commit** `.env` or real secrets to GitHub
- Use Railway Variables dashboard for all secrets
- `ADMIN_PATH` acts as a secret URL - keep it private
- Rotate `JWT_SECRET` periodically
- Use strong `ADMIN_PASSWORD` (12+ chars, mixed case, numbers, symbols)