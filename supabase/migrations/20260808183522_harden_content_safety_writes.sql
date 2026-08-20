-- Public user-generated content must be written through the Next.js BFF so
-- Tencent Cloud moderation cannot be bypassed through the Supabase Data API.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_posts
  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_post_comments
  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_hot_topic_answer_comments
  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.community_circles
  FROM anon, authenticated;

DROP POLICY IF EXISTS "community_posts_insert_own"
  ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_update_own"
  ON public.community_posts;
DROP POLICY IF EXISTS "community_posts_delete_own"
  ON public.community_posts;

DROP POLICY IF EXISTS "community_post_comments_insert_own"
  ON public.community_post_comments;
DROP POLICY IF EXISTS "community_post_comments_update_own"
  ON public.community_post_comments;
DROP POLICY IF EXISTS "community_post_comments_delete_own"
  ON public.community_post_comments;

DROP POLICY IF EXISTS "hot_topic_answer_comments_insert_own"
  ON public.community_hot_topic_answer_comments;
DROP POLICY IF EXISTS "hot_topic_answer_comments_update_own"
  ON public.community_hot_topic_answer_comments;

DROP POLICY IF EXISTS "community_circles_insert_own"
  ON public.community_circles;
DROP POLICY IF EXISTS "community_circles_update_own"
  ON public.community_circles;
