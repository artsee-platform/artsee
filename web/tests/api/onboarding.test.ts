import { describe, expect, it, beforeEach, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as completeOnboarding } from "@/app/api/v1/auth/complete-onboarding/route";

type Row = Record<string, unknown>;

const userIds: Record<string, string> = {
  business: "business-user",
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  organizations: [],
  organization_members: [],
  verifications: [],
};

function resetDb() {
  db.user_profiles = [];
  db.organizations = [];
  db.organization_members = [];
  db.verifications = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private inserted: Row | null = null;
  private patch: Row | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  order() {
    return this;
  }

  async limit(count: number) {
    return { data: this.findRows().slice(0, count), error: null };
  }

  insert(row: Row) {
    this.inserted = {
      id:
        typeof row.id === "string"
          ? row.id
          : `${this.table}-${db[this.table].length + 1}`,
      created_at: "2026-06-15T12:00:00.000Z",
      updated_at: "2026-06-15T12:00:00.000Z",
      ...row,
    };
    db[this.table].push(this.inserted);
    return this;
  }

  upsert(row: Row, options?: { onConflict?: string }) {
    const conflictFields = (options?.onConflict ?? "id")
      .split(",")
      .map((field) => field.trim())
      .filter(Boolean);
    const rows = db[this.table];
    const index = rows.findIndex((item) =>
      conflictFields.every((field) => item[field] === row[field])
    );
    const next = {
      id:
        typeof row.id === "string"
          ? row.id
          : index >= 0
            ? rows[index].id
            : `${this.table}-${rows.length + 1}`,
      ...row,
    };
    if (index >= 0) {
      rows[index] = { ...rows[index], ...next };
      this.inserted = rows[index];
    } else {
      rows.push(next);
      this.inserted = next;
    }
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
    if (this.inserted) return { data: this.inserted, error: null };
    if (this.patch) {
      const rows = db[this.table];
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
    return this.filters.every(({ field, value }) => row[field] === value);
  }
}

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    const id = token ? userIds[token] : null;
    return id ? ({ id } as { id: string }) : null;
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function req(body: Row, token: keyof typeof userIds | null = "business") {
  return new NextRequest("http://localhost/api/v1/auth/complete-onboarding", {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

describe("POST /api/v1/auth/complete-onboarding", () => {
  beforeEach(resetDb);

  it("creates a pending gallery verification while completing business onboarding", async () => {
    const res = await completeOnboarding(
      req({
        userId: userIds.business,
        userType: "business",
        userRole: "gallery_exhibition",
        primaryGoal: "receive_leads",
        goals: ["receive_leads", "create_profile"],
        targetDirections: ["business_settlement", "gallery_exhibition"],
        targetMajors: ["营业执照或机构证明", "成功案例"],
        cityPreference: "上海",
        activityCities: ["上海"],
        currentStage: "pending_business_review",
        verificationIntent: "business_review",
        businessName: "艺见美术馆",
        businessCity: "上海",
        businessContact: "ops@example.com",
        businessChannel: "公众号：艺见美术馆",
        businessIntro: "专注青年艺术展览与公共教育",
        businessMaterials: ["营业执照或机构证明", "成功案例"],
        businessProofFiles: ["https://example.com/license.pdf"],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(db.user_profiles[0]).toMatchObject({
      id: userIds.business,
      user_type: "business",
      user_role: "gallery_exhibition",
      has_completed_onboarding: true,
    });
    expect(db.organizations[0]).toMatchObject({
      id: "organizations-1",
      owner_user_id: userIds.business,
      name: "艺见美术馆",
      type: "gallery_exhibition",
      status: "active",
      verification_status: "pending",
      metadata: {
        source: "onboarding",
        city: "上海",
        contact: "ops@example.com",
        channel: "公众号：艺见美术馆",
        summary: "专注青年艺术展览与公共教育",
        needs: ["receive_leads", "create_profile"],
        materials: ["营业执照或机构证明", "成功案例"],
        proof_files: ["https://example.com/license.pdf"],
      },
    });
    expect(db.organization_members[0]).toMatchObject({
      organization_id: "organizations-1",
      user_id: userIds.business,
      role: "owner",
      status: "active",
    });
    expect(db.verifications[0]).toMatchObject({
      user_id: userIds.business,
      type: "business",
      status: "pending",
      materials: {
        source: "onboarding",
        organization_id: "organizations-1",
        organization_name: "艺见美术馆",
        company_name: "艺见美术馆",
        requested_role: "gallery_exhibition",
        user_role: "gallery_exhibition",
        city: "上海",
        contact: "ops@example.com",
        channel: "公众号：艺见美术馆",
        note: "专注青年艺术展览与公共教育",
        business_needs: ["receive_leads", "create_profile"],
        business_materials: ["营业执照或机构证明", "成功案例"],
        business_proof_files: ["https://example.com/license.pdf"],
      },
    });
    expect(body.businessReview.organization.id).toBe("organizations-1");
    expect(body.businessReview.verification.id).toBe("verifications-1");
  });

  it("rejects retired commercial agency roles during onboarding", async () => {
    const res = await completeOnboarding(
      req({
        userId: userIds.business,
        userType: "business",
        userRole: "study_abroad_agency",
        businessName: "旧留学机构",
        verificationIntent: "business_review",
      })
    );
    const body = await res.json();

    expect(res.status).toBe(400);
    expect(body.success).toBe(false);
    expect(body.error).toContain("已下线");
    expect(db.user_profiles).toHaveLength(0);
    expect(db.organizations).toHaveLength(0);
    expect(db.verifications).toHaveLength(0);
  });
});
