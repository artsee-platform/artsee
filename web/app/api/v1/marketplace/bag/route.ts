import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { attachPlazaPostState } from "@/lib/api/plaza";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";

type Row = Record<string, unknown>;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{12}$/i;
const STATUSES = new Set(["saved", "pending", "consulted", "ordered", "closed"]);

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function asPost(row: Row) {
  const rawPost = row.community_posts;
  const post = Array.isArray(rawPost) ? rawPost[0] : rawPost;
  if (!post || typeof post !== "object") return null;
  return post as Row;
}

function optionalUuid(value: unknown) {
  const text = cleanText(value);
  return text && UUID_RE.test(text) ? text : null;
}

async function fetchMarketListing(
  supabase: ReturnType<typeof createServiceClient>,
  listingPostId: string
) {
  const { data, error } = await supabase
    .from("community_posts")
    .select("*")
    .eq("id", listingPostId)
    .eq("status", "published")
    .eq("metadata->>surface", "plaza")
    .eq("metadata->>kind", "market")
    .maybeSingle();
  if (error) throw error;
  return data as Row | null;
}

export async function GET(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const status = cleanText(searchParams.get("status"));
    const supabase = createServiceClient();
    let query = supabase
      .from("marketplace_bag_items")
      .select("*, community_posts(*)", { count: "exact" })
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (status && STATUSES.has(status)) query = query.eq("status", status);

    const { data: rows, error, count } = await query;
    if (error) return errorResponse(error);

    const entries = (rows ?? []) as Row[];
    const posts = entries.map(asPost).filter(Boolean) as Row[];
    const statePosts = await attachPlazaPostState(supabase, posts, user.id);
    const postMap = new Map(statePosts.map((post) => [cleanText(post.id), post]));

    return NextResponse.json({
      success: true,
      data: entries.map((entry) => ({
        ...entry,
        listing: postMap.get(cleanText(entry.listing_post_id)) ?? asPost(entry),
        community_posts: undefined,
      })),
      count,
      pagination: { limit, offset },
    });
  } catch (e) {
    return errorResponse(e);
  }
}

export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const body = (await req.json().catch(() => ({}))) as Row;
    const listingPostId = cleanText(body.listing_post_id ?? body.listingPostId);
    if (!UUID_RE.test(listingPostId)) {
      return NextResponse.json({ success: false, error: "无效商品 ID" }, { status: 400 });
    }

    const supabase = createServiceClient();
    const listing = await fetchMarketListing(supabase, listingPostId);
    if (!listing) {
      return NextResponse.json({ success: false, error: "商品不存在或已下架" }, { status: 404 });
    }

    const { data: existing, error: existingError } = await supabase
      .from("marketplace_bag_items")
      .select("*")
      .eq("user_id", user.id)
      .eq("listing_post_id", listingPostId)
      .maybeSingle();
    if (existingError) return errorResponse(existingError);

    const rawStatus = cleanText(body.status);
    const existingStatus = cleanText((existing as Row | null)?.status);
    const status = STATUSES.has(rawStatus)
      ? rawStatus
      : existingStatus || (body.saved === true ? "saved" : "pending");
    const saved =
      typeof body.saved === "boolean"
        ? body.saved
        : Boolean((existing as Row | null)?.saved);
    const message =
      body.message === null
        ? null
        : cleanText(body.message) || ((existing as Row | null)?.message ?? null);
    const metadata = {
      ...objectValue((existing as Row | null)?.metadata),
      ...objectValue(body.metadata),
    };
    const payload = {
      status,
      saved,
      message,
      conversation_id:
        optionalUuid(body.conversation_id ?? body.conversationId) ??
        ((existing as Row | null)?.conversation_id ?? null),
      order_id:
        optionalUuid(body.order_id ?? body.orderId) ??
        ((existing as Row | null)?.order_id ?? null),
      metadata,
    };

    const result = existing
      ? await supabase
          .from("marketplace_bag_items")
          .update(payload)
          .eq("id", (existing as Row).id)
          .eq("user_id", user.id)
          .select("*")
          .single()
      : await supabase
          .from("marketplace_bag_items")
          .insert({
            ...payload,
            user_id: user.id,
            listing_post_id: listingPostId,
          })
          .select("*")
          .single();

    if (result.error) return errorResponse(result.error);
    const [listingWithState] = await attachPlazaPostState(supabase, [listing], user.id);
    return NextResponse.json({
      success: true,
      data: {
        ...result.data,
        listing: listingWithState,
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
