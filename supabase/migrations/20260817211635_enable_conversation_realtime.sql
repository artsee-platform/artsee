-- Deliver persisted conversations through Supabase Realtime. Message writes
-- remain server-authoritative so the BFF content-safety checks cannot be
-- bypassed from a public client.

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON TABLE
  public.conversations,
  public.conversation_participants,
  public.messages
TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON TABLE
  public.conversations,
  public.conversation_participants,
  public.messages
FROM authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.conversations,
  public.conversation_participants,
  public.messages
TO service_role;

REVOKE ALL ON TABLE
  public.conversations,
  public.conversation_participants,
  public.messages
FROM anon;

-- Keep message reads cheap because Realtime evaluates this policy for every
-- subscriber that may receive a Postgres change.
DROP POLICY IF EXISTS "messages_select_member" ON public.messages;
CREATE POLICY "messages_select_member"
  ON public.messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants AS participant
      WHERE participant.conversation_id = messages.conversation_id
        AND participant.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "conversations_select_member" ON public.conversations;
CREATE POLICY "conversations_select_member"
  ON public.conversations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_participants AS participant
      WHERE participant.conversation_id = conversations.id
        AND participant.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "conversation_participants_select_own"
  ON public.conversation_participants;
CREATE POLICY "conversation_participants_select_own"
  ON public.conversation_participants
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON public.messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversation_participants_user_created
  ON public.conversation_participants (user_id, created_at DESC);

-- Supabase creates this publication for Postgres Changes. Guard every add so
-- the migration is safe for projects where a table is already enabled.
DO $$
DECLARE
  realtime_table TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    RAISE EXCEPTION 'Supabase Realtime publication is missing';
  END IF;

  FOREACH realtime_table IN ARRAY ARRAY[
    'conversations',
    'conversation_participants',
    'messages'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = realtime_table
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        realtime_table
      );
    END IF;
  END LOOP;
END
$$;

NOTIFY pgrst, 'reload schema';
