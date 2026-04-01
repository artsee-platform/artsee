'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

// ─── 案例相关 ─────────────────────────────────────────────
export async function createCase(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const title = formData.get('title') as string
  const undergrad = formData.get('undergrad') as string
  const gpa = formData.get('gpa') as string
  const target_school = formData.get('target_school') as string
  const target_program = formData.get('target_program') as string
  const result = formData.get('result') as string
  const excerpt = formData.get('excerpt') as string
  const content = formData.get('content') as string
  const year = formData.get('year') as string
  const is_anonymous = formData.get('is_anonymous') === 'on'
  const tagsRaw = formData.get('tags') as string
  const tags = tagsRaw ? tagsRaw.split(',').map(t => t.trim()).filter(Boolean) : []

  const { data, error } = await supabase.from('cases').insert({
    author_id: user.id,
    title, undergrad, gpa, target_school, target_program,
    result, excerpt, content, year, is_anonymous, tags,
  }).select('id').single()

  if (error) return { error: error.message }
  revalidatePath('/cases')
  return { id: data.id }
}

// ─── 帖子相关 ─────────────────────────────────────────────
export async function createPost(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const title = formData.get('title') as string
  const content = formData.get('content') as string
  const type = formData.get('type') as string
  const tagsRaw = formData.get('tags') as string
  const tags = tagsRaw ? tagsRaw.split(',').map(t => t.trim()).filter(Boolean) : []

  const { data, error } = await supabase.from('posts').insert({
    author_id: user.id, title, content, type, tags,
  }).select('id').single()

  if (error) return { error: error.message }
  revalidatePath('/forum')
  return { id: data.id }
}

export async function createReply(postId: string, content: string) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const { error } = await supabase.from('post_replies').insert({
    post_id: postId, author_id: user.id, content,
  })
  if (error) return { error: error.message }

  revalidatePath(`/forum/${postId}`)
  return { success: true }
}

// ─── 收藏相关 ─────────────────────────────────────────────
export async function toggleFavorite(programId: number) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const { data: existing } = await supabase
    .from('user_favorites')
    .select('id')
    .eq('user_id', user.id)
    .eq('program_id', programId)
    .single()

  if (existing) {
    await supabase.from('user_favorites').delete().eq('id', existing.id)
    return { favorited: false }
  } else {
    await supabase.from('user_favorites').insert({ user_id: user.id, program_id: programId })
    return { favorited: true }
  }
}

// ─── 追踪相关 ─────────────────────────────────────────────
export async function updateTrackerStatus(id: string, status: string) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  await supabase.from('application_tracker')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', id).eq('user_id', user.id)

  revalidatePath('/profile')
  return { success: true }
}

export async function createTrackerEntry(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const school_name = formData.get('school_name') as string
  const program_name = formData.get('program_name') as string
  const tier = formData.get('tier') as string
  const status = formData.get('status') as string

  const { error } = await supabase.from('application_tracker').insert({
    user_id: user.id,
    school_name,
    program_name,
    tier,
    status,
  })

  if (error) return { error: error.message }
  revalidatePath('/profile')
  return { success: true }
}

export async function signOut() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  revalidatePath('/')
}

// ─── 点赞相关 ─────────────────────────────────────────────
export async function toggleLike(targetId: string, targetType: 'case' | 'post') {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const { data: existing } = await supabase
    .from('likes')
    .select('id')
    .eq('user_id', user.id)
    .eq('target_id', targetId)
    .eq('target_type', targetType)
    .single()

  if (existing) {
    await supabase.from('likes').delete().eq('id', existing.id)
    if (targetType === 'case') {
      await supabase.rpc('decrement_case_like', { case_id: targetId })
    } else {
      await supabase.rpc('decrement_post_like', { post_id: targetId })
    }
    return { liked: false }
  } else {
    await supabase.from('likes').insert({ user_id: user.id, target_id: targetId, target_type: targetType })
    if (targetType === 'case') {
      await supabase.rpc('increment_case_like', { case_id: targetId })
    } else {
      await supabase.rpc('increment_post_like', { post_id: targetId })
    }
    return { liked: true }
  }
}

export async function checkLiked(targetId: string, targetType: 'case' | 'post') {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { liked: false }

  const { data } = await supabase
    .from('likes')
    .select('id')
    .eq('user_id', user.id)
    .eq('target_id', targetId)
    .eq('target_type', targetType)
    .single()

  return { liked: !!data }
}

// ─── 编辑资料 ─────────────────────────────────────────────
export async function updateProfile(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { error: '请先登录' }

  const nickname = formData.get('nickname') as string
  const bio = formData.get('bio') as string
  const location = formData.get('location') as string

  const { error } = await supabase
    .from('user_profiles')
    .update({ nickname, bio, location, updated_at: new Date().toISOString() })
    .eq('id', user.id)

  if (error) return { error: error.message }
  revalidatePath('/profile')
  return { success: true }
}
