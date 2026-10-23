package com.demo.domain.repository

import kotlinx.coroutines.flow.StateFlow

import com.demo.core.model.TtsState
import com.demo.core.model.TtsVoice

/**
 * 朗读引擎（TTS）。实现位于 data 层（Android TextToSpeech），
 * 上层只依赖本接口，便于替换/关闭。
 */
interface TtsRepository {

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

    /**
     * 提前初始化引擎。
     * 首次点击「朗读」才初始化会明显卡顿（引擎加载 + 语音数据校验），
     * 建议在进入阅读器时就预热。
     */
    fun prewarm()

    /**
     * 系统已安装的语音列表（未安装语音不会出现在列表里）。
     *
     * 必须是 suspend：引擎初始化在独立线程上进行，进入设置页时往往还没 ready，
     * 同步调用只会拿到空列表（表现为"点了选择却没有列表"）。
     * 实现内部会等待引擎就绪（有超时），不会阻塞调用线程。
     */
    suspend fun availableVoices(): List<TtsVoice>

    /** 引擎是否已就绪（用于 UI 决定是否显示"正在检测"） */
    fun isReady(): Boolean

    /** 选择系统语音；空串表示恢复系统默认 */
    fun setVoice(name: String)

    /** 跳转系统「文字转语音」设置：语音包下载由用户在该处完成 */
    fun openSystemSettings()

    /** 同上：专门用于"去下载语音"入口，落到 TTS 设置页而不是系统设置首页 */
    fun launchTtsSettings()

    /** 释放引擎（应用退出/不再朗读时调用） */
    fun shutdown()
}
