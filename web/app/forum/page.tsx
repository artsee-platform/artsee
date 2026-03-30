import { createClient } from '@/lib/supabase/server'
import { ForumClient } from './forum-client'

export default async function ForumPage() {
  const supabase = await createClient()
  const { data: posts } = await supabase
    .from('posts')
    .select('*, user_profiles(nickname, avatar_url)')
    .eq('status', 'published')
    .order('created_at', { ascending: false })

  return <ForumClient posts={posts ?? []} />
}
