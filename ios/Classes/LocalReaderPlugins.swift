import Flutter
import Foundation
import PDFKit
import AVFoundation

/// BookRenderBridge 的 iOS 侧实现骨架（参考实现，非可编译成品）。
/// 连续翻页走 FlutterTexture 的 copyPixelBuffer + textureFrameAvailable；
/// 单页快照走 PNG 字节。Dart 只传 index 与目标像素尺寸。
public class RenderPlugin: NSObject, FlutterPlugin {
    private var registry: FlutterTextureRegistry?
    private var handles: [Int: DocumentHandle] = [:]
    private var nextHandle = 1

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.demo.localreader/render",
                                          binaryMessenger: registrar.messenger())
        let instance = RenderPlugin()
        instance.registry = registrar.textures()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else { return result(FlutterError(code: "ARG", message: "参数缺失", details: nil)) }
        switch call.method {
        case "open":
            let id = nextHandle; nextHandle += 1
            let path = args["localPath"] as? String ?? ""
            // TODO(P2): PDFKit PDFDocument(url:) 或统一用 PDFium 静态库保持三端像素一致
            handles[id] = DocumentHandle(path: path, registry: registry!)
            result(id)
        case "pageCount": result(handles[args["handle"] as? Int ?? -1]?.pageCount ?? 0)
        case "pageInfo":  result(["w": 1080, "h": 1920, "aspect": 1080.0 / 1920.0])
        case "render":
            let h = args["handle"] as? Int ?? -1
            let index = args["index"] as? Int ?? 0
            let w = args["w"] as? Int ?? 1080
            let ht = args["h"] as? Int ?? 1920
            guard let doc = handles[h] else { return result(FlutterError(code: "HANDLE", message: "句柄已释放", details: nil)) }
            result(["textureId": doc.renderToTexture(index: index, w: w, h: ht), "w": w, "h": ht])
        case "prefetch", "evict":
            let indices = args["indices"] as? [Int] ?? []
            handles[args["handle"] as? Int ?? -1]?.applyWindow(method: call.method, indices: indices)
            result(nil)
        case "close":
            handles.removeValue(forKey: args["handle"] as? Int ?? -1)?.close()
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }
}

private class DocumentHandle: NSObject {
    let path: String
    let registry: FlutterTextureRegistry
    private var textures: [Int: PageTexture] = [:]
    private var decoded: [Int: CGImage] = [:]

    init(path: String, registry: FlutterTextureRegistry) { self.path = path; self.registry = registry }
    var pageCount: Int { 0 } // TODO: PDFDocument.pageCount / ZIP 条目数

    func renderToTexture(index: Int, w: Int, h: Int) -> Int64 {
        if let existing = textures[index] { return existing.textureId }
        let page = PageTexture()
        let id = registry.register(page)
        page.textureId = id
        textures[index] = page
        // TODO: PDFKit page.thumbnail(of: CGSize(width: w, height: h), for: .mediaBox)
        //   → CGImage → CVPixelBuffer → page.onFrameReady()
        return id
    }

    func applyWindow(method: String, indices: [Int]) {
        if method == "evict" {
            indices.forEach { decoded.removeValue(forKey: $0) }
            // texture 释放需与 Dart 侧 evict 窗口一致
        }
        // TODO: prefetch 在后台队列按目标尺寸解码，完成后 textureFrameAvailable
    }

    func close() {
        decoded.removeAll()
        textures.values.forEach { registry.unregisterTexture($0.textureId) }
        textures.removeAll()
    }
}

private class PageTexture: NSObject, FlutterTexture {
    var textureId: Int64 = -1
    private var buffer: CVPixelBuffer?
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
    func onFrameReady(pixelBuffer: CVPixelBuffer) {
        buffer = pixelBuffer
        // registry.textureFrameAvailable(textureId) 由持有 registry 的对象调用
    }
}

/// 字符集：纯 Dart 只做 BOM/UTF-8 校验，GBK / GB18030 / Big5 下沉原生。
public class CharsetPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.demo.localreader/charset", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(CharsetPlugin(), channel: channel)
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "decode", let args = call.arguments as? [String: Any],
              let data = args["bytes"] as? FlutterStandardTypedData else { return result(FlutterMethodNotImplemented) }
        let hint = (args["encoding"] as? String ?? "unknown").lowercased()
        let encoding: String.Encoding
        switch hint {
        case "big5":     encoding = String.Encoding(rawValue: 0x8000_0A03) // CFStringEncoding Big5
        case "gb18030":  encoding = String.Encoding(rawValue: 0x8000_0A08)
        default:         encoding = String.Encoding(rawValue: 0x8000_0A01) // GBK 需按实际 CFStringEncoding 校正
        }
        // TODO(P2): unknown 时做统计判别；CFStringEncoding → NSStringEncoding 转换
        result(["text": String(data: data.data, encoding: encoding) ?? "", "encoding": hint])
    }
}

/// TTS：Dart 侧 SentenceQueue 决定读哪一句，原生按句回报完成事件。
public class TtsPlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var channel: FlutterMethodChannel?
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.demo.localreader/tts", binaryMessenger: registrar.messenger())
        let instance = TtsPlugin(); instance.channel = channel; instance.synth.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "speak":
            let u = AVSpeechUtterance(string: args["sentence"] as? String ?? "")
            u.rate = Float(args["rate"] as? Double ?? 0.5)
            u.pitchMultiplier = Float(args["pitch"] as? Double ?? 1.0)
            synth.speak(u) // 每句独立；Dart 侧 await 完成才推进 cursor
        case "pause": synth.pauseSpeaking(at: .word)
        case "stop":  synth.stopSpeaking(at: .immediate)
        default: return result(FlutterMethodNotImplemented)
        }
        result(nil)
    }
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        channel?.invokeMethod("onSentenceDone", arguments: nil)
    }
}
