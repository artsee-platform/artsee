import { createClient } from '@/lib/supabase/server'
import { CasesClient } from './cases-client'

export default async function CasesPage() {
  const supabase = await createClient()
  const { data: cases } = await supabase
    .from('cases')
    .select('*, user_profiles(nickname, avatar_url)')
    .eq('status', 'published')
    .order('created_at', { ascending: false })

  return <CasesClient cases={cases ?? []} />
}
