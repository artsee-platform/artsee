-- Plaza uses the existing community post system as its feed substrate.
-- Comments need just enough structure for nested replies and AI/official personas.

ALTER TABLE community_post_comments
  ADD COLUMN IF NOT EXISTS parent_id UUID
    REFERENCES community_post_comments (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS author_type TEXT NOT NULL DEFAULT 'user'
    CHECK (author_type IN ('user', 'ai', 'official')),
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_community_post_comments_parent_created
  ON community_post_comments (parent_id, created_at);

CREATE INDEX IF NOT EXISTS idx_community_post_comments_author_type
  ON community_post_comments (author_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_post_comments_metadata_stance
  ON community_post_comments ((metadata->>'stance'));

CREATE INDEX IF NOT EXISTS idx_community_posts_plaza_feed
  ON community_posts (status, created_at DESC, like_count DESC, comment_count DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_plaza_kind_created
  ON community_posts ((metadata->>'kind'), status, created_at DESC);

NOTIFY pgrst, 'reload schema';
