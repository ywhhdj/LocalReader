import Flutter
import Foundation
import UIKit
import PDFKit
import AVFoundation
import Compression
import SQLite3
import ImageIO
import UniformTypeIdentifiers

/// LocalReader 的 iOS 平台通道实现（第三十二轮收尾）。
///
/// 旧文件只有 3 个骨架插件，且**没有被 Runner.xcodeproj 引用**，因此 iOS 上
/// 所有 MethodChannel 调用都会落到 MissingPluginException。本文件覆盖
/// LrChannels 的全部 11 个通道，并由 AppDelegate 在引擎初始化后安装。
///
/// 协议与 Dart 侧保持一致：
///  - render 返回 `bytes`（FlutterStandardTypedData）+ 真实 w/h，Dart 用 Image.memory；
///  - tts 的 onSentenceDone 携带 utteranceId，SentenceQueue 据此精确到句推进；
///  - database 执行 Dart 侧 schema 迁移，不自己建表；
///  - saf 用 UIDocumentPicker 选目录 + bookmark 持久化，重启后可重扫。
public final class LocalReaderPluginHub: NSObject {

    public static var shared: LocalReaderPluginHub?

    private let presenter: () -> UIViewController?
    private let render = RenderBackend()
    private let tts: TtsBackend
    private let database = DatabaseBackend()
    private let saf: SafBackend
    private var channels: [FlutterMethodChannel] = []

    private init(presenter: @escaping () -> UIViewController?) {
        self.presenter = presenter
        self.tts = TtsBackend()
        self.saf = SafBackend(presenter: presenter)
        super.init()
    }

    public static func install(messenger: FlutterBinaryMessenger,
                               presenter: @escaping () -> UIViewController?) {
        let hub = LocalReaderPluginHub(presenter: presenter)
        shared = hub
        hub.tts.attach(messenger: messenger)
        for (name, handler) in hub.handlers() {
            let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
            channel.setMethodCallHandler(handler)
            hub.channels.append(channel)
        }
    }

    private func handlers() -> [(String, (FlutterMethodCall, @escaping FlutterResult) -> Void)] {
        let names = [
            "render", "charset", "saf", "database", "device", "share",
            "widgets", "files", "fonts", "voice", "tts",
        ]
        return names.map { name in
            (name, { [weak self] call, result in
                guard let self else { return result(FlutterMethodNotImplemented) }
                self.dispatch(channel: name, call: call, result: result)
            })
        }
    }

    private func args(_ call: FlutterMethodCall) -> [String: Any] {
        call.arguments as? [String: Any] ?? [:]
    }

    private func dispatch(channel: String, call: FlutterMethodCall,
                          result: @escaping FlutterResult) {
        let a = args(call)
        switch channel {
        case "render":   render.handle(call, a, result)
        case "charset":  CharsetBackend.handle(call, a, result)
        case "saf":      saf.handle(call, a, result)
        case "database": database.handle(call, a, result)
        case "device":   handleDevice(call, a, result)
        case "share":    handleShare(call, a, result)
        case "widgets":  handleWidgets(call, a, result)
        case "files":    handleFiles(call, a, result)
        case "fonts":    handleFonts(call, a, result)
        case "voice":    result(AVSpeechSynthesisVoice.speechVoices().map { "\($0.language) · \($0.name)" })
        case "tts":      tts.handle(call, a, result)
        default:         result(FlutterMethodNotImplemented)
        }
    }

    // ------------------------------------------------------------ device / fonts

