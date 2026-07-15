import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createCheckoutSession } from "@/lib/api/payment-checkout";
import { errorResponse } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";

type Row = Record<string, unknown>;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{12}$/i;

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function makeOrderNo() {
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
  const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `AQ${stamp}${rand}`;
}

function intValue(value: unknown) {
  const num = Number(value);
  return Number.isInteger(num) && num > 0 ? num : null;
}

function priceLabel(post: Row) {
  const metadata = objectValue(post.metadata);
  return (
    cleanText(metadata.price) ||
    cleanText(metadata.amount) ||
    cleanText(metadata.budget) ||
    cleanText(metadata.exchange)
  );
}

function priceToCents(post: Row) {
  const metadata = objectValue(post.metadata);
  const configured =
    intValue(metadata.amount_total) ??
    intValue(metadata.amountTotal) ??
    intValue(metadata.price_amount) ??
    intValue(metadata.priceAmount);
  if (configured) return configured;

  const raw = priceLabel(post).toLowerCase();
  if (!raw) return null;
  if (
    raw.includes("~") ||
    raw.includes("-") ||
    raw.includes("起") ||
    raw.includes("报价") ||
    raw.includes("议价") ||
    raw.includes("沟通") ||
    raw.includes("委托") ||
    raw.includes("custom")
  ) {
    return null;
  }

  const match = raw.replace(/,/g, "").match(/(\d+(?:\.\d{1,2})?)/);
  if (!match) return null;
  const amount = Number(match[1]);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  return Math.round(amount * 100);
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

    const quantity = Math.min(Math.max(intValue(body.quantity) ?? 1, 1), 99);
    const message = cleanText(body.message);
    const supabase = createServiceClient();
    const listing = await fetchMarketListing(supabase, listingPostId);
    if (!listing) {
      return NextResponse.json({ success: false, error: "商品不存在或已下架" }, { status: 404 });
    }
    const sellerUserId = cleanText(listing.author_id);
    if (sellerUserId === user.id) {
      return NextResponse.json({ success: false, error: "不能购买自己发布的商品" }, { status: 400 });
    }

    const unitAmount = priceToCents(listing);
    if (!unitAmount) {
      return NextResponse.json(
        { success: false, error: "该商品需要先咨询发布者确认报价" },
        { status: 400 }
      );
    }

    const title = cleanText(listing.title) || "市集商品";
    const metadata = objectValue(listing.metadata);
    const amountTotal = unitAmount * quantity;
    const { data: order, error } = await supabase
      .from("orders")
      .insert({
        user_id: user.id,
        order_no: makeOrderNo(),
        subject: `市集商品：${title}`,
        item_type: "marketplace_listing",
        product_type: "marketplace_listing",
        item_id: listingPostId,
        amount_total: amountTotal,
        currency: "cny",
        status: "pending",
        provider: "internal",
        metadata: {
          source: "marketplace",
          listing_post_id: listingPostId,
          listing_title: title,
          listing_category: cleanText(metadata.category) || null,
          listing_price_label: priceLabel(listing) || null,
          seller_user_id: sellerUserId || null,
          quantity,
          unit_amount: unitAmount,
          message: message || null,
        },
      })
      .select("*")
      .single();
    if (error) return errorResponse(error);

    const checkout = await createCheckoutSession(order);
    const { data: updatedOrder, error: updateError } = await supabase
      .from("orders")
      .update({
        status: "checkout_created",
        provider: checkout.provider,
        provider_checkout_session_id: checkout.checkoutSessionId ?? null,
        provider_payment_intent_id: checkout.paymentIntentId ?? null,
        provider_customer_id: checkout.customerId ?? null,
      })
      .eq("id", order.id)
      .eq("user_id", user.id)
      .select("*")
      .single();
    if (updateError) return errorResponse(updateError);

    await supabase
      .from("marketplace_bag_items")
      .upsert(
        {
          user_id: user.id,
          listing_post_id: listingPostId,
          status: "ordered",
          saved: true,
          message: message || null,
          order_id: updatedOrder.id,
          metadata: {
            source: "marketplace_order",
            checkout_provider: checkout.provider,
          },
        },
        { onConflict: "user_id,listing_post_id" }
      )
      .then(({ error: bagError }) => {
        if (bagError) {
          console.warn("[marketplace] failed to upsert bag item for order", bagError);
        }
      });

    return NextResponse.json({
      success: true,
      data: {
        orderId: updatedOrder.id,
        orderNo: updatedOrder.order_no,
        status: updatedOrder.status,
        checkoutUrl: checkout.checkoutUrl,
        order: updatedOrder,
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
