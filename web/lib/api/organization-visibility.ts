type Row = Record<string, unknown>;

const PUBLIC_OFFICIAL_TYPES = new Set([
  "official_association",
  "industry_association",
  "academic_association",
  "official_partner",
  "school_official",
  "public_institution",
]);

const COMMERCIAL_AGENCY_TYPES = new Set([
  "study_abroad_agency",
  "portfolio_training",
]);

const OFFICIAL_METADATA_KINDS = new Set([
  "official",
  "association",
  "official_association",
  "industry_association",
  "academic_association",
  "official_partner",
  "school_official",
  "public_institution",
]);

const VERIFIED_STATUSES = new Set(["verified", "approved", "passed"]);
const HIDDEN_VISIBILITY = new Set(["hidden", "archived", "private"]);

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

export function isRetiredCommercialAgencyType(value: unknown) {
  return COMMERCIAL_AGENCY_TYPES.has(cleanText(value).toLowerCase());
}

function boolValue(value: unknown) {
  if (typeof value === "boolean") return value;
  const text = cleanText(value).toLowerCase();
  if (["true", "1", "yes"].includes(text)) return true;
  if (["false", "0", "no"].includes(text)) return false;
  return null;
}

function objectValue(value: unknown): Row {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function officialKind(metadata: Row) {
  return cleanText(
    metadata.organization_kind ||
      metadata.org_kind ||
      metadata.kind ||
      metadata.category
  ).toLowerCase();
}

function hasVerifiedOfficialStatus(row: Row, metadata: Row) {
  const status = cleanText(row.verification_status).toLowerCase();
  return (
    VERIFIED_STATUSES.has(status) ||
    boolValue(metadata.verified_official) === true ||
    boolValue(metadata.official_verified) === true
  );
}

export function isPublicOfficialOrganization(row: Row) {
  const metadata = objectValue(row.metadata);
  const visibility = cleanText(
    metadata.public_visibility || metadata.visibility
  ).toLowerCase();
  if (HIDDEN_VISIBILITY.has(visibility)) return false;
  if (!hasVerifiedOfficialStatus(row, metadata)) return false;

  const type = cleanText(row.type).toLowerCase();
  if (isRetiredCommercialAgencyType(type)) return false;
  if (visibility === "official") return true;
  if (PUBLIC_OFFICIAL_TYPES.has(type)) return true;
  if (
    boolValue(metadata.is_official) === true ||
    boolValue(metadata.official) === true
  ) {
    return true;
  }

  const kind = officialKind(metadata);
  return kind ? OFFICIAL_METADATA_KINDS.has(kind) : false;
}
