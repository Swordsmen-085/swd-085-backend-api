-- =====================================================================
-- SWD-085 #10: automated checks for db/documents_table.sql
-- LOCAL USE ONLY. It creates (and first DROPS) a scratch database
-- called swd085_documents_test; it never touches any other database.
--
-- How to run (from the repository root; connects to the default
-- "postgres" database only to create the scratch one):
--   psql -U postgres -d postgres -f db/documents_table_test.sql
--
-- Expected output: one line per check, all starting with PASS.
-- Any line starting with FAIL means the schema is not behaving as designed.
-- It can be run as many times as you like.
-- =====================================================================

\set ON_ERROR_STOP on
DROP DATABASE IF EXISTS swd085_documents_test;
CREATE DATABASE swd085_documents_test;
\connect swd085_documents_test
\i db/news_events_tables.sql
\i db/documents_table.sql
\set ON_ERROR_STOP off

-- Show only the result lines, without table decoration.
\t on
\pset format unaligned

-- Helper: returns PASS/FAIL for a boolean condition.
CREATE FUNCTION pg_temp.check_true(label text, ok boolean) RETURNS text AS $$
    SELECT CASE WHEN ok IS TRUE THEN 'PASS  ' ELSE 'FAIL  ' END || label;
$$ LANGUAGE sql;

-- Helper: runs a statement that MUST be rejected with the given SQLSTATE
-- (23514 = check violation, 23502 = not null violation).
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

-- 1. Minimal document: version is optional
INSERT INTO documents (title, category, file_url, created_by)
VALUES ('Procedures Manual', 'Procedures', 'https://example.com/procedures.pdf', 'Zero');
SELECT pg_temp.check_true('1. document without a version is accepted',
  (SELECT version IS NULL FROM documents WHERE title = 'Procedures Manual'));

-- 2. Document with a version label
INSERT INTO documents (title, category, file_url, version, created_by)
VALUES ('Squadron Rules', 'Rules', 'https://example.com/rules.pdf', 'v1.2', 'Zero');
SELECT pg_temp.check_true('2. version label is stored',
  (SELECT version = 'v1.2' FROM documents WHERE title = 'Squadron Rules'));

-- 3. New documents start as drafts (not public by accident)
SELECT pg_temp.check_true('3. new documents start as draft',
  (SELECT count(*) = 2 AND bool_and(status = 'draft') FROM documents));

-- 4. updated_at moves on UPDATE (trigger reused from news_events_tables.sql)
SELECT pg_sleep(1) AS s \gset
UPDATE documents SET version = 'v1.3' WHERE title = 'Squadron Rules';
SELECT pg_temp.check_true('4. documents.updated_at moves on UPDATE',
  (SELECT updated_at > created_at FROM documents WHERE title = 'Squadron Rules'));

-- 5. Filter by category (REQ-003 acceptance criterion)
INSERT INTO documents (title, category, file_url, created_by)
VALUES ('Flight Guide', 'Procedures', 'https://example.com/guide.pdf', 'Zero');
SELECT pg_temp.check_true('5. filtering by category returns only that category',
  (SELECT count(*) = 2 AND bool_and(category = 'Procedures')
     FROM documents WHERE category = 'Procedures'));

-- 6. Public listing shows only published documents
UPDATE documents SET status = 'published' WHERE title = 'Procedures Manual';
SELECT pg_temp.check_true('6. public listing returns only published documents',
  (SELECT string_agg(title, ',') = 'Procedures Manual'
     FROM documents WHERE status = 'published'));

-- ---------------------------------------------------------------------
-- Expected rejections (each statement MUST fail with the right error)
-- ---------------------------------------------------------------------

SELECT pg_temp.check_rejected('7. invalid status is rejected',
  $q$INSERT INTO documents (title, category, file_url, status, created_by)
     VALUES ('x', 'Rules', 'https://example.com/a.pdf', 'banana', 'Zero')$q$, '23514');

SELECT pg_temp.check_rejected('8. title is required',
  $q$INSERT INTO documents (category, file_url, created_by)
     VALUES ('Rules', 'https://example.com/a.pdf', 'Zero')$q$, '23502');

SELECT pg_temp.check_rejected('9. blank title is rejected',
  $q$INSERT INTO documents (title, category, file_url, created_by)
     VALUES ('   ', 'Rules', 'https://example.com/a.pdf', 'Zero')$q$, '23514');

SELECT pg_temp.check_rejected('10. category is required',
  $q$INSERT INTO documents (title, file_url, created_by)
     VALUES ('x', 'https://example.com/a.pdf', 'Zero')$q$, '23502');

SELECT pg_temp.check_rejected('11. blank category is rejected',
  $q$INSERT INTO documents (title, category, file_url, created_by)
     VALUES ('x', '', 'https://example.com/a.pdf', 'Zero')$q$, '23514');

SELECT pg_temp.check_rejected('12. file URL is required',
  $q$INSERT INTO documents (title, category, created_by)
     VALUES ('x', 'Rules', 'Zero')$q$, '23502');

SELECT pg_temp.check_rejected('13. blank file URL is rejected',
  $q$INSERT INTO documents (title, category, file_url, created_by)
     VALUES ('x', 'Rules', ' ', 'Zero')$q$, '23514');

SELECT pg_temp.check_rejected('14. blank version is rejected (use NULL instead)',
  $q$INSERT INTO documents (title, category, file_url, version, created_by)
     VALUES ('x', 'Rules', 'https://example.com/a.pdf', '', 'Zero')$q$, '23514');

SELECT pg_temp.check_rejected('15. created_by is required',
  $q$INSERT INTO documents (title, category, file_url)
     VALUES ('x', 'Rules', 'https://example.com/a.pdf')$q$, '23502');
