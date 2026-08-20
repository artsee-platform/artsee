import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const migrationsDirectory = path.resolve(process.cwd(), "../supabase/migrations");
const hardeningMigrationName = readdirSync(migrationsDirectory)
  .filter((name) => name.endsWith("_harden_message_writes.sql"))
  .sort()
  .at(-1);

if (!hardeningMigrationName) {
  throw new Error("Missing harden_message_writes migration");
}

const hardeningMigration = readFileSync(
  path.join(migrationsDirectory, hardeningMigrationName),
  "utf8"
);

describe("conversation message write boundary", () => {
  it("revokes client writes and leaves service_role as the writer", () => {
    expect(hardeningMigration).toMatch(
      /REVOKE\s+INSERT,\s*UPDATE,\s*DELETE\s+ON\s+TABLE\s+public\.messages\s+FROM\s+PUBLIC,\s*anon,\s*authenticated;/i
    );
    expect(hardeningMigration).toMatch(
      /GRANT\s+SELECT,\s*INSERT,\s*UPDATE,\s*DELETE\s+ON\s+TABLE\s+public\.messages\s+TO\s+service_role;/i
    );
  });

  it("removes every RLS policy capable of authorizing a write", () => {
    expect(hardeningMigration).toMatch(
      /tablename\s*=\s*'messages'[\s\S]*cmd\s+IN\s*\(\s*'ALL',\s*'INSERT',\s*'UPDATE',\s*'DELETE'\s*\)/i
    );
    expect(hardeningMigration).toMatch(
      /DROP\s+POLICY\s+IF\s+EXISTS\s+%I\s+ON\s+public\.messages/i
    );
  });
});
