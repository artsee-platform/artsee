-- Public organization visibility policy:
-- - Official associations / official partners / school official records are the
--   only organization records intended for public discovery.
-- - Legacy commercial study-abroad / portfolio agency records are retired from
--   public discovery and app workbench access. Historical rows remain only for
--   audit/reference links.

UPDATE organizations
SET
  metadata = jsonb_strip_nulls(
    COALESCE(metadata, '{}'::jsonb) ||
    jsonb_build_object(
      'is_official', true,
      'public_visibility', 'official',
      'organization_kind',
      CASE type
        WHEN 'official_association' THEN 'official_association'
        WHEN 'industry_association' THEN 'industry_association'
        WHEN 'academic_association' THEN 'academic_association'
        WHEN 'official_partner' THEN 'official_partner'
        WHEN 'school_official' THEN 'school_official'
        WHEN 'public_institution' THEN 'public_institution'
        ELSE NULL
      END
    )
  ),
  verification_status = CASE
    WHEN owner_user_id IS NULL AND verification_status = 'pending' THEN 'verified'
    ELSE verification_status
  END
WHERE type IN (
  'official_association',
  'industry_association',
  'academic_association',
  'official_partner',
  'school_official',
  'public_institution'
);

UPDATE organizations
SET metadata = jsonb_strip_nulls(
  COALESCE(metadata, '{}'::jsonb) ||
  jsonb_build_object(
    'public_visibility', 'hidden',
    'legacy_commercial_agency', true,
    'retired_from_workbench', true,
    'retired_reason', 'study_abroad_agency_backend_removed',
    'retired_at', COALESCE(metadata->>'retired_at', now()::text)
  )
)
WHERE type IN ('study_abroad_agency', 'portfolio_training');

CREATE INDEX IF NOT EXISTS idx_organizations_public_official_visibility
  ON organizations (status, verification_status, type)
  WHERE status = 'active';

COMMENT ON COLUMN organizations.type IS
  'Organization category. Public discovery is limited to verified official organization types such as official_association, official_partner, school_official, industry_association, academic_association, and public_institution. study_abroad_agency and portfolio_training are retired legacy commercial types, hidden from public discovery, and excluded from app workbench access.';

NOTIFY pgrst, 'reload schema';
