import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 自定义插件不在 GeneratedPluginRegistrant 里，必须显式安装。
    // 此前 iOS 上 render / tts / database / saf / files 等 11 个通道全部
    // 落到 MissingPluginException，按钮点了没有任何反应。
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalReaderPluginHub")
    LocalReaderPluginHub.install(messenger: registrar.messenger()) { [weak self] in
      self?.topViewController()
    }
  }

  private func topViewController() -> UIViewController? {
    if #available(iOS 13.0, *) {
      let windows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
      if let vc = (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.rootViewController {
        return vc
      }
    }
    return UIApplication.shared.keyWindow?.rootViewController
  }
}
