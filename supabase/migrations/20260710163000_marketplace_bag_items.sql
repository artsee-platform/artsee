CREATE TABLE IF NOT EXISTS marketplace_bag_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  listing_post_id UUID NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('saved', 'pending', 'consulted', 'ordered', 'closed')
  ),
  saved BOOLEAN NOT NULL DEFAULT false,
  message TEXT,
  conversation_id UUID REFERENCES conversations (id) ON DELETE SET NULL,
  order_id UUID REFERENCES orders (id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, listing_post_id)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_bag_user_status
  ON marketplace_bag_items (user_id, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_bag_listing
  ON marketplace_bag_items (listing_post_id, updated_at DESC);

DROP TRIGGER IF EXISTS trg_marketplace_bag_items_updated_at ON marketplace_bag_items;
CREATE TRIGGER trg_marketplace_bag_items_updated_at
  BEFORE UPDATE ON marketplace_bag_items
  FOR EACH ROW
  EXECUTE FUNCTION set_orders_updated_at();

ALTER TABLE marketplace_bag_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "marketplace_bag_select_own" ON marketplace_bag_items;
CREATE POLICY "marketplace_bag_select_own"
  ON marketplace_bag_items
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "marketplace_bag_insert_own" ON marketplace_bag_items;
CREATE POLICY "marketplace_bag_insert_own"
  ON marketplace_bag_items
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "marketplace_bag_update_own" ON marketplace_bag_items;
CREATE POLICY "marketplace_bag_update_own"
  ON marketplace_bag_items
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "marketplace_bag_delete_own" ON marketplace_bag_items;
CREATE POLICY "marketplace_bag_delete_own"
  ON marketplace_bag_items
  FOR DELETE
  USING (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
