#!/usr/bin/env node
/**
 * Audit and optionally mark retired commercial agency organizations.
 *
 * Default mode is read-only:
 *   npm run audit:retired-agencies
 *
 * Apply mode marks matching organizations as hidden/retired in metadata:
 *   npm run audit:retired-agencies -- --apply
 *
 * Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment or
 * project-root .env.
 */
import { createClient } from '@supabase/supabase-js';
import { existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const RETIRED_TYPES = ['study_abroad_agency', 'portfolio_training'];
const RETIRED_REASON = 'study_abroad_agency_backend_removed';
const PAGE_SIZE = 1000;

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = join(__dirname, '..');

function loadEnvFromRoot() {
  const envPath = join(rootDir, '.env');
  if (!existsSync(envPath)) return;
  const text = readFileSync(envPath, 'utf8');
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = value;
  }
}

function parseArgs(argv) {
  return {
    apply: argv.includes('--apply'),
    json: argv.includes('--json'),
    help: argv.includes('--help') || argv.includes('-h'),
  };
}

function printHelp() {
  console.log(`Usage:
  npm run audit:retired-agencies
  npm run audit:retired-agencies -- --json
  npm run audit:retired-agencies -- --apply

Default mode is dry-run. --apply writes metadata only; it does not delete rows,
change organization.type, or remove historical consultations/contracts.`);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function objectValue(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value;
}

function text(value, fallback = '') {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

async function readAllOrganizations(supabase) {
  const rows = [];
  for (let offset = 0; ; offset += PAGE_SIZE) {
    const { data, error } = await supabase
      .from('organizations')
      .select('id,name,type,status,verification_status,owner_user_id,metadata,created_at,updated_at')
      .in('type', RETIRED_TYPES)
      .order('created_at', { ascending: false })
      .range(offset, offset + PAGE_SIZE - 1);

    if (error) throw new Error(`organizations query failed: ${error.message}`);
    rows.push(...(data ?? []));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

async function countBy(supabase, table, field, value) {
  const { count, error } = await supabase
    .from(table)
    .select('id', { count: 'exact', head: true })
    .eq(field, value);
  if (error) return { count: null, error: error.message };
  return { count: count ?? 0, error: null };
}

async function buildAuditRow(supabase, organization) {
  const id = text(organization.id);
  const [members, consultations, contracts, serviceBookings] = await Promise.all([
    countBy(supabase, 'organization_members', 'organization_id', id),
    countBy(supabase, 'consultations', 'assigned_to_org_id', id),
    countBy(supabase, 'contracts', 'organization_id', id),
    countBy(supabase, 'service_bookings', 'assigned_to_org_id', id),
  ]);
  const metadata = objectValue(organization.metadata);
  return {
    id,
    name: text(organization.name, '(unnamed)'),
    type: text(organization.type),
    status: text(organization.status),
    verification_status: text(organization.verification_status),
    owner_user_id: text(organization.owner_user_id),
    public_visibility: text(metadata.public_visibility),
    legacy_commercial_agency: metadata.legacy_commercial_agency === true,
    retired_from_workbench: metadata.retired_from_workbench === true,
    retired_at: text(metadata.retired_at),
    counts: {
      members,
      consultations,
      contracts,
      service_bookings: serviceBookings,
    },
  };
}

async function markRetired(supabase, organization, now) {
  const metadata = objectValue(organization.metadata);
  const retiredAt = text(metadata.retired_at) || now;
  const nextMetadata = {
    ...metadata,
    public_visibility: 'hidden',
    legacy_commercial_agency: true,
    retired_from_workbench: true,
    retired_reason: RETIRED_REASON,
    retired_at: retiredAt,
  };

  const { error } = await supabase
    .from('organizations')
    .update({ metadata: nextMetadata })
    .eq('id', organization.id);
  if (error) throw new Error(`update failed for ${organization.id}: ${error.message}`);
  return nextMetadata;
}

function summarize(rows) {
  const byType = Object.fromEntries(RETIRED_TYPES.map((type) => [type, 0]));
  let alreadyRetired = 0;
  for (const row of rows) {
    byType[row.type] = (byType[row.type] ?? 0) + 1;
    if (
      row.public_visibility === 'hidden' &&
      row.legacy_commercial_agency &&
      row.retired_from_workbench
    ) {
      alreadyRetired += 1;
    }
  }
  return {
    total: rows.length,
    by_type: byType,
    already_retired: alreadyRetired,
    needs_metadata_update: rows.length - alreadyRetired,
  };
}

function printReport(report) {
  console.log('Retired commercial agency organization audit');
  console.log(`Mode: ${report.mode}`);
  console.log(`Found: ${report.summary.total}`);
  console.log(`Already marked retired: ${report.summary.already_retired}`);
  console.log(`Needs metadata update: ${report.summary.needs_metadata_update}`);
  console.log('');

  if (report.rows.length === 0) {
    console.log('No study_abroad_agency or portfolio_training organizations found.');
    return;
  }

  for (const row of report.rows) {
    console.log(`- ${row.name} (${row.type})`);
    console.log(`  id: ${row.id}`);
    console.log(
      `  status: ${row.status || '-'} / verification: ${row.verification_status || '-'} / visibility: ${row.public_visibility || '-'}`,
    );
    console.log(
      `  retired: ${row.retired_from_workbench ? 'yes' : 'no'} / members: ${formatCount(row.counts.members)} / consultations: ${formatCount(row.counts.consultations)} / contracts: ${formatCount(row.counts.contracts)} / bookings: ${formatCount(row.counts.service_bookings)}`,
    );
  }
  console.log('');
  if (report.mode === 'dry-run') {
    console.log('Dry-run only. Re-run with --apply to mark metadata as hidden/retired.');
  }
}

function formatCount(result) {
  if (!result || result.count == null) return `unknown (${result?.error ?? 'query failed'})`;
  return String(result.count);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }

  loadEnvFromRoot();
  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    fail('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.');
  }

  const supabase = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const organizations = await readAllOrganizations(supabase);
  const now = new Date().toISOString();
  if (options.apply) {
    for (const organization of organizations) {
      await markRetired(supabase, organization, now);
    }
  }

  const refreshedOrganizations = options.apply
    ? await readAllOrganizations(supabase)
    : organizations;
  const rows = await Promise.all(
    refreshedOrganizations.map((organization) => buildAuditRow(supabase, organization)),
  );
  const report = {
    mode: options.apply ? 'apply' : 'dry-run',
    retired_types: RETIRED_TYPES,
    summary: summarize(rows),
    rows,
  };

  if (options.json) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    printReport(report);
  }
}

main().catch((error) => {
  console.error(error?.message || error);
  process.exit(1);
});
