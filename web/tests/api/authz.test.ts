import { describe, expect, it, beforeEach, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as postEvent } from "@/app/api/v1/events/route";
import { POST as postOpportunity } from "@/app/api/v1/opportunities/route";
import { POST as postArtwork } from "@/app/api/v1/artworks/route";
import { PUT as putArtwork } from "@/app/api/v1/artworks/[id]/route";
import { POST as postArtist } from "@/app/api/v1/artists/route";
import { GET as getCreatorCenter } from "@/app/api/v1/me/creator-center/route";

type Row = Record<string, unknown>;

const db: Record<string, Row[]> = {
  user_profiles: [],
  organizations: [],
  organization_members: [],
  events: [],
  opportunities: [],
  artworks: [],
  artwork_stats: [],
  artist_profiles: [],
  notifications: [],
};

const userIds: Record<string, string> = {
  student: "student-user",
  business: "business-user",
  admin: "admin-user",
  super: "super-admin-user",
  org: "org-member-user",
  legacyBusiness: "legacy-business-user",
};

function resetDb() {
  db.user_profiles = [
    {
      id: userIds.student,
      role: "user",
      user_role: "student",
      user_type: "personal",
    },
    {
      id: userIds.business,
      role: "user",
      user_role: "gallery_exhibition",
      user_type: "business",
    },
    {
      id: userIds.admin,
      role: "admin",
      user_role: null,
      user_type: null,
    },
    {
      id: userIds.super,
      role: "super_admin",
      user_role: null,
      user_type: null,
    },
    {
      id: userIds.org,
      role: "user",
      user_role: "student",
      user_type: "personal",
    },
    {
      id: userIds.legacyBusiness,
      role: "user",
      user_role: null,
      user_type: "business",
    },
  ];
  db.organization_members = [
    {
      id: "member-1",
      user_id: userIds.org,
      organization_id: "org-1",
      role: "advisor",
      status: "active",
    },
  ];
  db.organizations = [
    {
      id: "org-1",
      type: "gallery_exhibition",
      status: "active",
    },
  ];
  db.events = [];
  db.opportunities = [];
  db.artworks = [
    {
      id: "artwork-1",
      user_id: userIds.student,
      title: "旧作品",
      status: "reviewing",
    },
  ];
  db.artwork_stats = [];
  db.artist_profiles = [];
  db.notifications = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private patch: Row | null = null;
  private inserted: Row | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  in(field: string, values: unknown[]) {
    this.filters.push({ field, value: values });
    return this;
  }

  order() {
    return this;
  }

  range() {
    return this;
  }

  limit(limit: number) {
    return {
      data: this.findRows().slice(0, limit),
      error: null,
    };
  }

  insert(row: Row) {
    this.inserted = {
      id: typeof row.id === "string" ? row.id : `${this.table}-${db[this.table].length + 1}`,
      ...row,
    };
    db[this.table].push(this.inserted);
    return this;
  }

  upsert(row: Row) {
    const onConflict = "user_id";
    const rows = db[this.table];
    const index = rows.findIndex((item) => item[onConflict] === row[onConflict]);
    const next = {
      id: typeof row.id === "string" ? row.id : `${this.table}-${rows.length + 1}`,
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
    return this.filters.every(({ field, value }) => {
      if (Array.isArray(value)) return value.includes(row[field]);
      return row[field] === value;
    });
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

function req(path: string, token: string | null, body: Row) {
  return new NextRequest(`http://localhost${path}`, {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

function putReq(path: string, token: string | null, body: Row) {
  return new NextRequest(`http://localhost${path}`, {
    method: "PUT",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

function getReq(path: string, token: string | null) {
  return new NextRequest(`http://localhost${path}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

function ctx(id: string) {
  return { params: Promise.resolve({ id }) };
}

describe("business content authz", () => {
  beforeEach(resetDb);

  it("requires login before creating events", async () => {
    const res = await postEvent(req("/api/v1/events", null, { title: "展览" }));
    expect(res.status).toBe(401);
  });

  it("blocks student users from creating business events", async () => {
    const res = await postEvent(
      req("/api/v1/events", "student", { title: "展览" })
    );
    expect(res.status).toBe(403);
  });

  it("keeps business-created events in review even when published is requested", async () => {
    const res = await postEvent(
      req("/api/v1/events", "business", {
        title: "青年艺术家联展",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.created_by).toBe(userIds.business);
  });

  it("allows admins to publish events directly", async () => {
    const res = await postEvent(
      req("/api/v1/events", "admin", {
        title: "官方活动",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.data.status).toBe("published");
  });

  it("allows super admins to publish events directly", async () => {
    const res = await postEvent(
      req("/api/v1/events", "super", {
        title: "超级管理员活动",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.data.status).toBe("published");
  });

  it("allows active organization members to submit opportunities for review", async () => {
    const res = await postOpportunity(
      req("/api/v1/opportunities", "org", {
        title: "品牌联名",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.created_by).toBe(userIds.org);
  });

  it("blocks business-type-only profiles without a current institution role or org membership", async () => {
    const res = await postOpportunity(
      req("/api/v1/opportunities", "legacyBusiness", {
        title: "旧机构服务",
        status: "published",
      })
    );

    expect(res.status).toBe(403);
  });

  it("blocks retired study-abroad agency members from business publishing", async () => {
    db.organizations[0].type = "study_abroad_agency";

    const res = await postOpportunity(
      req("/api/v1/opportunities", "org", {
        title: "旧留学服务",
        status: "published",
      })
    );
    expect(res.status).toBe(403);
  });

  it("keeps student-created artworks in review when published is requested", async () => {
    const res = await postArtwork(
      req("/api/v1/artworks", "student", {
        title: "作品展示",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.data.status).toBe("reviewing");
    expect(db.artwork_stats[0].artwork_id).toBe(body.data.id);
  });

  it("upgrades users to creator after their third effective content item", async () => {
    db.user_profiles[0].content_count = 2;
    db.user_profiles[0].creator_score = 20;
    db.user_profiles[0].creator_level = "none";

    const res = await postArtwork(
      req("/api/v1/artworks", "student", {
        title: "第三条作品",
        status: "published",
      })
    );
    expect(res.status).toBe(201);
    expect(db.user_profiles[0].content_count).toBe(3);
    expect(db.user_profiles[0].creator_score).toBe(30);
    expect(db.user_profiles[0].creator_level).toBe("creator");
    expect(db.notifications.at(-1)?.type).toBe("creator_level");
    expect(db.notifications.at(-1)?.user_id).toBe(userIds.student);
  });

  it("returns creator center progress for the signed-in user", async () => {
    db.user_profiles[0].content_count = 4;
    db.user_profiles[0].creator_score = 40;
    db.user_profiles[0].creator_level = "creator";

    const res = await getCreatorCenter(getReq("/api/v1/me/creator-center", "student"));
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.creator_level).toBe("creator");
    expect(body.data.next_level.creator_level).toBe("active_creator");
    expect(body.data.next_level.remaining_content_count).toBe(6);
    expect(body.data.next_level.remaining_creator_score).toBe(60);
  });

  it("blocks banned users in unified authz guarded routes", async () => {
    db.user_profiles[0].status = "banned";
    const res = await postArtwork(
      req("/api/v1/artworks", "student", {
        title: "封禁后作品",
      })
    );
    expect(res.status).toBe(403);
  });

  it("keeps artist profile submissions in review when published is requested", async () => {
    const res = await postArtist(
      req("/api/v1/artists", "student", {
        display_name: "新锐艺术家",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.user_id).toBe(userIds.student);
  });

  it("allows admins to publish artist profiles directly", async () => {
    const res = await postArtist(
      req("/api/v1/artists", "admin", {
        display_name: "官方艺术家",
        status: "published",
      })
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.status).toBe("published");
  });

  it("does not let artwork owners publish by editing status", async () => {
    const res = await putArtwork(
      putReq("/api/v1/artworks/artwork-1", "student", {
        title: "更新作品",
        status: "published",
      }),
      ctx("artwork-1")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.title).toBe("更新作品");
  });
});
