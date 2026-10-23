package com.demo.core.model


/**
 * 朗读音色（预设）。
 *
 * 说明：系统 TextToSpeech 不提供音色包下载能力，这里的"音色"是通过
 * **音调 + 语速**组合模拟的听感差异，不产生任何网络请求、不下载语音包。
 * 真正换发声人需使用系统已安装语音（见 [AppSettings.ttsVoiceName]），
 * 缺失时由用户自行到系统「文字转语音」设置里下载。
 */
enum class TtsTimbre(val value: String, val label: String, val pitch: Float, val rate: Float) {
  DEFAULT("DEFAULT", "默认", 1.0f, 1.0f),
  GIRL("GIRL", "少女音", 1.35f, 1.0f),
  LOLI("LOLI", "萝莉音", 1.7f, 1.08f),
  WOMAN("WOMAN", "成熟女声", 1.1f, 0.98f),
  MAN("MAN", "成熟男声", 0.75f, 0.95f);

  companion object {
    fun from(value: String?): TtsTimbre =
      entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: DEFAULT
  }
}

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

/** 系统可用语音（供听读设置里选择；语音包由用户在系统设置中下载） */
data class TtsVoice(
  val name: String,
  val displayName: String,
  val locale: String = "",
  val quality: Int = 0
)