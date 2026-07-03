-- 社区图文收藏：用户收藏关系与并发安全计数
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS save_count INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS community_post_saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_post_saves_post
  ON community_post_saves (post_id);
CREATE INDEX IF NOT EXISTS idx_community_post_saves_user_created
  ON community_post_saves (user_id, created_at DESC);

ALTER TABLE community_post_saves ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_post_saves_select_own" ON community_post_saves;
DROP POLICY IF EXISTS "community_post_saves_insert_own" ON community_post_saves;
DROP POLICY IF EXISTS "community_post_saves_delete_own" ON community_post_saves;

CREATE POLICY "community_post_saves_select_own"
  ON community_post_saves FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "community_post_saves_insert_own"
  ON community_post_saves FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "community_post_saves_delete_own"
  ON community_post_saves FOR DELETE
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION increment_community_post_save(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE community_posts
  SET save_count = save_count + 1,
      updated_at = now()
  WHERE id = p_post_id;
END;
$$;

CREATE OR REPLACE FUNCTION decrement_community_post_save(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE community_posts
  SET save_count = GREATEST(save_count - 1, 0),
      updated_at = now()
  WHERE id = p_post_id;
END;
$$;

UPDATE community_posts AS post
SET save_count = saves.total
FROM (
  SELECT post_id, COUNT(*)::INT AS total
  FROM community_post_saves
  GROUP BY post_id
) AS saves
WHERE post.id = saves.post_id;

NOTIFY pgrst, 'reload schema';
