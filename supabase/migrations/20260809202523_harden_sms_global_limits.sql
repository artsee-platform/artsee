-- Add an application-wide circuit breaker to the existing phone/IP SMS
-- limits. This stops a distributed attack that rotates both source IPs and
-- destination phone numbers before a paid provider call is made.

CREATE INDEX IF NOT EXISTS sms_verifications_created_idx
  ON public.sms_verifications (created_at DESC);

DROP FUNCTION IF EXISTS public.reserve_sms_verification(
  TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT,
  INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);

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
  p_ip_daily_limit INTEGER DEFAULT 100,
  p_global_hourly_limit INTEGER DEFAULT 100,
  p_global_daily_limit INTEGER DEFAULT 500
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_id BIGINT;
  v_count BIGINT;
BEGIN
  IF p_phone_cooldown_seconds < 1
    OR p_phone_hourly_limit < 1
    OR p_phone_daily_limit < 1
    OR p_ip_hourly_limit < 1
    OR p_ip_daily_limit < 1
    OR p_global_hourly_limit < 1
    OR p_global_daily_limit < 1
  THEN
    RAISE EXCEPTION 'SMS_RATE_CONFIG_INVALID' USING ERRCODE = '22023';
  END IF;

  -- Every caller takes locks in this order to avoid deadlocks. The global
  -- lock makes the application-wide count and insert one atomic decision.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sms-global', 0)
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sms-phone:' || p_phone, 0)
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sms-ip:' || p_ip_hash, 0)
  );

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE created_at >= pg_catalog.NOW() - INTERVAL '1 hour';
  IF v_count >= p_global_hourly_limit THEN
    RAISE EXCEPTION 'SMS_RATE_GLOBAL_HOURLY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE created_at >= pg_catalog.NOW() - INTERVAL '1 day';
  IF v_count >= p_global_daily_limit THEN
    RAISE EXCEPTION 'SMS_RATE_GLOBAL_DAILY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND created_at >= pg_catalog.NOW()
      - pg_catalog.make_interval(secs => p_phone_cooldown_seconds);
  IF v_count > 0 THEN
    RAISE EXCEPTION 'SMS_RATE_PHONE_COOLDOWN';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND created_at >= pg_catalog.NOW() - INTERVAL '1 hour';
  IF v_count >= p_phone_hourly_limit THEN
    RAISE EXCEPTION 'SMS_RATE_PHONE_HOURLY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE phone = p_phone
    AND created_at >= pg_catalog.NOW() - INTERVAL '1 day';
  IF v_count >= p_phone_daily_limit THEN
    RAISE EXCEPTION 'SMS_RATE_PHONE_DAILY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE request_ip_hash = p_ip_hash
    AND created_at >= pg_catalog.NOW() - INTERVAL '1 hour';
  IF v_count >= p_ip_hourly_limit THEN
    RAISE EXCEPTION 'SMS_RATE_IP_HOURLY';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.sms_verifications
  WHERE request_ip_hash = p_ip_hash
    AND created_at >= pg_catalog.NOW() - INTERVAL '1 day';
  IF v_count >= p_ip_daily_limit THEN
    RAISE EXCEPTION 'SMS_RATE_IP_DAILY';
  END IF;

  UPDATE public.sms_verifications
  SET invalidated_at = pg_catalog.NOW()
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
  INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_sms_verification(
  TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT,
  INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
) TO service_role;

NOTIFY pgrst, 'reload schema';
