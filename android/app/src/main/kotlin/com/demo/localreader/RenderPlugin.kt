package com.demo.localreader

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.LruCache
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale
import kotlin.math.roundToInt
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

/**
 * BookRenderBridge 的 Android 侧真实实现。
 *
 * 与 Dart 侧 `PlatformRenderBridge.render()` 的协议一致：返回 PNG `bytes` +
 * 实际像素 w/h，由 Dart 的 `Image.memory` 显示；不再注册一个永远空白的
 * textureId（旧骨架 pageCount() 恒为 0、renderToTexture() 不画帧）。
 *
 * 支持：
 *  - PDF：系统 `PdfRenderer`，按目标像素直接栅格化（不引第三方 PDFium）；
 *  - CBZ / ZIP：`ZipFile` 列出图片条目并按页序自然排序；
 *  - 图片文件夹：目录内图片按文件名自然排序；
 *  - 路径为 content:// 时走 ContentResolver 的 openFileDescriptor / openInputStream。
 * RAR / CBR（含 RAR5、加密包）明确返回 UNSUPPORTED，提示转 CBZ / ZIP。
 *
 * 窗口缓存用 LruCache，evict 与 Dart 侧 ComicPrefetchWindow 对齐，避免漫画大图常驻。
 */
class RenderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private val handles = mutableMapOf<Int, DocumentHandle>()
    private var nextHandle = 1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.demo.localreader/render")
            .also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        handles.values.forEach { it.close() }
        handles.clear()
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    val path = call.argument<String>("localPath")
                        ?: return result.error("ARG", "localPath 缺失", null)
                    val h = nextHandle++
                    handles[h] = DocumentHandle.open(path, appContext)
                    result.success(h)
                }
                "pageCount" -> result.success(handles[handleOf(call)]?.pageCount() ?: 0)
                "pageInfo" -> {
                    val h = handles[handleOf(call)]
                        ?: return result.error("HANDLE", "句柄已释放", null)
                    val i = call.argument<Int>("index") ?: 0
                    val size = h.pageSize(i)
                    result.success(
                        mapOf(
                            "w" to size.first.toDouble(),
                            "h" to size.second.toDouble(),
                            "aspect" to size.first.toDouble() / size.second.coerceAtLeast(1).toDouble()
                        )
                    )
                }
                "render" -> {
                    val h = handles[handleOf(call)]
                        ?: return result.error("HANDLE", "句柄已释放", null)
                    val i = call.argument<Int>("index") ?: 0
                    // 按目标尺寸渲染，别出 4K 图再在 Dart 里缩。
                    val w = (call.argument<Int>("w") ?: 1080).coerceIn(64, 4096)
                    val ht = (call.argument<Int>("h") ?: 1920).coerceIn(64, 4096)
                    val png = h.render(i, w, ht)
                    result.success(mapOf("bytes" to png.first, "w" to png.second, "h" to png.third))
                }
                "prefetch", "evict" -> {
                    val h = handles[handleOf(call)]
                    val indices = call.argument<List<Int>>("indices") ?: emptyList()
                    h?.applyWindow(call.method, indices)
                    result.success(null)
                }
                "close" -> {
                    handles.remove(handleOf(call))?.close()
                    result.success(null)
                }
                "capabilities" -> result.success(
                    mapOf("pdf" to "android.graphics.pdf.PdfRenderer", "zip" to "ok", "raster" to "png")
                )
                else -> result.notImplemented()
            }
        } catch (e: UnsupportedArchiveException) {
            result.error("UNSUPPORTED", e.message, null)
        } catch (e: Throwable) {
            result.error("RENDER", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun handleOf(call: MethodCall): Int = call.argument<Int>("handle") ?: -1
}

class UnsupportedArchiveException(message: String) : Exception(message)

/** 单文档句柄：PDF 描述符 / ZIP 条目 / 目录图片，统一成「按 index 取一页」。 */
private class DocumentHandle private constructor(
    private val context: Context?,
    private val path: String,
    private val kind: Kind,
) {
    private enum class Kind { PDF, ZIP, DIR }

    private var pdf: PdfRenderer? = null
    private var pfd: ParcelFileDescriptor? = null
    private var zip: ZipFile? = null
    private var entries: List<ZipEntry> = emptyList()
    private var files: List<File> = emptyList()
    // 24MB 上限，按位图实际字节计量（默认 sizeOf 返回 1 会缓存成千上万张大图）。
    private val cache = object : LruCache<String, Bitmap>(24 * 1024) {
        override fun sizeOf(key: String, value: Bitmap): Int =
            (value.byteCount / 1024).coerceAtLeast(1)
    }
    private val bounds = mutableMapOf<Int, Pair<Int, Int>>()

    companion object {
        private val IMAGE_EXTS = setOf("jpg", "jpeg", "png", "webp", "bmp", "gif")

        /** 数字感知的自然排序：page2 < page10，不会排成 1,10,2。 */
        private val NATURAL = Comparator<String> { a, b ->
            var i = 0
            var j = 0
            while (i < a.length && j < b.length) {
                val ca = a[i]
                val cb = b[j]
                if (ca.isDigit() && cb.isDigit()) {
                    var endA = i
                    var endB = j
                    while (endA < a.length && a[endA].isDigit()) endA++
                    while (endB < b.length && b[endB].isDigit()) endB++
                    val na = a.substring(i, endA).trimStart('0').ifEmpty { "0" }
                    val nb = b.substring(j, endB).trimStart('0').ifEmpty { "0" }
                    val cmp = when {
                        na.length != nb.length -> na.length.compareTo(nb.length)
                        else -> na.compareTo(nb)
                    }
                    if (cmp != 0) return@Comparator cmp
                    i = endA; j = endB
                } else {
                    val cmp = ca.lowercaseChar().compareTo(cb.lowercaseChar())
                    if (cmp != 0) return@Comparator cmp
                    i++; j++
                }
            }
            a.length.compareTo(b.length)
        }

        private fun ext(name: String) =
            name.substringAfterLast('.', "").lowercase(Locale.ROOT)

        private fun isImage(name: String) = ext(name) in IMAGE_EXTS

        fun open(path: String, context: Context?): DocumentHandle {
            val lower = path.lowercase(Locale.ROOT)
            if (lower.endsWith(".cbr") || lower.endsWith(".rar") ||
                lower.contains("rar5")
            ) {
                throw UnsupportedArchiveException(
                    "RAR / CBR（含 RAR5、加密包）暂不支持，请转换为 CBZ / ZIP 后重新导入"
                )
            }
            val handle = DocumentHandle(context, path, detect(path, context))
            handle.init()
            return handle
        }

        private fun detect(path: String, context: Context?): Kind = when {
            path.lowercase(Locale.ROOT).endsWith(".pdf") -> Kind.PDF
            path.lowercase(Locale.ROOT).let { it.endsWith(".cbz") || it.endsWith(".zip") } -> Kind.ZIP
            File(path).isDirectory -> Kind.DIR
            // content:// 的 MIME 由系统给出，兜底按 PDF 处理。
            path.startsWith("content://") ->
                if ((context?.contentResolver?.getType(Uri.parse(path)) ?: "").contains("pdf")) Kind.PDF
                else Kind.ZIP
            else -> Kind.DIR // 单张图片：把所在目录当一页书
        }

    }

    /** 打开时按文档类型初始化；普通成员方法，避免扩展函数访问私有字段的歧义。 */
    fun init() {
        when (kind) {
            Kind.PDF -> {
                val c = context
                pfd = if (path.startsWith("content://")) {
                    c?.contentResolver?.openFileDescriptor(Uri.parse(path), "r")
                } else {
                    ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
                } ?: throw IllegalStateException("无法打开 PDF：$path")
                pdf = PdfRenderer(pfd!!)
            }
            Kind.ZIP -> {
                zip = ZipFile(path)
                entries = zip!!.entries().toList()
                    .filter { !it.isDirectory && isImage(it.name) }
                    .sortedWith { a, b -> NATURAL.compare(a.name, b.name) }
            }
            Kind.DIR -> {
                val f = File(path)
                val dir = if (f.isDirectory) f else f.parentFile
                files = dir?.listFiles()?.filter { it.isFile && isImage(it.name) }
                    ?.sortedWith { a, b -> NATURAL.compare(a.name, b.name) }
                    ?: emptyList()
            }
        }
    }

    fun pageCount(): Int = when (kind) {
        Kind.PDF -> pdf?.pageCount ?: 0
        Kind.ZIP -> entries.size
        Kind.DIR -> files.size
    }

    fun pageSize(index: Int): Pair<Int, Int> {
        bounds[index]?.let { return it }
        val size = try {
            when (kind) {
                Kind.PDF -> {
                    // PdfRenderer 的宽高是 1/72 英寸点，乘 2 得到常见阅读像素密度。
                    val p = pdf?.openPage(index.coerceIn(0, (pageCount() - 1).coerceAtLeast(0)))
                    val r = if (p != null) Pair(p.width * 2, p.height * 2) else Pair(1080, 1920)
                    p?.close()
                    r
                }
                Kind.ZIP -> decodeBounds { zip?.getInputStream(entries[index])?.use { it.readBytes() } }
                Kind.DIR -> decodeBounds { files[index].readBytes() }
            }
        } catch (_: Throwable) {
            Pair(1080, 1920)
        }
        bounds[index] = size
        return size
    }

    private fun decodeBounds(read: () -> ByteArray?): Pair<Int, Int> {
        val bytes = read() ?: return Pair(1080, 1920)
        val opt = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opt)
        return Pair(opt.outWidth.coerceAtLeast(1), opt.outHeight.coerceAtLeast(1))
    }

    /** 返回 PNG 字节与实际宽高；缓存键包含目标尺寸，改字号/分栏不会复用旧图。 */
    fun render(index: Int, w: Int, h: Int): Triple<ByteArray, Int, Int> {
        val key = "$index:$w:$h"
        cache.get(key)?.let { return Triple(toPng(it), it.width, it.height) }

        val bmp: Bitmap = when (kind) {
            Kind.PDF -> {
                val page = pdf?.openPage(index)
                    ?: throw IllegalStateException("PDF 页 $index 不存在")
                val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                // 白底，避免透明像素在深色主题下发灰。
                out.eraseColor(android.graphics.Color.WHITE)
                page.render(out, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                page.close()
                out
            }
            Kind.ZIP, Kind.DIR -> {
                val bytes = if (kind == Kind.ZIP) {
                    zip?.getInputStream(entries[index])?.use { it.readBytes() }
                } else {
                    files[index].readBytes()
                } ?: throw IllegalStateException("第 $index 页读取失败")
                val opt = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opt)
                val sample = computeSample(opt.outWidth, opt.outHeight, w, h)
                val full = BitmapFactory.decodeByteArray(
                    bytes, 0, bytes.size,
                    BitmapFactory.Options().apply { inSampleSize = sample }
                ) ?: throw IllegalStateException("第 $index 页解码失败")
                // 保持宽高比缩到目标框内，交给 Dart 侧 BoxFit.contain 居中。
                val scale = minOf(
                    w.toFloat() / full.width.toFloat(),
                    h.toFloat() / full.height.toFloat(),
                    1f
                )
                val scaled = Bitmap.createScaledBitmap(
                    full,
                    (full.width.toFloat() * scale).roundToInt().coerceAtLeast(1),
                    (full.height.toFloat() * scale).roundToInt().coerceAtLeast(1),
                    true
                )
                if (scaled != full) full.recycle()
                scaled
            }
        }
        cache.put(key, bmp)
        return Triple(toPng(bmp), bmp.width, bmp.height)
    }

    private fun computeSample(sw: Int, sh: Int, tw: Int, th: Int): Int {
        var sample = 1
        var w = sw
        var h = sh
        while (w / 2 >= tw && h / 2 >= th) {
            w /= 2; h /= 2; sample *= 2
        }
        return sample.coerceAtMost(16)
    }

    private fun toPng(bmp: Bitmap): ByteArray {
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    fun applyWindow(method: String, indices: List<Int>) {
        if (method == "evict") {
            for (i in indices) {
                bounds.remove(i)
                cache.snapshot().keys.filter { it.startsWith("$i:") }.forEach { cache.remove(it) }
            }
        }
        // prefetch 由 Dart 侧按当前页批量调用 render() 预热，这里不额外开线程，
        // 避免在滚动回调里逐帧跨 channel。
    }

    fun close() {
        cache.evictAll()
        runCatching { pdf?.close() }
        runCatching { pfd?.close() }
        runCatching { zip?.close() }
        pdf = null; pfd = null; zip = null
        entries = emptyList(); files = emptyList(); bounds.clear()
    }
}
