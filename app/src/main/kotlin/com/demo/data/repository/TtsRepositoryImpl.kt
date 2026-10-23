package com.demo.data.repository

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

import java.util.Locale

import com.demo.core.model.TtsState
import com.demo.core.model.TtsVoice

import com.demo.domain.repository.TtsRepository

/**
 * 系统 TextToSpeech 封装
 *
 * 线程模型：
 * - 引擎跑在独立的 [HandlerThread] 上：初始化、speak、stop 全部 post 到该线程；
 *   此前这些调用都在主线程，首次点击「朗读」时引擎加载 + 语音校验会直接卡住 UI。
 * - 分句（正则处理整章几万字）放在 [Dispatchers.Default]，不再占渲染线程。
 * - 回调在引擎线程触发，只做 StateFlow 赋值（线程安全），不再跨线程切回主线程写状态。
 *
 * 其他能力：
 * - 自动分句，逐句入队，UI 可显示 x/y 进度
 * - 优先中文语音，缺失时回退系统默认语言
 * - TextToSpeech 无 pause API：暂停用 stop + 从当前句续播实现
 * - 音色预设（core.model.TtsTimbre）：以音调/语速组合模拟听感，不下载任何语音包
 */
class TtsRepositoryImpl(context: Context) : TtsRepository {

    private val appContext = context.applicationContext
    private var tts: TextToSpeech? = null

    @Volatile
    private var ready = false

    private val _state = MutableStateFlow(TtsState())
    override val state: StateFlow<TtsState> = _state.asStateFlow()

    private var sentences: List<String> = emptyList()
    private var cursor = 0
    private var rate = 1.0f
    private var pitch = 1.0f
    private var voiceName: String = ""

    /**
     * 引擎专属线程：TextToSpeech 的初始化回调需要 Looper，
     * 用独立 HandlerThread 既满足要求，又不占用主线程。
     */
    private val engineThread = HandlerThread("tts-engine").apply { start() }
    private val engineHandler = Handler(engineThread.looper)

    /** 在引擎线程执行；已在引擎线程则直接执行，避免多余的 post 延迟 */
    private fun onEngine(block: () -> Unit) {
        if (Looper.myLooper() == engineThread.looper) {
            runCatching(block)
        } else {
            engineHandler.post { runCatching(block) }
        }
    }

    private val listener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {
            _state.value = _state.value.copy(speaking = true, chunkIndex = cursor + 1)
        }

        override fun onDone(utteranceId: String?) {
            cursor++
            if (cursor >= sentences.size) {
                _state.value = _state.value.copy(speaking = false, chunkIndex = sentences.size)
            } else {
                _state.value = _state.value.copy(chunkIndex = cursor + 1)
            }
        }

        override fun onError(utteranceId: String?) {
            _state.value = _state.value.copy(speaking = false, error = "朗读出错")
        }

