import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const migrationDir = path.resolve(process.cwd(), "../supabase/migrations");
const migrationName = fs
  .readdirSync(migrationDir)
  .find((name) => name.endsWith("_enable_conversation_realtime.sql"));

if (!migrationName) {
  throw new Error("Missing enable_conversation_realtime migration");
}

const sql = fs.readFileSync(path.join(migrationDir, migrationName), "utf8");

describe("conversation Realtime migration", () => {
  it("publishes the conversation tables idempotently", () => {
    expect(sql).toMatch(/pg_publication_tables/i);
    expect(sql).toMatch(/pubname\s*=\s*'supabase_realtime'/i);
    expect(sql).toMatch(/'conversations'/i);
    expect(sql).toMatch(/'conversation_participants'/i);
    expect(sql).toMatch(/'messages'/i);
    expect(sql).toMatch(
      /ALTER PUBLICATION supabase_realtime ADD TABLE public\.%I/i
    );
  });

  it("grants authenticated reads and protects rows with membership RLS", () => {
    expect(sql).toMatch(
      /GRANT SELECT ON TABLE[\s\S]*public\.messages[\s\S]*TO authenticated/i
    );
    expect(sql).toMatch(
      /REVOKE INSERT, UPDATE, DELETE ON TABLE[\s\S]*public\.messages[\s\S]*FROM authenticated/i
    );
    expect(sql).toMatch(
      /GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE[\s\S]*public\.messages[\s\S]*TO service_role/i
    );
    expect(sql).toMatch(
      /CREATE POLICY "messages_select_member"[\s\S]*participant\.conversation_id = messages\.conversation_id[\s\S]*participant\.user_id = \(SELECT auth\.uid\(\)\)/i
    );
    expect(sql).toMatch(
      /CREATE POLICY "conversation_participants_select_own"[\s\S]*user_id = \(SELECT auth\.uid\(\)\)/i
    );
    expect(sql).toMatch(/REVOKE ALL ON TABLE[\s\S]*FROM anon/i);
  });
});
