-- =====================================================================
-- SWD-085 #5: automated checks for db/news_events_tables.sql
-- LOCAL USE ONLY. It creates (and first DROPS) a scratch database
-- called swd085_test; it never touches any other database.
--
-- How to run (from the repository root; connects to the default
-- "postgres" database only to create the scratch one):
--   psql -U postgres -d postgres -f db/news_events_tables_test.sql
--
-- Expected output: one line per check, all starting with PASS.
-- Any line starting with FAIL means the schema is not behaving as designed.
-- It can be run as many times as you like.
-- =====================================================================

\set ON_ERROR_STOP on
DROP DATABASE IF EXISTS swd085_test;
CREATE DATABASE swd085_test;
\connect swd085_test
\i db/news_events_tables.sql
\set ON_ERROR_STOP off

-- Show only the result lines, without table decoration.
\t on
\pset format unaligned

-- Helper: returns PASS/FAIL for a boolean condition.
CREATE FUNCTION pg_temp.check_true(label text, ok boolean) RETURNS text AS $$
    SELECT CASE WHEN ok IS TRUE THEN 'PASS  ' ELSE 'FAIL  ' END || label;
$$ LANGUAGE sql;

-- Helper: runs a statement that MUST be rejected with the given SQLSTATE
-- (23514 = check violation, 23505 = unique violation, 23502 = not null).
CREATE FUNCTION pg_temp.check_rejected(label text, stmt text, expected_state text)
RETURNS text AS $$
BEGIN
    EXECUTE stmt;
    RETURN 'FAIL  ' || label || ' (statement was accepted)';
EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = expected_state THEN
        RETURN 'PASS  ' || label;
    END IF;
    RETURN 'FAIL  ' || label || ' (unexpected error ' || SQLSTATE || ': ' || SQLERRM || ')';
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- Expected successes
-- ---------------------------------------------------------------------

-- 1. No end time -> defaults to start + 2 hours
INSERT INTO events (title, slug, content, starts_at, timezone, organizer, created_by)
VALUES ('No end time', 'no-end-time', 'Test', '2026-12-01 20:00+00', 'UTC', 'Zero', 'Zero');
SELECT pg_temp.check_true('1. end time defaults to 2 hours',
  (SELECT ends_at - starts_at = interval '2 hours' FROM events WHERE slug = 'no-end-time'));

-- 2. Explicit end time is respected
INSERT INTO events (title, slug, content, starts_at, ends_at, timezone, organizer, created_by)
VALUES ('With end', 'with-end', 'Test', '2026-12-02 20:00+00', '2026-12-02 23:00+00', 'UTC', 'Zero', 'Zero');
SELECT pg_temp.check_true('2. explicit end time is respected (3 hours)',
  (SELECT ends_at - starts_at = interval '3 hours' FROM events WHERE slug = 'with-end'));

-- 3. Event with requirements, image and one document
INSERT INTO events (title, slug, content, requirements, image_url, attachment_url, attachment_name,
                    starts_at, timezone, organizer, created_by)
VALUES ('Operation Beslan', 'operation-beslan', 'Briefing details...',
        'F/A-18C, F-16C, C-130. Caucasus map required.',
        'https://example.com/beslan.jpg', 'https://example.com/briefing.pdf', 'Briefing.pdf',
        now() + interval '5 days', 'UTC', 'Mixxy', 'Zero');
SELECT pg_temp.check_true('3. event stores requirements, image and one document',
  (SELECT requirements IS NOT NULL AND image_url IS NOT NULL AND attachment_name = 'Briefing.pdf'
     FROM events WHERE slug = 'operation-beslan'));

-- 4. Approval flow with history: submitted, then approved
UPDATE events SET status = 'pending_review' WHERE slug = 'operation-beslan';
INSERT INTO review_log (event_id, action, actor)
  SELECT id, 'submitted', 'Zero' FROM events WHERE slug = 'operation-beslan';
UPDATE events SET status = 'published', reviewed_by = 'Mixxy', reviewed_at = now()
  WHERE slug = 'operation-beslan';
INSERT INTO review_log (event_id, action, actor)
  SELECT id, 'approved', 'Mixxy' FROM events WHERE slug = 'operation-beslan';
SELECT pg_temp.check_true('4. approval flow leaves a 2-step history (submitted, approved)',
  (SELECT string_agg(action, ',' ORDER BY created_at, action DESC) = 'submitted,approved'
     FROM review_log)
  AND (SELECT status = 'published' FROM events WHERE slug = 'operation-beslan'));

