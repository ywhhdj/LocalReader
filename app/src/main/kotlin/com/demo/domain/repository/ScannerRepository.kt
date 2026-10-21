package com.demo.domain.repository

import kotlinx.coroutines.flow.Flow

/**
 * 扫描目标：
 * - [ScanTarget.Path]：本地绝对路径（需要存储权限）
 * - [ScanTarget.Tree]：SAF 目录授权 URI（Android 11+ 无所有文件权限时的主路径）
 */
sealed interface ScanTarget {

  /** 本地文件/目录绝对路径 */
  data class Path(val path: String) : ScanTarget

  /** SAF 树授权 URI（content://...） */
  data class Tree(val uri: String) : ScanTarget

  companion object {
    fun parse(raw: String): ScanTarget {
      if (raw.startsWith("content://")) return Tree(raw)
      return Path(raw)
    }
    fun parseAll(raws: List<String>): List<ScanTarget> = raws.map { parse(it) }
  }
}

data class ScanOptions(
  val maxDepth: Int = 4,
  val maxFiles: Int = 20_000,
  val maxFileSize: Long = 200L * 1024 * 1024,
  val skipHidden: Boolean = true,
  /** 已存在的文件是否按 mtime/size 变化更新元数据 */
  val refreshExisting: Boolean = true,
  /** 连续图片目录整体作为一本漫画导入 */
  val folderAsComic: Boolean = true
)

data class ScanProgress(
  val scanned: Int = 0,
  val imported: Int = 0,
  val skipped: Int = 0,
  val failed: Int = 0,
  val current: String = "",
  val done: Boolean = false,
  /** 提示信息：如"RAR/CBR 暂不支持，请转为 CBZ/ZIP" */
  val message: String? = null
)

interface ScannerRepository {
  /** 扫描并入库，回传进度（取消 Flow 收集即中断） */
  fun scan(targets: List<ScanTarget>, options: ScanOptions = ScanOptions()): Flow<ScanProgress>

  /** 便捷重载：直接传路径/URI 字符串 */
  fun scanRaw(raws: List<String>, options: ScanOptions = ScanOptions()): Flow<ScanProgress> = scan(ScanTarget.parseAll(raws), options)
}
