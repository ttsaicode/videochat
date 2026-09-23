-- ============================================================
-- LELA WebRTC Video Chat - Database Schema (Migration-Safe)
-- Run this in Supabase SQL Editor - works on fresh or existing DB
-- ============================================================

-- ============================================================
-- 1. ADMINS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT,
    email TEXT,
    password_hash TEXT,
    role TEXT DEFAULT 'admin',
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns safely
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'admin';
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.admins ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Migrate username: generate unique values for NULL rows, then add constraints
UPDATE public.admins 
SET username = 'admin_' || substr(id::text, 1, 8)
WHERE username IS NULL;

-- Now add NOT NULL and UNIQUE constraints
ALTER TABLE public.admins ALTER COLUMN username SET NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'admins_username_key' AND conrelid = 'public.admins'::regclass
    ) THEN
        ALTER TABLE public.admins ADD CONSTRAINT admins_username_key UNIQUE (username);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_admins_username ON public.admins(username);
CREATE INDEX IF NOT EXISTS idx_admins_role ON public.admins(role);
CREATE INDEX IF NOT EXISTS idx_admins_is_active ON public.admins(is_active);

-- ============================================================
-- 2. ADS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT DEFAULT '',
    cta_text TEXT DEFAULT 'Learn more ↗',
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL DEFAULT 'image',
    link_url TEXT,
    placement TEXT NOT NULL DEFAULT 'stranger-overlay',
    device_target TEXT NOT NULL DEFAULT 'all',
    rotation_seconds INT NOT NULL DEFAULT 12,
    priority INT NOT NULL DEFAULT 1,
    active BOOLEAN NOT NULL DEFAULT true,
    impressions BIGINT NOT NULL DEFAULT 0,
    clicks BIGINT NOT NULL DEFAULT 0,
    created_by TEXT DEFAULT 'admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add missing columns for existing tables
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS body TEXT DEFAULT '';
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS cta_text TEXT DEFAULT 'Learn more ↗';
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS device_target TEXT DEFAULT 'all';
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS placement TEXT DEFAULT 'stranger-overlay';
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS media_type TEXT DEFAULT 'image';
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS priority INT DEFAULT 1;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS rotation_seconds INT DEFAULT 12;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS impressions BIGINT DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS clicks BIGINT DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS created_by TEXT DEFAULT 'admin';
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Fix old placement values
UPDATE public.ads SET placement = 'stranger-overlay' WHERE placement = 'below-video';

CREATE INDEX IF NOT EXISTS idx_ads_active_priority ON public.ads(active, priority DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ads_placement ON public.ads(placement) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_ads_created_at ON public.ads(created_at DESC);

-- ============================================================
-- 3. AD EVENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ad_events (
    id BIGSERIAL PRIMARY KEY,
    ad_id UUID REFERENCES public.ads(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    client_ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ad_events_composite ON public.ad_events(ad_id, event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ad_events_created_at ON public.ad_events(created_at DESC);

-- ============================================================
-- 4. REPORTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id INT,
    reported_id INT,
    reporter_ip TEXT,
    reported_ip TEXT,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    action_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_reports_status_created ON public.reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported_ip ON public.reports(reported_ip);

-- ============================================================
-- 5. BANS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ip TEXT UNIQUE NOT NULL,
    reason TEXT NOT NULL,
    banned_by TEXT DEFAULT 'admin',
    banned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bans_ip ON public.bans(ip);
CREATE INDEX IF NOT EXISTS idx_bans_expires ON public.bans(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================================
-- 6. SYSTEM LOGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.system_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id TEXT,
    action TEXT NOT NULL,
    details JSONB,
    ip TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON public.system_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_action ON public.system_logs(action);

-- ============================================================
-- 7. SYSTEM SETTINGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default ad settings if not exists
INSERT INTO public.system_settings (key, value) 
VALUES ('ad_settings', '{"enabled": true, "defaultPlacement": "stranger-overlay", "mobileDockStranger": true, "rotationSeconds": 12, "allowDismiss": true, "redisplayOnRotate": true}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLICIES (Safe creation with existence checks)
-- ============================================================
DO $$
BEGIN
    -- Admins
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access Admins' AND tablename = 'admins') THEN
        CREATE POLICY "Service Role Full Access Admins" ON public.admins FOR ALL USING (true);
    END IF;
    
    -- Ads
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access Ads' AND tablename = 'ads') THEN
        CREATE POLICY "Service Role Full Access Ads" ON public.ads FOR ALL USING (true);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Read Active Ads' AND tablename = 'ads') THEN
        CREATE POLICY "Public Read Active Ads" ON public.ads FOR SELECT USING (active = true);
    END IF;
    
    -- Ad Events
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access AdEvents' AND tablename = 'ad_events') THEN
        CREATE POLICY "Service Role Full Access AdEvents" ON public.ad_events FOR ALL USING (true);
    END IF;
    
    -- Reports
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access Reports' AND tablename = 'reports') THEN
        CREATE POLICY "Service Role Full Access Reports" ON public.reports FOR ALL USING (true);
    END IF;
    
    -- Bans
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access Bans' AND tablename = 'bans') THEN
        CREATE POLICY "Service Role Full Access Bans" ON public.bans FOR ALL USING (true);
    END IF;
    
    -- System Logs
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access Logs' AND tablename = 'system_logs') THEN
        CREATE POLICY "Service Role Full Access Logs" ON public.system_logs FOR ALL USING (true);
    END IF;
    
    -- System Settings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service Role Full Access Settings' AND tablename = 'system_settings') THEN
        CREATE POLICY "Service Role Full Access Settings" ON public.system_settings FOR ALL USING (true);
    END IF;
END $$;