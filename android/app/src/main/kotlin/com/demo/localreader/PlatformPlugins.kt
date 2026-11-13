package com.demo.localreader

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.Charset
import java.util.Locale

/**
 * 第三十二轮：把 dev 分支里所有「❄️ 冻结」的 Dart 平台能力在 Android 侧补齐。
 *
 * 通道名与 lib/data/platform/platform_bridges.dart 的 LrChannels 一一对应：
 *   render / tts / charset / saf / database / device / share / widgets / files / fonts / voice
 * 每个插件都实现 FlutterPlugin，由 MainActivity.configureFlutterEngine 统一注册，
 * 不再出现「Dart 调了通道、原生没挂 handler」的 MissingPluginException。
 */

class CharsetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/charset")
            .also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "decode") return result.notImplemented()
        val bytes = call.argument<ByteArray>("bytes")
            ?: return result.error("ARG", "bytes 缺失", null)
        val hint = (call.argument<String>("encoding") ?: "auto").lowercase(Locale.ROOT)
        try {
            // unknown / auto 时按「替换字符最少」做统计判别，避免把 Big5 猜成 GBK。
            val candidates = when (hint) {
                "big5" -> listOf("Big5")
                "gb18030" -> listOf("GB18030")
                "gbk" -> listOf("GBK")
                else -> listOf("UTF-8", "GB18030", "GBK", "Big5")
            }
            var bestName = candidates.first()
            var bestText = ""
            var bestBad = Int.MAX_VALUE
            for (name in candidates) {
                val cs = runCatching { Charset.forName(name) }.getOrNull() ?: continue
                val text = String(bytes, cs)
                val bad = text.count { it == '\uFFFD' }
                if (bad < bestBad) {
                    bestBad = bad; bestText = text; bestName = name
                }
                if (bad == 0) break
            }
            result.success(mapOf("text" to bestText, "encoding" to bestName))
        } catch (e: Throwable) {
            result.error("CHARSET", e.message, null)
        }
    }
}

/** 按句朗读：Dart 的 SentenceQueue 决定读哪句，原生读完一句回报 utteranceId。 */
class TtsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var tts: TextToSpeech? = null
    private var rate = 1.0f
    private var pitch = 1.0f

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/tts")
            .also { it.setMethodCallHandler(this) }
        tts = TextToSpeech(b.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.setSpeechRate(rate)
                tts?.setPitch(pitch)
            }
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) {
                channel?.invokeMethod(
                    "onSentenceDone", mapOf("utteranceId" to (utteranceId ?: "0"))
                )
            }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                channel?.invokeMethod(
                    "onSentenceError", mapOf("utteranceId" to (utteranceId ?: "0"))
                )
            }
        })
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        tts?.stop(); tts?.shutdown()
        tts = null; channel = null; context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val engine = tts ?: return result.error("TTS", "引擎尚未初始化", null)
        when (call.method) {
            "speak" -> {
                val sentence = call.argument<String>("sentence") ?: ""
                val utteranceId = call.argument<String>("utteranceId") ?: "0"
                val r = call.argument<Double>("rate")?.toFloat() ?: rate
                val p = call.argument<Double>("pitch")?.toFloat() ?: pitch
                engine.setSpeechRate(r); engine.setPitch(p)
                engine.speak(sentence, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                result.success(null)
            }
            "setRate" -> {
                rate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                engine.setSpeechRate(rate); result.success(null)
            }
            "setPitch" -> {
                pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat()
                engine.setPitch(pitch); result.success(null)
            }
            "pause", "stop" -> { engine.stop(); result.success(null) }
            "resume" -> { result.success(null) } // 下一句由 Dart 队列重新 speak
            "openSettings" -> {
                val intent = Intent("com.android.settings.TTS_SETTINGS")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                val ok = runCatching { context?.startActivity(intent) }.isSuccess
                if (ok) result.success(null)
                else result.error("TTS", "无法打开系统 TTS 设置", null)
            }
            else -> result.notImplemented()
        }
    }
}

