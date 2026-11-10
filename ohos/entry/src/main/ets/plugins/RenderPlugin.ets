import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodResult, MethodChannel } from '@ohos/flutter_ohos';
import { textureRegistry, OHOSExternalTexture } from './NativeTexture';

/**
 * BookRenderBridge 的 HarmonyOS 侧实现骨架（参考实现，非可编译成品）。
 *
 * 鸿蒙专项要点：
 *  - PlatformView 走 XComponent + 纹理合成，与 Android VirtualDisplay 不同，
 *    有额外异步消息与序列化开销；本项目只用外部纹理，不嵌原生 View。
 *  - OHOSExternalTexture 采用生产者/消费者模型：XComponent / 解码器写 buffer，
 *    MarkNewFrameAvailable() 触发 Flutter 重绘，ScheduleFrame() 驱动帧。
 *  - PDFium 等 C/C++ SO 需交叉编译为可在 HarmonyOS 运行的库，
 *    ohos 工程用 CMake 构建后由 dart:ffi 加载；不能写死 /system/lib。
 *  - 不依赖 WebView：EPUB 文字型在 Dart 侧转 ContentBlock 自绘。
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
    this.handles.forEach((h: DocumentHandle) => h.close());
    this.handles.clear();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const args = call.args as Record<string, Object>;
    switch (call.method) {
      case 'open': {
        const h = this.nextHandle++;
        const path = args['localPath'] as string;
        // TODO(P2): dart:ffi 加载交叉编译的 libpdfium.so，或 ohos PDF Kit；
        //   RAR5 直接返回 UNSUPPORTED 并提示转 CBZ/ZIP
        this.handles.set(h, new DocumentHandle(path));
        result.success(h);
        break;
      }
      case 'pageCount':
        result.success(this.handles.get(args['handle'] as number)?.pageCount() ?? 0);
        break;
      case 'pageInfo':
        result.success({ w: 1080, h: 1920, aspect: 1080 / 1920 });
        break;
      case 'render': {
        const handle = this.handles.get(args['handle'] as number);
        if (!handle) { result.error('HANDLE', '句柄已释放', null); return; }
        const index = args['index'] as number;
        const w = args['w'] as number;   // 按目标像素渲染，别出 4K 再缩
        const ht = args['h'] as number;
        const textureId = handle.renderToTexture(index, w, ht);
        result.success({ textureId: textureId, w: w, h: ht });
        break;
      }
      case 'prefetch':
      case 'evict': {
        const indices = (args['indices'] ?? []) as number[];
        this.handles.get(args['handle'] as number)?.applyWindow(call.method, indices);
        result.success(null);
        break;
      }
      case 'close':
        this.handles.get(args['handle'] as number)?.close();
        this.handles.delete(args['handle'] as number);
        result.success(null);
        break;
      case 'capabilities':
        // 三端能力探测：Dart 侧据此决定是否降级
        result.success({ pdfium: 'pending', externalTexture: 'ok', webview: 'unused' });
        break;
      default:
        result.notImplemented();
    }
  }
}

class DocumentHandle {
  private path: string;
  private textures: Map<number, OHOSExternalTexture> = new Map();
  private decoded: Map<number, ArrayBuffer> = new Map();

  constructor(path: string) { this.path = path; }

  pageCount(): number { return 0; } // TODO: PDFium FPDF_GetPageCount / ZIP 条目数

  renderToTexture(index: number, w: number, h: number): number {
    let texture = this.textures.get(index);
    if (!texture) {
      texture = textureRegistry.createExternalTexture();
      this.textures.set(index, texture);
    }
    // TODO: FPDFBitmap_Create(w,h) → FPDF_RenderPageBitmap → BGRA
    //   → 生产者 requestBuffer()/queueBuffer() → OnFrameAvailable
    //   → texture.markNewFrameAvailable() → ScheduleFrame()
    return texture.textureId;
  }

  applyWindow(method: string, indices: number[]): void {
    if (method === 'prefetch') {
      // TODO: TaskPool 后台按目标尺寸解码，批量而不是逐帧跨 channel
    } else {
      indices.forEach((i: number) => this.decoded.delete(i));
    }
  }

  close(): void {
    this.decoded.clear();
    this.textures.forEach((t: OHOSExternalTexture) => t.unregister());
    this.textures.clear();
  }
}
