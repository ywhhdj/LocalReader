-- LocalReader · SQLite schema

PRAGMA user_version = 3;
PRAGMA foreign_keys = ON;

-- v1 ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS books (
  id            TEXT PRIMARY KEY,
  title         TEXT NOT NULL,
  author        TEXT NOT NULL DEFAULT '',
  source_path   TEXT NOT NULL,
  source_format TEXT NOT NULL,
  cover_path    TEXT,
  encoding      TEXT,
  added_at      INTEGER NOT NULL,
  last_read_at  INTEGER
);

CREATE TABLE IF NOT EXISTS chapters (
  id          TEXT PRIMARY KEY,
  book_id     TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  ordinal     INTEGER NOT NULL,
  title       TEXT NOT NULL,
  block_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS progress (
  book_id       TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
  chapter_index INTEGER NOT NULL DEFAULT 0,
  page_index    INTEGER NOT NULL DEFAULT 0,
  block_index   INTEGER NOT NULL DEFAULT 0,
  line_index    INTEGER NOT NULL DEFAULT 0,
  char_offset   INTEGER NOT NULL DEFAULT 0,
  updated_at    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_books_last_read ON books(last_read_at DESC);
CREATE INDEX IF NOT EXISTS idx_chapters_book_ordinal ON chapters(book_id, ordinal);

-- v2 进度页内位置 + 锚点 -------------------------------------------
ALTER TABLE progress ADD COLUMN page_offset   REAL    NOT NULL DEFAULT 0.0;
ALTER TABLE progress ADD COLUMN anchor_block  INTEGER NOT NULL DEFAULT 0;
ALTER TABLE progress ADD COLUMN anchor_line   INTEGER NOT NULL DEFAULT 0;
ALTER TABLE progress ADD COLUMN anchor_char   INTEGER NOT NULL DEFAULT 0;

-- v3 分组与阅读会话 --------------------------------------------------
CREATE TABLE IF NOT EXISTS groups_table (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS book_groups (
  book_id  TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  group_id TEXT NOT NULL REFERENCES groups_table(id) ON DELETE CASCADE,
  PRIMARY KEY (book_id, group_id)
);

CREATE TABLE IF NOT EXISTS reading_sessions (
  id         TEXT PRIMARY KEY,
  book_id    TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  started_at INTEGER NOT NULL,
  ended_at   INTEGER,
  minutes    INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sessions_book_started ON reading_sessions(book_id, started_at);
