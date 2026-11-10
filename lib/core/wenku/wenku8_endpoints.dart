import 'package:flutter/foundation.dart';

import 'wenku8_hosts.dart';

/// Wenku8 **站点适配层**：所有 URL 只在这里构造。
///
/// 第二十五轮按用户提供的页面清单补全（此前第二十三轮只有两个占位路径）：
///
/// | 用途 | 路径 | 来源 |
/// | --- | --- | --- |
/// | 登录 | `/login.php` POST | 用户提供 |
/// | 个人书架 | `/modules/article/bookcase.php` GET | 用户提供 |
/// | 搜索 | `/modules/article/search.php?searchkey=...` GET | 用户提供 |
/// | 排行榜 | `/modules/article/toplist.php?type=...` GET | 用户提供 |
/// | 详情 / 目录 | `/book/{aid}.htm` GET | 用户提供 + 公开书目页形态 |
/// | 章节正文 | `/modules/article/reader.php?aid=...&cid=...` GET | 用户提供 |
///
/// **重要事实（必须如实标注）**：本轮尝试读取用户给出的 10 个地址时，资源解析
/// 服务全部失败；其中 `www.wenku8.net/login.php` 直接返回的是「本站正式关闭」
/// 公告页，没有 `<form>` / `input`，`toplist.php` 也无法取得内容。因此这些路径
/// 与表单字段是**按用户提供的清单配置、尚未经过页面解析验证**，真机接入时必须
/// 按实际站点核对并在此替换；页面层不得自己拼 URL，也不得把公告页当登录失败。
///
/// 合规护栏不变：全 HTTPS、双域名白名单（`Wenku8Hosts.allowed`）、`owns()`
/// 拒绝第三方中继 / 代理、不内置 appver / 伪装浏览器 UA / 自定义书源。
@immutable
class Wenku8Endpoints {
  const Wenku8Endpoints({
    required this.authority,
    required this.bookPathTemplate,
    required this.listingPath,
    required this.searchPath,
    required this.chapterPathTemplate,
    this.loginPath = '/login.php',
    this.bookcasePath = '/modules/article/bookcase.php',
    this.topListPath = '/modules/article/toplist.php',
    this.searchKeyParam = 'searchkey',
    this.topListTypeParam = 'type',
    this.readerAidParam = 'aid',
    this.readerCidParam = 'cid',
    this.allowedHosts = Wenku8Hosts.allowed,
    this.forceHttps = true,
  });

  /// 默认域名来自用户清单里出现最多的 `www.wenku8.net`；
  /// `www.wenku8.com` 作为可切换的第二域名同在白名单内。
  factory Wenku8Endpoints.publicWeb() => const Wenku8Endpoints(
        authority: 'www.wenku8.net',
        bookPathTemplate: '/book/{aid}.htm',
        // TODO(真机核对): 下列路径来自用户提供的页面清单，需按实际站点确认。
        listingPath: '/modules/article/toplist.php',
        searchPath: '/modules/article/search.php',
        chapterPathTemplate: '/modules/article/reader.php',
      );

  /// 指向你**自己有权使用**的合规上游（自建 OPDS 网关等）。
  /// 不得用于绕过来源站点限制；调用方自行承担该服务的合规责任。
  factory Wenku8Endpoints.custom({
    required String authority,
    required String bookPathTemplate,
    required String listingPath,
    required String searchPath,
    required String chapterPathTemplate,
    bool forceHttps = true,
  }) =>
      Wenku8Endpoints(
        authority: authority,
        bookPathTemplate: bookPathTemplate,
        listingPath: listingPath,
        searchPath: searchPath,
        chapterPathTemplate: chapterPathTemplate,
        allowedHosts: <String>{authority},
        forceHttps: forceHttps,
      );

  final String authority;
  final String bookPathTemplate;
  final String listingPath;
  final String searchPath;
  final String chapterPathTemplate;
  final String loginPath;
  final String bookcasePath;
  final String topListPath;
  final String searchKeyParam;
  final String topListTypeParam;
  final String readerAidParam;
  final String readerCidParam;
  final Set<String> allowedHosts;
  final bool forceHttps;

  /// 切换来源域名。只允许白名单内的两个域名；不会放开任意 host。
  Wenku8Endpoints withAuthority(String next) => Wenku8Endpoints(
        authority: allowedHosts.contains(next) ? next : authority,
        bookPathTemplate: bookPathTemplate,
        listingPath: listingPath,
        searchPath: searchPath,
        chapterPathTemplate: chapterPathTemplate,
        loginPath: loginPath,
        bookcasePath: bookcasePath,
        topListPath: topListPath,
        searchKeyParam: searchKeyParam,
        topListTypeParam: topListTypeParam,
        readerAidParam: readerAidParam,
        readerCidParam: readerCidParam,
        allowedHosts: allowedHosts,
        forceHttps: forceHttps,
      );

  String _fill(String template, String aid, String? cid) => template
      .replaceAll('{aid}', aid)
      .replaceAll('{cid}', cid ?? '0');

  Uri _uri(String path, [Map<String, String>? query]) => Uri(
        scheme: forceHttps ? 'https' : 'http',
        host: authority,
        path: path,
        queryParameters: query,
      );

  /// 榜单（用户给 `toplist.php`，`?type=` 区分榜单）。
  Uri listing() => _uri(listingPath);

  Uri topList(String type) =>
      _uri(topListPath, <String, String>{topListTypeParam: type});

  /// 搜索：用户明确给的是 `searchkey`，不是 `keyword`。
  Uri search(String keyword) =>
      _uri(searchPath, <String, String>{searchKeyParam: keyword});

  Uri detail(String bookId) =>
      _uri(_fill(bookPathTemplate, bookId, null));

  Uri login() => _uri(loginPath);

  /// 个人书架：需要登录 Cookie。
  Uri bookcase() => _uri(bookcasePath);

  /// 章节正文：`reader.php?aid={aid}&cid={cid}`。
  Uri reader(String bookId, String chapterId) => _uri(
        _fill(chapterPathTemplate, bookId, chapterId),
        <String, String>{
          readerAidParam: bookId,
          readerCidParam: chapterId,
        },
      );

  Uri chapter(String bookId, String chapterId) =>
      reader(bookId, chapterId);

  /// 合规护栏：只允许本类构造的域名，杜绝页面层拼出第三方中继地址。
  bool owns(Uri uri) =>
      allowedHosts.contains(uri.host) &&
      uri.scheme == (forceHttps ? 'https' : 'http');
}