-- 5. Published news with every required field
INSERT INTO news (title, slug, content, created_by, status, reviewed_by, reviewed_at, published_at)
VALUES ('First news', 'first-news', 'Body text', 'Zero', 'published', 'Mixxy', now(), now());
SELECT pg_temp.check_true('5. published news is accepted when fully reviewed',
  (SELECT count(*) = 1 FROM news WHERE slug = 'first-news' AND status = 'published'));

-- 6. updated_at moves on UPDATE (news)
INSERT INTO news (title, slug, content, created_by)
VALUES ('Updated test', 'updated-test', 'Body', 'Zero');
SELECT pg_sleep(1) AS s \gset
UPDATE news SET title = 'Updated test (edited)' WHERE slug = 'updated-test';
SELECT pg_temp.check_true('6. news.updated_at moves on UPDATE',
  (SELECT updated_at > created_at FROM news WHERE slug = 'updated-test'));

-- 7. updated_at moves on UPDATE (events)
INSERT INTO events (title, slug, content, starts_at, timezone, organizer, created_by)
VALUES ('Updated event', 'updated-event', 'Test', '2026-12-05 20:00+00', 'UTC', 'Zero', 'Zero');
SELECT pg_sleep(1) AS s \gset
UPDATE events SET title = 'Updated event (edited)' WHERE slug = 'updated-event';
SELECT pg_temp.check_true('7. events.updated_at moves on UPDATE',
  (SELECT updated_at > created_at FROM events WHERE slug = 'updated-event'));

-- 8. Upcoming events: only published events that have not ended
SELECT pg_temp.check_true('8. upcoming events = only "Operation Beslan"',
  (SELECT string_agg(title, ',') = 'Operation Beslan'
     FROM events WHERE status = 'published' AND ends_at >= now()));

-- 9. Past events (archive): only published events that already ended
INSERT INTO events (title, slug, content, starts_at, timezone, organizer, created_by,
                    status, reviewed_by, reviewed_at)
VALUES ('Past training', 'past-training', 'Test', now() - interval '10 days',
        'Europe/Madrid', 'Zero', 'Zero', 'published', 'Mixxy', now());
SELECT pg_temp.check_true('9. archive = only "Past training"',
  (SELECT string_agg(title, ',') = 'Past training'
     FROM events WHERE status = 'published' AND ends_at < now()));

-- ---------------------------------------------------------------------
-- Expected rejections (each statement MUST fail with the right error)
-- ---------------------------------------------------------------------

SELECT pg_temp.check_rejected('10. cannot publish an event without a reviewer',
  $q$INSERT INTO events (title, slug, content, starts_at, timezone, organizer, created_by, status)
     VALUES ('x', 'x-pub', 'x', now(), 'UTC', 'Zero', 'Zero', 'published')$q$, '23514');

SELECT pg_temp.check_rejected('11. cannot reject without a reason',
  $q$INSERT INTO news (title, slug, content, created_by, status)
     VALUES ('x', 'x-rej', 'x', 'Zero', 'rejected')$q$, '23514');

SELECT pg_temp.check_rejected('12. cannot publish news without published_at',
  $q$INSERT INTO news (title, slug, content, created_by, status, reviewed_by, reviewed_at)
     VALUES ('x', 'x-news', 'x', 'Zero', 'published', 'Mixxy', now())$q$, '23514');

SELECT pg_temp.check_rejected('13. cannot set a document name without a document URL',
  $q$INSERT INTO news (title, slug, content, created_by, attachment_name)
     VALUES ('x', 'x-att', 'x', 'Zero', 'Lonely name.pdf')$q$, '23514');

SELECT pg_temp.check_rejected('14. review log entry must point to a news item or an event',
  $q$INSERT INTO review_log (action, actor) VALUES ('approved', 'Mixxy')$q$, '23514');

SELECT pg_temp.check_rejected('15. invalid status is rejected',
  $q$INSERT INTO news (title, slug, content, created_by, status)
     VALUES ('x', 'x-bad', 'x', 'Zero', 'banana')$q$, '23514');

SELECT pg_temp.check_rejected('16. an event cannot end before it starts',
  $q$INSERT INTO events (title, slug, content, starts_at, ends_at, timezone, organizer, created_by)
     VALUES ('bad', 'bad-dates', 'x', now(), now() - interval '1 day', 'UTC', 'x', 'x')$q$, '23514');

SELECT pg_temp.check_rejected('17. duplicate slug is rejected',
  $q$INSERT INTO events (title, slug, content, starts_at, timezone, organizer, created_by)
     VALUES ('dup', 'operation-beslan', 'x', now(), 'UTC', 'x', 'x')$q$, '23505');
