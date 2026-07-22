import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET as getWorkbenchConsultations } from "@/app/api/v1/me/workbench/consultations/route";
import { GET as getWorkbenchConsultation } from "@/app/api/v1/me/workbench/consultations/[id]/route";
import { POST as assignWorkbenchConsultation } from "@/app/api/v1/me/workbench/consultations/[id]/assign/route";
import { PATCH as patchWorkbenchCollaborators } from "@/app/api/v1/me/workbench/consultations/[id]/collaborators/route";
import { POST as addWorkbenchTeamMember } from "@/app/api/v1/me/workbench/team/route";
import { PATCH as patchWorkbenchTeamMember } from "@/app/api/v1/me/workbench/team/[memberId]/route";
import { GET as getWorkbenchTeamInvitations } from "@/app/api/v1/me/workbench/team-invitations/route";
import { POST as respondWorkbenchTeamInvitation } from "@/app/api/v1/me/workbench/team-invitations/[memberId]/respond/route";

type Row = Record<string, unknown>;

const ORG_ID = "10000000-0000-4000-8000-000000000001";
const OWNER_ID = "10000000-0000-4000-8000-000000000010";
const ADVISOR_A_ID = "10000000-0000-4000-8000-000000000011";
const ADVISOR_B_ID = "10000000-0000-4000-8000-000000000012";
const ADVISOR_C_ID = "10000000-0000-4000-8000-000000000013";
const OWNER_MEMBER_ID = "10000000-0000-4000-8000-000000000020";
const MEMBER_A_ID = "10000000-0000-4000-8000-000000000021";
const MEMBER_B_ID = "10000000-0000-4000-8000-000000000022";
const UNASSIGNED_ID = "10000000-0000-4000-8000-000000000030";
const ASSIGNED_A_ID = "10000000-0000-4000-8000-000000000031";
const ASSIGNED_B_ID = "10000000-0000-4000-8000-000000000032";

const tokenUsers: Record<string, string> = {
  owner: OWNER_ID,
  advisorA: ADVISOR_A_ID,
  advisorB: ADVISOR_B_ID,
  advisorC: ADVISOR_C_ID,
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  organization_members: [],
  organizations: [],
  consultations: [],
  consultation_messages: [],
  notifications: [],
};

function resetDb() {
  db.user_profiles = [
    { id: OWNER_ID, role: "user", user_role: "student", nickname: "机构负责人" },
    { id: ADVISOR_A_ID, role: "user", user_role: "student", nickname: "张老师" },
    { id: ADVISOR_B_ID, role: "user", user_role: "student", nickname: "李老师" },
    { id: ADVISOR_C_ID, role: "user", user_role: "student", nickname: "王老师" },
  ];
  db.organizations = [{ id: ORG_ID, name: "艺见美术馆", type: "gallery_exhibition" }];
  db.organization_members = [
    {
      id: OWNER_MEMBER_ID,
      organization_id: ORG_ID,
      user_id: OWNER_ID,
      role: "owner",
      status: "active",
      created_at: "2026-06-12T00:00:00.000Z",
    },
    {
      id: MEMBER_A_ID,
      organization_id: ORG_ID,
      user_id: ADVISOR_A_ID,
      role: "advisor",
      status: "active",
      metadata: { display_name: "张老师" },
      created_at: "2026-06-12T00:01:00.000Z",
    },
    {
      id: MEMBER_B_ID,
      organization_id: ORG_ID,
      user_id: ADVISOR_B_ID,
      role: "advisor",
      status: "active",
      metadata: { display_name: "李老师" },
      created_at: "2026-06-12T00:02:00.000Z",
    },
  ];
  db.consultations = [
    {
      id: UNASSIGNED_ID,
      user_id: "20000000-0000-4000-8000-000000000001",
      assigned_to_org_id: ORG_ID,
      assigned_to_user_id: null,
      assigned_to_member_id: null,
      primary_advisor_id: null,
      collaborator_ids: [],
      target_name: "RCA",
      topic: "portfolio",
      status: "new",
      metadata: {},
      updated_at: "2026-06-12T10:00:00.000Z",
    },
    {
      id: ASSIGNED_A_ID,
      user_id: "20000000-0000-4000-8000-000000000002",
      assigned_to_org_id: ORG_ID,
      assigned_to_user_id: ADVISOR_A_ID,
      assigned_to_member_id: MEMBER_A_ID,
      primary_advisor_id: ADVISOR_A_ID,
      collaborator_ids: [],
      target_name: "UAL",
      topic: "major",
      status: "pending",
      metadata: {},
      updated_at: "2026-06-12T09:00:00.000Z",
    },
    {
      id: ASSIGNED_B_ID,
      user_id: "20000000-0000-4000-8000-000000000003",
      assigned_to_org_id: ORG_ID,
      assigned_to_user_id: ADVISOR_B_ID,
      assigned_to_member_id: MEMBER_B_ID,
      primary_advisor_id: ADVISOR_B_ID,
      collaborator_ids: [],
      target_name: "Goldsmiths",
      topic: "budget",
      status: "pending",
      metadata: {},
      updated_at: "2026-06-12T08:00:00.000Z",
    },
  ];
  db.notifications = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown; op: "eq" | "in" | "is" }> = [];
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

  is(field: string, value: unknown) {
    this.filters.push({ field, value, op: "is" });
    return this;
  }

  or() {
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
    db[this.table].push(
      ...rows.map((item, index) => ({
        id:
          typeof item.id === "string"
            ? item.id
            : `${this.table}-${db[this.table].length + index + 1}`,
        ...item,
      }))
    );
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
      const rows = db[this.table];
      return { data: rows[rows.length - 1] ?? null, error: null };
    }
    if (!this.patch) {
      const row = this.findRows()[0] ?? null;
      return { data: row, error: row ? null : { message: "not found" } };
    }
    const rows = db[this.table];
    const index = rows.findIndex((row) => this.matches(row));
    if (index < 0) return { data: null, error: { message: "not found" } };
    rows[index] = { ...rows[index], ...this.patch };
    return { data: rows[index], error: null };
  }

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    const allRows = this.findRows();
    const rows =
      this.rangeEnd == null
        ? allRows
        : allRows.slice(this.rangeStart, this.rangeEnd + 1);
    return Promise.resolve({ data: rows, count: allRows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private findRows() {
    return (db[this.table] ?? []).filter((row) => this.matches(row));
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value, op }) => {
      if (op === "in") return Array.isArray(value) && value.includes(row[field]);
      if (op === "is") return row[field] === value;
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
    auth: {
      admin: {
        listUsers: async () => ({
          data: {
            users: [
              { id: OWNER_ID, email: "owner@example.com" },
              { id: ADVISOR_A_ID, email: "a@example.com" },
              { id: ADVISOR_B_ID, email: "b@example.com" },
              { id: ADVISOR_C_ID, email: "c@example.com" },
            ],
          },
          error: null,
        }),
      },
    },
  }),
}));

