import { createClient } from '@/lib/supabase/server'
import { ExploreClient } from './explore-client'

export default async function ExplorePage({
  searchParams,
}: {
  searchParams: Promise<{ school?: string }>
}) {
  const { school } = await searchParams
  const supabase = await createClient()

  const { data: programs } = await supabase
    .from('programs')
    .select(`
      *,
      schools ( id, name_zh, name_en, country, city, logo_url, qs_art_rank ),
      program_admissions ( ielts_overall, reference_count, regular_deadline, portfolio_requirements ),
      program_fees ( international_tuition_fee, currency_code )
    `)
    .eq('status', 'active')
    .order('id')

  return <ExploreClient programs={programs ?? []} initialSchool={school} />
}
