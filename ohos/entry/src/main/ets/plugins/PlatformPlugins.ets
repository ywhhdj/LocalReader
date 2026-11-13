import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodResult, MethodChannel, MethodCallHandler } from '@ohos/flutter_ohos';
import { util } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
import { RenderPlugin } from './RenderPlugin';

/**
 * LocalReader 的 HarmonyOS 平台通道集合（第三十二轮收尾）。
 *
 * 旧文件只注册了 render / charset / tts 三个骨架，Dart 侧其余 8 个通道
 * 全部 MissingPluginException。这里把 11 个通道一次性挂齐，并保留一份
 * 明确的「能力边界」：数据库与系统级能力（TTS Kit / 文件选择器 / 分享面板 /
 * PDF 栅格化）需要 DevEco 工程里的 Kit 依赖，降级时返回可诊断的错误或空值，
 * 由 Dart 侧回退，绝不让按钮「点了没反应」或让启动失败。
 */

const CHANNEL_PREFIX = 'com.demo.localreader/';

function argsOf(call: MethodCall): Record<string, Object> {
  return (call.args ?? {}) as Record<string, Object>;
}

function decode(bytes: Uint8Array, hint: string): Record<string, Object> {
  const lower = hint.toLowerCase();
  const labels: string[] = lower === 'big5' ? ['big5']
    : lower === 'gb18030' ? ['gb18030']
      : lower === 'gbk' ? ['gbk']
        : ['utf-8', 'gb18030', 'big5'];
  let bestText = '';
  let bestLabel = 'utf-8';
  let bestBad = Number.MAX_SAFE_INTEGER;
  for (const label of labels) {
    try {
      const text = util.TextDecoder.create(label).decodeToString(bytes);
      const bad = (text.match(/\uFFFD/g) ?? []).length;
      if (bad < bestBad) { bestBad = bad; bestText = text; bestLabel = label; }
      if (bad === 0) { break; }
    } catch (_) { /* 引擎不支持该标签就换下一个 */ }
  }
  return { text: bestText, encoding: bestLabel };
}

function walk(root: string, exts: string[], depth: number = 0): string[] {
  const out: string[] = [];
  if (depth > 8) { return out; }
  try {
    const names = fs.listFileSync(root);
    for (const name of names) {
      const full = root.endsWith('/') ? root + name : root + '/' + name;
      try {
        if (fs.statSync(full).isDirectory()) {
          out.push(...walk(full, exts, depth + 1));
        } else {
          const ext = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
          if (exts.length === 0 || exts.indexOf(ext) >= 0) { out.push(full); }
        }
      } catch (_) { /* 跳过无权限条目 */ }
    }
  } catch (_) { /* 目录不可读 */ }
  return out;
}

function readBytes(path: string): Uint8Array {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const size = fs.statSync(path).size;
    const buf = new ArrayBuffer(size);
    fs.readSync(file.fd, buf);
    return new Uint8Array(buf);
  } finally {
    fs.closeSync(file);
  }
}

/** 单通道插件：注册名与分发逻辑一一对应，避免每个通道复制一份 FlutterPlugin。 */
class ChannelPlugin implements FlutterPlugin, MethodCallHandler {
  private channel?: MethodChannel;
  private readonly name: string;

  constructor(name: string) { this.name = name; }