    private func handleDevice(_ call: FlutterMethodCall, _ a: [String: Any],
                              _ result: @escaping FlutterResult) {
        switch call.method {
        case "capability":
            result([
                "ramMB": Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024),
                "cores": ProcessInfo.processInfo.processorCount,
                "maxRefreshHz": UIScreen.main.maximumFramesPerSecond,
                "tier": "unknown",
                "platformLabel": "iOS \(UIDevice.current.systemVersion)",
            ])
        case "setScreenOn":
            UIApplication.shared.isIdleTimerDisabled = a["on"] as? Bool ?? false
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func handleFonts(_ call: FlutterMethodCall, _ a: [String: Any],
                             _ result: @escaping FlutterResult) {
        switch call.method {
        case "list": result(UIFont.familyNames.sorted())
        case "load":
            let path = a["path"] as? String ?? ""
            let src = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                return result(FlutterError(code: "FONT", message: "字体文件不存在：\(path)", details: nil))
            }
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("fonts", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dst = dir.appendingPathComponent(src.lastPathComponent)
            try? FileManager.default.removeItem(at: dst)
            do {
                try FileManager.default.copyItem(at: src, to: dst)
                result(dst.path)
            } catch {
                result(FlutterError(code: "FONT", message: error.localizedDescription, details: nil))
            }
        default: result(FlutterMethodNotImplemented)
        }
    }

    // ------------------------------------------------------------ share / widgets

    private func exportsDir() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func handleShare(_ call: FlutterMethodCall, _ a: [String: Any],
                             _ result: @escaping FlutterResult) {
        let rawName = a["name"] as? String ?? "export.txt"
        let safe = rawName.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined(separator: "_")
        let file = exportsDir().appendingPathComponent(safe.isEmpty ? "export.txt" : safe)
        do {
            switch call.method {
            case "saveText":
                try (a["text"] as? String ?? "").write(to: file, atomically: true, encoding: .utf8)
                result(file.path)
            case "saveImage":
                let bytes = (a["bytes"] as? FlutterStandardTypedData)?.data ?? Data()
                try bytes.write(to: file)
                result(nil)
            case "shareText":
                let vc = UIActivityViewController(activityItems: [a["text"] as? String ?? ""],
                                                  applicationActivities: nil)
                presenter()?.present(vc, animated: true)
                result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: "SHARE", message: error.localizedDescription, details: nil))
        }
    }

    private func handleWidgets(_ call: FlutterMethodCall, _ a: [String: Any],
                               _ result: @escaping FlutterResult) {
        let id = a["id"] as? String ?? ""
        let store = UserDefaults(suiteName: "group.com.demo.localreader.widgets")
            ?? UserDefaults.standard
        switch call.method {
        case "update":
            if let payload = a["payload"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: payload) {
                store.set(String(data: data, encoding: .utf8), forKey: id)
            }
            // WidgetKit 扩展读同一份 App Group 数据；无扩展时也不影响主 App。
            result(nil)
        case "remove":
            store.removeObject(forKey: id)
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    // ------------------------------------------------------------ files

    private func handleFiles(_ call: FlutterMethodCall, _ a: [String: Any],
                             _ result: @escaping FlutterResult) {
        switch call.method {
        case "list":
            let root = a["uri"] as? String ?? ""
            let exts = Set((a["exts"] as? [String] ?? []).map { $0.lowercased() })
            let url = resolve(root)
            var out: [String] = []
            if let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let f as URL in enumerator {
                    if exts.isEmpty || exts.contains(f.pathExtension.lowercased()) {
                        out.append(f.path)
                    }
                }
            } else if FileManager.default.fileExists(atPath: url.path) {
                out.append(url.path)
            }
            result(out.sorted())
        case "readBytes":
            let path = resolve(a["path"] as? String ?? "").path
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                result(FlutterStandardTypedData(bytes: data))
            } else {
                result(FlutterError(code: "FILES", message: "无法读取：\(path)", details: nil))
            }
        case "size":
            let path = resolve(a["path"] as? String ?? "").path
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)??.intValue ?? 0
            result(size)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func resolve(_ raw: String) -> URL {
        if raw.hasPrefix("file://"), let u = URL(string: raw) { return u }
        // SAF 选目录返回的是安全作用域 URL 字符串；先尝试书签，再按普通路径。
        if let u = URL(string: raw), u.scheme != nil { return u }
        return URL(fileURLWithPath: raw)
    }
}

// MARK: - 字符集

private enum CharsetBackend {
    static func handle(_ call: FlutterMethodCall, _ a: [String: Any],
                       _ result: @escaping FlutterResult) {
        guard call.method == "decode",
              let data = (a["bytes"] as? FlutterStandardTypedData)?.data else {
            return result(FlutterMethodNotImplemented)
        }
        let hint = (a["encoding"] as? String ?? "auto").lowercased()
        let candidates: [(String, String.Encoding)] = {
            func enc(_ cf: CFStringEncodings) -> String.Encoding {
                String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(cf.rawValue)))
            }
            switch hint {
            case "big5":    return [("Big5", enc(.big5))]
            case "gb18030": return [("GB18030", enc(.GB_18030_2000))]
            case "gbk":     return [("GBK", enc(.GBK_95))]
            default:        return [("UTF-8", .utf8), ("GB18030", enc(.GB_18030_2000)),
                                    ("Big5", enc(.big5))]
            }
        }()
        var best: (String, String)? = nil
        var bestBad = Int.max
        for (label, encoding) in candidates {
            guard let text = String(data: data, encoding: encoding) else { continue }
            let bad = text.filter { $0 == "\u{FFFD}" }.count
            if bad < bestBad { bestBad = bad; best = (label, text) }
            if bad == 0 { break }
        }
        result(["text": best?.1 ?? "", "encoding": best?.0 ?? "UTF-8"])
    }
}

