CREATE TABLE IF NOT EXISTS public.qr_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL CHECK (type IN ('user', 'group', 'event')),
  target_id UUID,
  owner_user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'revoked', 'expired')),
  expires_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_codes_active_user_card
  ON public.qr_codes (owner_user_id, target_id)
  WHERE type = 'user' AND status = 'active';

CREATE INDEX IF NOT EXISTS idx_qr_codes_owner_type_status
  ON public.qr_codes (owner_user_id, type, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_qr_codes_target_type
  ON public.qr_codes (target_id, type, status);

ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "qr_codes_select_own" ON public.qr_codes;
CREATE POLICY "qr_codes_select_own"
  ON public.qr_codes FOR SELECT
  TO authenticated
  USING (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "qr_codes_service_all" ON public.qr_codes;
CREATE POLICY "qr_codes_service_all"
  ON public.qr_codes FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
