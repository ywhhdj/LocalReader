import 'package:charset/charset.dart';

/// 表单编码（第二十五轮）。
///
/// 用户示例用 `dio` 的 `formUrlEncodedContentType`，它会按 **UTF-8** 编码请求体。
/// 但 Wenku8 页面是 GBK（工程第二十三轮已引入 `charset` 做正文解码），
/// `submit: '登录'` 这类中文字段值用 UTF-8 发出去，服务端按 GBK 解会变成乱码，
/// 登录可能因此静默失败。这里按页面编码做**字节级百分号编码**。
class Wenku8FormEncoding {
  const Wenku8FormEncoding._();

  static const Set<int> _unreserved = <int>{
    0x2D, 0x2E, 0x5F, 0x7E, // - . _ ~
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, // 0-9
    0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A,
    0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54,
    0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, // A-Z
    0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A,
    0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74,
    0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, // a-z
  };

  static String encodeValue(String value) {
    final List<int> bytes = gbk.encode(value);
    final StringBuffer out = StringBuffer();
    for (final int b in bytes) {
      if (b == 0x20) {
        out.write('+');
      } else if (_unreserved.contains(b)) {
        out.writeCharCode(b);
      } else {
        out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  /// 输出的是纯 ASCII，可直接放进 `Request.bodyBytes`。
  static String encode(Map<String, String> fields) => fields.entries
      .map((MapEntry<String, String> e) =>
          '${encodeValue(e.key)}=${encodeValue(e.value)}')
      .join('&');

  /// 登录表单字段：与用户提供的清单一致，集中一处便于按抓包结果替换。
  static const String usernameField = 'username';
  static const String passwordField = 'password';
  static const String submitField = 'submit';
  static const String submitValue = '登录';

  static Map<String, String> loginFields(String username, String password) =>
      <String, String>{
        usernameField: username,
        passwordField: password,
        submitField: submitValue,
      };
}
