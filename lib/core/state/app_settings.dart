import 'package:flutter/foundation.dart';

import '../comic/comic_spread.dart';
import '../content/localized_texts.dart';
import '../comic/comic_toc.dart';
import 'reader_style.dart';

/// 全应用设置。默认口径对齐 LocalReader 原定位：纯本地、无联网、无广告。
///
/// 关键约束：`pureLocal` 是 **master switch**。为 true 时，无论其它字段怎么设置，
/// 都必须强制关闭所有联网项——否则「我的」页显示纯本地、文库页却在发请求，
/// 就是产品级自相矛盾。归一化集中在 normalized()，页面不允许各自解释开关。
///
/// 第二个归一化：`motion=false`（整体关闭界面动效）时，翻页动效必须强制为 none。
/// 否则「设置里关了动效、阅读器还在仿真翻页」，同样是状态自相矛盾。
///
/// 第三个归一化：`comicReadMode=vertical`（竖向连续）时，双页跨页与 RTL 都
/// 强制锁回 `single / ltr`——竖向滚动没有左右概念，留着偏好却看不出效果是
/// 又一处「设置各说各话」。归一化仍集中在 normalized()，页面不各自解释。
@immutable
class AppSettings {
  const AppSettings({
    this.pureLocal = true,
    this.onlineDirectory = false,
    this.webdav = false,
    this.motion = true,
    this.tts = true,
    this.reader = const ReaderStyle(),
    this.appLanguage,
  });

  final bool pureLocal;
  final bool onlineDirectory;
  final bool webdav;
  final bool motion;
  final bool tts;

  /// 阅读排版偏好：字号 / 行高 / 背景 / 翻页 / TTS 语速音调等。
  final ReaderStyle reader;

  /// 应用语言（第二十六轮）。null = 跟随系统 locale，由 MaterialApp 解析；
  /// 非 null = 用户显式指定，覆盖系统。默认中文的产品口径不变：
  /// 跟随系统时系统若非中/英，官方 supportedLocales 回退到列表首项 zh-CN。
  final AppLanguage? appLanguage;

  AppSettings copyWith({
    bool? pureLocal,
    bool? onlineDirectory,
    bool? webdav,
    bool? motion,
    bool? tts,
    ReaderStyle? reader,
    AppLanguage? appLanguage,
    bool clearAppLanguage = false,
  }) =>
      AppSettings(
        pureLocal: pureLocal ?? this.pureLocal,
        onlineDirectory: onlineDirectory ?? this.onlineDirectory,
        webdav: webdav ?? this.webdav,
        motion: motion ?? this.motion,
        tts: tts ?? this.tts,
        reader: reader ?? this.reader,
        // nullable 字段不能靠 copyWith 传 null 表示清空：
        // 用显式开关，否则「跟随系统」点了没反应（第十八轮同款陷阱）。
        appLanguage: clearAppLanguage
            ? null
            : (appLanguage ?? this.appLanguage),
      );

  /// 唯一真相：纯本地清零联网项；关闭界面动效时锁死翻页动效；
  /// 竖向连续阅读时锁死双页与 RTL。
  AppSettings normalized() {
    AppSettings cleared = pureLocal && (onlineDirectory || webdav)
        ? copyWith(onlineDirectory: false, webdav: false)
        : this;
    if (!cleared.motion && cleared.reader.pageTurn != ReaderPageTurn.none) {
      cleared = cleared.copyWith(
        reader: cleared.reader.copyWith(pageTurn: ReaderPageTurn.none),
      );
    }
    final ReaderStyle r = cleared.reader;
    if (r.comicReadMode == ComicReadMode.vertical &&
        (r.comicSpreadMode != ComicSpreadMode.single ||
            r.comicDirection != ComicReadingDirection.ltr)) {
      cleared = cleared.copyWith(
        reader: r.copyWith(
          comicSpreadMode: ComicSpreadMode.single,
          comicDirection: ComicReadingDirection.ltr,
        ),
      );
    }
    return cleared;
  }

  /// 在线目录是否真正可用（文库页只读这一个值）。
  bool get onlineEnabled => !pureLocal && onlineDirectory;

  /// 全应用是否允许产生任何网络请求。
  bool get networkingAllowed => !pureLocal && (onlineDirectory || webdav);

  Map<String, Object> toMap() => <String, Object>{
        'pureLocal': pureLocal,
        'onlineDirectory': onlineDirectory,
        'webdav': webdav,
        'motion': motion,
        'tts': tts,
        'reader': reader.toMap(),
        'appLanguage': appLanguage?.name ?? '',
      };

  static AppSettings fromMap(Map<String, Object?> m) {
    bool flag(String key, bool fallback) {
      final Object? v = m[key];
      return v is bool ? v : fallback;
    }

    final Object? rawReader = m['reader'];
    final ReaderStyle reader = rawReader is Map
        ? ReaderStyle.fromMap(rawReader)
        : const ReaderStyle();

    AppLanguage? savedLanguage(AppLanguage? fallback) {
      final Object? v = m['appLanguage'];
      if (v is! String || v.isEmpty) return fallback;
      for (final AppLanguage l in AppLanguage.values) {
        if (l.name == v) return l;
      }
      return fallback;
    }

    return AppSettings(
      pureLocal: flag('pureLocal', true),
      onlineDirectory: flag('onlineDirectory', false),
      webdav: flag('webdav', false),
      motion: flag('motion', true),
      tts: flag('tts', true),
      reader: reader,
      appLanguage: savedLanguage(null),
    ).normalized();
  }

  /// 值相等：AppState.updateSettings 靠它避免「同值也重建整棵 widget 树」。
  /// 之前只有引用比较，copyWith 每次都产生新对象，任何一次开关都会无意义刷新。
  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.pureLocal == pureLocal &&
      other.onlineDirectory == onlineDirectory &&
      other.webdav == webdav &&
      other.motion == motion &&
      other.tts == tts &&
      other.reader == reader &&
      other.appLanguage == appLanguage;

  @override
  int get hashCode => Object.hash(
      pureLocal, onlineDirectory, webdav, motion, tts, reader, appLanguage);
}

/// 持久化抽象。静态交付模式下只有内存实现；
/// 未来接 SharedPreferences / DataStore / 鸿蒙首选项时替换即可，页面零改动。
abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([AppSettings? initial]) : _value = (initial ?? const AppSettings()).normalized();

  AppSettings _value;

  @override
  Future<AppSettings> load() async => _value;

  @override
  Future<void> save(AppSettings settings) async {
    _value = settings.normalized();
  }
}
