-- Tencent SMS / phone OTP hardening.
-- The application BFF is the only caller; browser/mobile clients must never
-- read verification or identity-link rows directly through PostgREST.

CREATE TABLE IF NOT EXISTS public.sms_verifications (
  id BIGSERIAL PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  verification_code VARCHAR(10),
  expires_at TIMESTAMPTZ NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.auth_provider_links (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  provider_user_id TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.sms_verifications
  ADD COLUMN IF NOT EXISTS country_code VARCHAR(10) DEFAULT '+86',
  ADD COLUMN IF NOT EXISTS purpose VARCHAR(50) DEFAULT 'login',
  ADD COLUMN IF NOT EXISTS verification_code_hash TEXT,
  ADD COLUMN IF NOT EXISTS request_ip_hash TEXT,
  ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS delivery_status TEXT NOT NULL DEFAULT 'legacy',
  ADD COLUMN IF NOT EXISTS provider_request_id TEXT,
  ADD COLUMN IF NOT EXISTS provider_serial_no TEXT;

ALTER TABLE public.sms_verifications
  ALTER COLUMN verification_code DROP NOT NULL,
  ALTER COLUMN purpose SET DEFAULT 'login',
  ALTER COLUMN country_code SET DEFAULT '+86';

UPDATE public.sms_verifications
SET
  verification_code = NULL,
  invalidated_at = COALESCE(invalidated_at, NOW()),
  delivery_status = 'legacy_invalidated'
WHERE delivery_status = 'legacy' OR verification_code IS NOT NULL;

ALTER TABLE public.sms_verifications
  DROP COLUMN IF EXISTS verification_code;

UPDATE public.sms_verifications
SET purpose = 'login'
WHERE purpose IS NULL OR BTRIM(purpose) = '';

UPDATE public.sms_verifications
SET country_code = '+86'
WHERE country_code IS NULL OR BTRIM(country_code) = '';

ALTER TABLE public.sms_verifications
  ALTER COLUMN purpose SET NOT NULL,
  ALTER COLUMN country_code SET NOT NULL;

ALTER TABLE public.sms_verifications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.sms_verifications FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.sms_verifications TO service_role;

DO $$
BEGIN
  IF to_regclass('public.sms_verifications_id_seq') IS NOT NULL THEN
    REVOKE ALL ON SEQUENCE public.sms_verifications_id_seq FROM PUBLIC, anon, authenticated;
    GRANT USAGE, SELECT ON SEQUENCE public.sms_verifications_id_seq TO service_role;
  END IF;
END
$$;

DO $$
DECLARE
  existing_policy RECORD;
BEGIN
  FOR existing_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'sms_verifications'
  LOOP
    EXECUTE FORMAT(
      'DROP POLICY IF EXISTS %I ON public.sms_verifications',
      existing_policy.policyname
    );
  END LOOP;
END
$$;

CREATE POLICY "sms_verifications_service_role_all"
  ON public.sms_verifications
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS sms_verifications_phone_created_idx
  ON public.sms_verifications (phone, created_at DESC);
CREATE INDEX IF NOT EXISTS sms_verifications_ip_created_idx
  ON public.sms_verifications (request_ip_hash, created_at DESC)
  WHERE request_ip_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS sms_verifications_active_idx
  ON public.sms_verifications (phone, purpose, created_at DESC)
  WHERE verified = false AND invalidated_at IS NULL;

ALTER TABLE public.auth_provider_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.auth_provider_links FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.auth_provider_links TO service_role;

DO $$
BEGIN
  IF to_regclass('public.auth_provider_links_id_seq') IS NOT NULL THEN
    REVOKE ALL ON SEQUENCE public.auth_provider_links_id_seq FROM PUBLIC, anon, authenticated;
    GRANT USAGE, SELECT ON SEQUENCE public.auth_provider_links_id_seq TO service_role;
  END IF;
END
$$;

DO $$
DECLARE
  existing_policy RECORD;
BEGIN
  FOR existing_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'auth_provider_links'
  LOOP
    EXECUTE FORMAT(
      'DROP POLICY IF EXISTS %I ON public.auth_provider_links',
      existing_policy.policyname
    );
  END LOOP;
END
$$;

CREATE POLICY "auth_provider_links_service_role_all"
  ON public.auth_provider_links
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE UNIQUE INDEX IF NOT EXISTS auth_provider_links_provider_identity_uidx
  ON public.auth_provider_links (provider, provider_user_id);

-- Keep the provider link and public profile in one database transaction. Auth
-- user creation happens through GoTrue and is compensated by the BFF if this
-- RPC fails.
CREATE OR REPLACE FUNCTION public.link_phone_auth_user(
  p_user_id UUID,
  p_e164 TEXT,
  p_national_number TEXT,
  p_country_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_linked_user UUID;
  v_profile JSONB;
BEGIN
  INSERT INTO public.auth_provider_links (
    user_id,
    provider,
    provider_user_id,
    is_primary
  ) VALUES (
    p_user_id,
    'phone',
    p_e164,
    true
  )
  ON CONFLICT (provider, provider_user_id) DO NOTHING;

  SELECT user_id INTO v_linked_user
  FROM public.auth_provider_links
  WHERE provider = 'phone'
    AND provider_user_id = p_e164;

  IF v_linked_user IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'SMS_PHONE_ALREADY_LINKED';
  END IF;

  INSERT INTO public.user_profiles (
    id,
    phone,
    country_code,
    last_login_at
  ) VALUES (
    p_user_id,
    p_national_number,
    p_country_code,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = EXCLUDED.phone,
    country_code = EXCLUDED.country_code,
    last_login_at = EXCLUDED.last_login_at;

  SELECT TO_JSONB(profile) INTO v_profile
  FROM public.user_profiles AS profile
  WHERE profile.id = p_user_id;

  RETURN v_profile;
END;
$$;

REVOKE ALL ON FUNCTION public.link_phone_auth_user(
  UUID, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.link_phone_auth_user(
  UUID, TEXT, TEXT, TEXT
) TO service_role;

CREATE OR REPLACE FUNCTION public.reserve_sms_verification(
  p_phone TEXT,
  p_country_code TEXT,
  p_purpose TEXT,
  p_code_hash TEXT,
  p_expires_at TIMESTAMPTZ,
  p_ip_hash TEXT,
  p_phone_cooldown_seconds INTEGER DEFAULT 60,
  p_phone_hourly_limit INTEGER DEFAULT 5,
  p_phone_daily_limit INTEGER DEFAULT 10,
  p_ip_hourly_limit INTEGER DEFAULT 20,
  p_ip_daily_limit INTEGER DEFAULT 100
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_id BIGINT;
  v_count BIGINT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('sms-phone:' || p_phone, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('sms-ip:' || p_ip_hash, 0));

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND created_at >= NOW() - make_interval(secs => p_phone_cooldown_seconds);
  IF v_count > 0 THEN
    RAISE EXCEPTION 'SMS_RATE_PHONE_COOLDOWN';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND created_at >= NOW() - INTERVAL '1 hour';
  IF v_count >= p_phone_hourly_limit THEN
    RAISE EXCEPTION 'SMS_RATE_PHONE_HOURLY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND created_at >= NOW() - INTERVAL '1 day';
  IF v_count >= p_phone_daily_limit THEN
    RAISE EXCEPTION 'SMS_RATE_PHONE_DAILY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE request_ip_hash = p_ip_hash
    AND created_at >= NOW() - INTERVAL '1 hour';
  IF v_count >= p_ip_hourly_limit THEN
    RAISE EXCEPTION 'SMS_RATE_IP_HOURLY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE request_ip_hash = p_ip_hash
    AND created_at >= NOW() - INTERVAL '1 day';
  IF v_count >= p_ip_daily_limit THEN
    RAISE EXCEPTION 'SMS_RATE_IP_DAILY';
  END IF;

  UPDATE public.sms_verifications
  SET invalidated_at = NOW()
  WHERE phone = p_phone
    AND purpose = p_purpose
    AND verified = false
    AND invalidated_at IS NULL;

  INSERT INTO public.sms_verifications (
    phone,
    country_code,
    purpose,
    verification_code_hash,
    request_ip_hash,
    expires_at,
    verified,
    attempt_count,
    delivery_status
  ) VALUES (
    p_phone,
    p_country_code,
    p_purpose,
    p_code_hash,
    p_ip_hash,
    p_expires_at,
    false,
    0,
    'pending'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_sms_verification(
  TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT,
  INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_sms_verification(
  TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT,
  INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
) TO service_role;

CREATE OR REPLACE FUNCTION public.consume_sms_verification(
  p_phone TEXT,
  p_purpose TEXT,
  p_code_hash TEXT,
  p_max_attempts INTEGER DEFAULT 5
)
RETURNS TABLE(status TEXT, attempts INTEGER, verification_id BIGINT)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_row public.sms_verifications%ROWTYPE;
  v_attempts INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('sms-phone:' || p_phone, 0));

  SELECT * INTO v_row
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND purpose = p_purpose
    AND verified = false
    AND invalidated_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND OR v_row.delivery_status <> 'sent' THEN
    RETURN QUERY SELECT 'not_found'::TEXT, 0, NULL::BIGINT;
    RETURN;
  END IF;

  IF v_row.expires_at <= NOW() THEN
    UPDATE public.sms_verifications
    SET invalidated_at = NOW()
    WHERE id = v_row.id;
    RETURN QUERY SELECT 'expired'::TEXT, v_row.attempt_count, v_row.id::BIGINT;
    RETURN;
  END IF;

  IF v_row.attempt_count >= p_max_attempts THEN
    UPDATE public.sms_verifications
    SET invalidated_at = COALESCE(invalidated_at, NOW())
    WHERE id = v_row.id;
    RETURN QUERY SELECT 'locked'::TEXT, v_row.attempt_count, v_row.id::BIGINT;
    RETURN;
  END IF;

  IF v_row.verification_code_hash IS DISTINCT FROM p_code_hash THEN
    v_attempts := v_row.attempt_count + 1;
    UPDATE public.sms_verifications
    SET
      attempt_count = v_attempts,
      invalidated_at = CASE
        WHEN v_attempts >= p_max_attempts THEN NOW()
        ELSE invalidated_at
      END
    WHERE id = v_row.id;
    RETURN QUERY SELECT
      CASE WHEN v_attempts >= p_max_attempts THEN 'locked' ELSE 'invalid_code' END,
      v_attempts,
      v_row.id::BIGINT;
    RETURN;
  END IF;

  UPDATE public.sms_verifications
  SET
    verified = true,
    used_at = NOW(),
    attempt_count = attempt_count + 1
  WHERE id = v_row.id;

  RETURN QUERY SELECT 'verified'::TEXT, v_row.attempt_count + 1, v_row.id::BIGINT;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_sms_verification(
  TEXT, TEXT, TEXT, INTEGER
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_sms_verification(
  TEXT, TEXT, TEXT, INTEGER
) TO service_role;