// MARK: - TTS

private final class TtsBackend: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var channel: FlutterMethodChannel?
    private var currentId = "0"
    private var rate: Float = 0.5
    private var pitch: Float = 1.0

    func attach(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.demo.localreader/tts",
                                       binaryMessenger: messenger)
        synth.delegate = self
    }

    func handle(_ call: FlutterMethodCall, _ a: [String: Any],
                _ result: @escaping FlutterResult) {
        switch call.method {
        case "speak":
            currentId = a["utteranceId"] as? String ?? "0"
            let u = AVSpeechUtterance(string: a["sentence"] as? String ?? "")
            u.rate = Float(a["rate"] as? Double ?? Double(rate))
            u.pitchMultiplier = Float(a["pitch"] as? Double ?? Double(pitch))
            synth.speak(u)
            result(nil)
        case "setRate":   rate = Float(a["rate"] as? Double ?? 0.5); result(nil)
        case "setPitch":  pitch = Float(a["pitch"] as? Double ?? 1.0); result(nil)
        case "pause":     synth.pauseSpeaking(at: .word); result(nil)
        case "stop":      synth.stopSpeaking(at: .immediate); result(nil)
        case "resume":    synth.continueSpeaking(); result(nil)
        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        channel?.invokeMethod("onSentenceDone", arguments: ["utteranceId": currentId])
    }
}

// MARK: - SAF（目录授权）

private final class SafBackend: NSObject, UIDocumentPickerDelegate {
    private let presenter: () -> UIViewController?
    private var pending: FlutterResult?
    private let key = "localreader_saf_urls"

    init(presenter: @escaping () -> UIViewController?) { self.presenter = presenter }

    func handle(_ call: FlutterMethodCall, _ a: [String: Any],
                _ result: @escaping FlutterResult) {
        switch call.method {
        case "pickDirectory":
            pending = result
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            DispatchQueue.main.async { self.presenter()?.present(picker, animated: true) }
        case "persistGrant":
            save(a["uri"] as? String ?? "")
            result(true)
        case "rescanPersisted": result(granted())
        case "hasPersistedGrant": result(!granted().isEmpty)
        default: result(FlutterMethodNotImplemented)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            pending?(nil)
            pending = nil
            return
        }
        _ = url.startAccessingSecurityScopedResource()
        save(url.absoluteString)
        pending?(url.absoluteString)
        pending = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pending?(nil); pending = nil
    }

    private func granted() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private func save(_ raw: String) {
        var all = granted()
        if !raw.isEmpty && !all.contains(raw) { all.append(raw) }
        UserDefaults.standard.set(all, forKey: key)
    }
}

// MARK: - SQLite

private final class DatabaseBackend: NSObject {
    private var db: OpaquePointer?

