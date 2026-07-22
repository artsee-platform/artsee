import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as updateProfile } from "@/app/api/v1/auth/update-profile/route";

type Row = Record<string, unknown>;

const db: Record<string, Row[]> = {
  user_profiles: [],
};

let createClientCalls = 0;

function resetDb() {
  db.user_profiles = [
    {
      id: "user-1",
      nickname: "测试用户",
      role: "user",
      status: "active",
      user_role: "student",
      target_countries: [],
      target_majors: [],
    },
  ];
  createClientCalls = 0;
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private patch: Row | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  update(patch: Row) {
    this.patch = patch;
    return this;
  }

  async single() {
    if (this.table !== "user_profiles") {
      return { data: null, error: { message: `Unexpected table: ${this.table}` } };
    }
    const rows = db.user_profiles;
    const index = rows.findIndex((row) => this.matches(row));
    if (index < 0) return { data: null, error: { message: "not found" } };
    if (this.patch) rows[index] = { ...rows[index], ...this.patch };
    return { data: rows[index], error: null };
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value }) => row[field] === value);
  }
}

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    return token === "valid-token" ? ({ id: "user-1", email: "u@example.com" } as any) : null;
  },
}));

vi.mock("@supabase/supabase-js", () => ({
  createClient: () => {
    createClientCalls += 1;
    return {
      from: (table: string) => new QueryStub(table),
    };
  },
}));

function req(body: Row, token: string | null = "valid-token") {
  return new NextRequest("http://localhost/api/v1/auth/update-profile", {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

describe("POST /api/v1/auth/update-profile", () => {
  beforeEach(resetDb);

  it("rejects retired commercial agency user roles", async () => {
    const res = await updateProfile(
      req({
        userRole: "study_abroad_agency",
      })
    );
    const body = await res.json();

    expect(res.status).toBe(400);
    expect(body.success).toBe(false);
    expect(body.message).toContain("已下线");
    expect(db.user_profiles[0].user_role).toBe("student");
    expect(createClientCalls).toBe(0);
  });

  it("still allows current institution roles to update", async () => {
    const res = await updateProfile(
      req({
        user_role: "gallery_exhibition",
        target_majors: ["策展"],
        target_countries: ["中国"],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(db.user_profiles[0].user_role).toBe("gallery_exhibition");
  });
});
