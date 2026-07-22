import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import {
  GET as getConsultationReview,
  POST as postConsultationReview,
} from "@/app/api/v1/me/consultations/[id]/review/route";

type Row = Record<string, unknown>;
type Ctx = { params: Promise<{ id: string }> };

const USER_ID = "10000000-0000-4000-8000-000000000001";
const OWNER_ID = "10000000-0000-4000-8000-000000000002";
const ORG_ID = "10000000-0000-4000-8000-000000000010";
const CLOSED_CONSULTATION_ID = "10000000-0000-4000-8000-000000000020";
const ACTIVE_CONSULTATION_ID = "10000000-0000-4000-8000-000000000021";
const OTHER_CONSULTATION_ID = "10000000-0000-4000-8000-000000000022";

const db: Record<string, Row[]> = {
  user_profiles: [],
  organizations: [],
  consultations: [],
  consultation_reviews: [],
  notifications: [],
};

function resetDb() {
  db.user_profiles = [
    { id: USER_ID, role: "user", status: "active", nickname: "学生 A" },
  ];
  db.organizations = [
    {
      id: ORG_ID,
      name: "艺见美术馆",
      owner_user_id: OWNER_ID,
      status: "active",
      rating: 0,
      review_count: 0,
    },
  ];
  db.consultations = [
    {
      id: CLOSED_CONSULTATION_ID,
      user_id: USER_ID,
      assigned_to_org_id: ORG_ID,
      status: "closed",
      target_name: "RCA",
      metadata: {},
    },
    {
      id: ACTIVE_CONSULTATION_ID,
      user_id: USER_ID,
      assigned_to_org_id: ORG_ID,
      status: "active",
      target_name: "UAL",
      metadata: {},
    },
    {
      id: OTHER_CONSULTATION_ID,
      user_id: "other-user",
      assigned_to_org_id: ORG_ID,
      status: "closed",
      metadata: {},
    },
  ];
  db.consultation_reviews = [];
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
    this.inserted = row;
    const rows = Array.isArray(row) ? row : [row];
    rows.forEach((item, index) => {
      db[this.table].push({
        id:
          typeof item.id === "string"
            ? item.id
            : `10000000-0000-4000-8000-00000000009${index}`,
        created_at: "2026-06-14T12:00:00.000Z",
        updated_at: "2026-06-14T12:00:00.000Z",
        ...item,
      });
    });
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
      const row = db[this.table][db[this.table].length - 1] ?? null;
      return { data: row, error: null };
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

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    const rows = this.findRows();
    return Promise.resolve({ data: rows, count: rows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private findRows() {
    return (db[this.table] ?? []).filter((row) => this.matches(row));
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value }) => row[field] === value);
  }
}

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const h = req.headers.get("authorization");
    if (h === "Bearer valid-token") return { id: USER_ID } as { id: string };
    return null;
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function req(path: string, method = "GET", body?: Row) {
  return new NextRequest(`http://localhost${path}`, {
    method,
    headers: { authorization: "Bearer valid-token" },
    body: body ? JSON.stringify(body) : undefined,
  });
}

function anonReq(path: string) {
  return new NextRequest(`http://localhost${path}`);
}

function ctx(id: string) {
  return { params: Promise.resolve({ id }) } satisfies Ctx;
}

describe("consultation organization reviews", () => {
  beforeEach(resetDb);

  it("未登录返回 401", async () => {
    const res = await getConsultationReview(
      anonReq(`/api/v1/me/consultations/${CLOSED_CONSULTATION_ID}/review`),
      ctx(CLOSED_CONSULTATION_ID)
    );
    expect(res.status).toBe(401);
  });

  it("未结束的咨询不能评价", async () => {
    const res = await postConsultationReview(
      req(`/api/v1/me/consultations/${ACTIVE_CONSULTATION_ID}/review`, "POST", {
        rating: 5,
      }),
      ctx(ACTIVE_CONSULTATION_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(409);
    expect(body.error).toBe("咨询结束后才可以评价机构");
  });

  it("咨询用户可以评价机构并回写机构评分", async () => {
    const res = await postConsultationReview(
      req(`/api/v1/me/consultations/${CLOSED_CONSULTATION_ID}/review`, "POST", {
        rating: 5,
        body: "回复很及时",
      }),
      ctx(CLOSED_CONSULTATION_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.success).toBe(true);
    expect(body.data.organization_id).toBe(ORG_ID);
    expect(body.organization.rating).toBe(5);
    expect(body.organization.review_count).toBe(1);
    expect(db.organizations[0].rating).toBe(5);
    expect(db.organizations[0].review_count).toBe(1);
    expect(db.notifications[0].type).toBe("consultation_review");
  });

  it("同一咨询不能重复评价", async () => {
    db.consultation_reviews.push({
      id: "10000000-0000-4000-8000-000000000099",
      consultation_id: CLOSED_CONSULTATION_ID,
      user_id: USER_ID,
      organization_id: ORG_ID,
      rating: 4,
    });
    const res = await postConsultationReview(
      req(`/api/v1/me/consultations/${CLOSED_CONSULTATION_ID}/review`, "POST", {
        rating: 5,
      }),
      ctx(CLOSED_CONSULTATION_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(409);
    expect(body.error).toBe("该咨询已评价");
  });

  it("GET 返回当前用户已有评价", async () => {
    db.consultation_reviews.push({
      id: "10000000-0000-4000-8000-000000000099",
      consultation_id: CLOSED_CONSULTATION_ID,
      user_id: USER_ID,
      organization_id: ORG_ID,
      rating: 4,
      body: "整体不错",
    });
    const res = await getConsultationReview(
      req(`/api/v1/me/consultations/${CLOSED_CONSULTATION_ID}/review`),
      ctx(CLOSED_CONSULTATION_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.rating).toBe(4);
    expect(body.organization_id).toBe(ORG_ID);
  });
});
