package com.demo.localreader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 第三十二轮：此前 MainActivity 没有注册任何插件，Dart 侧所有 MethodChannel
 * 调用都会落到 MissingPluginException —— 这正是「朗读 / 导入 / 备份 / 渲染
 * 点了没反应」的根因。这里一次性把十个通道全部挂上。
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val registry = flutterEngine.plugins
        registry.add(RenderPlugin())
        registry.add(CharsetPlugin())
        registry.add(TtsPlugin())
        registry.add(SafPlugin())
        registry.add(SharePlugin())
        registry.add(FontsPlugin())
        registry.add(VoicePlugin())
        registry.add(WidgetsPlugin())
        registry.add(FilesPlugin())
        registry.add(DevicePlugin())
        registry.add(DatabasePlugin())
    }
}
