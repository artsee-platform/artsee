import { createHmac } from "crypto";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as postPaymentWebhook } from "@/app/api/v1/payments/webhook/[provider]/route";

type Row = Record<string, unknown>;

const SECRET = "test-webhook-secret";
const ORDER_ID = "40000000-0000-4000-8000-000000000001";
const BOOKING_ID = "40000000-0000-4000-8000-000000000002";
const MENTOR_ID = "40000000-0000-4000-8000-000000000003";
const MENTOR_USER_ID = "40000000-0000-4000-8000-000000000004";
const ORG_ID = "40000000-0000-4000-8000-000000000005";

const db: Record<string, Row[]> = {
  orders: [],
  user_profiles: [],
  mentor_bookings: [],
  mentors: [],
  organizations: [],
  mentor_earnings: [],
  payment_events: [],
  financial_ledger_entries: [],
  notifications: [],
};

function resetDb() {
  process.env.PAYMENT_WEBHOOK_SECRET = SECRET;
  process.env.MEMBERSHIP_YEARLY_AMOUNT_TOTAL = "99900";
  process.env.ORG_SUBSCRIPTION_YEARLY_AMOUNT_TOTAL = "198000";
  db.orders = [
    {
      id: ORDER_ID,
      user_id: "student-1",
      order_no: "AQ202606130001",
      subject: "作品集评估",
      item_type: "mentor_booking",
      item_id: BOOKING_ID,
      amount_total: 50000,
      currency: "cny",
      status: "checkout_created",
      provider: "stripe",
      metadata: {},
    },
  ];
  db.user_profiles = [
    {
      id: "student-1",
      membership_status: "free",
      membership_started_at: null,
      membership_expires_at: null,
    },
  ];
  db.mentor_bookings = [
    {
      id: BOOKING_ID,
      mentor_id: MENTOR_ID,
      status: "requested",
      payment_status: "unpaid",
    },
  ];
  db.mentors = [{ id: MENTOR_ID, user_id: MENTOR_USER_ID }];
  db.organizations = [
    {
      id: ORG_ID,
      name: "艺见美术馆",
      subscription_status: "inactive",
      subscription_started_at: null,
      subscription_expires_at: null,
      subscription_plan: null,
    },
  ];
  db.mentor_earnings = [];
  db.payment_events = [];
  db.financial_ledger_entries = [];
  db.notifications = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private patch: Row | null = null;
  private inserted: Row | Row[] | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  insert(row: Row | Row[]) {
    const rows = Array.isArray(row) ? row : [row];
    const inserted = rows.map((item, index) => ({
      id: typeof item.id === "string" ? item.id : `${this.table}-${db[this.table].length + index + 1}`,
      ...item,
    }));
    db[this.table].push(...inserted);
    this.inserted = Array.isArray(row) ? inserted : inserted[0];
    return this;
  }

  upsert(row: Row | Row[], options?: { onConflict?: string }) {
    const rows = Array.isArray(row) ? row : [row];
    const conflictKey = options?.onConflict ?? "id";
    const upserted = rows.map((item, index) => {
      const existingIndex = db[this.table].findIndex(
        (current) => current[conflictKey] === item[conflictKey]
      );
      if (existingIndex >= 0) {
        db[this.table][existingIndex] = {
          ...db[this.table][existingIndex],
          ...item,
        };
        return db[this.table][existingIndex];
      }
      const next = {
        id: typeof item.id === "string" ? item.id : `${this.table}-${db[this.table].length + index + 1}`,
        ...item,
      };
      db[this.table].push(next);
      return next;
    });
    this.inserted = Array.isArray(row) ? upserted : upserted[0];
    return this;
  }

  update(patch: Row) {
    this.patch = patch;
    return this;
  }

  async maybeSingle() {
    return { data: this.findRows()[0] ?? null, error: null };
  }

  async single() {
    if (this.inserted && !this.patch) {
      return { data: Array.isArray(this.inserted) ? this.inserted[0] : this.inserted, error: null };
    }
    if (!this.patch) {
      const row = this.findRows()[0] ?? null;
      return { data: row, error: row ? null : { message: "not found" } };
    }
    const row = this.applyPatch()[0] ?? null;
    return { data: row, error: row ? null : { message: "not found" } };
  }

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    if (this.patch) this.applyPatch();
    const rows = this.inserted
      ? Array.isArray(this.inserted)
        ? this.inserted
        : [this.inserted]
      : this.findRows();
    return Promise.resolve({ data: rows, count: rows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private applyPatch() {
    const rows = db[this.table] ?? [];
    const updated: Row[] = [];
    rows.forEach((row, index) => {
      if (!this.matches(row)) return;
      rows[index] = { ...row, ...this.patch };
      updated.push(rows[index]);
    });
    return updated;
  }

  private findRows() {
    return (db[this.table] ?? []).filter((row) => this.matches(row));
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value }) => row[field] === value);
  }
}

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function signedReq(body: Row, signatureSecret = SECRET) {
  const raw = JSON.stringify(body);
  const signature = createHmac("sha256", signatureSecret).update(raw).digest("hex");
  return new NextRequest("http://localhost/api/v1/payments/webhook/stripe", {
    method: "POST",
    headers: { "x-artiqore-signature": signature },
    body: raw,
  });
}

