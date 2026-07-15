import { createServiceClient } from "@/lib/api/supabase-service";

export const PLAZA_UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Supabase = ReturnType<typeof createServiceClient>;
type Row = Record<string, unknown>;
type Profile = { nickname: string | null; avatar_url: string | null };

function asRecord(value: unknown): Row {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Row)
    : {};
}

function intValue(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function stringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map(String).map((item) => item.trim()).filter(Boolean);
}

function textExcerpt(value: unknown, max = 84) {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max - 1)}…`;
}

function kindFromMetadata(metadata: Row) {
  return String(metadata.kind ?? metadata.type ?? "article").trim() || "article";
}

function tagsFromMetadata(metadata: Row) {
  const tags = metadata.tags ?? metadata.labels;
  if (Array.isArray(tags)) return tags.map(String).filter(Boolean);
  const category = metadata.category ?? metadata.group ?? metadata.circle;
  return category ? [String(category)] : [];
}

function groupFromMetadata(metadata: Row) {
  return String(
    metadata.group ??
      metadata.circle_title ??
      metadata.circle ??
      metadata.category ??
      "广场"
  );
}

export function isPlazaPost(post: Row) {
  const metadata = asRecord(post.metadata);
  const surface = String(metadata.surface ?? "").trim().toLowerCase();
  const source = String(metadata.source ?? "").trim().toLowerCase();
  return surface === "plaza" || source.startsWith("plaza_");
}

export function normalizePlazaPost(
  post: Row,
  options: {
    profile?: Profile | null;
    likedByMe?: boolean;
    savedByMe?: boolean;
  } = {}
) {
  const metadata = asRecord(post.metadata);
  const kind = kindFromMetadata(metadata);
  const likeCount = intValue(post.like_count);
  const commentCount = intValue(post.comment_count);
  const viewCount = intValue(post.view_count);
  const saveCount = intValue(post.save_count);

  return {
    feed_type: "post",
    surface: "plaza",
    kind,
    id: String(post.id),
    title: String(post.title ?? ""),
    body: post.body ?? null,
    body_excerpt: textExcerpt(post.body),
    image_urls: stringArray(post.image_urls),
    status: String(post.status ?? "published"),
    group: groupFromMetadata(metadata),
    tags: tagsFromMetadata(metadata),
    rating: asRecord(metadata.rating),
    debate: asRecord(metadata.debate),
    quote: metadata.quote ?? null,
    author_type: String(metadata.author_type ?? "user"),
    author_id: post.author_id ? String(post.author_id) : null,
    user_profiles: options.profile ?? null,
    like_count: likeCount,
    comment_count: commentCount,
    save_count: saveCount,
    view_count: viewCount,
    heat_score: likeCount * 3 + commentCount * 4 + Math.round(viewCount * 0.2),
    liked_by_me: options.likedByMe ?? false,
    saved_by_me: options.savedByMe ?? false,
    created_at: post.created_at ?? null,
    updated_at: post.updated_at ?? null,
    metadata,
  };
}

export async function attachPlazaPostState(
  supabase: Supabase,
  posts: Row[],
  userId?: string
) {
  const authorIds = [
    ...new Set(posts.map((post) => String(post.author_id ?? "")).filter(Boolean)),
  ];
  let profileMap: Record<string, Profile> = {};
  if (authorIds.length > 0) {
    const { data: profiles } = await supabase
      .from("user_profiles")
      .select("id, nickname, avatar_url")
      .in("id", authorIds);
    profileMap = Object.fromEntries(
      (profiles ?? []).map((profile: { id: string; nickname: string | null; avatar_url: string | null }) => [
        profile.id,
        { nickname: profile.nickname, avatar_url: profile.avatar_url },
      ])
    );
  }

  const postIds = posts.map((post) => String(post.id)).filter(Boolean);
  let likedIds = new Set<string>();
  let savedIds = new Set<string>();

  if (userId && postIds.length > 0) {
    const { data: likes } = await supabase
      .from("community_post_likes")
      .select("post_id")
      .eq("user_id", userId)
      .in("post_id", postIds);
    likedIds = new Set((likes ?? []).map((item: { post_id: string }) => item.post_id));

    const { data: saves } = await supabase
      .from("community_post_saves")
      .select("post_id")
      .eq("user_id", userId)
      .in("post_id", postIds);
    savedIds = new Set((saves ?? []).map((item: { post_id: string }) => item.post_id));
  }

  return posts.map((post) =>
    normalizePlazaPost(post, {
      profile: profileMap[String(post.author_id)] ?? null,
      likedByMe: likedIds.has(String(post.id)),
      savedByMe: savedIds.has(String(post.id)),
    })
  );
}
