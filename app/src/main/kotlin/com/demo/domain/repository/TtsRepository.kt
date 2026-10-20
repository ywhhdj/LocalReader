package com.demo.domain.repository

import kotlinx.coroutines.flow.StateFlow

data class TtsState(
    val available: Boolean = false,
    val speaking: Boolean = false,
    /** 当前朗读分片序号（1 起） */
    val chunkIndex: Int = 0,
    val chunkCount: Int = 0,
    val error: String? = null
) {
    val progressText: String
        get() = if (chunkCount > 0) "$chunkIndex/$chunkCount" else ""
}

/**
 * 朗读引擎（TTS）。实现位于 data 层（Android TextToSpeech），
 * 上层只依赖本接口，便于替换/关闭。
 */
interface TtsEngine {

    val state: StateFlow<TtsState>

    /** 朗读整段文本（内部自动分句） */
    suspend fun speak(text: String): Boolean

    /** 按句子列表朗读，便于 UI 展示进度 */
    suspend fun speakSentences(sentences: List<String>): Boolean

    fun pause()

    fun resume()

    fun stop()

    /** 语速 0.5 ~ 2.0 */
    fun setRate(rate: Float)

    /** 音调 0.5 ~ 2.0 */
    fun setPitch(pitch: Float)

    /** 释放引擎（应用退出/不再朗读时调用） */
    fun shutdown()
}
