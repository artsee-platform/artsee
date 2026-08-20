import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocked = vi.hoisted(() => ({
  linkedUserId: null as string | null,
  rpcResult: { data: null as unknown, error: null as { message: string } | null },
  deleteCalls: [] as string[],
  createdUser: {
    id: "new-user",
    phone: "+8613800138000",
    email: "phone.hash@auth.artsee.internal",
  },
}));

vi.mock("@supabase/supabase-js", () => ({
  createClient: () => ({
    auth: {
      verifyOtp: async () => ({
        data: {
          user: { id: mocked.linkedUserId || mocked.createdUser.id },
          session: {
            access_token: "access-token",
            refresh_token: "refresh-token",
            expires_in: 3600,
            expires_at: 123456,
            token_type: "bearer",
          },
        },
        error: null,
      }),
    },
  }),
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => {
      if (table !== "auth_provider_links") throw new Error(`Unexpected table: ${table}`);
      return {
        select: () => ({
          eq: () => ({
            eq: () => ({
              maybeSingle: async () => ({
                data: mocked.linkedUserId ? { user_id: mocked.linkedUserId } : null,
                error: null,
              }),
            }),
          }),
        }),
      };
    },
    rpc: async () => mocked.rpcResult,
    auth: {
      admin: {
        createUser: async () => ({ data: { user: mocked.createdUser }, error: null }),
        getUserById: async (id: string) => ({
          data: {
            user: {
              ...mocked.createdUser,
              id,
            },
          },
          error: null,
        }),
        listUsers: async () => ({ data: { users: [] }, error: null }),
        updateUserById: async () => ({ data: { user: mocked.createdUser }, error: null }),
        deleteUser: async (id: string) => {
          mocked.deleteCalls.push(id);
          return { data: null, error: null };
        },
        generateLink: async () => ({
          data: { properties: { hashed_token: "hashed-magiclink-token" } },
          error: null,
        }),
      },
    },
  }),
}));

import {
  issuePhoneAuthSession,
  PhoneAuthSessionError,
} from "@/lib/api/phone-auth-session";

const phone = {
  e164: "+8613800138000",
  countryCode: "+86",
  nationalNumber: "13800138000",
};

describe("phone auth session", () => {
  beforeEach(() => {
    mocked.linkedUserId = null;
    mocked.rpcResult = { data: null, error: null };
    mocked.deleteCalls = [];
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "anon-key");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("returns a standard Supabase session for an atomically linked account", async () => {
    mocked.linkedUserId = "existing-user";
    mocked.rpcResult = {
      data: { id: "existing-user", role: "member", phone: "13800138000" },
      error: null,
    };

    await expect(issuePhoneAuthSession(phone)).resolves.toMatchObject({
      isNewUser: false,
      user: { id: "existing-user", role: "member" },
      session: {
        access_token: "access-token",
        refresh_token: "refresh-token",
      },
    });
    expect(mocked.deleteCalls).toEqual([]);
  });

  it("deletes a newly-created Auth user when the atomic database link fails", async () => {
    mocked.rpcResult = {
      data: null,
      error: { message: "database write failed" },
    };

    await expect(issuePhoneAuthSession(phone)).rejects.toBeInstanceOf(
      PhoneAuthSessionError
    );
    expect(mocked.deleteCalls).toEqual(["new-user"]);
  });
});
