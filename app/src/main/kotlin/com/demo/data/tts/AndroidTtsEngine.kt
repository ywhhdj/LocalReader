package com.demo.data.tts

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener

import com.demo.domain.repository.TtsEngine
import com.demo.domain.repository.TtsState

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

import java.util.Locale

/**
 * 系统 TextToSpeech 封装（零第三方依赖）。
 * - 自动分句，逐句入队，UI 可显示 x/y 进度
 * - 优先中文语音，缺失时回退系统默认语言
 * - TextToSpeech 无 pause API：暂停用 stop + 从当前句续播实现
 */
class AndroidTtsEngine(context: Context) : TtsEngine {

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
        runCatching { initEngine() }.onFailure {
            _state.value = TtsState(available = false, error = "TTS 不可用")
        }
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
                }
                ready = true
                _state.value = _state.value.copy(available = true, error = null)
            } else {
                _state.value = TtsState(available = false, error = "初始化失败($status)")
            }
        }
    }

    override suspend fun speak(text: String): Boolean = speakSentences(splitSentences(text))

    override suspend fun speakSentences(list: List<String>): Boolean {
        val engine = awaitEngine() ?: run {
            _state.value = _state.value.copy(error = "TTS 未就绪")
            return false
        }
        if (list.isEmpty()) return false
        sentences = list
        cursor = 0
        _state.value = _state.value.copy(speaking = true, chunkIndex = 1, chunkCount = list.size, error = null)
        enqueue(engine, 0)
        return true
    }

    private fun enqueue(engine: TextToSpeech, from: Int) {
        val params = Bundle()
        for (i in from until sentences.size) {
            params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "chunk-$i")
            engine.speak(sentences[i], TextToSpeech.QUEUE_ADD, params, "chunk-$i")
        }
    }

    override fun pause() {
        stop()
    }

    override fun resume() {
        val engine = tts ?: return
        if (sentences.isEmpty()) return
        cursor = cursor.coerceIn(0, sentences.lastIndex)
        enqueue(engine, cursor)
        _state.value = _state.value.copy(speaking = true)
    }

    override fun stop() {
        runCatching { tts?.stop() }
        _state.value = _state.value.copy(speaking = false)
    }

    override fun setRate(value: Float) {
        rate = value.coerceIn(0.5f, 2.0f)
        runCatching { tts?.setSpeechRate(rate) }
    }

    override fun setPitch(value: Float) {
        pitch = value.coerceIn(0.5f, 2.0f)
        runCatching { tts?.setPitch(pitch) }
    }

    override fun shutdown() {
        runCatching {
            tts?.stop()
            tts?.shutdown()
        }
        tts = null
        ready = false
        _state.value = TtsState()
    }

    private suspend fun awaitEngine(): TextToSpeech? {
        if (ready) return tts
        // 等待初始化（最多 3 秒）
        var waited = 0
        while (!ready && waited < 3000) {
            delay(100)
            waited += 100
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
        val result = ArrayList<String>()
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
