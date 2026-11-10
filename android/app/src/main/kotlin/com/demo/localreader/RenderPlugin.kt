package com.demo.localreader

import android.graphics.Bitmap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * BookRenderBridge 的 Android 侧实现骨架（参考实现，非可编译成品）。
 *
 * 边界约定：
 *  - Dart 只传 documentId / localPath / index / 目标像素 w,h，不传原始文件流；
 *  - 原生不认文件格式，只按 handle 出页；
 *  - 连续翻页走 TextureRegistry 的 textureId；单页快照才回 PNG 字节；
 *  - prefetch / evict 是批量窗口，禁止在滚动回调里逐帧跨 channel。
 *
 * 不嵌原生 View：只用外部纹理，绕开 Texture-layer 快速滚动卡顿、
 * Hybrid composition 线程合并掉帧、HCPP 需 API 34+ / Vulkan / Impeller 这组取舍。
 */
class RenderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var textures: TextureRegistry? = null
    private val handles = mutableMapOf<Int, DocumentHandle>()
    private var nextHandle = 1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        textures = binding.textureRegistry
        channel = MethodChannel(binding.binaryMessenger, "com.demo.localreader/render").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        handles.values.forEach { it.close() }
        handles.clear()
        textures = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    val id = call.argument<String>("documentId") ?: 
                        return result.error("ARG", "documentId 缺失", null)
                    val path = call.argument<String>("localPath") ?: 
                        return result.error("ARG", "localPath 缺失", null)
                    val h = nextHandle++
                    // TODO(P2): PDFium JNI/FFI 打开；CBZ/ZIP 用 archive 解包；RAR5 直接返回 UNSUPPORTED 并提示转 CBZ/ZIP
                    handles[h] = DocumentHandle(h, path, textures!!)
                    result.success(h)
                }
                "pageCount" -> result.success(handles[handleOf(call)]?.pageCount() ?: 0)
                "pageInfo" -> {
                    val h = handles[handleOf(call)] ?: return result.error("HANDLE", "句柄已释放", null)
                    val i = call.argument<Int>("index") ?: 0
                    result.success(
                        mapOf("w" to h.pageWidth(i), "h" to h.pageHeight(i), "aspect" to h.aspect(i))
                    )
                }
                "render" -> {
                    val h = handles[handleOf(call)] ?: return result.error("HANDLE", "句柄已释放", null)
                    val i = call.argument<Int>("index") ?: 0
                    // 关键：按目标尺寸渲染，别出 4K 再在 Dart 里缩
                    val w = call.argument<Int>("w") ?: 1080
                    val ht = call.argument<Int>("h") ?: 1920
                    val textureId = h.renderToTexture(i, w, ht)
                    result.success(mapOf("textureId" to textureId, "w" to w, "h" to ht))
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
                "capabilities" -> result.success(mapOf("pdfium" to "pending", "texture" to "ok"))
                else -> result.notImplemented()
            }
        } catch (e: UnsupportedArchiveException) {
            result.error("UNSUPPORTED", e.message, null)
        } catch (e: Throwable) {
            result.error("RENDER", e.message, null)
        }
    }

    private fun handleOf(call: MethodCall): Int = call.argument<Int>("handle") ?: -1
}

class UnsupportedArchiveException(message: String) : Exception(message)

/** 单文档句柄：持有已解码页缓存，窗口外按 evict 释放，避免漫画大图常驻内存。 */
private class DocumentHandle(
    private val id: Int,
    private val path: String,
    private val textures: TextureRegistry
) {
    private val entries = mutableMapOf<Int, TextureRegistry.SurfaceTextureEntry>()
    private val decoded = mutableMapOf<Int, Bitmap>()

    fun pageCount(): Int = 0 // TODO: PDFium FPDF_GetPageCount / ZIP 条目数
    fun pageWidth(i: Int): Double = 1080.0
    fun pageHeight(i: Int): Double = 1920.0
    fun aspect(i: Int): Double = pageWidth(i) / pageHeight(i)

    fun renderToTexture(index: Int, w: Int, h: Int): Long {
        // TODO: PDFium FPDFBitmap_Create(w,h) → FPDF_RenderPageBitmap → BGRA 缓冲
        //  → 写入 entry.surfaceTexture 的 Surface → 触发帧通知
        val entry = entries.getOrPut(index) { textures.createSurfaceTexture() }
        return entry.id()
    }

    fun applyWindow(method: String, indices: List<Int>) {
        if (method == "prefetch") {
            // TODO: 后台线程池按目标尺寸解码 indices，完成后 markNewFrameAvailable
        } else {
            indices.forEach { i ->
                decoded.remove(i)?.recycle()
                // texture entry 的释放要与 Dart 侧 evict 窗口保持一致
            }
        }
    }

    fun close() {
        decoded.values.forEach { it.recycle() }
        decoded.clear()
        entries.values.forEach { it.release() }
        entries.clear()
    }
}