        override fun onError(utteranceId: String?, errorCode: Int) {
            _state.value = _state.value.copy(speaking = false, error = "朗读出错($errorCode)")
        }
    }

    init {
        // 初始化也放到引擎线程：构造 TextToSpeech 会绑定服务并校验语音数据，耗时明显
        onEngine(::initEngine)
    }

    private fun initEngine() {
        tts = TextToSpeech(appContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val engine = tts
                if (engine != null) {
                    val result = runCatching { engine.setLanguage(Locale.SIMPLIFIED_CHINESE) }.getOrDefault(0)
                    if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                        runCatching { engine.setLanguage(Locale.getDefault()) }
                    }
                    engine.setOnUtteranceProgressListener(listener)
                    engine.setSpeechRate(rate)
                    engine.setPitch(pitch)
                    // 恢复上次选择的系统语音（如仍在已安装列表里）
                    if (voiceName.isNotBlank()) applyVoice(engine, voiceName)
                }
                ready = true
                _state.value = _state.value.copy(available = true, error = null)
            } else {
                _state.value = TtsState(available = false, error = "初始化失败($status)")
            }
        }
    }

    /** 预热：进入阅读器时调用，避免首次点击朗读才初始化造成卡顿 */
    override fun prewarm() {
        if (ready) return
        onEngine {
            if (tts == null) initEngine()
        }
    }

    override suspend fun speak(text: String): Boolean {
        // 分句是纯 CPU + 正则，整章几万字在主线程会明显掉帧 → 放到 Default
        val list = withContext(Dispatchers.Default) { splitSentences(text) }
        return speakSentences(list)
    }

    override suspend fun speakSentences(list: List<String>): Boolean {
        if (list.isEmpty()) return false
        val engine = awaitEngine() ?: run {
            _state.value = _state.value.copy(error = "TTS 未就绪")
            return false
        }
        sentences = list
        cursor = 0
        _state.value = _state.value.copy(speaking = true, chunkIndex = 1, chunkCount = list.size, error = null)
        onEngine { enqueue(engine, 0) }
        return true
    }

    private fun enqueue(engine: TextToSpeech, from: Int) {
        val params = Bundle()
        // 批量入队一次性 post 完成：逐句 post 会产生几百个 Runnable，白白占用引擎线程
        for (i in from until sentences.size) {
            params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "chunk-$i")
            engine.speak(sentences[i], TextToSpeech.QUEUE_ADD, params, "chunk-$i")
        }
    }

    override fun pause() {
        // 系统 TTS 没有暂停：停掉队列，resume 时从当前句继续
        stop()
    }

    override fun resume() {
        val engine = tts ?: return
        if (sentences.isEmpty()) return
        cursor = cursor.coerceIn(0, sentences.lastIndex)
        onEngine { enqueue(engine, cursor) }
        _state.value = _state.value.copy(speaking = true)
    }

    override fun stop() {
        onEngine { tts?.stop() }
        _state.value = _state.value.copy(speaking = false)
    }

    override fun setRate(value: Float) {
        rate = value.coerceIn(0.5f, 2.0f)
        onEngine { tts?.setSpeechRate(rate) }
    }

    override fun setPitch(value: Float) {
        pitch = value.coerceIn(0.5f, 2.0f)
        onEngine { tts?.setPitch(pitch) }
    }

    override fun availableVoices(): List<TtsVoice> {
        val engine = tts ?: return emptyList()
        if (!ready) return emptyList()
        return runCatching {
            val voices: Set<Voice>? = engine.voices
            voices?.map { v ->
                TtsVoice(
                    name = v.name,
                    displayName = buildDisplayName(v),
                    locale = runCatching { v.locale.toLanguageTag() }.getOrDefault(v.locale.toString()),
                    quality = v.quality
                )
            }?.sortedBy { it.displayName } ?: emptyList()
        }.getOrDefault(emptyList())
    }

    private fun buildDisplayName(v: Voice): String {
        val lang = runCatching { v.locale.getDisplayName(Locale.SIMPLIFIED_CHINESE) }
            .getOrDefault(v.locale.toString())
        val name = v.name.substringAfterLast('/').substringAfterLast('-')
        return "$lang · $name"
    }

    override fun setVoice(name: String) {
        voiceName = name
        onEngine { tts?.let { applyVoice(it, name) } }
    }

    private fun applyVoice(engine: TextToSpeech, name: String) {
        if (name.isBlank()) return
        val target = runCatching { engine.voices }.getOrNull()
            ?.firstOrNull { it.name == name } ?: return
        runCatching { engine.setVoice(target) }
    }

    override fun openSystemSettings() {
        runCatching { 
            runCatching {
                appContext.startActivity(
                    Intent("com.android.settings.TTS_SETTINGS")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }
    }

    override fun launchTtsSettings() {
        runCatching {
            appContext.startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    override fun shutdown() {
        onEngine {
            tts?.stop()
            tts?.shutdown()
            tts = null
            ready = false
        }
        _state.value = TtsState()
    }

    /** 释放引擎线程（进程结束时可不调用；供容器显式回收） */
    fun releaseThread() {
        runCatching { engineThread.quitSafely() }
    }

    private suspend fun awaitEngine(): TextToSpeech? {
        if (ready) return tts
        // 等待初始化（最多 3 秒）。等待发生在调用方协程里，不阻塞任何线程
        var waited = 0
        while (!ready && waited < 3000) {
            delay(50)
            waited += 50
        }
        return if (ready) tts else null
    }

    /** 按标点分句，超长句再按 120 字切分，避免单条过长被截断 */
    private fun splitSentences(text: String): List<String> {
        if (text.isBlank()) return emptyList()
        val normalized = text.replace("\r", "").replace(Regex("""\n{2,}"""), "\n")
        val raw = Regex("""(?<=[。！？!?；;…\n])""").split(normalized)
            .map { it.trim() }
            .filter { it.isNotBlank() }
        val result = ArrayList<String>((raw.size * 1.2).toInt().coerceAtLeast(16))
        raw.forEach { sentence ->
            if (sentence.length <= 120) {
                result.add(sentence)
            } else {
                var i = 0
                while (i < sentence.length) {
                    result.add(sentence.substring(i, (i + 120).coerceAtMost(sentence.length)))
                    i += 120
                }
            }
        }
        return result
    }
}
