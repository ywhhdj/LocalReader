package com.demo.core.database.migration

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/** 迁移占位：版本 2 起在此追加；当前版本 1 无需迁移 */
val MIGRATIONS: Array<Migration> = emptyArray()

/** 示例（后续启用）：
 * val MIGRATION_1_2 = object : Migration(1, 2) {
 *     override fun migrate(db: SupportSQLiteDatabase) {
 *         db.execSQL("ALTER TABLE books ADD COLUMN tag TEXT")
 *     }
 * }
 */
object MigrationNotes {
    const val NOTE = "版本 1 → 2 时在此登记 Migration，并在 DatabaseProvider 中 addMigrations(*MIGRATIONS)"
}
