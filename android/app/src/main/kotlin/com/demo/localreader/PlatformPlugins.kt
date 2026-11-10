package com.demo.localreader

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

/**
 * CharsetBridge.nativeFallback 的 Android 实现。
 * 纯 Dart 没有可靠的 GBK / GB18030 / Big5 解码器；未注入时必须显式报错，绝不静默乱码。
 */
class CharsetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/charset").also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "decode") return result.notImplemented()
        val bytes = call.argument<ByteArray>("bytes") ?: return result.error("ARG", "bytes 缺失", null)
        val hint = call.argument<String>("encoding") ?: "unknown"
        try {
            // TODO(P2): unknown 时做 GBK / GB18030 / Big5 统计判别，避免把 Big5 猜成 GBK
            val name = when (hint.lowercase()) {
                "big5" -> "Big5"
                "gb18030" -> "GB18030"
                else -> "GBK"
            }
            val cs = Charset.forName(name)
            result.success(mapOf("text" to String(bytes, cs), "encoding" to name))
        } catch (e: Throwable) {
            result.error("CHARSET", e.message, null)
        }
    }
}

/**
 * TTS 按句朗读：Dart 侧 SentenceQueue 决定「读哪一句」，原生只负责读一句并回报完成。
 * 绝不把整章塞给 speak()，否则「暂停/续播精确到句」做不到。
 */
class TtsPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    private lateinit var tts: TextToSpeech
    private var channel: MethodChannel? = null

    fun attach(messenger: io.flutter.plugin.common.BinaryMessenger) {
        channel = MethodChannel(messenger, "com.demo.localreader/tts").also { it.setMethodCallHandler(this) }
        tts = TextToSpeech(context) { /* onInit */ }
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) {
                channel?.invokeMethod("onSentenceDone", mapOf("utteranceId" to utteranceId))
            }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                channel?.invokeMethod("onSentenceError", mapOf("utteranceId" to utteranceId))
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "speak" -> {
                val sentence = call.argument<String>("sentence") ?: ""
                val utteranceId = call.argument<String>("utteranceId") ?: "s0"
                // QUEUE_FLUSH：每句独立，Dart 侧一次 await 完成才推进 cursor
                tts.speak(sentence, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                result.success(null)
            }
            "setRate" -> { tts.setSpeechRate((call.argument<Double>("rate") ?: 1.0).toFloat()); result.success(null) }
            "setPitch" -> { tts.setPitch((call.argument<Double>("pitch") ?: 1.0).toFloat()); result.success(null) }
            "pause", "stop" -> { tts.stop(); result.success(null) }
            else -> result.notImplemented()
        }
    }
}

/**
 * SAF 目录授权持久化：对齐原项目「首页导入 → 选择目录，授权会持久化，重启后可一键重扫」。
 * 权限维持最小集：13+ READ_MEDIA_IMAGES，12- READ_EXTERNAL_STORAGE；文档类走 SAF 或所有文件访问。
 */
class SafPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val REQUEST_OPEN_TREE = 1001
        private const val PREFS = "localreader_saf"
        private const val KEY_URIS = "granted_uris"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                // TODO: 通过 ActivityPluginBinding 的 ActivityResultListener 接回 onActivityResult
                result.success(null)
            }
            "persistGrant" -> {
                val uri = Uri.parse(call.argument<String>("uri") ?: return result.error("ARG", "uri 缺失", null))
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                context.contentResolver.takePersistableUriPermission(uri, flags)
                val set = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getStringSet(KEY_URIS, emptySet())!!.toMutableSet()
                set.add(uri.toString())
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putStringSet(KEY_URIS, set).apply()
                result.success(true)
            }
            "rescanPersisted" -> {
                val set = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getStringSet(KEY_URIS, emptySet()) ?: emptySet()
                // TODO: DocumentFile.fromTreeUri 递归扫描，只收 TXT/EPUB/CBZ/PDF 等已登记格式
                result.success(set.toList())
            }
            "hasPersistedGrant" -> {
                val set = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getStringSet(KEY_URIS, emptySet()) ?: emptySet()
                result.success(set.isNotEmpty())
            }
            else -> result.notImplemented()
        }
    }
}
