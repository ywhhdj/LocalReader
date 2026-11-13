import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// WebDAV 备份配置。凭据只保存在应用私有数据库（app_prefs），
/// 不写日志、不进反馈草稿、不随崩溃记录外发。
class WebDavConfig {
  const WebDavConfig({
    required this.url,
    this.username = '',
    this.password = '',
    this.remoteDir = 'LocalReader',
  });

  final String url;
  final String username;
  final String password;
  final String remoteDir;

  bool get isConfigured => url.trim().isNotEmpty;

  Map<String, Object?> toMap() => <String, Object?>{
        'url': url,
        'username': username,
        'password': password,
        'remoteDir': remoteDir,
      };

  static WebDavConfig fromMap(Map<String, Object?> m) => WebDavConfig(
        url: (m['url'] as String?) ?? '',
        username: (m['username'] as String?) ?? '',
        password: (m['password'] as String?) ?? '',
        remoteDir: (m['remoteDir'] as String?) ?? 'LocalReader',
      );

  static const WebDavConfig empty = WebDavConfig(url: '');
}

class WebDavException implements Exception {
  const WebDavException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'WebDAV：$message'
      : 'WebDAV（$statusCode）：$message';
}

/// 真实 WebDAV 客户端：PROPFIND / MKCOL / PUT / GET / DELETE。
/// 只使用 `http` 包（pubspec 已声明），不引入 dart:io，便于 Flutter Web / 鸿蒙复用。
/// 目标：把「测试连接 / 立即备份 / 远端列表 / 从远端恢复 / 导出到本地」
/// 五个按钮从静态演示改成真实动作。
class WebDavClient {
  WebDavClient(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  final WebDavConfig config;
  final http.Client _client;
  bool _closed = false;

  Map<String, String> get _headers {
    final Map<String, String> h = <String, String>{
      'Depth': '1',
      'Content-Type': 'application/xml; charset=utf-8',
    };
    if (config.username.isNotEmpty) {
      h['Authorization'] = 'Basic ${base64Encode(utf8.encode(
        '${config.username}:${config.password}',
      ))}';
    }
    return h;
  }

  Uri _uri([String path = '']) {
    final String base = config.url.trim().replaceAll(RegExp(r'/+$'), '');
    final String dir = config.remoteDir.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final List<String> parts = <String>[
      if (dir.isNotEmpty) dir,
      if (path.isNotEmpty) path.replaceAll(RegExp(r'^/+'), ''),
    ];
    return Uri.parse('$base/${parts.join('/')}');
  }

  Future<http.Response> _send(String method, Uri uri,
      {Object? body, Map<String, String>? headers}) async {
    if (_closed) throw const WebDavException('客户端已关闭');
    final http.Request req = http.Request(method, uri)
      ..headers.addAll(<String, String>{..._headers, ...?headers});
    if (body is String) {
      req.body = body;
    } else if (body is List<int>) {
      req.bodyBytes = body;
    }
    final http.StreamedResponse streamed = await _client.send(req);
    return http.Response.fromStream(streamed);
  }

  bool _ok(int code) => code >= 200 && code < 300;

  /// 测试连接：对远端目录做一次 PROPFIND，401/403/404 都给出明确原因。
  Future<String> testConnection() async {
    if (!config.isConfigured) {
      throw const WebDavException('未填写服务器地址');
    }
    final http.Response r = await _send('PROPFIND', _uri(),
        headers: <String, String>{'Depth': '0'});
    if (_ok(r.statusCode)) return '连接成功（HTTP ${r.statusCode}）';
    throw WebDavException(_reason(r.statusCode), r.statusCode);
  }

  Future<void> ensureDirectory() async {
    final http.Response r = await _send('MKCOL', _uri());
    // 405 = 目录已存在；301/409 由服务端决定，交给后续 PUT 判定。
    if (!_ok(r.statusCode) && r.statusCode != 405) {
      throw WebDavException('创建远端目录失败：${_reason(r.statusCode)}', r.statusCode);
    }
  }

  Future<void> put(String fileName, String text) async {
    await ensureDirectory();
    final http.Response r = await _send('PUT', _uri(fileName),
        body: utf8.encode(text),
        headers: <String, String>{'Content-Type': 'text/plain; charset=utf-8'});
    if (!_ok(r.statusCode)) {
      throw WebDavException('上传失败：${_reason(r.statusCode)}', r.statusCode);
    }
  }

  Future<String> get(String fileName) async {
    final http.Response r = await _send('GET', _uri(fileName),
        headers: <String, String>{'Depth': '0'});
    if (!_ok(r.statusCode)) {
      throw WebDavException('下载失败：${_reason(r.statusCode)}', r.statusCode);
    }
    return utf8.decode(r.bodyBytes, allowMalformed: true);
  }

  /// 远端备份列表：从 PROPFIND 的 <d:href> 里取文件名，按时间倒序。
  Future<List<String>> list() async {
    final http.Response r = await _send('PROPFIND', _uri(),
        headers: <String, String>{'Depth': '1'});
    if (!_ok(r.statusCode)) {
      throw WebDavException('列出失败：${_reason(r.statusCode)}', r.statusCode);
    }
    final Set<String> names = <String>{};
    for (final Match m in RegExp(r'<(?:\w+:)?href>([^<]+)</(?:\w+:)?href>')
        .allMatches(r.body)) {
      final String raw = Uri.decodeComponent(m.group(1)!.trim());
      final String name = raw.split('/').where((String s) => s.isNotEmpty).last;
      if (name.toLowerCase().endsWith('.json')) names.add(name);
    }
    final List<String> out = names.toList()..sort((String a, String b) => b.compareTo(a));
    return out;
  }

  Future<void> remove(String fileName) async {
    final http.Response r = await _send('DELETE', _uri(fileName));
    if (!_ok(r.statusCode) && r.statusCode != 404) {
      throw WebDavException('删除失败：${_reason(r.statusCode)}', r.statusCode);
    }
  }

  String _reason(int code) {
    switch (code) {
      case 401:
        return '账号或密码错误';
      case 403:
        return '服务器拒绝访问（检查目录权限）';
      case 404:
        return '远端目录不存在';
      case 405:
        return '服务器未启用 WebDAV 方法';
      case 423:
        return '文件被锁定';
      case 507:
        return '服务器空间不足';
      default:
        return 'HTTP $code';
    }
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
