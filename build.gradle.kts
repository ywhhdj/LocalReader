// 根工程：统一声明插件与依赖版本
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("com.google.devtools.ksp") version "2.0.21-1.0.25" apply false
}

// 依赖版本集中管理
extra["versions"] = mapOf(
    "compileSdk" to 34,
    "minSdk" to 26,
    "targetSdk" to 34,
    "composeBom" to "2024.09.03",
    "coreKtx" to "1.13.1",
    "activityCompose" to "1.9.1",
    "lifecycle" to "2.8.6",
    "navigation" to "2.8.4",
    "room" to "2.6.1",
    "datastore" to "1.1.1",
    "coil" to "2.6.0",
    "coroutines" to "1.8.1"
)
