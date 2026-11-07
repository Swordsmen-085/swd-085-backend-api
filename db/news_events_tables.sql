-- =====================================================================
-- SWD-085: news, events and review history tables (issue #5)
-- Content flow: draft -> pending_review -> published | rejected
-- Only 'published' content is shown to the public.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NEWS
-- ---------------------------------------------------------------------
CREATE TABLE news (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title            text        NOT NULL,
    slug             text        NOT NULL UNIQUE,
    content          text        NOT NULL,
    image_url        text,                   -- optional main image
    attachment_url   text,                   -- optional single document
    attachment_name  text,                   -- visible name of the document
    created_by       text        NOT NULL,   -- who submitted it (will reference users after #15)
    status           text        NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'published', 'rejected')),
    rejection_reason text,
    reviewed_by      text,                   -- last reviewer
    reviewed_at      timestamptz,
    published_at     timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT news_published_requires_review
        CHECK (status <> 'published'
               OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL AND published_at IS NOT NULL)),
    CONSTRAINT news_rejected_requires_reason
        CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL),
    CONSTRAINT news_attachment_name_requires_url
        CHECK (attachment_name IS NULL OR attachment_url IS NOT NULL)
);

CREATE INDEX idx_news_status_published_at
    ON news (status, published_at DESC);

-- ---------------------------------------------------------------------
-- EVENTS
-- Past events are derived from ends_at; there is no "archived" column.
-- Event kind (class, operation, informal) is expressed in the title/content.
-- ---------------------------------------------------------------------
CREATE TABLE events (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title            text        NOT NULL,
    slug             text        NOT NULL UNIQUE,
    content          text        NOT NULL,
    requirements     text,                   -- free text: modules, mods, map, notes
    starts_at        timestamptz NOT NULL,   -- stored in UTC
    ends_at          timestamptz NOT NULL,   -- optional on insert: defaults to start + 2 hours
    timezone         text        NOT NULL,   -- IANA name, e.g. 'America/Bogota'
    organizer        text        NOT NULL,   -- who leads the event
    join_url         text,
    image_url        text,                   -- optional main image
    attachment_url   text,                   -- optional single document
    attachment_name  text,
    created_by       text        NOT NULL,   -- who submitted it
    status           text        NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'published', 'rejected')),
    rejection_reason text,
    reviewed_by      text,
    reviewed_at      timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT events_end_after_start
        CHECK (ends_at >= starts_at),
    CONSTRAINT events_published_requires_review
        CHECK (status <> 'published'
               OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)),
    CONSTRAINT events_rejected_requires_reason
        CHECK (status <> 'rejected' OR rejection_reason IS NOT NULL),
    CONSTRAINT events_attachment_name_requires_url
        CHECK (attachment_name IS NULL OR attachment_url IS NOT NULL)
);

CREATE INDEX idx_events_status_starts_at
    ON events (status, starts_at);

-- If the organizer does not provide an end time, assume 2 hours.
-- To change the default duration, edit the interval below.
CREATE FUNCTION set_default_event_end() RETURNS trigger AS $$
BEGIN
    IF NEW.ends_at IS NULL THEN
        NEW.ends_at := NEW.starts_at + interval '2 hours';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_events_default_end
    BEFORE INSERT OR UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION set_default_event_end();

-- ---------------------------------------------------------------------
-- REVIEW LOG: history of submissions and decisions.
-- Intended to be append-only: the API must only INSERT into it.
-- NOTE: the database does not block UPDATE/DELETE on this table (open point).
-- Each row refers to exactly one news item or one event.
-- ---------------------------------------------------------------------
CREATE TABLE review_log (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    news_id    uuid REFERENCES news (id),
    event_id   uuid REFERENCES events (id),
    action     text        NOT NULL
               CHECK (action IN ('submitted', 'approved', 'rejected')),
    actor      text        NOT NULL,   -- who performed the action
    reason     text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT review_log_exactly_one_target
        CHECK ((news_id IS NULL) <> (event_id IS NULL))
);

CREATE INDEX idx_review_log_news_id  ON review_log (news_id);
CREATE INDEX idx_review_log_event_id ON review_log (event_id);

-- ---------------------------------------------------------------------
-- Keep updated_at current on every UPDATE (a DEFAULT only applies on INSERT).
-- ---------------------------------------------------------------------
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_news_updated_at
    BEFORE UPDATE ON news
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
