import 'package:flutter/foundation.dart';

import '../../../l10n/legal_texts.dart';
import 'wenku8_models.dart';

/// 接入 Wenku8 的**合规单一出口**（第二十二轮）。
///
/// 参考仓库 README 的边界全部收在这里，页面不各自解释：
/// 不运营在线书库、不发布小说、不打包小说文件；在线内容由 Wenku8 提供；
/// 本地书由用户导入；不提供因版权原因下架的内容；仅 Wenku8 与本地导入，
/// **不支持其它来源与自定义书源**；不绕过访问限制、不破 DRM、不复制分发售卖；
/// 第三方服务可能变更 / 限流 / 不可用；Issue 里绝不带密码 / Cookie / Token。
///
/// 纯 Dart、零平台依赖，所有规则都可被规格单测与静态自检验证。
@immutable
class Wenku8Compliance {
  const Wenku8Compliance._();

  static const String wenku8SourceId = 'wenku8';
  static const String localImportSourceId = 'local-import';

  /// 仅两种来源。自定义书源入口在产品层面**明确不提供**。
  static const List<String> supportedSourceIds = <String>[
    wenku8SourceId,
    localImportSourceId,
  ];

  static const bool customSourcesAllowed = false;

  static List<String> get rules => <String>[
    LegalTexts.wenkuOnlySources,
    LegalTexts.wenkuContentOwnership,
    LegalTexts.wenkuNoWithdrawn,
    LegalTexts.wenkuNoCircumvention,
    LegalTexts.wenkuThirdParty,
    LegalTexts.wenkuNoCredentials,
  ];

  /// 下架内容一律不展示、不提供访问。所有列表出口都必须过这一层。
  static List<Wenku8Book> withoutWithdrawn(Iterable<Wenku8Book> books) =>
      List<Wenku8Book>.unmodifiable(
        books.where((Wenku8Book b) => b.isAvailable),
      );

  static bool isSupportedSource(String sourceId) =>
      supportedSourceIds.contains(sourceId);

  /// 凭据脱敏：Issue 文本 / 日志 / 反馈预览一律先过这里。
  /// 大小写不敏感，覆盖常见键名与 Bearer / Basic 头；命中整段替换为占位符。
  static const List<String> _credentialKeys = <String>[
    'password', 'passwd', 'pwd', 'secret', 'cookie', 'set-cookie',
    'token', 'access_token', 'refresh_token', 'authorization',
    'api_key', 'apikey', 'session', 'credential', 'bearer', 'basic',
  ];

  static const String redactedPlaceholder = '[凭据已移除]';

  static String redact(String text) {
    String out = text;
    for (final String key in _credentialKeys) {
      final RegExp re = RegExp(
        r'${RegExp.escape(key)}\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      );
      out = out.replaceAllMapped(re, (Match m) => '$key: ${redactedPlaceholder}');
    }
    // 独立的 Bearer / Basic 凭据串（前面没有键名时也要拦）。
    out = out.replaceAllMapped(
      RegExp(r'\b(?:Bearer|Basic)\s+[A-Za-z0-9+/=._-]{8,}',
          caseSensitive: false),
      (Match _) => redactedPlaceholder,
    );
    return out;
  }

  static bool containsCredential(String text) {
    final String lowered = text.toLowerCase();
    return _credentialKeys.any((String k) => lowered.contains(k)) ||
        RegExp(r'\b(?:bearer|basic)\s+[a-z0-9+/=._-]{8,}',
                caseSensitive: false)
            .hasMatch(text);
  }
}
