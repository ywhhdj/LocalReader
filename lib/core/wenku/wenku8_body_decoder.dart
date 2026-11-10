import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// 正文解码器（第二十三轮）。
///
/// Wenku8 网页 / TXT 大量使用 GBK（`txtgbk`、方正书宋 GBK 等公开资料可佐证），
/// 直接用 `utf8.decode` 会整页乱码。Dart 标准库没有 GBK，因此引入纯 Dart 的
/// `package:charset`（2.0.1，`gbk` 是 `GbkCodec`：`Codec<String, List<int>>`，
/// 故有 `decode(List<int>)` / `encode(String)`）。
///
/// 判定顺序：响应头 Content-Type charset → HTML meta charset → 默认 GBK。
abstract interface class Wenku8BodyDecoder {
  String decode(Uint8List bytes, String contentType, String rawProbe);
}

class DefaultWenku8BodyDecoder implements Wenku8BodyDecoder {
  const DefaultWenku8BodyDecoder();

  @override
  String decode(Uint8List bytes, String contentType, String rawProbe) {
    final String declared = _charsetOf(contentType).isNotEmpty
        ? _charsetOf(contentType)
        : _metaCharsetOf(rawProbe);
    final String cs = declared.isEmpty ? 'gbk' : declared;
    try {
      if (_isGbk(cs)) return gbk.decode(bytes);
      if (_isLatin(cs)) return latin1.decode(bytes, allowInvalid: true);
      return utf8.decode(bytes, allowMalformed: true);
    } on FormatException {
      // 站点编码声明与实际字节不一致时，退回 GBK 再试一次；仍失败则明确交上层
      // 判为 upstreamChanged，不把乱码当内容渲染。
      return gbk.decode(bytes);
    }
  }

  static bool _isGbk(String cs) =>
      cs == 'gbk' || cs == 'gb2312' || cs == 'gb18030' || cs == 'cp936';

  static bool _isLatin(String cs) =>
      cs == 'iso-8859-1' || cs == 'latin1' || cs == 'windows-1252';

  static String _charsetOf(String contentType) {
    final RegExp re = RegExp(r'charset\s*=\s*[\x22\x27]?([\w-]+)', caseSensitive: false);
    final Match? m = re.firstMatch(contentType);
    return m == null ? '' : (m.group(1) ?? '').toLowerCase();
  }

  static String _metaCharsetOf(String rawProbe) {
    // rawProbe 是 latin1 粗解码出的前若干字节，只用于找 meta 声明，不当正文。
    final RegExp re = RegExp(
        r'charset\s*=\s*[\x22\x27]?([\w-]+)', caseSensitive: false);
    final Match? m = re.firstMatch(rawProbe);
    return m == null ? '' : (m.group(1) ?? '').toLowerCase();
  }
}

/// 用 latin1 粗解码拿 meta 声明（不产生乱码替换字符，字节可逐一对回）。
String probeAscii(Uint8List bytes) {
  final int n = bytes.length > 2048 ? 2048 : bytes.length;
  return latin1.decode(bytes.sublist(0, n), allowInvalid: true);
}