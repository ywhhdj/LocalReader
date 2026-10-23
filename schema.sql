-- ============================================================================
-- Local Reader · 本地数据库 Schema
-- ----------------------------------------------------------------------------
-- 对应代码：app/src/main/kotlin/com/demo/core/database/
--   实体：BookEntity / BookGroupEntity / ReadingProgressEntity / ReadingSessionEntity
--   Room：@Database(version = 1, exportSchema = true)，DB 名 local_reader.db
--
-- 用途：
--   1) 用 sqlite3 / DB Browser 等工具建一份与 App 完全同构的库做调试；
--   2) 备份恢复、数据修复、批量导入导出时对照表结构；
--   3) 排查问题时直接用下面的统计/维护查询。
--
-- ⚠ 让 Room 直接打开本文件生成的 .db 时，必须补上 room_master_table 的
--    identity_hash，否则 Room 会因校验不通过抛
--    "Pre-packaged database has an invalid schema"
-- ============================================================================

-- ============================================================================
-- 1. 库级设置
-- ============================================================================

PRAGMA journal_mode = WAL;
-- 与 DatabaseProvider 的 WRITE_AHEAD_LOGGING 一致
PRAGMA synchronous = NORMAL;
-- WAL 下的推荐档位
PRAGMA foreign_keys = ON;
-- 外键为连接级开关，每次连接都要设

-- ============================================================================
-- 2. 表结构
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 书籍表 books           （对应 BookEntity）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS books (
  id INTEGER PRIMARY KEY AUTOINCREMENT, -- 自增主键
  title TEXT NOT NULL, -- 书名
  author TEXT NOT NULL, -- 作者（空串表示未知）
  type TEXT NOT NULL, -- NOVEL / COMIC（BookType）
  FORMAT TEXT NOT NULL, -- EPUB / TXT / PDF / CBZ / ZIP / FOLDER ...
  file_path TEXT NOT NULL, -- 绝对路径或 SAF 物化路径，去重依据
  source_uri TEXT, -- SAF 树 URI（content://...），可为空
  cover_path TEXT, -- 封面缓存路径；为空时用文字占位封面
  size_bytes INTEGER NOT NULL DEFAULT 0, -- 文件体积
  added_at INTEGER NOT NULL DEFAULT 0, -- 入库时间戳（ms）
  last_read_at INTEGER NOT NULL DEFAULT 0, -- 最近阅读时间戳（ms），书架默认排序键
  group_id INTEGER, -- 所属分组；NULL = 未分组
  favorite INTEGER NOT NULL DEFAULT 0, -- 收藏：0 / 1（SQLite 无 BOOLEAN）
  progress REAL NOT NULL DEFAULT 0, -- 阅读进度 0.0 ~ 1.0
  chapter_count INTEGER NOT NULL DEFAULT 0, -- 章节数（小说）
  page_count INTEGER NOT NULL DEFAULT 0, -- 页数（漫画 / PDF）
  meta_json TEXT -- 附加信息（Converters 用 \u0001 分隔的列表等）
);

-- ----------------------------------------------------------------------------
-- 2.2 分组表 book_groups      （对应 BookGroupEntity）
-- ----------------------------------------------------------------------------
-- 只存用户自建分组。内置分组「全部 / 小说 / 漫画 / 收藏」是代码中的负数常量
-- （BuiltInGroup：ALL=-1, NOVEL=-2, COMIC=-3, FAVORITE=-4），不落库。
CREATE TABLE IF NOT EXISTS book_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, -- 分组名，唯一
  sort_order INTEGER NOT NULL DEFAULT 0, -- 排序序号
  kind TEXT NOT NULL DEFAULT 'USER', -- SYSTEM / USER
  created_at INTEGER NOT NULL DEFAULT 0 -- 创建时间戳（ms）
);

-- ----------------------------------------------------------------------------
-- 2.3 阅读进度表 reading_progress  （对应 ReadingProgressEntity）
-- ----------------------------------------------------------------------------
-- 一本书一条；book_id 由代码保证存在（Room 实体未声明外键，避免 Room schema 校验失败）
CREATE TABLE IF NOT EXISTS reading_progress (
  book_id INTEGER PRIMARY KEY, -- 书籍 id，非自增
  chapter_index INTEGER NOT NULL DEFAULT 0, -- 章节索引（小说）
  char_offset INTEGER NOT NULL DEFAULT 0, -- 章内字符偏移
  page_index INTEGER NOT NULL DEFAULT 0, -- 页索引（漫画 / PDF）
  progress REAL NOT NULL DEFAULT 0, -- 总进度 0.0 ~ 1.0
  updated_at INTEGER NOT NULL DEFAULT 0 -- 更新时间戳（ms）
);

