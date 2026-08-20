-- One-time permits consumed by Tencent IM before-send callbacks. A valid
-- UserSig is not sufficient to mint a permit, so direct SDK sends are denied
-- once the corresponding Tencent callbacks are enabled in fail-closed mode.

CREATE TABLE public.tencent_im_send_permits (
  token_hash TEXT PRIMARY KEY,
  from_identifier TEXT NOT NULL,
  target_kind TEXT NOT NULL,
  target_identifier TEXT NOT NULL,
  msg_body_sha256 TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT tencent_im_send_permits_token_hash_format
    CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT tencent_im_send_permits_target_kind
    CHECK (target_kind IN ('c2c', 'group')),
  CONSTRAINT tencent_im_send_permits_body_hash_format
    CHECK (msg_body_sha256 ~ '^[0-9a-f]{64}$'),
  CONSTRAINT tencent_im_send_permits_expiry
    CHECK (expires_at > created_at)
);

CREATE INDEX tencent_im_send_permits_expiry_idx
  ON public.tencent_im_send_permits (expires_at);

ALTER TABLE public.tencent_im_send_permits ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.tencent_im_send_permits
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.tencent_im_send_permits
  TO service_role;

CREATE OR REPLACE FUNCTION public.consume_tencent_im_send_permit(
  p_token_hash TEXT,
  p_from_identifier TEXT,
  p_target_kind TEXT,
  p_target_identifier TEXT,
  p_msg_body_sha256 TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_consumed_token_hash TEXT;
BEGIN
  DELETE FROM public.tencent_im_send_permits
  WHERE token_hash = p_token_hash
    AND from_identifier = p_from_identifier
    AND target_kind = p_target_kind
    AND target_identifier = p_target_identifier
    AND msg_body_sha256 = p_msg_body_sha256
    AND expires_at >= NOW()
  RETURNING token_hash INTO v_consumed_token_hash;

  RETURN v_consumed_token_hash IS NOT NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_tencent_im_send_permit(
  TEXT, TEXT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_tencent_im_send_permit(
  TEXT, TEXT, TEXT, TEXT, TEXT
) TO service_role;

NOTIFY pgrst, 'reload schema';