    private func open() throws -> OpaquePointer {
        if let db { return db }
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("localreader.db").path
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw NSError(domain: "DB", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "sqlite3_open 失败"])
        }
        return db!
    }

    func handle(_ call: FlutterMethodCall, _ a: [String: Any],
                _ result: @escaping FlutterResult) {
        do {
            let d = try open()
            switch call.method {
            case "userVersion":     result(pragma(d, "PRAGMA user_version"))
            case "setUserVersion":  try exec(d, "PRAGMA user_version = \(a["version"] as? Int ?? 0)", []); result(nil)
            case "execute":         try exec(d, a["sql"] as? String ?? "", a["args"] as? [Any] ?? []); result(nil)
            case "query":           result(try query(d, a["sql"] as? String ?? "", a["args"] as? [Any] ?? []))
            case "begin":           try exec(d, "BEGIN TRANSACTION", []); result(nil)
            case "commit":          try exec(d, "COMMIT", []); result(nil)
            case "rollback":        try exec(d, "ROLLBACK", []); result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: "DB", message: error.localizedDescription, details: nil))
        }
    }

    private func pragma(_ d: OpaquePointer, _ sql: String) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func bind(_ stmt: OpaquePointer?, _ args: [Any]) {
        for (i, v) in args.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case let n as Int:    sqlite3_bind_int64(stmt, idx, Int64(n))
            case let n as Double: sqlite3_bind_double(stmt, idx, n)
            case let s as String: sqlite3_bind_text(stmt, idx, s, -1, transient)
            case let b as Bool:   sqlite3_bind_int(stmt, idx, b ? 1 : 0)
            case let d as FlutterStandardTypedData:
                _ = d.data.withUnsafeBytes { raw in
                    sqlite3_bind_blob(stmt, idx, raw.baseAddress, Int32(d.data.count), transient)
                }
            default: sqlite3_bind_null(stmt, idx)
            }
        }
    }

    private func exec(_ d: OpaquePointer, _ sql: String, _ args: [Any]) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "DB", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(d))])
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, args)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "DB", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(d))])
        }
    }

    private func query(_ d: OpaquePointer, _ sql: String, _ args: [Any]) throws -> [[String: Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "DB", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(d))])
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, args)
        let cols = Int(sqlite3_column_count(stmt))
        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<cols {
                let name = String(cString: sqlite3_column_name(stmt, Int32(i)))
                switch sqlite3_column_type(stmt, Int32(i)) {
                case SQLITE_INTEGER: row[name] = sqlite3_column_int64(stmt, Int32(i))
                case SQLITE_FLOAT:   row[name] = sqlite3_column_double(stmt, Int32(i))
                case SQLITE_NULL:    row[name] = NSNull()
                default:
                    if let c = sqlite3_column_text(stmt, Int32(i)) {
                        row[name] = String(cString: c)
                    } else { row[name] = "" }
                }
            }
            rows.append(row)
        }
        return rows
    }
}

// MARK: - 渲染（PDFKit / ZIP / 图片文件夹）

private final class RenderBackend: NSObject {
    fileprivate enum Kind { case pdf, zip, images }
    fileprivate final class Doc {
        let kind: Kind
        var pdf: PDFDocument?
        var pages: [Data] = []
        var paths: [String] = []
        init(kind: Kind) { self.kind = kind }
    }
    private var handles: [Int: Doc] = [:]
    private var next = 1

    private let imageExts: Set<String> = ["jpg", "jpeg", "png", "webp", "bmp", "gif"]

    func handle(_ call: FlutterMethodCall, _ a: [String: Any],
                _ result: @escaping FlutterResult) {
        do {
            switch call.method {
            case "open":
                let path = a["localPath"] as? String ?? ""
                let h = next; next += 1
                handles[h] = try openDoc(path)
                result(h)
            case "pageCount": result(doc(a)?.count ?? 0)
            case "pageInfo":
                guard let d = doc(a) else { return result(err("HANDLE", "句柄已释放")) }
                let i = a["index"] as? Int ?? 0
                let size = d.size(i)
                result(["w": Double(size.0), "h": Double(size.1),
                        "aspect": Double(size.0) / max(1.0, Double(size.1))])
            case "render":
                guard let d = doc(a) else { return result(err("HANDLE", "句柄已释放")) }
                let i = a["index"] as? Int ?? 0
                let w = min(max(a["w"] as? Int ?? 1080, 64), 4096)
                let h = min(max(a["h"] as? Int ?? 1920, 64), 4096)
                let data = try d.render(i, w: w, h: h)
                let size = d.size(i)
                result(["bytes": FlutterStandardTypedData(bytes: data),
                        "w": size.0, "h": size.1])
            case "prefetch", "evict": result(nil)
            case "close":
                handles.removeValue(forKey: a["handle"] as? Int ?? -1)
                result(nil)
            case "capabilities":
                result(["pdf": "PDFKit", "zip": "Compression", "raster": "bytes"])
            default: result(FlutterMethodNotImplemented)
            }
        } catch let e as NSError where e.domain == "UNSUPPORTED" {
            result(FlutterError(code: "UNSUPPORTED", message: e.localizedDescription, details: nil))
        } catch {
            result(FlutterError(code: "RENDER", message: error.localizedDescription, details: nil))
        }
    }

