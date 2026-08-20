-- Conversation messages are moderated and delivered by the Next.js BFF.
-- Keep reads compatible with existing clients, but make every write
-- server-authoritative so the content-safety pipeline cannot be bypassed via
-- Supabase's Data API.

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.messages
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.messages
  TO service_role;

-- Remove every policy that can authorize a write, including an unexpected
-- FOR ALL policy that may have been added outside the checked-in migrations.
-- The service role bypasses RLS but still needs the explicit table privileges
-- granted above.
DO $$
DECLARE
  write_policy RECORD;
BEGIN
  FOR write_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND cmd IN ('ALL', 'INSERT', 'UPDATE', 'DELETE')
  LOOP
    EXECUTE FORMAT(
      'DROP POLICY IF EXISTS %I ON public.messages',
      write_policy.policyname
    );
  END LOOP;
END
$$;

NOTIFY pgrst, 'reload schema';
