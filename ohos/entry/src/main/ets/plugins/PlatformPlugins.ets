import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodResult, MethodChannel } from '@ohos/flutter_ohos';
import { util } from '@kit.ArkTS';

/** CharsetBridge.nativeFallback 的鸿蒙实现：GBK / GB18030 / Big5 解码。 */
export class CharsetPlugin implements FlutterPlugin, MethodCallHandler {
  private channel?: MethodChannel;
  getUniqueClassName(): string { return 'CharsetPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.demo.localreader/charset');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'decode') { result.notImplemented(); return; }
    const args = call.args as Record<string, Object>;
    const bytes = args['bytes'] as Uint8Array;
    const hint = (args['encoding'] as string ?? 'unknown').toLowerCase();
    // TODO(P2): unknown 时做统计判别，避免把 Big5 猜成 GBK
    const label = hint === 'big5' ? 'big5' : hint === 'gb18030' ? 'gb18030' : 'gbk';
    try {
      const decoder = util.TextDecoder.create(label);
      result.success({ text: decoder.decodeToString(bytes), encoding: label });
    } catch (e) {
      result.error('CHARSET', String(e), null);
    }
  }
}

/**
 * TTS：Dart 侧 SentenceQueue 决定读哪一句，ArkTS 只负责读一句并回报完成。
 * 平台差异全部收口在 plugins/，禁止把 Platform.isOhos 判断散进 Dart 业务页面。
 */
export class TtsPlugin implements FlutterPlugin, MethodCallHandler {
  private channel?: MethodChannel;
  getUniqueClassName(): string { return 'TtsPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.demo.localreader/tts');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const args = call.args as Record<string, Object>;
    switch (call.method) {
      case 'speak':
        // TODO(P2): 系统 TTS Kit 按句朗读；完成后 channel.invokeMethod('onSentenceDone')
        break;
      case 'setRate':
      case 'setPitch':
      case 'pause':
      case 'stop':
        break;
      default:
        result.notImplemented();
        return;
    }
    result.success(null);
  }
}

/** 插件注册表：EntryAbility 在此统一挂载，别把逻辑堆进同一个原生文件。 */
import { RenderPlugin } from './RenderPlugin';
export const kLocalReaderPlugins: FlutterPlugin[] = [
  new RenderPlugin(),
  new CharsetPlugin(),
  new TtsPlugin(),
];
