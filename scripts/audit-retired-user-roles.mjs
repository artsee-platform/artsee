#!/usr/bin/env node
/**
 * Audit user profile rows that still carry retired commercial agency roles.
 *
 * Default mode is read-only:
 *   npm run audit:retired-user-roles
 *
 * Optional apply mode requires an explicit target:
 *   npm run audit:retired-user-roles -- --apply --target-role=other_service
 *   npm run audit:retired-user-roles -- --apply --clear-role
 *
 * Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment or
 * project-root .env.
 */
import { createClient } from '@supabase/supabase-js';
import { existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const RETIRED_ROLES = ['study_abroad_agency', 'portfolio_training'];
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
  const targetArg = argv.find((arg) => arg.startsWith('--target-role='));
  return {
    apply: argv.includes('--apply'),
    clearRole: argv.includes('--clear-role'),
    json: argv.includes('--json'),
    help: argv.includes('--help') || argv.includes('-h'),
    targetRole: targetArg ? targetArg.slice('--target-role='.length).trim() : '',
  };
}

function printHelp() {
  console.log(`Usage:
  npm run audit:retired-user-roles
  npm run audit:retired-user-roles -- --json
  npm run audit:retired-user-roles -- --apply --target-role=other_service
  npm run audit:retired-user-roles -- --apply --clear-role

Default mode is dry-run. --apply only updates user_profiles.user_role. It does
not delete users, organizations, memberships, consultations, contracts, chats,
or historical verification records.`);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function text(value, fallback = '') {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

function isRetiredRole(value) {
  return RETIRED_ROLES.includes(text(value).toLowerCase());
}

async function readAllProfiles(supabase) {
  const byId = new Map();
  for (const column of ['user_role', 'user_type', 'role']) {
    for (let offset = 0; ; offset += PAGE_SIZE) {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('id,nickname,role,status,is_verified,user_type,user_role,created_at,updated_at,last_login_at')
        .in(column, RETIRED_ROLES)
        .order('updated_at', { ascending: false, nullsFirst: false })
        .range(offset, offset + PAGE_SIZE - 1);

      if (error) throw new Error(`user_profiles ${column} query failed: ${error.message}`);
      for (const row of data ?? []) byId.set(String(row.id), row);
      if (!data || data.length < PAGE_SIZE) break;
    }
  }
  return [...byId.values()];
}

async function readMembershipsForUser(supabase, userId) {
  const { data: memberships, error } = await supabase
    .from('organization_members')
    .select('id,organization_id,role,status,created_at')
    .eq('user_id', userId);
  if (error) return { error: error.message, rows: [] };

  const orgIds = [
    ...new Set(
      (memberships ?? [])
        .map((row) => text(row.organization_id))
        .filter(Boolean),
    ),
  ];
  const organizations = new Map();
  if (orgIds.length > 0) {
    const { data: orgRows, error: orgError } = await supabase
      .from('organizations')
      .select('id,name,type,status,verification_status,metadata')
      .in('id', orgIds);
    if (orgError) return { error: orgError.message, rows: memberships ?? [] };
    for (const org of orgRows ?? []) organizations.set(String(org.id), org);
  }

  const rows = (memberships ?? []).map((membership) => {
    const organization = organizations.get(String(membership.organization_id)) ?? null;
    return {
      id: text(membership.id),
      organization_id: text(membership.organization_id),
      role: text(membership.role),
      status: text(membership.status),
      organization_name: text(organization?.name),
      organization_type: text(organization?.type),
      organization_status: text(organization?.status),
      organization_verification_status: text(organization?.verification_status),
      organization_retired_type: isRetiredRole(organization?.type),
    };
  });
  return { error: null, rows };
}

async function buildAuditRow(supabase, profile) {
  const memberships = await readMembershipsForUser(supabase, String(profile.id));
  const activeMemberships = memberships.rows.filter((row) => row.status === 'active');
  return {
    id: text(profile.id),
    nickname: text(profile.nickname, '(unnamed)'),
    role: text(profile.role),
    status: text(profile.status),
    is_verified: profile.is_verified === true,
    user_type: text(profile.user_type),
    user_role: text(profile.user_role),
    retired_fields: {
      role: isRetiredRole(profile.role),
      user_type: isRetiredRole(profile.user_type),
      user_role: isRetiredRole(profile.user_role),
    },
    created_at: text(profile.created_at),
    updated_at: text(profile.updated_at),
    last_login_at: text(profile.last_login_at),
    memberships: {
      error: memberships.error,
      total: memberships.rows.length,
      active: activeMemberships.length,
      active_current_orgs: activeMemberships.filter((row) => !row.organization_retired_type).length,
      active_retired_orgs: activeMemberships.filter((row) => row.organization_retired_type).length,
      rows: memberships.rows,
    },
  };
}

async function applyProfilePatch(supabase, profile, options) {
  const patch = {};
  if (isRetiredRole(profile.user_role)) {
    patch.user_role = options.clearRole ? null : options.targetRole;
  }
  if (isRetiredRole(profile.user_type)) {
    patch.user_type = options.clearRole ? null : 'business';
  }
  if (Object.keys(patch).length === 0) return false;

  patch.updated_at = new Date().toISOString();
  const { error } = await supabase
    .from('user_profiles')
    .update(patch)
    .eq('id', profile.id);
  if (error) throw new Error(`update failed for ${profile.id}: ${error.message}`);
  return true;
}

function summarize(rows) {
  const byUserRole = Object.fromEntries(RETIRED_ROLES.map((role) => [role, 0]));
  const byUserType = Object.fromEntries(RETIRED_ROLES.map((role) => [role, 0]));
  let profilesWithValidCurrentOrg = 0;
  for (const row of rows) {
    if (isRetiredRole(row.user_role)) byUserRole[row.user_role] = (byUserRole[row.user_role] ?? 0) + 1;
    if (isRetiredRole(row.user_type)) byUserType[row.user_type] = (byUserType[row.user_type] ?? 0) + 1;
    if (row.memberships.active_current_orgs > 0) profilesWithValidCurrentOrg += 1;
  }
  return {
    total: rows.length,
    by_user_role: byUserRole,
    by_user_type: byUserType,
    profiles_with_active_current_org_membership: profilesWithValidCurrentOrg,
    profiles_needing_user_role_update: rows.filter((row) => row.retired_fields.user_role).length,
    profiles_with_retired_user_type: rows.filter((row) => row.retired_fields.user_type).length,
  };
}

function printReport(report) {
  console.log('Retired commercial agency user profile audit');
  console.log(`Mode: ${report.mode}`);
  console.log(`Found profiles: ${report.summary.total}`);
  console.log(`Need user_role update: ${report.summary.profiles_needing_user_role_update}`);
  console.log(`Retired user_type values: ${report.summary.profiles_with_retired_user_type}`);
  console.log(`Profiles with active current org membership: ${report.summary.profiles_with_active_current_org_membership}`);
  console.log('');

  if (report.rows.length === 0) {
    console.log('No user_profiles rows with retired commercial agency roles found.');
    return;
  }

  for (const row of report.rows) {
    console.log(`- ${row.nickname}`);
    console.log(`  id: ${row.id}`);
    console.log(`  profile: role=${row.role || '-'} / user_type=${row.user_type || '-'} / user_role=${row.user_role || '-'}`);
    console.log(
      `  memberships: active_current=${row.memberships.active_current_orgs} / active_retired=${row.memberships.active_retired_orgs} / total=${row.memberships.total}`,
    );
    if (row.memberships.error) console.log(`  membership lookup warning: ${row.memberships.error}`);
  }
  console.log('');
  if (report.mode === 'dry-run') {
    console.log('Dry-run only. Re-run with --apply plus --target-role=other_service or --clear-role to update user_profiles.user_role.');
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }
  if (options.apply && options.clearRole && options.targetRole) {
    fail('Use either --clear-role or --target-role=..., not both.');
  }
  if (options.apply && !options.clearRole && !options.targetRole) {
    fail('Apply mode requires --target-role=other_service or --clear-role.');
  }
  if (options.targetRole && isRetiredRole(options.targetRole)) {
    fail('target role cannot be a retired commercial agency role.');
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

  const profiles = await readAllProfiles(supabase);
  let updated = 0;
  if (options.apply) {
    for (const profile of profiles) {
      if (await applyProfilePatch(supabase, profile, options)) updated += 1;
    }
  }

  const refreshedProfiles = options.apply ? await readAllProfiles(supabase) : profiles;
  const rows = await Promise.all(
    refreshedProfiles.map((profile) => buildAuditRow(supabase, profile)),
  );
  const report = {
    mode: options.apply ? 'apply' : 'dry-run',
    updated,
    retired_roles: RETIRED_ROLES,
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
