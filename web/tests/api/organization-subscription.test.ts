import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as upgradeOrganizationSubscription } from "@/app/api/v1/me/organizations/[id]/subscription/upgrade/route";

type Row = Record<string, unknown>;
type Ctx = { params: Promise<{ id: string }> };

const ORG_ID = "10000000-0000-4000-8000-000000000010";
const OWNER_ID = "10000000-0000-4000-8000-000000000001";
const ADVISOR_ID = "10000000-0000-4000-8000-000000000002";

const tokenUsers: Record<string, string> = {
  owner: OWNER_ID,
  advisor: ADVISOR_ID,
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  organization_members: [],
  organizations: [],
  orders: [],
};

function resetDb() {
  delete process.env.ORG_SUBSCRIPTION_YEARLY_AMOUNT_TOTAL;
  delete process.env.PAYMENT_PROVIDER;
  delete process.env.PAYMENT_CHECKOUT_ENDPOINT;
  db.user_profiles = [
    { id: OWNER_ID, role: "user", status: "active" },
    { id: ADVISOR_ID, role: "user", status: "active" },
  ];
  db.organization_members = [
    {
      id: "10000000-0000-4000-8000-000000000020",
      organization_id: ORG_ID,
      user_id: OWNER_ID,
      role: "owner",
      status: "active",
    },
    {
      id: "10000000-0000-4000-8000-000000000021",
      organization_id: ORG_ID,
      user_id: ADVISOR_ID,
      role: "advisor",
      status: "active",
    },
  ];
  db.organizations = [
    {
      id: ORG_ID,
      name: "艺见美术馆",
      type: "gallery_exhibition",
      status: "active",
      subscription_status: "inactive",
      subscription_expires_at: null,
    },
  ];
  db.orders = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown; op: "eq" | "in" }> = [];
  private patch: Row | null = null;
  private inserted: Row | Row[] | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value, op: "eq" });
    return this;
  }

  in(field: string, values: unknown[]) {
    this.filters.push({ field, value: values, op: "in" });
    return this;
  }

  insert(row: Row | Row[]) {
    const rows = Array.isArray(row) ? row : [row];
    const inserted = rows.map((item, index) => ({
      id:
        typeof item.id === "string"
          ? item.id
          : `10000000-0000-4000-8000-00000000009${index}`,
      ...item,
    }));
    db[this.table].push(...inserted);
    this.inserted = Array.isArray(row) ? inserted : inserted[0];
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
      return {
        data: Array.isArray(this.inserted) ? this.inserted[0] : this.inserted,
        error: null,
      };
    }
    if (this.patch) {
      const rows = db[this.table] ?? [];
      const index = rows.findIndex((row) => this.matches(row));
      if (index < 0) return { data: null, error: { message: "not found" } };
      rows[index] = { ...rows[index], ...this.patch };
      return { data: rows[index], error: null };
    }
    const row = this.findRows()[0] ?? null;
    return { data: row, error: row ? null : { message: "not found" } };
  }

  private findRows() {
    return (db[this.table] ?? []).filter((row) => this.matches(row));
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value, op }) => {
      if (op === "in") return Array.isArray(value) && value.includes(row[field]);
      return row[field] === value;
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

function req(token?: keyof typeof tokenUsers) {
  return new NextRequest(
    `http://localhost/api/v1/me/organizations/${ORG_ID}/subscription/upgrade`,
    {
      method: "POST",
      headers: token ? { authorization: `Bearer ${token}` } : undefined,
      body: JSON.stringify({}),
    }
  );
}

function ctx(id = ORG_ID) {
  return { params: Promise.resolve({ id }) } satisfies Ctx;
}

describe("POST /api/v1/me/organizations/:id/subscription/upgrade", () => {
  beforeEach(resetDb);

  it("requires login", async () => {
    const res = await upgradeOrganizationSubscription(req(), ctx());
    expect(res.status).toBe(401);
  });

  it("requires owner or admin membership", async () => {
    process.env.ORG_SUBSCRIPTION_YEARLY_AMOUNT_TOTAL = "198000";
    const res = await upgradeOrganizationSubscription(req("advisor"), ctx());
    expect(res.status).toBe(403);
  });

  it("requires configured yearly amount", async () => {
    const res = await upgradeOrganizationSubscription(req("owner"), ctx());
    const body = await res.json();
    expect(res.status).toBe(503);
    expect(body.error).toContain("ORG_SUBSCRIPTION_YEARLY_AMOUNT_TOTAL");
  });

  it("blocks retired study-abroad agency subscription upgrades", async () => {
    db.organizations[0].type = "study_abroad_agency";
    process.env.ORG_SUBSCRIPTION_YEARLY_AMOUNT_TOTAL = "198000";
    const res = await upgradeOrganizationSubscription(req("owner"), ctx());
    const body = await res.json();
    expect(res.status).toBe(403);
    expect(body.error).toBe("该机构类型已下线");
  });

  it("creates an organization subscription checkout order", async () => {
    process.env.ORG_SUBSCRIPTION_YEARLY_AMOUNT_TOTAL = "198000";
    const res = await upgradeOrganizationSubscription(req("owner"), ctx());
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.productType).toBe("org_subscription");
    expect(body.data.organizationId).toBe(ORG_ID);
    expect(body.data.checkoutUrl).toBe(`/orders/${body.data.orderId}`);
    expect(db.orders[0].item_type).toBe("org_subscription");
    expect(db.orders[0].item_id).toBe(ORG_ID);
    expect(db.orders[0].amount_total).toBe(198000);
  });
});
