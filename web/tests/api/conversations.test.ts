import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as postConversation } from "@/app/api/v1/conversations/route";
import { POST as postMessage } from "@/app/api/v1/conversations/[id]/messages/route";
import { auditContent } from "@/lib/api/content-safety";

type Row = Record<string, unknown>;

const ORG_ID = "50000000-0000-4000-8000-000000000001";
const STUDENT_ID = "student-user";
const OWNER_ID = "org-owner";
const ADVISOR_ID = "org-advisor";

const db: Record<string, Row[]> = {
  organizations: [],
  organization_members: [],
  user_profiles: [],
  conversations: [],
  conversation_participants: [],
  messages: [],
};

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) return null;
    return { id: STUDENT_ID };
  },
}));

vi.mock("@/lib/api/content-safety", () => ({
  collectAuditText: (...values: unknown[]) =>
    values.filter((value) => typeof value === "string" && value).join("\n"),
  auditContent: vi.fn(async () => ({
    provider: "tencent_cloud",
    suggestion: "pass",
    audit_status: "approved",
    items: [],
  })),
}));

vi.mock("@/lib/api/content-safety-http", () => ({
  contentSafetyErrorResponse: () => null,
  rejectedAuditResponse: (audit: { audit_status: string }) =>
    audit.audit_status === "approved"
      ? null
      : Response.json(
          { success: false, error: "消息需要进一步审核" },
          { status: 422 }
        ),
}));

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private inFilters: Array<{ field: string; values: unknown[] }> = [];
  private limitCount: number | null = null;
  private rangeStart = 0;
  private rangeEnd: number | null = null;
  private updatePayload: Row | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  in(field: string, values: unknown[]) {
    this.inFilters.push({ field, values });
    return this;
  }

  order() {
    return this;
  }

  limit(count: number) {
    this.limitCount = count;
    return this;
  }

  range(start: number, end: number) {
    this.rangeStart = start;
    this.rangeEnd = end;
    return this;
  }

  update(payload: Row) {
    this.updatePayload = payload;
    return this;
  }

  insert(payload: Row | Row[]) {
    const rows = (Array.isArray(payload) ? payload : [payload]).map((row) => {
      if (this.table === "conversations") {
        return {
          id: `conv-${db.conversations.length + 1}`,
          created_at: "2026-06-26T10:00:00.000Z",
          updated_at: "2026-06-26T10:00:00.000Z",
          ...row,
        };
      }
      if (this.table === "messages") {
        return {
          id: `msg-${db.messages.length + 1}`,
          created_at: "2026-06-26T10:00:00.000Z",
          ...row,
        };
      }
      return row;
    });
    db[this.table].push(...rows);
    return {
      select: () => ({
        single: async () => ({ data: rows[0], error: null }),
      }),
      then: <TResult1 = unknown, TResult2 = never>(
        onfulfilled?:
          | ((value: { data: null; error: null }) => TResult1 | PromiseLike<TResult1>)
          | null,
        onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
      ) => Promise.resolve({ data: null, error: null }).then(onfulfilled, onrejected),
    };
  }

  async maybeSingle() {
    return { data: this.findRows()[0] ?? null, error: null };
  }

  async single() {
    return { data: this.findRows()[0] ?? null, error: null };
  }

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    if (this.updatePayload) {
      for (const row of this.findRows()) {
        Object.assign(row, this.updatePayload);
      }
      return Promise.resolve({ data: [] as Row[], count: 0, error: null }).then(
        onfulfilled,
        onrejected
      );
    }

    const rows = this.findRows();
    const ranged =
      this.rangeEnd == null ? rows : rows.slice(this.rangeStart, this.rangeEnd + 1);
    const limited =
      this.limitCount == null ? ranged : ranged.slice(0, this.limitCount);
    return Promise.resolve({ data: limited, count: rows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private findRows() {
    return (db[this.table] ?? []).filter(
      (row) =>
        this.filters.every(({ field, value }) => row[field] === value) &&
        this.inFilters.every(({ field, values }) => values.includes(row[field]))
    );
  }
}

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function resetDb() {
  vi.clearAllMocks();
  db.organizations = [
    {
      id: ORG_ID,
      owner_user_id: OWNER_ID,
      name: "艺见美术馆",
      type: "gallery_exhibition",
      status: "active",
      subscription_status: "active",
      subscription_expires_at: "2099-01-01T00:00:00.000Z",
      metadata: { avatar_url: "https://cdn.example.com/org.png" },
    },
  ];
  db.organization_members = [
    { organization_id: ORG_ID, user_id: OWNER_ID, role: "owner", status: "active" },
    { organization_id: ORG_ID, user_id: ADVISOR_ID, role: "advisor", status: "active" },
    { organization_id: ORG_ID, user_id: "disabled-member", role: "advisor", status: "disabled" },
  ];
  db.user_profiles = [
    { id: STUDENT_ID, nickname: "学生", avatar_url: null, user_role: "student" },
    { id: OWNER_ID, nickname: "机构负责人", avatar_url: null, user_role: "advisor" },
    { id: ADVISOR_ID, nickname: "顾问", avatar_url: null, user_role: "advisor" },
  ];
  db.conversations = [];
  db.conversation_participants = [];
  db.messages = [];
}

function req(url: string, body: unknown, token = "token") {
  return new NextRequest(`http://localhost${url}`, {
    method: "POST",
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

describe("conversations API", () => {
  beforeEach(resetDb);

  it("creates a student-organization group conversation", async () => {
    const res = await postConversation(
      req("/api/v1/conversations", {
        organization_id: ORG_ID,
        metadata: { source: "organization_detail_message" },
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(db.conversations[0]).toMatchObject({
      type: "organization",
      title: "艺见美术馆",
    });
    expect(db.conversations[0].metadata).toMatchObject({
      group_kind: "student_organization",
      organization_id: ORG_ID,
      student_user_id: STUDENT_ID,
      transport_provider: "supabase_realtime",
    });
    expect(db.conversation_participants).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ user_id: STUDENT_ID, role: "owner" }),
        expect.objectContaining({ user_id: OWNER_ID, role: "admin" }),
        expect.objectContaining({ user_id: ADVISOR_ID, role: "member" }),
      ])
    );
    expect(
      db.conversation_participants.some((row) => row.user_id === "disabled-member")
    ).toBe(false);
    expect(body.data.realtime_topic).toBe("conversation:conv-1:messages");
    expect(body.data.participant_profiles).toHaveLength(3);
  });

  it("reuses an existing organization conversation and backfills members", async () => {
    db.conversations = [
      {
        id: "conv-existing",
        type: "organization",
        title: "艺见美术馆",
        created_by: STUDENT_ID,
        metadata: { organization_id: ORG_ID, student_user_id: STUDENT_ID },
      },
    ];
    db.conversation_participants = [
      { conversation_id: "conv-existing", user_id: STUDENT_ID, role: "owner" },
      { conversation_id: "conv-existing", user_id: OWNER_ID, role: "admin" },
    ];

    const res = await postConversation(
      req("/api/v1/conversations", { organization_id: ORG_ID })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data.id).toBe("conv-existing");
    expect(db.conversations).toHaveLength(1);
    expect(db.conversation_participants).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          conversation_id: "conv-existing",
          user_id: ADVISOR_ID,
          role: "member",
        }),
      ])
    );
  });

  it("creates a realtime group conversation without an external transport", async () => {
    const res = await postConversation(
      req("/api/v1/conversations", {
        type: "group",
        title: "作品集讨论组",
        participant_ids: [OWNER_ID, ADVISOR_ID],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(201);
    expect(body.data.peer_user_id).toBeNull();
    expect(body.data.realtime_topic).toBe("conversation:conv-1:messages");
    expect(body.data.metadata).toMatchObject({
      transport_provider: "supabase_realtime",
    });
  });

  it("persists image attachment messages by URL", async () => {
    db.conversations = [
      {
        id: "conv-1",
        type: "direct",
        created_by: STUDENT_ID,
        metadata: {},
      },
    ];
    db.conversation_participants = [
      { conversation_id: "conv-1", user_id: STUDENT_ID, role: "owner" },
      { conversation_id: "conv-1", user_id: OWNER_ID, role: "member" },
    ];

    const res = await postMessage(
      req("/api/v1/conversations/conv-1/messages", {
        message_type: "image",
        attachment_url: "https://cdn.example.com/messages/a.jpg",
        attachment_name: "a.jpg",
        content_type: "image/jpeg",
      }),
      { params: Promise.resolve({ id: "conv-1" }) }
    );
    const body = await res.json();

    expect(res.status).toBe(201);
    expect(body.data.body).toBe("[图片]");
    expect(body.data.message_type).toBe("image");
    expect(body.data.metadata).toMatchObject({
      attachment_url: "https://cdn.example.com/messages/a.jpg",
      attachment_name: "a.jpg",
      provider: "tencent_cos",
      realtime_status: "persisted",
      transport_provider: "supabase_realtime",
      content_audit: { audit_status: "approved" },
    });
  });

  it("rejects file attachment messages without a URL", async () => {
    db.conversation_participants = [
      { conversation_id: "conv-1", user_id: STUDENT_ID, role: "owner" },
    ];

    const res = await postMessage(
      req("/api/v1/conversations/conv-1/messages", {
        message_type: "file",
        attachment_name: "portfolio.pdf",
      }),
      { params: Promise.resolve({ id: "conv-1" }) }
    );
    const body = await res.json();

    expect(res.status).toBe(400);
    expect(body.error).toBe("附件链接无效");
  });

  it("persists one canonical message for Realtime delivery", async () => {
    db.conversations = [
      { id: "conv-1", type: "direct", created_by: STUDENT_ID, metadata: {} },
    ];
    db.conversation_participants = [
      { conversation_id: "conv-1", user_id: STUDENT_ID, role: "owner" },
      { conversation_id: "conv-1", user_id: OWNER_ID, role: "member" },
    ];

    const res = await postMessage(
      req("/api/v1/conversations/conv-1/messages", { body: "你好" }),
      { params: Promise.resolve({ id: "conv-1" }) }
    );
    const body = await res.json();

    expect(res.status).toBe(201);
    expect(db.messages).toHaveLength(1);
    expect(body.data.id).toBe(db.messages[0].id);
    expect(db.messages[0].metadata).toMatchObject({
      realtime_status: "persisted",
      transport_provider: "supabase_realtime",
    });
  });

  it("does not persist private messages awaiting content review", async () => {
    vi.mocked(auditContent).mockResolvedValueOnce({
      provider: "tencent_cloud",
      suggestion: "review",
      audit_status: "reviewing",
      items: [],
    });
    db.conversations = [
      { id: "conv-1", type: "direct", created_by: STUDENT_ID, metadata: {} },
    ];
    db.conversation_participants = [
      { conversation_id: "conv-1", user_id: STUDENT_ID, role: "owner" },
      { conversation_id: "conv-1", user_id: OWNER_ID, role: "member" },
    ];

    const res = await postMessage(
      req("/api/v1/conversations/conv-1/messages", { body: "待复审内容" }),
      { params: Promise.resolve({ id: "conv-1" }) }
    );

    expect(res.status).toBe(422);
    expect(db.messages).toHaveLength(0);
  });
});
