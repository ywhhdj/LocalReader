/// Wenku8 连接状态（第二十三轮从 `wenku8_source.dart` 抽离）。
///
/// 抽离原因：`wenku8_models.dart` 的 `Wenku8Listing` / `Wenku8ChapterText`
/// 都引用 `Wenku8Status`，而 `wenku8_source.dart` 又 import models —— 把枚举留在
/// source 会让 models 缺 import（二十二轮遗留的编译级缺陷）。独立成库后
/// source.dart 继续 `export`，所有既有调用点 import 一行都不用改。
///
/// 第三方服务可能变更、限流或不可用；这几种不是程序错误，页面要如实呈现。

/// 连接状态：第三方服务可能**变更、限流或不可用**（参考仓库 README 原文口径）。
/// 这四种不是「程序错误」，而是产品要如实呈现的常态，页面不能只显示「加载失败」。
enum Wenku8Status {
  idle,
  loading,
  ok,
  rateLimited,
  unavailable,
  upstreamChanged,

  /// 版权受限 / 需要访问验证。**不重试、不绕过**，引导用户去来源官网。
  restricted,

  /// `pureLocal` master switch 锁定：全应用零请求，连演示源也不读。
  lockedByPureLocal,
}

class Wenku8StatusLabels {
  const Wenku8StatusLabels._();

  static const Map<Wenku8Status, String> titles = <Wenku8Status, String>{
    Wenku8Status.idle: '尚未加载',
    Wenku8Status.loading: '正在读取目录',
    Wenku8Status.ok: '目录已就绪',
    Wenku8Status.rateLimited: '来源请求过于频繁',
    Wenku8Status.unavailable: '来源暂时不可用',
    Wenku8Status.upstreamChanged: '来源页面结构已变化',
    Wenku8Status.restricted: '内容不可读或需要验证',
    Wenku8Status.lockedByPureLocal: '纯本地模式已锁定',
  };

  static const Map<Wenku8Status, String> hints = <Wenku8Status, String>{
    Wenku8Status.idle: '切换榜单或打开在线目录即可加载。',
    Wenku8Status.loading: '只读取列表与目录元数据，不下载小说正文。',
    Wenku8Status.ok: '列表与内容由 Wenku8 提供，可用性与下架状态以来源为准。',
    Wenku8Status.rateLimited: '稍后再试；不要反复重试，避免给来源带去额外压力。',
    Wenku8Status.unavailable: '第三方服务可能变更、限流或暂时不可用，请稍后再试。',
    Wenku8Status.upstreamChanged: '来源页面结构变化时需更新解析器，请按实际公开页面更新解析规则。',
    Wenku8Status.restricted: '因版权原因不可读，或来源要求访问验证。请到 Wenku8 官网确认；本应用不绕过验证、不提供下架内容。',
    Wenku8Status.lockedByPureLocal: '关闭纯本地模式并打开「在线目录」后才会读取；关闭态全应用零网络请求。',
  };

  static const Set<Wenku8Status> healthy = <Wenku8Status>{Wenku8Status.ok};

  static bool isUsable(Wenku8Status s) => s == Wenku8Status.ok;
}
