import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import {
  GET as getContracts,
  POST as createContract,
} from "@/app/api/v1/me/contracts/route";
import { GET as getWorkbenchContracts } from "@/app/api/v1/me/workbench/contracts/route";
import { PATCH as patchWorkbenchContract } from "@/app/api/v1/me/workbench/contracts/[id]/route";

type Row = Record<string, unknown>;

const USER_ID = "10000000-0000-4000-8000-000000000001";
const OWNER_ID = "10000000-0000-4000-8000-000000000002";
const ADVISOR_ID = "10000000-0000-4000-8000-000000000003";
const ORG_ID = "10000000-0000-4000-8000-000000000010";
const OTHER_ORG_ID = "10000000-0000-4000-8000-000000000011";
const CONSULTATION_ID = "10000000-0000-4000-8000-000000000020";
const OTHER_CONSULTATION_ID = "10000000-0000-4000-8000-000000000021";

const tokenUsers: Record<string, string> = {
  student: USER_ID,
  owner: OWNER_ID,
  advisor: ADVISOR_ID,
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  organizations: [],
  organization_members: [],
  consultations: [],
  contracts: [],
  notifications: [],
};

function resetDb() {
  db.user_profiles = [
    { id: USER_ID, role: "user", status: "active", nickname: "学生 A" },
    { id: OWNER_ID, role: "user", status: "active", nickname: "机构负责人" },
    { id: ADVISOR_ID, role: "user", status: "active", nickname: "顾问老师" },
  ];
  db.organizations = [
    {
      id: ORG_ID,
      name: "艺见美术馆",
      type: "gallery_exhibition",
      status: "active",
      city: "上海",
      province: "上海",
      metadata: { logo_url: "https://example.com/logo.png" },
      contract_count: 0,
    },
    {
      id: OTHER_ORG_ID,
      name: "另一个美术馆",
      type: "official_association",
      status: "active",
      city: "北京",
      metadata: {},
      contract_count: 0,
    },
  ];
  db.organization_members = [
    {
      id: "10000000-0000-4000-8000-000000000030",
      organization_id: ORG_ID,
      user_id: OWNER_ID,
      role: "owner",
      status: "active",
    },
    {
      id: "10000000-0000-4000-8000-000000000031",
      organization_id: ORG_ID,
      user_id: ADVISOR_ID,
      role: "advisor",
      status: "active",
    },
  ];
  db.consultations = [
    {
      id: CONSULTATION_ID,
      user_id: USER_ID,
      assigned_to_org_id: ORG_ID,
      target_type: "school",
      target_name: "RCA",
      topic: "作品集",
      status: "active",
      metadata: {},
      created_at: "2026-06-14T10:00:00.000Z",
    },
    {
      id: OTHER_CONSULTATION_ID,
      user_id: USER_ID,
      assigned_to_org_id: OTHER_ORG_ID,
      target_name: "UAL",
      status: "active",
      metadata: {},
    },
  ];
  db.contracts = [
    {
      id: "10000000-0000-4000-8000-000000000040",
      user_id: USER_ID,
      organization_id: ORG_ID,
      consultation_id: CONSULTATION_ID,
      file_url: "https://example.com/old.pdf",
      signed_at: "2026-06-10T00:00:00.000Z",
      status: "confirmed",
      notes: "已确认",
      created_at: "2026-06-14T11:00:00.000Z",
    },
  ];
  db.notifications = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown; op: "eq" | "in" }> = [];
  private patch: Row | null = null;
  private inserted: Row | Row[] | null = null;
  private rangeStart = 0;
  private rangeEnd: number | null = null;

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

  order() {
    return this;
  }

  range(start: number, end: number) {
    this.rangeStart = start;
    this.rangeEnd = end;
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
      return { data: row ? this.withRelations(row) : null, error: null };
    }

    if (this.patch) {
      this.applyPatch();
    }
    const row = this.findRows()[0] ?? null;
    return { data: row ? this.withRelations(row) : null, error: row ? null : { message: "not found" } };
  }

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    if (this.patch) {
      this.applyPatch();
    }
    const allRows = this.findRows().map((row) => this.withRelations(row));
    const rows =
      this.rangeEnd == null
        ? allRows
        : allRows.slice(this.rangeStart, this.rangeEnd + 1);
    return Promise.resolve({ data: rows, count: allRows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private applyPatch() {
    if (!this.patch) return;
    db[this.table] = db[this.table].map((row) =>
      this.matches(row) ? { ...row, ...this.patch } : row
    );
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

  private withRelations(row: Row) {
    if (this.table !== "contracts") return row;
    return {
      ...row,
      organization:
        db.organizations.find((org) => org.id === row.organization_id) ?? null,
      consultation:
        db.consultations.find((consultation) => consultation.id === row.consultation_id) ??
        null,
    };
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

function req(path: string, token?: keyof typeof tokenUsers, method = "GET", body?: Row) {
  return new NextRequest(`http://localhost${path}`, {
    method,
    headers: token ? { authorization: `Bearer ${token}` } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
}

function ctx(id: string) {
  return { params: Promise.resolve({ id }) };
}

describe("contracts API", () => {
  beforeEach(resetDb);

  it("用户合同列表需要登录", async () => {
    const res = await getContracts(req("/api/v1/me/contracts"));
    expect(res.status).toBe(401);
  });

  it("用户可以查看自己的合同存档", async () => {
    const res = await getContracts(req("/api/v1/me/contracts", "student"));
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].organization.name).toBe("艺见美术馆");
    expect(body.data[0].organization.avatar_url).toBe("https://example.com/logo.png");
  });

  it("用户可以创建合同存档并刷新机构合同数", async () => {
    const res = await createContract(
      req("/api/v1/me/contracts", "student", "POST", {
        organization_id: ORG_ID,
        consultation_id: CONSULTATION_ID,
        file_url: "https://example.com/new.pdf",
        signed_at: "2026-06-14T12:00:00.000Z",
        notes: "线下签约",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.success).toBe(true);
    expect(body.data.organization_id).toBe(ORG_ID);
    expect(db.contracts).toHaveLength(2);
    expect(db.organizations.find((org) => org.id === ORG_ID)?.contract_count).toBe(2);
    expect(db.notifications).toHaveLength(1);
    expect(db.notifications.map((item) => item.user_id).sort()).toEqual([
      OWNER_ID,
    ]);
    expect(db.notifications[0]).toMatchObject({
      title: "有新的合同存档待确认",
      type: "contract",
      read_status: "unread",
      metadata: {
        organization_id: ORG_ID,
        consultation_id: CONSULTATION_ID,
      },
    });
  });

  it("用户不能直接创建已确认合同", async () => {
    const res = await createContract(
      req("/api/v1/me/contracts", "student", "POST", {
        organization_id: ORG_ID,
        status: "confirmed",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.error).toBe("用户上传合同只能创建待确认存档");
  });

  it("不允许把咨询关联到不匹配的机构", async () => {
    const res = await createContract(
      req("/api/v1/me/contracts", "student", "POST", {
        organization_id: ORG_ID,
        consultation_id: OTHER_CONSULTATION_ID,
      })
    );
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.error).toBe("咨询不属于该机构");
  });

  it("机构 owner 可以在工作台查看合同和用户资料", async () => {
    const res = await getWorkbenchContracts(
      req("/api/v1/me/workbench/contracts", "owner")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].user_profile.nickname).toBe("学生 A");
  });

  it("旧留学机构不再进入机构工作台合同列表", async () => {
    const organization = db.organizations.find((row) => row.id === ORG_ID);
    if (organization) organization.type = "study_abroad_agency";

    const res = await getWorkbenchContracts(
      req("/api/v1/me/workbench/contracts", "owner")
    );
    const body = await res.json();
    expect(res.status).toBe(403);
    expect(body.error).toBe("仅机构所有者或管理员可查看合同存档");
  });

  it("普通顾问不能查看全机构合同列表", async () => {
    const res = await getWorkbenchContracts(
      req("/api/v1/me/workbench/contracts", "advisor")
    );
    const body = await res.json();
    expect(res.status).toBe(403);
    expect(body.error).toBe("仅机构所有者或管理员可查看合同存档");
  });

  it("机构 owner 可以更新合同状态并通知用户", async () => {
    const contractId = "10000000-0000-4000-8000-000000000040";
    const res = await patchWorkbenchContract(
      req(`/api/v1/me/workbench/contracts/${contractId}`, "owner", "PATCH", {
        status: "disputed",
        notes: "合同金额待核对",
      }),
      ctx(contractId)
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.status).toBe("disputed");
    expect(body.data.notes).toBe("合同金额待核对");
    expect(db.contracts[0].status).toBe("disputed");
    expect(db.notifications[0]).toMatchObject({
      user_id: USER_ID,
      title: "合同存档状态已更新",
      type: "contract",
      read_status: "unread",
      metadata: {
        contract_id: contractId,
        organization_id: ORG_ID,
        status: "disputed",
      },
    });
  });

  it("普通顾问不能更新合同状态", async () => {
    const contractId = "10000000-0000-4000-8000-000000000040";
    const res = await patchWorkbenchContract(
      req(`/api/v1/me/workbench/contracts/${contractId}`, "advisor", "PATCH", {
        status: "confirmed",
      }),
      ctx(contractId)
    );
    const body = await res.json();
    expect(res.status).toBe(403);
    expect(body.error).toBe("无权更新该合同");
  });
});
