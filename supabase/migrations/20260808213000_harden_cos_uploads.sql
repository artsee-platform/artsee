-- Make upload_files server-authoritative and track COS upload sessions.

ALTER TABLE public.upload_files
  ADD COLUMN IF NOT EXISTS expected_size INT
    CHECK (expected_size IS NULL OR expected_size > 0),
  ADD COLUMN IF NOT EXISTS access_level TEXT NOT NULL DEFAULT 'public'
    CHECK (access_level IN ('public', 'private')),
  ADD COLUMN IF NOT EXISTS upload_status TEXT NOT NULL DEFAULT 'completed'
    CHECK (upload_status IN ('pending', 'completed', 'failed')),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS object_etag TEXT,
  ADD COLUMN IF NOT EXISTS object_crc64 TEXT;

UPDATE public.upload_files
SET
  expected_size = COALESCE(expected_size, NULLIF(size, 0)),
  completed_at = COALESCE(completed_at, created_at)
WHERE upload_status = 'completed';

CREATE INDEX IF NOT EXISTS idx_upload_files_user_status_created
  ON public.upload_files (user_id, upload_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_upload_files_pending_expiry
  ON public.upload_files (expires_at)
  WHERE upload_status = 'pending';

DROP POLICY IF EXISTS "upload_files_insert_own" ON public.upload_files;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.upload_files FROM anon, authenticated;
GRANT SELECT ON TABLE public.upload_files TO authenticated;

NOTIFY pgrst, 'reload schema';