function req(path: string, token: keyof typeof tokenUsers, method = "GET", body?: Row) {
  return new NextRequest(`http://localhost${path}`, {
    method,
    headers: { authorization: `Bearer ${token}` },
    body: body ? JSON.stringify(body) : undefined,
  });
}

function ctx(id: string) {
  return { params: Promise.resolve({ id }) };
}

describe("workbench member assignment", () => {
  beforeEach(resetDb);

  it("lets organization owners assign an org consultation to an advisor", async () => {
    const res = await assignWorkbenchConsultation(
      req(`/api/v1/me/workbench/consultations/${UNASSIGNED_ID}/assign`, "owner", "POST", {
        member_id: MEMBER_A_ID,
      }),
      ctx(UNASSIGNED_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.assigned_to_member_id).toBe(MEMBER_A_ID);
    expect(body.data.primary_advisor_id).toBe(ADVISOR_A_ID);
    expect(body.data.assigned_to_user_id).toBe(ADVISOR_A_ID);
    expect(body.data.status).toBe("pending");
    expect(db.notifications).toHaveLength(1);
  });

  it("does not let advisors assign consultations for the whole organization", async () => {
    const res = await assignWorkbenchConsultation(
      req(`/api/v1/me/workbench/consultations/${UNASSIGNED_ID}/assign`, "advisorA", "POST", {
        member_id: MEMBER_A_ID,
      }),
      ctx(UNASSIGNED_ID)
    );
    expect(res.status).toBe(404);
  });

  it("filters the workbench list to the advisor's own assignments", async () => {
    const res = await getWorkbenchConsultations(
      req("/api/v1/me/workbench/consultations", "advisorA")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.map((row: Row) => row.id)).toEqual([ASSIGNED_A_ID]);
  });

  it("hides another advisor's consultation detail", async () => {
    const res = await getWorkbenchConsultation(
      req(`/api/v1/me/workbench/consultations/${ASSIGNED_B_ID}`, "advisorA"),
      ctx(ASSIGNED_B_ID)
    );
    expect(res.status).toBe(404);
  });

  it("lets organization owners see all organization consultations", async () => {
    const res = await getWorkbenchConsultations(
      req("/api/v1/me/workbench/consultations", "owner")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.map((row: Row) => row.id)).toEqual([
      UNASSIGNED_ID,
      ASSIGNED_A_ID,
      ASSIGNED_B_ID,
    ]);
  });

  it("旧留学机构不再进入机构工作台咨询列表", async () => {
    const organization = db.organizations.find((row) => row.id === ORG_ID);
    if (organization) organization.type = "study_abroad_agency";

    const res = await getWorkbenchConsultations(
      req("/api/v1/me/workbench/consultations", "owner")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data).toEqual([]);
  });

  it("lets organization owners add collaborators who can then open the consultation", async () => {
    const res = await patchWorkbenchCollaborators(
      req(
        `/api/v1/me/workbench/consultations/${ASSIGNED_A_ID}/collaborators`,
        "owner",
        "PATCH",
        {
          mode: "add",
          member_ids: [MEMBER_B_ID],
        }
      ),
      ctx(ASSIGNED_A_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.collaborator_ids).toEqual([
      {
        member_id: MEMBER_B_ID,
        user_id: ADVISOR_B_ID,
        name: "李老师",
        role: "advisor",
      },
    ]);
    expect(db.notifications).toHaveLength(1);

    const detail = await getWorkbenchConsultation(
      req(`/api/v1/me/workbench/consultations/${ASSIGNED_A_ID}`, "advisorB"),
      ctx(ASSIGNED_A_ID)
    );
    expect(detail.status).toBe(200);
  });

  it("does not let unrelated advisors add themselves as collaborators", async () => {
    const res = await patchWorkbenchCollaborators(
      req(
        `/api/v1/me/workbench/consultations/${ASSIGNED_A_ID}/collaborators`,
        "advisorB",
        "PATCH",
        {
          mode: "add",
          member_ids: [MEMBER_B_ID],
        }
      ),
      ctx(ASSIGNED_A_ID)
    );
    expect(res.status).toBe(404);
  });

  it("lets the primary advisor remove collaborators", async () => {
    db.consultations[1].collaborator_ids = [
      {
        member_id: MEMBER_B_ID,
        user_id: ADVISOR_B_ID,
        name: "李老师",
        role: "advisor",
      },
    ];

    const res = await patchWorkbenchCollaborators(
      req(
        `/api/v1/me/workbench/consultations/${ASSIGNED_A_ID}/collaborators`,
        "advisorA",
        "PATCH",
        {
          mode: "remove",
          member_ids: [MEMBER_B_ID],
        }
      ),
      ctx(ASSIGNED_A_ID)
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.collaborator_ids).toEqual([]);
  });

  it("lets organization owners add a registered user to the team", async () => {
    const res = await addWorkbenchTeamMember(
      req("/api/v1/me/workbench/team", "owner", "POST", {
        email: "c@example.com",
        role: "advisor",
        display_name: "王老师",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.success).toBe(true);
    expect(body.data.user_id).toBe(ADVISOR_C_ID);
    expect(body.data.role).toBe("advisor");
    expect(body.data.status).toBe("invited");
    expect(db.organization_members.some((row) => row.user_id === ADVISOR_C_ID)).toBe(true);
    expect(db.notifications.at(-1)?.user_id).toBe(ADVISOR_C_ID);
  });

  it("lets invited users list and accept team invitations", async () => {
    const invite = await addWorkbenchTeamMember(
      req("/api/v1/me/workbench/team", "owner", "POST", {
        email: "c@example.com",
        role: "advisor",
        display_name: "王老师",
      })
    );
    const invited = await invite.json();
    const memberId = invited.data.id as string;

    const list = await getWorkbenchTeamInvitations(
      req("/api/v1/me/workbench/team-invitations", "advisorC")
    );
    const listBody = await list.json();
    expect(list.status).toBe(200);
    expect(listBody.data).toHaveLength(1);
    expect(listBody.data[0].id).toBe(memberId);
    expect(listBody.data[0].organization.name).toBe("艺见美术馆");

    const accepted = await respondWorkbenchTeamInvitation(
      req(
        `/api/v1/me/workbench/team-invitations/${memberId}/respond`,
        "advisorC",
        "POST",
        { action: "accept" }
      ),
      { params: Promise.resolve({ memberId }) }
    );
    const acceptedBody = await accepted.json();
    expect(accepted.status).toBe(200);
    expect(acceptedBody.data.status).toBe("active");
    expect(
      db.organization_members.find((row) => row.id === memberId)?.status
    ).toBe("active");
    expect(db.notifications.at(-1)?.user_id).toBe(OWNER_ID);
  });

  it("does not let advisors add team members", async () => {
    const res = await addWorkbenchTeamMember(
      req("/api/v1/me/workbench/team", "advisorA", "POST", {
        email: "c@example.com",
        role: "advisor",
      })
    );
    expect(res.status).toBe(403);
  });

  it("lets organization owners update member role and status", async () => {
    const res = await patchWorkbenchTeamMember(
      req(`/api/v1/me/workbench/team/${MEMBER_A_ID}`, "owner", "PATCH", {
        role: "admin",
        status: "disabled",
        display_name: "张主管",
      }),
      { params: Promise.resolve({ memberId: MEMBER_A_ID }) }
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.role).toBe("admin");
    expect(body.data.status).toBe("disabled");
    expect((body.data.metadata as Row).display_name).toBe("张主管");
    expect(db.notifications.at(-1)?.user_id).toBe(ADVISOR_A_ID);
  });

  it("does not let owners modify the owner membership from team management", async () => {
    const res = await patchWorkbenchTeamMember(
      req(`/api/v1/me/workbench/team/${OWNER_MEMBER_ID}`, "owner", "PATCH", {
        role: "member",
      }),
      { params: Promise.resolve({ memberId: OWNER_MEMBER_ID }) }
    );
    expect(res.status).toBe(400);
  });
});