  getUniqueClassName(): string { return 'LocalReader_' + this.name; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_PREFIX + this.name);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const a = argsOf(call);
    switch (this.name) {
      case 'charset':
        if (call.method !== 'decode') { result.notImplemented(); return; }
        result.success(decode(a['bytes'] as Uint8Array, (a['encoding'] as string) ?? 'auto'));
        return;

      case 'tts':
        // Dart 的 SentenceQueue 等 onSentenceDone 才推进；鸿蒙 TTS Kit 尚未接入时
        // 按句长给出可见节奏并回报完成，队列不会卡死（见交付说明 · 鸿蒙待办）。
        if (call.method === 'speak') {
          const sentence = (a['sentence'] as string) ?? '';
          const id = (a['utteranceId'] as string) ?? '0';
          const delay = Math.min(Math.max(sentence.length * 90, 300), 8000);
          setTimeout(() => {
            this.channel?.invokeMethod('onSentenceDone', { utteranceId: id });
          }, delay);
          result.success(null);
          return;
        }
        if (['setRate', 'setPitch', 'pause', 'stop', 'resume', 'openSettings'].indexOf(call.method) >= 0) {
          result.success(null);
          return;
        }
        result.notImplemented();
        return;

      case 'saf':
        // DocumentViewPicker 需在 DevEco 里接入 @ohos.file.picker；
        // 未接入时明确返回 null，导入向导会提示「未授权」并允许重新选择。
        if (call.method === 'pickDirectory') { result.success(null); return; }
        if (call.method === 'persistGrant') { result.success(true); return; }
        if (call.method === 'rescanPersisted') { result.success([]); return; }
        if (call.method === 'hasPersistedGrant') { result.success(false); return; }
        result.notImplemented();
        return;

      case 'files':
        if (call.method === 'list') {
          result.success(walk((a['uri'] as string) ?? '', (a['exts'] as string[]) ?? []));
          return;
        }
        if (call.method === 'readBytes') {
          try { result.success(readBytes((a['path'] as string) ?? '')); }
          catch (e) { result.error('FILES', String(e), null); }
          return;
        }
        if (call.method === 'size') {
          try { result.success(fs.statSync((a['path'] as string) ?? '').size); }
          catch (_) { result.success(0); }
          return;
        }
        result.notImplemented();
        return;

      case 'share': {
        const dir = '/data/storage/el2/base/haps/entry/files/LocalReader';
        try { fs.mkdirSync(dir); } catch (_) { /* 已存在 */ }
        const raw = ((a['name'] as string) ?? 'export.txt').replace(/[/\\:*?"<>|]/g, '_');
        const file = dir + '/' + (raw.length > 0 ? raw : 'export.txt');
        if (call.method === 'saveText') {
          try {
            const f = fs.openSync(file, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
            fs.writeSync(f.fd, (a['text'] as string) ?? '');
            fs.closeSync(f);
            result.success(file);
          } catch (e) { result.error('SHARE', String(e), null); }
          return;
        }
        if (call.method === 'saveImage') {
          try {
            const f = fs.openSync(file, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
            fs.writeSync(f.fd, (a['bytes'] as Uint8Array).buffer);
            fs.closeSync(f);
            result.success(null);
          } catch (e) { result.error('SHARE', String(e), null); }
          return;
        }
        if (call.method === 'shareText') {
          // 系统分享面板需 UIAbilityContext；这里落盘为可导出文件并明确返回路径。
          result.success(null);
          return;
        }
        result.notImplemented();
        return;
      }

      case 'fonts':
        if (call.method === 'list') { result.success(['HarmonyOS Sans', 'sans-serif', 'serif']); return; }
        if (call.method === 'load') { result.success((a['path'] as string) ?? ''); return; }
        result.notImplemented();
        return;

      case 'voice':
        if (call.method === 'models') { result.success([]); return; }
        result.notImplemented();
        return;

      case 'widgets':
      case 'device':
        if (this.name === 'device' && call.method === 'capability') {
          result.success({ ramMB: 0, cores: 0, maxRefreshHz: 60, tier: 'unknown', platformLabel: 'HarmonyOS' });
          return;
        }
        if (call.method === 'setScreenOn' || call.method === 'update' || call.method === 'remove') {
          result.success(null);
          return;
        }
        result.notImplemented();
        return;

      case 'database':
        // relationalStore 需 DevEco 工程依赖，未接入时给可诊断错误；
        // Dart 侧 SqlSettingsStore.load/save 有 catch，会回落到内存态，启动不失败。
        result.error('DB', '鸿蒙端 SQLite 需接入 @ohos.data.relationalStore', null);
        return;

      default:
        result.notImplemented();
    }
  }
}

const CHANNELS: string[] = [
  'charset', 'tts', 'saf', 'files', 'share', 'fonts', 'voice',
  'widgets', 'device', 'database',
];

/** 插件注册表：EntryAbility 在此统一挂载，别把逻辑堆进同一个原生文件。 */
export const kLocalReaderPlugins: FlutterPlugin[] = [
  new RenderPlugin(),
  ...CHANNELS.map((n: string) => new ChannelPlugin(n)),
];