    private func err(_ code: String, _ msg: String) -> FlutterError {
        FlutterError(code: code, message: msg, details: nil)
    }

    private func doc(_ a: [String: Any]) -> Doc? {
        handles[a["handle"] as? Int ?? -1]
    }

    private func openDoc(_ raw: String) throws -> Doc {
        let lower = raw.lowercased()
        if lower.hasSuffix(".cbr") || lower.hasSuffix(".rar") {
            throw NSError(domain: "UNSUPPORTED", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "RAR / CBR 暂不支持，请转换为 CBZ / ZIP"])
        }
        let url: URL = raw.hasPrefix("file://") ? URL(string: raw)! : URL(fileURLWithPath: raw)
        let d: Doc
        if lower.hasSuffix(".pdf") {
            guard let pdf = PDFDocument(url: url) else {
                throw NSError(domain: "RENDER", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "PDF 打开失败：\(raw)"])
            }
            d = Doc(kind: .pdf); d.pdf = pdf
        } else if lower.hasSuffix(".cbz") || lower.hasSuffix(".zip") {
            d = Doc(kind: .zip)
            d.pages = try ZipReader.imageEntries(data: try Data(contentsOf: url), exts: imageExts)
        } else {
            d = Doc(kind: .images)
            var isDir: ObjCBool = false
            let dir = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
                ? url : url.deletingLastPathComponent()
            let items = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            d.paths = items
                .filter { imageExts.contains(($0 as NSString).pathExtension.lowercased()) }
                .naturalSorted()
                .map { dir.appendingPathComponent($0).path }
        }
        return d
    }
}

fileprivate extension RenderBackend.Doc {
    var count: Int {
        switch kind {
        case .pdf: return pdf?.pageCount ?? 0
        case .zip: return pages.count
        case .images: return paths.count
        }
    }

    func size(_ i: Int) -> (Int, Int) {
        guard i >= 0, i < count else { return (1080, 1920) }
        switch kind {
        case .pdf:
            let b = pdf?.page(at: i)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
            return (Int(b.width * 2), Int(b.height * 2))
        default:
            return Self.imageSize(data(at: i))
        }
    }

    private func data(at i: Int) -> Data {
        switch kind {
        case .zip: return pages[i]
        case .images: return (try? Data(contentsOf: URL(fileURLWithPath: paths[i]))) ?? Data()
        case .pdf: return Data()
        }
    }

    private static func imageSize(_ data: Data) -> (Int, Int) {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            return (1080, 1920)
        }
        return (w, h)
    }

    func render(_ i: Int, w: Int, h: Int) throws -> Data {
        switch kind {
        case .pdf:
            guard let page = pdf?.page(at: i) else {
                throw NSError(domain: "RENDER", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "PDF 页 \(i) 不存在"])
            }
            let image = page.thumbnail(of: CGSize(width: w, height: h), for: .mediaBox)
            #if canImport(UIKit)
            return image.pngData() ?? Data()
            #else
            return Data()
            #endif
        default:
            // 图片字节直通：Dart 侧 Image.memory 负责解码与缩放，原生不再重复解码。
            return data(at: i)
        }
    }
}

/// 最小 ZIP central-directory 读取器：CBZ 里图片通常是 stored；
/// deflate 条目走 Compression 的 zlib 解码（不加第三方依赖）。
private enum ZipReader {
    struct Entry { let name: String; let method: Int; let compSize: Int; let localOffset: Int }

