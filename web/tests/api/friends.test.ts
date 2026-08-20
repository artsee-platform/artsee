import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET, POST } from "@/app/api/v1/me/friends/route";
import { ensureTencentImFriendship } from "@/lib/api/tencent-im";

type Row = Record<string, unknown>;

const db: Record<string, Row[]> = {
  user_profiles: [],
  user_friends: [],
  conversations: [],
  conversation_participants: [],
};

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) return null;
    return { id: "user-1" };
  },
}));

vi.mock("@/lib/api/tencent-im", () => ({
  TencentImConfigError: class TencentImConfigError extends Error {
    constructor(public readonly missing: string[]) {
      super(`missing ${missing.join(",")}`);
    }
  },
  buildTencentImIdentifier: (id: string) => `u_${id}`,
  ensureTencentImFriendship: vi.fn(async () => ({ status: "synced" })),
}));

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private inFilters: Array<{ field: string; values: unknown[] }> = [];
  private rangeStart = 0;
  private rangeEnd: number | null = null;
  private limitCount: number | null = null;

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

  range(start: number, end: number) {
    this.rangeStart = start;
    this.rangeEnd = end;
    return this;
  }

  limit(count: number) {
    this.limitCount = count;
    return this;
  }

  insert(payload: Row | Row[]) {
    if (this.table === "conversations") {
      const row = {
        id: `conv-${db.conversations.length + 1}`,
        ...(payload as Row),
        created_at: "2026-06-25T00:00:00.000Z",
        updated_at: "2026-06-25T00:00:00.000Z",
      };
      db.conversations.push(row);
      return {
        select: () => ({
          single: async () => ({ data: row, error: null }),
        }),
      };
    }
    const rows = Array.isArray(payload) ? payload : [payload];
    db[this.table].push(...rows);
    return Promise.resolve({ data: null, error: null });
  }

  upsert(payload: Row | Row[]) {
    const rows = Array.isArray(payload) ? payload : [payload];
    for (const row of rows) {
      const index = db[this.table].findIndex(
        (existing) =>
          existing.user_id === row.user_id &&
          existing.friend_id === row.friend_id
      );
      if (index >= 0) db[this.table][index] = { ...db[this.table][index], ...row };
      else db[this.table].push(row);
    }
    return Promise.resolve({ data: null, error: null });
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
    const ranged =
      this.rangeEnd == null
        ? rows
        : rows.slice(this.rangeStart, this.rangeEnd + 1);
    const limited = this.limitCount == null ? ranged : ranged.slice(0, this.limitCount);
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
  db.user_profiles = [
    {
      id: "user-1",
      nickname: "Artsee开发者",
      avatar_url: "https://example.com/u1.png",
      status: "active",
    },
    {
      id: "user-2",
      nickname: "林清越",
      avatar_url: "https://example.com/u2.png",
      user_role: "artist",
      status: "active",
    },
  ];
  db.user_friends = [];
  db.conversations = [];
  db.conversation_participants = [];
}

function req(method: "GET" | "POST", body?: unknown, token = "token") {
  return new NextRequest("http://localhost/api/v1/me/friends", {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      "content-type": "application/json",
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
}

describe("friends API", () => {
  beforeEach(resetDb);

  it("requires login", async () => {
    const res = await GET(req("GET", undefined, ""));
    expect(res.status).toBe(401);
  });

  it("adds a mutual friend and returns a direct conversation", async () => {
    const res = await POST(req("POST", { target_user_id: "user-2" }));
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(ensureTencentImFriendship).toHaveBeenCalledWith(
      expect.objectContaining({ fromUserId: "user-1", toUserId: "user-2" })
    );
    expect(db.user_friends).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ user_id: "user-1", friend_id: "user-2" }),
        expect.objectContaining({ user_id: "user-2", friend_id: "user-1" }),
      ])
    );
    expect(body.data.status).toBe("active");
    expect(body.data.im_identifier).toBe("u_user-2");
    expect(body.data.conversation.peer_im_identifier).toBe("u_user-2");
  });

  it("lists current user's friends", async () => {
    db.user_friends = [
      {
        user_id: "user-1",
        friend_id: "user-2",
        status: "active",
        source: "manual",
        created_at: "2026-06-25T00:00:00.000Z",
        updated_at: "2026-06-25T00:00:00.000Z",
      },
    ];

    const res = await GET(req("GET"));
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].profile.nickname).toBe("林清越");
    expect(body.data[0].im_identifier).toBe("u_user-2");
  });
});