function ctx(provider = "stripe") {
  return { params: Promise.resolve({ provider }) };
}

describe("POST /api/v1/payments/webhook/:provider", () => {
  beforeEach(resetDb);

  it("rejects invalid signatures", async () => {
    const res = await postPaymentWebhook(
      signedReq({ id: "evt_bad", type: "payment.succeeded" }, "wrong-secret"),
      ctx()
    );
    expect(res.status).toBe(401);
  });

  it("processes paid events once and creates mentor earnings", async () => {
    const payload = {
      id: "evt_paid_1",
      type: "payment.succeeded",
      data: {
        object: {
          order_id: ORDER_ID,
          amount_paid: 50000,
          payment_intent: "pi_123",
          customer_id: "cus_123",
        },
      },
    };

    const res = await postPaymentWebhook(signedReq(payload), ctx());
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.order.status).toBe("paid");
    expect(db.orders[0].provider_payment_intent_id).toBe("pi_123");
    expect(db.mentor_bookings[0].payment_status).toBe("paid");
    expect(db.mentor_earnings[0].net_amount).toBe(45000);
    expect(db.financial_ledger_entries.map((entry) => entry.entry_type)).toEqual([
      "order_payment_gross",
      "platform_fee_accrual",
      "mentor_earning_accrual",
    ]);
    expect(db.financial_ledger_entries[1].amount).toBe(5000);
    expect(db.financial_ledger_entries[2].amount).toBe(45000);
    expect(db.payment_events[0].status).toBe("processed");
    expect(db.notifications[0].user_id).toBe(MENTOR_USER_ID);

    const duplicate = await postPaymentWebhook(signedReq(payload), ctx());
    const duplicateBody = await duplicate.json();
    expect(duplicate.status).toBe(200);
    expect(duplicateBody.duplicate).toBe(true);
    expect(db.mentor_earnings).toHaveLength(1);
  });

  it("marks membership orders paid and extends user membership", async () => {
    db.orders[0] = {
      id: ORDER_ID,
      user_id: "student-1",
      order_no: "AQ202606130002",
      subject: "Artiqore 年度会员",
      item_type: "membership_yearly",
      product_type: "membership_yearly",
      item_id: null,
      amount_total: 99900,
      currency: "cny",
      status: "checkout_created",
      provider: "stripe",
      metadata: {},
    };

    const res = await postPaymentWebhook(
      signedReq({
        id: "evt_membership_paid_1",
        type: "payment.succeeded",
        data: {
          object: {
            order_id: ORDER_ID,
            amount_paid: 99900,
            paid_at: "2026-06-14T12:00:00.000Z",
          },
        },
      }),
      ctx()
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.order.status).toBe("paid");
    expect(body.data.membership.membership_status).toBe("member");
    expect(db.user_profiles[0].membership_status).toBe("member");
    expect(db.user_profiles[0].membership_started_at).toBe("2026-06-14T12:00:00.000Z");
    expect(db.user_profiles[0].membership_expires_at).toBe("2027-06-14T12:00:00.000Z");
    expect(db.mentor_earnings).toHaveLength(0);
    expect(db.financial_ledger_entries).toHaveLength(1);
  });

  it("rejects managed product orders when the order amount differs from platform config", async () => {
    db.orders[0] = {
      id: ORDER_ID,
      user_id: "student-1",
      order_no: "AQ202606130004",
      subject: "Artiqore 年度会员",
      item_type: "membership_yearly",
      product_type: "membership_yearly",
      item_id: null,
      amount_total: 100,
      currency: "cny",
      status: "checkout_created",
      provider: "stripe",
      metadata: {},
    };

    const res = await postPaymentWebhook(
      signedReq({
        id: "evt_membership_bad_amount_1",
        type: "payment.succeeded",
        data: {
          object: {
            order_id: ORDER_ID,
            amount_paid: 100,
            paid_at: "2026-06-14T12:00:00.000Z",
          },
        },
      }),
      ctx()
    );
    const body = await res.json();

    expect(res.status).toBe(500);
    expect(body.error).toBe("受管商品订单金额与平台配置不一致");
    expect(db.orders[0].status).toBe("checkout_created");
    expect(db.user_profiles[0].membership_status).toBe("free");
    expect(db.financial_ledger_entries).toHaveLength(0);
    expect(db.payment_events[0]).toMatchObject({
      status: "failed",
      error_message: "受管商品订单金额与平台配置不一致",
    });
  });

  it("marks organization subscription orders paid and extends organization subscription", async () => {
    db.orders[0] = {
      id: ORDER_ID,
      user_id: "owner-1",
      order_no: "AQ202606130003",
      subject: "艺见美术馆 年度入驻服务",
      item_type: "org_subscription",
      product_type: "org_subscription",
      item_id: ORG_ID,
      amount_total: 198000,
      currency: "cny",
      status: "checkout_created",
      provider: "stripe",
      metadata: { organization_id: ORG_ID },
    };

    const res = await postPaymentWebhook(
      signedReq({
        id: "evt_org_subscription_paid_1",
        type: "payment.succeeded",
        data: {
          object: {
            order_id: ORDER_ID,
            amount_paid: 198000,
            paid_at: "2026-06-14T12:00:00.000Z",
          },
        },
      }),
      ctx()
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.order.status).toBe("paid");
    expect(body.data.organization_subscription.subscription_status).toBe("active");
    expect(db.organizations[0].subscription_status).toBe("active");
    expect(db.organizations[0].subscription_started_at).toBe("2026-06-14T12:00:00.000Z");
    expect(db.organizations[0].subscription_expires_at).toBe("2027-06-14T12:00:00.000Z");
    expect(db.organizations[0].subscription_plan).toBe("yearly");
    expect(db.mentor_earnings).toHaveLength(0);
    expect(db.financial_ledger_entries).toHaveLength(1);
  });

  it("marks orders, bookings, and earnings as refunded", async () => {
    db.orders[0] = {
      ...db.orders[0],
      status: "paid",
      provider_payment_intent_id: "pi_123",
    };
    db.mentor_bookings[0] = { ...db.mentor_bookings[0], payment_status: "paid" };
    db.mentor_earnings = [
      {
        id: "earning-1",
        order_id: ORDER_ID,
        mentor_id: MENTOR_ID,
        status: "available",
        net_amount: 45000,
      },
    ];

    const res = await postPaymentWebhook(
      signedReq({
        id: "evt_refund_1",
        type: "payment.refunded",
        data: {
          object: {
            payment_intent: "pi_123",
          },
        },
      }),
      ctx()
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.order.status).toBe("refunded");
    expect(db.mentor_bookings[0].payment_status).toBe("refunded");
    expect(db.mentor_earnings[0].status).toBe("refunded");
    expect(db.financial_ledger_entries.map((entry) => entry.entry_type)).toEqual([
      "order_refund_gross",
      "mentor_earning_reversal",
    ]);
  });
});
