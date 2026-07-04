-- =============================================================================
-- PowerDNS 4.7+ schema migration (domains.options, domains.catalog)
-- =============================================================================

ALTER TABLE domains CONVERT TO CHARACTER SET latin1;
ALTER TABLE domains ADD COLUMN IF NOT EXISTS options VARCHAR(64000) DEFAULT NULL;
ALTER TABLE domains ADD COLUMN IF NOT EXISTS catalog VARCHAR(255) DEFAULT NULL;
ALTER TABLE domains MODIFY type VARCHAR(8) NOT NULL;
CREATE INDEX IF NOT EXISTS catalog_idx ON domains(catalog);