/** SAF 目录授权：持久化 + ActivityResultListener 接回选择结果。 */
class SafPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    companion object {
        const val REQUEST_OPEN_TREE = 1001
        private const val PREFS = "localreader_saf"
        private const val KEY_URIS = "granted_uris"
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var pending: MethodChannel.Result? = null

    private val resultListener = PluginRegistry.ActivityResultListener { req, code, data ->
        if (req != REQUEST_OPEN_TREE) return@ActivityResultListener false
        val uri = data?.data
        if (code == Activity.RESULT_OK && uri != null) {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            runCatching {
                context?.contentResolver?.takePersistableUriPermission(uri, flags)
            }
            saveUri(uri.toString())
            pending?.success(uri.toString())
        } else {
            pending?.success(null)
        }
        pending = null
        true
    }

    private fun prefs() = context?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun grantedUris(): Set<String> =
        prefs()?.getStringSet(KEY_URIS, emptySet())?.toSet() ?: emptySet()

    private fun saveUri(uri: String) {
        val next = grantedUris().toMutableSet().apply { add(uri) }
        prefs()?.edit()?.putStringSet(KEY_URIS, next)?.apply()
    }

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/saf")
            .also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null; context = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity; binding = b
        b.addActivityResultListener(resultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) {
        onAttachedToActivity(b)
    }
    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(resultListener)
        binding = null; activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> {
                val a = activity
                    ?: return result.error("SAF", "Activity 未就绪", null)
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                pending = result
                a.startActivityForResult(intent, REQUEST_OPEN_TREE)
            }
            "persistGrant" -> {
                val raw = call.argument<String>("uri")
                    ?: return result.error("ARG", "uri 缺失", null)
                val uri = Uri.parse(raw)
                runCatching {
                    context?.contentResolver?.takePersistableUriPermission(
                        uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                }
                saveUri(raw)
                result.success(true)
            }
            "rescanPersisted" -> result.success(grantedUris().toList())
            "hasPersistedGrant" -> result.success(grantedUris().isNotEmpty())
            else -> result.notImplemented()
        }
    }
}

/** 导出到本地 + 系统分享；文件写在应用私有目录，不需要额外存储权限。 */
class SharePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null

    private fun outDir(): File {
        val base = context?.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
            ?: File(context?.filesDir, "exports")
        return File(base, "LocalReader").apply { mkdirs() }
    }

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/share")
            .also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null; context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "saveText" -> {
                    val name = call.argument<String>("name") ?: "export.txt"
                    val text = call.argument<String>("text") ?: ""
                    val file = File(outDir(), sanitize(name))
                    file.writeText(text, Charsets.UTF_8)
                    result.success(file.absolutePath)
                }
                "saveImage" -> {
                    val name = call.argument<String>("name") ?: "image.png"
                    val bytes = call.argument<ByteArray>("bytes")
                        ?: return result.error("ARG", "bytes 缺失", null)
                    val file = File(outDir(), sanitize(name))
                    FileOutputStream(file).use { it.write(bytes) }
                    result.success(file.absolutePath)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context?.startActivity(Intent.createChooser(intent, "分享").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("SHARE", e.message, null)
        }
    }

    private fun sanitize(name: String) =
        name.replace(Regex("[/\\\\:*?\"<>|]"), "_").ifEmpty { "export.txt" }
}

/** 字体目录 / 语音模型 / 小组件数据推送。 */
class FontsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/fonts")
            .also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null; context = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "list" -> {
                val names = mutableListOf<String>()
                runCatching {
                    File("/system/fonts").listFiles()?.forEach { names.add(it.nameWithoutExtension) }
                }
                result.success(names.distinct())
            }
            "load" -> {
                val path = call.argument<String>("path") ?: ""
                // 字体字节由 Flutter 侧 FontLoader 使用；这里把文件复制到私有目录并返回路径。
                val src = File(path)
                if (!src.exists()) return result.error("FONT", "字体文件不存在：$path", null)
                val dst = File(context?.filesDir, "fonts/${src.name}").apply { parentFile?.mkdirs() }
                src.copyTo(dst, overwrite = true)
                result.success(dst.absolutePath)
            }
            else -> result.notImplemented()
        }
    }
}

class VoicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var tts: TextToSpeech? = null
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/voice")
            .also { it.setMethodCallHandler(this) }
        tts = TextToSpeech(b.applicationContext) {}
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        tts?.shutdown(); tts = null; channel = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "models" -> {
                val names = runCatching {
                    tts?.voices?.map { "${it.locale.toLanguageTag()} · ${it.name}" } ?: emptyList()
                }.getOrDefault(emptyList())
                result.success(names)
            }
            else -> result.notImplemented()
        }
    }
}

class WidgetsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private fun prefs() = context?.getSharedPreferences("localreader_widgets", Context.MODE_PRIVATE)
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/widgets")
            .also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null; context = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: ""
        when (call.method) {
            "update" -> {
                val payload = call.argument<Map<String, Any?>>("payload") ?: emptyMap()
                val json = JSONObject()
                payload.forEach { (k, v) -> json.put(k, v ?: JSONObject.NULL) }
                prefs()?.edit()?.putString(id, json.toString())?.apply()
                // 通知桌面小组件刷新；AppWidgetProvider 在真机侧读取同一份 JSON。
                context?.sendBroadcast(Intent("com.demo.localreader.WIDGET_UPDATE").apply {
                    putExtra("id", id)
                })
                result.success(null)
            }
            "remove" -> {
                prefs()?.edit()?.remove(id)?.apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}

/** 递归列目录 + 读字节：同时兼容 SAF content:// 与普通绝对路径。 */
class FilesPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/files")
            .also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null; context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "list" -> {
                    val root = call.argument<String>("uri") ?: ""
                    val exts = call.argument<List<String>>("exts") ?: emptyList()
                    result.success(walk(root, exts.map { it.lowercase(Locale.ROOT) }.toSet()))
                }
                "readBytes" -> {
                    val p = call.argument<String>("path") ?: ""
                    val bytes = if (p.startsWith("content://")) {
                        context?.contentResolver?.openInputStream(Uri.parse(p))?.use { it.readBytes() }
                    } else {
                        File(p).takeIf { it.exists() }?.readBytes()
                    }
                    if (bytes == null) result.error("FILES", "无法读取：$p", null)
                    else result.success(bytes)
                }
                "size" -> {
                    val p = call.argument<String>("path") ?: ""
                    val size = if (p.startsWith("content://")) {
                        context?.contentResolver?.openInputStream(Uri.parse(p))?.use { it.available() } ?: 0
                    } else {
                        File(p).takeIf { it.exists() }?.length()?.toInt() ?: 0
                    }
                    result.success(size)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("FILES", e.message, null)
        }
    }

    private fun walk(root: String, exts: Set<String>): List<String> {
        val out = mutableListOf<String>()
        if (root.startsWith("content://")) {
            val tree = DocumentFile.fromTreeUri(context!!, Uri.parse(root)) ?: return out
            collectTree(tree, exts, out)
        } else {
            val dir = File(root)
            if (!dir.exists()) return out
            dir.walkTopDown().maxDepth(8).forEach { f ->
                if (f.isFile && exts.contains(f.extension.lowercase(Locale.ROOT))) {
                    out.add(f.absolutePath)
                }
            }
        }
        return out.distinct().sorted()
    }

    private fun collectTree(dir: DocumentFile, exts: Set<String>, out: MutableList<String>, depth: Int = 0) {
        if (depth > 8) return
        for (child in dir.listFiles()) {
            if (child.isDirectory) {
                collectTree(child, exts, out, depth + 1)
            } else if (child.isFile) {
                val name = child.name ?: continue
                val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
                if (exts.isEmpty() || exts.contains(ext)) out.add(child.uri.toString())
            }
        }
    }
}

