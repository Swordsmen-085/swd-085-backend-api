-- =====================================================================
-- SWD-085: documents table (issue #10)
-- Metadata of the documentation library (REQ-003). The files themselves
-- live in external storage (#9); this table only stores how to find them.
-- Depends on db/news_events_tables.sql, which defines set_updated_at().
-- Apply that file first.
-- =====================================================================

CREATE TABLE documents (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title       text        NOT NULL,
    category    text        NOT NULL,   -- free text; valid values are checked by the API
    file_url    text        NOT NULL,   -- link to the file (exact content depends on #9)
    version     text,                   -- free label such as 'v1.2'; optional
    status      text        NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft', 'published')),
    created_by  text        NOT NULL,   -- who uploaded it (will reference users after #15)
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    -- NOT NULL still accepts empty strings, so block those too.
    CONSTRAINT documents_title_not_blank
        CHECK (btrim(title) <> ''),
    CONSTRAINT documents_category_not_blank
        CHECK (btrim(category) <> ''),
    CONSTRAINT documents_file_url_not_blank
        CHECK (btrim(file_url) <> ''),
    CONSTRAINT documents_version_not_blank
        CHECK (version IS NULL OR btrim(version) <> '')
);

-- The public library lists published documents and filters them by
-- category (REQ-003 acceptance criterion).
CREATE INDEX idx_documents_status_category
    ON documents (status, category);

-- Keep updated_at current on every UPDATE (set_updated_at() comes from
-- db/news_events_tables.sql).
CREATE TRIGGER trg_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
