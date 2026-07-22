import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET as getAdminMetrics } from "@/app/api/v1/admin/metrics/route";

type Row = Record<string, unknown>;

const ADMIN_ID = "admin-user";
const STUDENT_ID = "student-user";

const tokenUsers: Record<string, string> = {
  admin: ADMIN_ID,
  student: STUDENT_ID,
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  organizations: [],
  consultations: [],
  events: [],
  opportunities: [],
  artworks: [],
  artist_profiles: [],
  verifications: [],
  mentors: [],
  mentor_bookings: [],
  orders: [],
  contracts: [],
  mentor_earnings: [],
  mentor_withdrawal_requests: [],
  payment_refund_requests: [],
  payout_batches: [],
};

function resetDb() {
  db.user_profiles = [
    {
      id: ADMIN_ID,
      role: "admin",
      status: "active",
      user_type: null,
      user_role: null,
      creator_level: "none",
      membership_status: "free",
      membership_expires_at: null,
    },
    {
      id: STUDENT_ID,
      role: "user",
      status: "active",
      user_type: "personal",
      user_role: "student",
      creator_level: "creator",
      membership_status: "member",
      membership_expires_at: "2099-01-01T00:00:00.000Z",
    },
    {
      id: "banned-user",
      role: "user",
      status: "banned",
      user_type: "personal",
      user_role: "student",
      creator_level: "active_creator",
      membership_status: "member",
      membership_expires_at: "2020-01-01T00:00:00.000Z",
    },
  ];
  db.organizations = [
    {
      id: "org-active",
      status: "active",
      type: "gallery_exhibition",
      subscription_status: "active",
      subscription_expires_at: "2099-01-01T00:00:00.000Z",
    },
    {
      id: "org-expired",
      status: "active",
      type: "official_association",
      subscription_status: "active",
      subscription_expires_at: "2020-01-01T00:00:00.000Z",
    },
    {
      id: "org-inactive",
      status: "pending",
      type: "gallery_exhibition",
      subscription_status: "inactive",
      subscription_expires_at: null,
    },
  ];
  db.consultations = [
    { id: "consultation-1", status: "new" },
    { id: "consultation-2", status: "active" },
    { id: "consultation-3", status: "converted" },
  ];
  db.events = [
    { id: "event-1", status: "reviewing" },
    { id: "event-2", status: "published" },
  ];
  db.opportunities = [{ id: "opportunity-1", status: "reviewing" }];
  db.artworks = [{ id: "artwork-1", status: "published" }];
  db.artist_profiles = [{ id: "artist-1", status: "reviewing" }];
  db.verifications = [
    { id: "verification-1", type: "business", status: "pending" },
    { id: "verification-2", type: "artist", status: "approved" },
    { id: "verification-3", type: "student", status: "rejected" },
  ];
  db.mentors = [
    { id: "mentor-1", status: "draft", verification_status: "pending" },
    { id: "mentor-2", status: "active", verification_status: "verified" },
  ];
  db.mentor_bookings = [
    { id: "booking-1", status: "requested", payment_status: "unpaid" },
    { id: "booking-2", status: "completed", payment_status: "paid" },
  ];
  db.orders = [
    {
      id: "order-1",
      status: "paid",
      product_type: "membership_yearly",
      amount_total: 50000,
      currency: "cny",
    },
    {
      id: "order-2",
      status: "pending",
      product_type: "membership_monthly",
      amount_total: 20000,
      currency: "cny",
    },
    {
      id: "order-3",
      status: "paid",
      product_type: "org_subscription",
      amount_total: 120000,
      currency: "cny",
    },
  ];
  db.contracts = [
    { id: "contract-1", status: "pending", organization_id: "org-active", user_id: STUDENT_ID },
    { id: "contract-2", status: "confirmed", organization_id: "org-active", user_id: STUDENT_ID },
    { id: "contract-3", status: "disputed", organization_id: "org-expired", user_id: STUDENT_ID },
  ];
  db.mentor_earnings = [
    { id: "earning-1", status: "available", net_amount: 45000, platform_fee_amount: 5000 },
    { id: "earning-2", status: "pending", net_amount: 18000, platform_fee_amount: 2000 },
  ];
  db.mentor_withdrawal_requests = [
    { id: "withdrawal-1", status: "requested", amount: 30000 },
    { id: "withdrawal-2", status: "paid", amount: 10000 },
  ];
  db.payment_refund_requests = [
    { id: "refund-1", status: "requested", amount: 20000 },
    { id: "refund-2", status: "succeeded", amount: 50000 },
  ];
  db.payout_batches = [
    { id: "payout-1", status: "processing", total_amount: 30000, item_count: 1 },
    { id: "payout-2", status: "paid", total_amount: 10000, item_count: 1 },
  ];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private rangeStart = 0;
  private rangeEnd: number | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  range(start: number, end: number) {
    this.rangeStart = start;
    this.rangeEnd = end;
    return this;
  }

  async maybeSingle() {
    return { data: this.findRows()[0] ?? null, error: null };
  }

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    const rows = this.findRows();
    const sliced =
      this.rangeEnd == null
        ? rows
        : rows.slice(this.rangeStart, this.rangeEnd + 1);
    return Promise.resolve({ data: sliced, count: rows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private findRows() {
    return (db[this.table] ?? []).filter((row) => {
      return this.filters.every(({ field, value }) => row[field] === value);
    });
  }
}

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    const id = token ? tokenUsers[token] : null;
    return id ? ({ id } as { id: string }) : null;
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function req(path: string, token: keyof typeof tokenUsers | null) {
  return new NextRequest(`http://localhost${path}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

describe("admin metrics", () => {
  beforeEach(resetDb);

  it("requires admin access", async () => {
    const denied = await getAdminMetrics(req("/api/v1/admin/metrics", "student"));
    expect(denied.status).toBe(403);
  });

  it("returns operational summaries and grouped metrics", async () => {
    const res = await getAdminMetrics(req("/api/v1/admin/metrics", "admin"));
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.summary.users_total).toBe(3);
    expect(body.summary.users_restricted).toBe(1);
    expect(body.summary.members_active).toBe(1);
    expect(body.summary.members_expired).toBe(1);
    expect(body.summary.creators_total).toBe(2);
    expect(body.summary.organizations_total).toBe(3);
    expect(body.summary.organizations_subscribed).toBe(1);
    expect(body.summary.content_reviewing).toBe(3);
    expect(body.summary.verifications_pending).toBe(1);
    expect(body.summary.consultations_open).toBe(2);
    expect(body.summary.consultations_converted).toBe(1);
    expect(body.summary.contracts_total).toBe(3);
    expect(body.summary.contracts_pending).toBe(1);
    expect(body.summary.contracts_confirmed).toBe(1);
    expect(body.summary.mentors_pending).toBe(1);
    expect(body.summary.paid_order_amount).toBe(170000);
    expect(body.summary.paid_membership_amount).toBe(50000);
    expect(body.summary.paid_org_subscription_amount).toBe(120000);
    expect(body.summary.available_earning_amount).toBe(45000);
    expect(body.summary.requested_withdrawal_amount).toBe(30000);
    expect(body.summary.requested_refund_amount).toBe(20000);
    expect(body.summary.processing_payout_amount).toBe(30000);
    expect(body.sections.content.by_type).toHaveLength(4);
    expect(body.sections.verifications.total).toBe(3);
    expect(body.sections.verifications.by_status.pending).toBe(1);
    expect(body.sections.verifications.by_type.business).toBe(1);
    expect(body.sections.users.by_creator_level.creator).toBe(1);
    expect(body.sections.users.by_creator_level.active_creator).toBe(1);
    expect(body.sections.users.by_membership_status.member).toBe(1);
    expect(body.sections.users.by_membership_status.expired).toBe(1);
    expect(body.sections.organizations.by_subscription_status.active).toBe(1);
    expect(body.sections.organizations.by_subscription_status.expired).toBe(1);
    expect(body.sections.contracts.by_status.disputed).toBe(1);
    expect(body.sections.commerce.orders.by_product_type.membership_yearly).toBe(1);
    expect(body.sections.commerce.orders.amount_by_status.paid).toBe(170000);
    expect(body.sections.commerce.orders.amount_by_product_type.org_subscription).toBe(120000);
    expect(body.sections.commerce.refunds.amount_by_status.succeeded).toBe(50000);
    expect(body.sections.commerce.payout_batches.amount_by_status.processing).toBe(30000);
  });
});