/** 设备能力探测 / 屏幕常亮。 */
class DevicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/device")
            .also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null); channel = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capability" -> {
                val act = android.app.ActivityManager.MemoryInfo()
                (context()?.getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager)
                    ?.getMemoryInfo(act)
                result.success(mapOf(
                    "ramMB" to (act.totalMem / (1024 * 1024)),
                    "cores" to Runtime.getRuntime().availableProcessors(),
                    "maxRefreshHz" to 60,
                    "tier" to "unknown",
                    "platformLabel" to "Android ${Build.VERSION.RELEASE}"
                ))
            }
            "setScreenOn" -> result.success(null) // 由 Flutter 侧 Wakelock / FlutterActivity window flag 处理
            else -> result.notImplemented()
        }
    }
    private fun context(): Context? = appContext
    companion object { var appContext: Context? = null }
}

/** SQLite 执行器：schema.dart 的 5 条迁移 SQL 由 Dart 侧下发，这里只负责执行。 */
class DatabasePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var db: SQLiteDatabase? = null
    private var inTransaction = false

    private fun open(): SQLiteDatabase {
        val current = db
        if (current != null && current.isOpen) return current
        val helper = object : SQLiteOpenHelper(context, "localreader.db", null, 5) {
            override fun onCreate(d: SQLiteDatabase) { /* Dart 侧 migrateDatabase 建表 */ }
            override fun onUpgrade(d: SQLiteDatabase, old: Int, new: Int) { /* 同上 */ }
        }
        db = helper.writableDatabase
        return db!!
    }

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        DevicePlugin.appContext = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "com.demo.localreader/database")
            .also { it.setMethodCallHandler(this) }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        db?.close(); db = null; channel = null; context = null
    }

    private fun bind(args: List<Any?>): Array<Any?> = args.map {
        when (it) {
            null -> null
            is Number -> it.toString()
            is Boolean -> if (it) "1" else "0"
            else -> it.toString()
        }
    }.toTypedArray()

    private fun bindStrings(args: List<Any?>): Array<String> =
        args.map { it?.toString() ?: "" }.toTypedArray()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val d = open()
            when (call.method) {
                "userVersion" -> {
                    val c: Cursor = d.rawQuery("PRAGMA user_version", null)
                    c.use { result.success(if (it.moveToFirst()) it.getInt(0) else 0) }
                }
                "setUserVersion" -> {
                    d.execSQL("PRAGMA user_version = ${call.argument<Int>("version") ?: 0}")
                    result.success(null)
                }
                "execute" -> {
                    val sql = call.argument<String>("sql") ?: ""
                    val args = call.argument<List<Any?>>("args") ?: emptyList()
                    d.execSQL(sql, bind(args))
                    result.success(null)
                }
                "query" -> {
                    val sql = call.argument<String>("sql") ?: ""
                    val args = call.argument<List<Any?>>("args") ?: emptyList()
                    val c: Cursor = d.rawQuery(sql, bindStrings(args))
                    c.use { cur ->
                        val rows = mutableListOf<Map<String, Any?>>()
                        val cols = cur.columnNames
                        while (cur.moveToNext()) {
                            val row = mutableMapOf<String, Any?>()
                            for (i in cols.indices) {
                                row[cols[i]] = when (cur.getType(i)) {
                                    Cursor.FIELD_TYPE_INTEGER -> cur.getLong(i)
                                    Cursor.FIELD_TYPE_FLOAT -> cur.getDouble(i)
                                    Cursor.FIELD_TYPE_BLOB -> cur.getBlob(i)
                                    Cursor.FIELD_TYPE_NULL -> null
                                    else -> cur.getString(i)
                                }
                            }
                            rows.add(row)
                        }
                        result.success(rows)
                    }
                }
                "begin" -> { d.beginTransaction(); inTransaction = true; result.success(null) }
                "commit" -> {
                    if (inTransaction) { d.setTransactionSuccessful(); d.endTransaction(); inTransaction = false }
                    result.success(null)
                }
                "rollback" -> {
                    if (inTransaction) { d.endTransaction(); inTransaction = false }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("DB", e.message, null)
        }
    }
}
