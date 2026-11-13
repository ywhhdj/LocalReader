import 'package:flutter/foundation.dart';

/// 字体资源目录（第二十四轮）。
///
/// 参考仓库 README 的口径逐条落下来：
/// - 阅读字体**按需下载、离线可用、可移除、不预装**；
/// - 可导入 TTF / OTF；
/// - **应用字体与阅读器字体分开选**。
///
/// 静态阶段只维护目录与状态：不下载、不落盘、不读文件系统。
/// 真实 `FontLoader` / 平台字体注册是 平台实现，接入时替换 `FontCatalogInstaller`。
enum FontOrigin { builtIn, imported, downloadable }

enum FontRole { app, reader }

enum FontInstallState { notInstalled, installing, installed, failed }

@immutable
class FontResource {
  const FontResource({
    required this.id,
    required this.name,
    required this.origin,
    required this.extensions,
    this.state = FontInstallState.notInstalled,
  });

  final String id;
  final String name;
  final FontOrigin origin;
  final List<String> extensions;
  final FontInstallState state;

  bool get isTtfOrOtf =>
      extensions.any((String e) => e == 'ttf' || e == 'otf');

  bool get isRemovable => origin != FontOrigin.builtIn;

  FontResource copyWith({FontInstallState? state}) => FontResource(
        id: id,
        name: name,
        origin: origin,
        extensions: extensions,
        state: state ?? this.state,
      );

  @override
  bool operator ==(Object other) =>
      other is FontResource &&
      other.id == id &&
      other.name == name &&
      other.origin == origin &&
      other.state == state;

  @override
  int get hashCode => Object.hash(id, name, origin, state);
}

@immutable
class FontSelection {
  const FontSelection({this.appFontId = 'builtin-sans', this.readerFontId = 'builtin-serif'});

  final String appFontId;
  final String readerFontId;

  String forRole(FontRole role) =>
      role == FontRole.app ? appFontId : readerFontId;

  FontSelection withRole(FontRole role, String id) => role == FontRole.app
      ? FontSelection(appFontId: id, readerFontId: readerFontId)
      : FontSelection(appFontId: appFontId, readerFontId: id);

  @override
  bool operator ==(Object other) =>
      other is FontSelection &&
      other.appFontId == appFontId &&
      other.readerFontId == readerFontId;

  @override
  int get hashCode => Object.hash(appFontId, readerFontId);
}

/// 目录本身不可变；「安装 / 移除」返回新目录，状态层只做替换，不就地改写。
@immutable
class FontCatalog {
  const FontCatalog(this.fonts, {this.selection = const FontSelection()});

  final List<FontResource> fonts;
  final FontSelection selection;

  static const List<FontResource> defaults = <FontResource>[
    FontResource(
      id: 'builtin-sans',
      name: '系统无衬线',
      origin: FontOrigin.builtIn,
      extensions: <String>[''],
      state: FontInstallState.installed,
    ),
    FontResource(
      id: 'builtin-serif',
      name: '思源宋体（内置）',
      origin: FontOrigin.builtIn,
      extensions: <String>['otf'],
      state: FontInstallState.installed,
    ),
    FontResource(
      id: 'dl-serif-sc',
      name: '思源宋体 · 按需包',
      origin: FontOrigin.downloadable,
      extensions: <String>['otf'],
    ),
  ];

  static const FontCatalog initial = FontCatalog(defaults);

  FontResource? byId(String id) {
    for (final FontResource f in fonts) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 导入只登记元数据；文件字节与 `FontLoader` 属平台层，静态阶段不处理。
  FontCatalog addImported(String name, List<String> extensions) {
    final String id = 'font-${name.hashCode.toUnsigned(32)}';
    if (byId(id) != null) return this;
    return FontCatalog(
      <FontResource>[
        ...fonts,
        FontResource(
          id: id,
          name: name,
          origin: FontOrigin.imported,
          extensions: extensions,
          state: FontInstallState.notInstalled,
        ),
      ],
      selection: selection,
    );
  }

  FontCatalog withState(String id, FontInstallState state) => FontCatalog(
        <FontResource>[
          for (final FontResource f in fonts)
            f.id == id ? f.copyWith(state: state) : f,
        ],
        selection: selection,
      );

  /// 内置字体不可移除；移除后若正被选中，回落内置，避免选到不存在的 id。
  FontCatalog remove(String id) {
    final FontResource? target = byId(id);
    if (target == null || !target.isRemovable) return this;
    FontSelection next = selection;
    if (selection.appFontId == id) {
      next = next.withRole(FontRole.app, 'builtin-sans');
    }
    if (selection.readerFontId == id) {
      next = next.withRole(FontRole.reader, 'builtin-serif');
    }
    return FontCatalog(
      <FontResource>[for (final FontResource f in fonts) if (f.id != id) f],
      selection: next,
    );
  }

  FontCatalog withSelection(FontSelection next) => FontCatalog(fonts, selection: next);

  /// 只返回「已安装」的字体供选择，未安装的按需包显示为可下载项。
  /// 目录对两个角色共享；`role` 只用于断言调用方没传错，不产生第二份清单。
  List<FontResource> selectable(FontRole role) {
    assert(role == FontRole.app || role == FontRole.reader);
    return List<FontResource>.unmodifiable(
      fonts.where((FontResource f) => f.state == FontInstallState.installed),
    );
  }

  int get downloadedCount => fonts
      .where((FontResource f) => f.origin != FontOrigin.builtIn && f.state == FontInstallState.installed)
      .length;
}