-- ----------------------------------------------------------------------------
-- 2.4 阅读会话表 reading_sessions  （对应 ReadingSessionEntity）
-- ----------------------------------------------------------------------------
-- 每进入一次阅读器产生一条，用于统计时长、连续天数、分类占比
CREATE TABLE IF NOT EXISTS reading_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL, -- 书籍 id
  start_at INTEGER NOT NULL, -- 开始时间戳（ms）
  duration_ms INTEGER NOT NULL, -- 时长（毫秒）
  type TEXT NOT NULL DEFAULT 'NOVEL' -- NOVEL / COMIC
);

-- ============================================================================
-- 3. 索引
-- ----------------------------------------------------------------------------
-- 命名规则与 Room 默认一致：index_<表名>_<列名>，否则 Room 校验会报索引缺失。
-- ============================================================================

-- books
CREATE UNIQUE INDEX IF NOT EXISTS index_books_file_path ON books (file_path);
-- 导入去重依据
CREATE INDEX IF NOT EXISTS index_books_type
  ON books (type);
-- 小说 / 漫画筛选
CREATE INDEX IF NOT EXISTS index_books_group_id ON books (group_id);
-- 分组筛选
CREATE INDEX IF NOT EXISTS index_books_last_read_at ON books (last_read_at);
-- 书架默认排序
CREATE INDEX IF NOT EXISTS index_books_title ON books (title);
-- 书名排序 / 搜索

-- book_groups
CREATE UNIQUE INDEX IF NOT EXISTS index_book_groups_name ON book_groups (name);
-- 同名分组校验

-- reading_sessions
CREATE INDEX IF NOT EXISTS index_reading_sessions_start_at ON reading_sessions (start_at);
-- 按时间范围聚合（近 7 天 / 连续天数）
CREATE INDEX IF NOT EXISTS index_reading_sessions_book_id ON reading_sessions (book_id);
-- 按书聚合

-- ============================================================================
-- 4. 查询示例（与 DAO 一一对应，调试时可直接改参数执行）
-- ============================================================================

-- 4.1 书架分页：按最近阅读（ShelfViewModel 默认排序）
--     :groupId 传 NULL 表示全部；:type 传 NULL 表示不限；:favoriteOnly 0/1
SELECT *
FROM books
WHERE (:groupId IS NULL OR group_id = :groupId)
  AND (:type IS NULL OR type = :type)
  AND (:favoriteOnly = 0 OR favorite = 1)
  AND (:keyword = '' OR title LIKE '%' || :keyword || '%'
                     OR author LIKE '%' || :keyword || '%')
ORDER BY last_read_at DESC, added_at DESC
LIMIT :limit OFFSET :offset;

-- 4.2 书架分页：按最近添加
SELECT * FROM books
WHERE (:groupId IS NULL OR group_id = :groupId)
  AND (:type IS NULL OR type = :type)
  AND (:favoriteOnly = 0 OR favorite = 1)
ORDER BY added_at DESC
LIMIT :limit OFFSET :offset;

-- 4.3 书架分页：按书名（忽略大小写）
SELECT * FROM books
WHERE (:groupId IS NULL OR group_id = :groupId)
  AND (:type IS NULL OR type = :type)
ORDER BY title COLLATE NOCASE ASC
LIMIT :limit OFFSET :offset;

-- 4.4 书架分页：按进度
SELECT * FROM books
WHERE (:groupId IS NULL OR group_id = :groupId)
  AND (:type IS NULL OR type = :type)
ORDER BY progress DESC, last_read_at DESC
LIMIT :limit OFFSET :offset;

-- 4.5 继续阅读（在读：进度 >0 且 <1）
SELECT * FROM books
WHERE progress > 0.001 AND progress < 0.999
ORDER BY last_read_at DESC
LIMIT :limit;

-- 4.6 收藏
SELECT * FROM books WHERE favorite = 1 ORDER BY last_read_at DESC LIMIT :limit;

-- 4.7 单本 / 按路径查重（导入去重）
SELECT * FROM books WHERE id = :id;

SELECT * FROM books WHERE file_path = :path LIMIT 1;

-- ============================================================================
-- 5. 统计查询（对应 StatsRepositoryImpl / ProfileViewModel）
-- ============================================================================

-- 5.1 总览：总册数、分类数、已读完、在读
SELECT
  COUNT(*) AS total_books,
  SUM(
    CASE
      WHEN type = 'NOVEL' THEN 1
      ELSE 0
    END
  ) AS novel_count,
  SUM(
    CASE
      WHEN type = 'COMIC' THEN 1
      ELSE 0
    END
  ) AS comic_count,
  SUM(
    CASE
      WHEN progress >= 0.999 THEN 1
      ELSE 0
    END
  ) AS finished_count,
  SUM(
    CASE
      WHEN progress > 0.001
      AND progress < 0.999 THEN 1
      ELSE 0
    END
  ) AS reading_count