    static func imageEntries(data: Data, exts: Set<String>) throws -> [Data] {
        let bytes = [UInt8](data)
        var eocd = -1
        var p = bytes.count - 22
        while p >= 0 && p + 4 <= bytes.count {
            if u32(bytes, p) == 0x06054b50 { eocd = p; break }
            p -= 1
        }
        guard eocd >= 0 else {
            throw NSError(domain: "RENDER", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "CBZ 不是合法 ZIP（未找到 EOCD）"])
        }
        let count = Int(u16(bytes, eocd + 10))
        var off = Int(u32(bytes, eocd + 16))
        var entries: [Entry] = []
        for _ in 0..<count {
            guard off + 46 <= bytes.count, u32(bytes, off) == 0x02014b50 else { break }
            let method = Int(u16(bytes, off + 10))
            let compSize = Int(u32(bytes, off + 20))
            let nameLen = Int(u16(bytes, off + 28))
            let extraLen = Int(u16(bytes, off + 30))
            let commentLen = Int(u16(bytes, off + 32))
            let local = Int(u32(bytes, off + 42))
            let name = String(bytes: bytes[(off + 46)..<(off + 46 + nameLen)], encoding: .utf8) ?? ""
            entries.append(Entry(name: name, method: method, compSize: compSize, localOffset: local))
            off += 46 + nameLen + extraLen + commentLen
        }
        let image = entries.filter {
            exts.contains(($0.name as NSString).pathExtension.lowercased())
        }.sorted { $0.name.naturalCompare($1.name) }

        var out: [Data] = []
        for e in image {
            let lo = e.localOffset
            guard lo + 30 <= bytes.count, u32(bytes, lo) == 0x04034b50 else { continue }
            let nameLen = Int(u16(bytes, lo + 26))
            let extraLen = Int(u16(bytes, lo + 28))
            let start = lo + 30 + nameLen + extraLen
            let end = min(start + e.compSize, bytes.count)
            guard start < end else { continue }
            let raw = Data(bytes[start..<end])
            if e.method == 0 {
                out.append(raw)
            } else if e.method == 8, let inflated = inflate(raw) {
                out.append(inflated)
            } else {
                throw NSError(domain: "UNSUPPORTED", code: 6,
                              userInfo: [NSLocalizedDescriptionKey:
                                "CBZ 使用了不支持的压缩方式（method \(e.method)），请转成 stored ZIP / CBZ"])
            }
        }
        return out
    }

    private static func inflate(_ raw: Data) -> Data? {
        // ZIP deflate 是 raw 流；Compression 的 ZLIB 解码器需要 2 字节头。
        var src = Data([0x78, 0x01]); src.append(raw)
        var cap = max(raw.count * 6, 64 * 1024)
        for _ in 0..<4 {
            var dst = Data(count: cap)
            let n = dst.withUnsafeMutableBytes { (d: UnsafeMutableRawBufferPointer) -> Int in
                src.withUnsafeBytes { (s: UnsafeRawBufferPointer) -> Int in
                    compression_decode_buffer(d.baseAddress!, cap, s.baseAddress!, src.count,
                                              nil, COMPRESSION_ZLIB)
                }
            }
            if n > 0 { return dst.prefix(n) }
            cap *= 4
        }
        return nil
    }

    private static func u16(_ b: [UInt8], _ o: Int) -> UInt16 {
        guard o + 2 <= b.count else { return 0 }
        return UInt16(b[o]) | (UInt16(b[o + 1]) << 8)
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        guard o + 4 <= b.count else { return 0 }
        return UInt32(b[o]) | (UInt32(b[o + 1]) << 8) |
               (UInt32(b[o + 2]) << 16) | (UInt32(b[o + 3]) << 24)
    }
}

// MARK: - 自然排序

private extension Array where Element == String {
    func naturalSorted() -> [String] { sorted { $0.naturalCompare($1) } }
}

private extension String {
    func naturalCompare(_ other: String) -> Bool {
        let a = Array(self.utf8), b = Array(other.utf8)
        var i = 0, j = 0
        while i < a.count, j < b.count {
            if a[i].isDigit && b[j].isDigit {
                var si = i, sj = j
                while si < a.count, a[si].isDigit { si += 1 }
                while sj < b.count, b[sj].isDigit { sj += 1 }
                let na = String(decoding: a[i..<si], as: UTF8.self).dropLeadingZeros
                let nb = String(decoding: b[i..<sj], as: UTF8.self).dropLeadingZeros
                if na.count != nb.count { return na.count < nb.count }
                if na != nb { return na < nb }
                i = si; j = sj
            } else {
                if a[i] != b[j] { return a[i] < b[j] }
                i += 1; j += 1
            }
        }
        return a.count < b.count
    }
    var dropLeadingZeros: String {
        let s = drop(while: { $0 == "0" })
        return s.isEmpty ? "0" : String(s)
    }
}

private extension UInt8 {
    var isDigit: Bool { self >= 48 && self <= 57 }
}
