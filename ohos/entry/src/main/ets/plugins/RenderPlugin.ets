import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodResult, MethodChannel, MethodCallHandler } from '@ohos/flutter_ohos';
import fs from '@ohos.file.fs';

/**
 * BookRenderBridge 的 HarmonyOS 侧实现（第三十二轮收尾）。
 *
 * 旧骨架 import 了仓库里并不存在的 './NativeTexture'，工程根本编译不过；
 * 且 pageCount() 恒为 0、renderToTexture() 只建空纹理不画帧，Dart 侧会黑屏。
 *
 * 这里改成与 Android/iOS 一致的「字节直通」协议：原生按 index 给出图片字节，
 * Dart 侧 Image.memory 解码，不引入 PDFium / XComponent / 外部纹理。
 * 支持图片文件夹、单张图片；PDF 与 CBZ/ZIP 的鸿蒙原生解码器需 DevEco 环境
 * 接入后替换 openDoc()，当前返回带明确原因的 UNSUPPORTED，不再假装能读。
 */
export class RenderPlugin implements FlutterPlugin, MethodCallHandler {
  private channel?: MethodChannel;
  private handles: Map<number, DocumentHandle> = new Map();
  private nextHandle: number = 1;

  getUniqueClassName(): string { return 'RenderPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.demo.localreader/render');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.handles.clear();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const args = call.args as Record<string, Object>;
    const handle = (args['handle'] as number) ?? -1;
    try {
      switch (call.method) {
        case 'open': {
          const path = args['localPath'] as string;
          const h = this.nextHandle++;
          this.handles.set(h, new DocumentHandle(path));
          result.success(h);
          break;
        }
        case 'pageCount':
          result.success(this.handles.get(handle)?.pageCount() ?? 0);
          break;
        case 'pageInfo': {
          const d = this.handles.get(handle);
          result.success(d ? { w: d.width, h: d.height, aspect: d.width / d.height } :
            { w: 1080, h: 1920, aspect: 1080 / 1920 });
          break;
        }
        case 'render': {
          const d = this.handles.get(handle);
          if (!d) { result.error('HANDLE', '句柄已释放', null); return; }
          const index = (args['index'] as number) ?? 0;
          const bytes = d.render(index);
          result.success({ bytes: bytes, w: d.width, h: d.height });
          break;
        }
        case 'prefetch':
        case 'evict': {
          const indices = (args['indices'] ?? []) as number[];
          if (call.method === 'evict') {
            this.handles.get(handle)?.evict(indices);
          }
          result.success(null);
          break;
        }
        case 'close':
          this.handles.delete(handle);
          result.success(null);
          break;
        case 'capabilities':
          result.success({ pdf: 'pending', zip: 'pending', images: 'ok', raster: 'bytes' });
          break;
        default:
          result.notImplemented();
      }
    } catch (e) {
      const msg = String(e);
      result.error(msg.includes('UNSUPPORTED') ? 'UNSUPPORTED' : 'RENDER', msg, null);
    }
  }
}

const IMAGE_EXTS: string[] = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'];

function naturalCompare(a: string, b: string): number {
  // 数字感知：page2 排在 page10 前面。
  return a.localeCompare(b, 'zh', { numeric: true });
}

class DocumentHandle {
  private pages: string[] = [];
  private cache: Map<number, Uint8Array> = new Map();
  width: number = 1080;
  height: number = 1920;

  constructor(path: string) {
    const lower = path.toLowerCase();
    if (lower.endsWith('.cbr') || lower.endsWith('.rar')) {
      throw new Error('UNSUPPORTED: RAR / CBR 暂不支持，请转换为 CBZ / ZIP');
    }
    if (lower.endsWith('.pdf')) {
      // 鸿蒙 PDF Kit / 交叉编译 PDFium 需在 DevEco 工程内接入；
      // 这里明确报错，避免返回一个永远空白的句柄。
      throw new Error('UNSUPPORTED: 鸿蒙端 PDF 栅格化需接入 PDF Kit，请改用 EPUB / TXT / 图片文件夹');
    }
    if (lower.endsWith('.cbz') || lower.endsWith('.zip')) {
      throw new Error('UNSUPPORTED: 鸿蒙端 CBZ 解包需接入 zlib，请解压为图片文件夹后导入');
    }
    let dir = path;
    try {
      const stat = fs.statSync(path);
      if (!stat.isDirectory()) {
        // 单张图片：把所在目录当成一页书。
        dir = path.substring(0, path.lastIndexOf('/'));
        this.pages = [path];
      }
    } catch (_) {
      dir = path;
    }
    if (this.pages.length === 0) {
      try {
        const names = fs.listFileSync(dir);
        this.pages = names
          .filter((n: string) => IMAGE_EXTS.indexOf(n.substring(n.lastIndexOf('.') + 1).toLowerCase()) >= 0)
          .sort(naturalCompare)
          .map((n: string) => (dir.endsWith('/') ? dir + n : dir + '/' + n));
      } catch (_) {
        this.pages = [];
      }
    }
  }

  pageCount(): number { return this.pages.length; }

  render(index: number): Uint8Array {
    const hit = this.cache.get(index);
    if (hit) { return hit; }
    const p = this.pages[index];
    if (!p) { throw new Error('RENDER: 页 ' + index + ' 不存在'); }
    const file = fs.openSync(p, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(p);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      const bytes = new Uint8Array(buf);
      // 只缓存窗口内的少量页，避免漫画大图常驻内存。
      if (this.cache.size > 12) { this.cache.clear(); }
      this.cache.set(index, bytes);
      return bytes;
    } finally {
      fs.closeSync(file);
    }
  }

  evict(indices: number[]): void {
    indices.forEach((i: number) => this.cache.delete(i));
  }
}