FROM books;

-- 5.2 阅读时长：今日 / 本周 / 累计
--     :todayStart 为今天 00:00 的时间戳（ms）
SELECT
    COALESCE(SUM(CASE WHEN start_at >= :todayStart THEN duration_ms END), 0) AS today_ms,
    COALESCE(SUM(CASE WHEN start_at >= :weekStart  THEN duration_ms END), 0) AS week_ms,
    COALESCE(SUM(duration_ms), 0)                                            AS total_ms
FROM reading_sessions;

-- 5.3 近 7 天每日时长（dayKey = 距 epoch 的天数，与 dailySince 一致）
SELECT start_at / 86400000 AS day_key, COALESCE(SUM(duration_ms), 0) AS total_ms
FROM reading_sessions
WHERE start_at >= :weekStart
GROUP BY day_key
ORDER BY day_key ASC;

-- 5.4 分类阅读占比
SELECT b.type AS type_name, COALESCE(SUM(s.duration_ms), 0) AS total_ms
FROM reading_sessions s
    INNER JOIN books b ON s.book_id = b.id
GROUP BY
    b.type;

-- 5.5 连续阅读天数（代码逻辑的 SQL 版：从今天/昨天往前数）
SELECT DISTINCT
    start_at / 86400000 AS day_key
FROM reading_sessions
ORDER BY day_key DESC
LIMIT 365;

-- ============================================================================
-- 6. 维护 / 修复（按需执行，执行前建议先备份 db 文件）
-- ============================================================================

-- 6.1 清理孤儿阅读会话（书籍已删除）
DELETE FROM reading_sessions
WHERE
  book_id NOT IN(
    SELECT id
    FROM books
  );

-- 6.2 清理孤儿阅读进度（书籍已删除）
DELETE FROM reading_progress
WHERE
  book_id NOT IN(
    SELECT id
    FROM books
  );

-- 6.3 把已删分组的书籍挂回"未分组"
UPDATE books
SET
  group_id = NULL
WHERE
  group_id IS NOT NULL
  AND group_id NOT IN(
    SELECT id
    FROM book_groups
  );

-- 6.4 修复越界进度（历史脏数据：负数或 >1）
UPDATE books SET progress = 0.0 WHERE progress < 0.0;

UPDATE books SET progress = 1.0 WHERE progress > 1.0;

-- 6.5 收藏字段规范为 0/1
UPDATE books
SET
  favorite = 0
WHERE
  favorite IS NULL
  OR favorite NOT IN(0, 1);

-- 6.6 更新查询计划统计信息（索引选择性变差时执行）
ANALYZE;

-- 6.7 回收空间（删除大量书籍后；会重写整个库，慎用）
-- VACUUM;

-- ============================================================================
-- 7. Room 兼容（仅当要让 Room 直接打开这个文件生成的 .db 时才需要）
-- ----------------------------------------------------------------------------
-- Room 建库时会写入 room_master_table 并校验 identity_hash；
-- 该值是 Room 根据实体结构计算出的哈希，必须取真实值，不能自行编造。
--
-- 获取方式（任选其一）：
--   a) 开启 exportSchema（AppDatabase 已开启），构建后从
--      app/schemas/com.demo.core.database.AppDatabase/1.json
--      取 "identityHash" 字段；
--   b) 用 App 真机跑一次建库，取出 db 后执行：
--      sqlite3 local_reader.db "SELECT identity_hash FROM room_master_table;"
--      再把结果填到下面的占位符。
--
-- 若只是用外部工具查看/修复数据，可整段跳过。
-- ============================================================================

CREATE TABLE IF NOT EXISTS room_master_table (
  id INTEGER PRIMARY KEY,
  identity_hash TEXT
);

-- 把 <IDENTITY_HASH> 替换为第 a / b 种方式拿到的真实值
INSERT
  OR
REPLACE INTO
  room_master_table (id, identity_hash)
VALUES (42, '<IDENTITY_HASH>');

-- ============================================================================
-- 8. 可选：外键级联（需要同步改代码才生效）
-- ----------------------------------------------------------------------------
-- 当前实体未声明 @ForeignKey，删书时 reading_progress / reading_sessions
-- 不会自动级联，靠 6.1 / 6.2 的清理语句兜底。
--
-- 如需数据库级联，须在 BookEntity 之外给两张子表加 @ForeignKey(
--     entity = BookEntity::class,
--     parentColumns = ["id"], childColumns = ["book_id"],
--     onDelete = ForeignKey.CASCADE
-- ) 并把数据库版本升到 2 写 Migration，否则 Room schema 校验会失败。
-- ============================================================================