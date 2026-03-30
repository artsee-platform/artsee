import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { ProfileClient } from './profile-client'

export default async function ProfilePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/auth/login?redirect=/profile')

  const [
    { data: profile },
    { data: trackers },
    { data: myCases },
    { data: favorites },
  ] = await Promise.all([
    supabase.from('user_profiles').select('*').eq('id', user.id).single(),
    supabase.from('application_tracker').select('*').eq('user_id', user.id).order('created_at', { ascending: false }),
    supabase.from('cases').select('id, title, target_school, result, like_count, comment_count, created_at, cover_gradient')
      .eq('author_id', user.id).order('created_at', { ascending: false }),
    supabase.from('user_favorites')
      .select('*, programs(id, program_name, schools(name_zh))')
      .eq('user_id', user.id).order('created_at', { ascending: false }),
  ])

  return (
    <ProfileClient
      profile={profile}
      trackers={trackers ?? []}
      myCases={myCases ?? []}
      favorites={favorites ?? []}
    />
  )
}
