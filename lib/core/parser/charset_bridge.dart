import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum DetectedEncoding { utf8, utf16le, utf16be, gbk, gb18030, big5, unknown }

class UnsupportedCharsetException implements Exception {
  const UnsupportedCharsetException(this.encoding);
  final DetectedEncoding encoding;

  @override
  String toString() => 'UnsupportedCharsetException: $encoding 需由原生 CharsetBridge 解码'
      '（Android Charset.forName / iOS CFStringEncoding / ohos util.TextDecoder）';
}

@immutable
class DecodedText {
  const DecodedText({required this.content, required this.encoding});
  final String content;
  final DetectedEncoding encoding;
}

/// 编码这块是「混合」的第一个真实交界：
/// BOM / UTF-8 合法性校验是纯 Dart；GBK / GB18030 / Big5 没有可靠的纯 Dart 解码器，
/// 必须下沉原生。这也解释了为什么「解析优先纯 Dart」不等于「全纯 Dart」。
abstract interface class CharsetBridge {
  DetectedEncoding detect(Uint8List bytes);
  Future<DecodedText> decode(Uint8List bytes, {DetectedEncoding? hint});
}

class PureDartCharsetBridge implements CharsetBridge {
  const PureDartCharsetBridge({this.nativeFallback});

  /// 三端原生实现，用于 GBK / GB18030 / Big5。未注入时抛异常，绝不静默乱码。
  final Future<String> Function(Uint8List bytes, DetectedEncoding encoding)? nativeFallback;

  @override
  DetectedEncoding detect(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) return DetectedEncoding.utf16le;
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) return DetectedEncoding.utf16be;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) return DetectedEncoding.utf8;

    if (_isValidUtf8(bytes)) return DetectedEncoding.utf8;

    // 简化启发式：高位字节密集但 UTF-8 校验失败，按常见中文编码交由原生探测。
    // 真实实现应下沉原生做 GBK / GB18030 / Big5 的统计判别，避免把 Big5 猜成 GBK。
    return DetectedEncoding.unknown;
  }

  bool _isValidUtf8(Uint8List bytes) {
    try {
      utf8.decode(bytes, allowMalformed: false);
      return true;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<DecodedText> decode(Uint8List bytes, {DetectedEncoding? hint}) async {
    final DetectedEncoding enc = hint ?? detect(bytes);
    switch (enc) {
      case DetectedEncoding.utf8:
        final int skip = bytes.length >= 3 &&
                bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF
            ? 3
            : 0;
        return DecodedText(content: utf8.decode(bytes.sublist(skip), allowMalformed: true), encoding: enc);
      case DetectedEncoding.utf16le:
      case DetectedEncoding.utf16be:
        final int skip = 2;
        return DecodedText(
          content: _decodeUtf16(bytes.sublist(skip), littleEndian: enc == DetectedEncoding.utf16le),
          encoding: enc,
        );
      case DetectedEncoding.gbk:
      case DetectedEncoding.gb18030:
      case DetectedEncoding.big5:
      case DetectedEncoding.unknown:
        if (nativeFallback == null) throw UnsupportedCharsetException(enc);
        return DecodedText(content: await nativeFallback!(bytes, enc), encoding: enc);
    }
  }

  /// dart:convert 没有 UTF-16 decoder，这里手写 code unit 与 surrogate pair 合并。
  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final int cu = littleEndian
          ? (bytes[i] | (bytes[i + 1] << 8))
          : ((bytes[i] << 8) | bytes[i + 1]);
      if (cu >= 0xD800 && cu <= 0xDBFF && i + 3 < bytes.length) {
        final int lo = littleEndian
            ? (bytes[i + 2] | (bytes[i + 3] << 8))
            : ((bytes[i + 2] << 8) | bytes[i + 3]);
        if (lo >= 0xDC00 && lo <= 0xDFFF) {
          final int cp = 0x10000 + ((cu - 0xD800) << 10) + (lo - 0xDC00);
          out.writeCharCode(cp);
          i += 2;
          continue;
        }
      }
      out.writeCharCode(cu);
    }
    return out.toString();
  }
}
