import 'package:Local_reader/core/model/navigation_spec.dart' show AppLanguagePref, SettingsSection, ThemePref;
import 'package:Local_reader/core/model/tts_engine_prefs.dart' show TtsEnginePrefs;
import 'package:Local_reader/assembly/route_contract.dart' show AppRoute, kRoutePaths;

/// 设置首页由扁平卡片改为 4 个分组入口。
class SettingsEntry {
  const SettingsEntry({
    required this.section,
    required this.titleKey,
    required this.route,
  });

  final SettingsSection section;
  final String titleKey;
  final AppRoute route;

  String get path => kRoutePaths[route]!;
}

const List<SettingsEntry> kSettingsEntries = <SettingsEntry>[
  SettingsEntry(
      section: SettingsSection.appearance,
      titleKey: 'uiSettingsAppearance',
      route: AppRoute.appearance),
  SettingsEntry(
      section: SettingsSection.performance,
      titleKey: 'uiSettingsPerformance',
      route: AppRoute.performance),
  SettingsEntry(
      section: SettingsSection.widgets,
      titleKey: 'uiSettingsWidgets',
      route: AppRoute.widgets),
  SettingsEntry(
      section: SettingsSection.dataStorage,
      titleKey: 'uiSettingsDataStorage',
      route: AppRoute.dataStorage),
];

/// 外观页三节：主题 / 语言 / 语言接口入口。
/// 偏好只写模型，页面不自行解释开关；ThemeMode 由 AppState 统一供给 MaterialApp。
class AppearanceSpec {
  const AppearanceSpec({
    this.theme = ThemePref.followSystem,
    this.language = AppLanguagePref.followSystem,
    this.tts = const TtsEnginePrefs(),
    this.ttsRoute = AppRoute.ttsEngine,
  });

  final ThemePref theme;
  final AppLanguagePref language;
  final TtsEnginePrefs tts;
  final AppRoute ttsRoute;

  List<String> get sectionKeys => const <String>[
        'uiTheme',
        'uiLanguage',
        'uiTtsEngine',
      ];
}

/// 性能页：生效值只由 PerformanceBudget.resolve() 裁决（docs/05 §5.5）。
class PerformanceSpec {
  const PerformanceSpec({
    this.frameRate = 'auto',
    this.visualEffects = 'full',
    this.interactionMotion = true,
    this.immersiveReading = false,
    this.lowPowerMode = false,
    this.deviceTier = 'auto',
  });

  final String frameRate;
  final String visualEffects;
  final bool interactionMotion;
  final bool immersiveReading; // 默认关闭，且只在阅读页生效
  final bool lowPowerMode;
  final String deviceTier;

  /// 关全局动效 ⇒ 交互动效减少 + 视觉最低档。
  PerformanceSpec normalized() => PerformanceSpec(
        frameRate: frameRate,
        visualEffects: interactionMotion ? visualEffects : 'minimal',
        interactionMotion: interactionMotion,
        immersiveReading: immersiveReading,
        lowPowerMode: lowPowerMode,
        deviceTier: deviceTier,
      );
}

/// 小组件页：可同时放多张，内容 / 样式 / 尺寸 / 外观 / 季节各自配置。
class WidgetsSpec {
  const WidgetsSpec({this.slots = const <String>[], this.multipleAllowed = true});

  final List<String> slots;
  final bool multipleAllowed;
}

/// 缓存管理：按 Wenku8CacheKind 统计与清理。
/// 红线：清缓存不取消收藏、不删进度、不删本地原书；章节缓存与插图一并清理。
enum CacheKind { listing, detail, chapter, bookcase }

class CacheStats {
  const CacheStats({
    this.entries = 0,
    this.bytes = 0,
    this.chapterCount = 0,
    this.byKind = const <CacheKind, int>{},
  });

  final int entries;
  final int bytes;
  final int chapterCount;
  final Map<CacheKind, int> byKind;
}

class CacheManageSpec {
  const CacheManageSpec({
    required this.stats,
    this.resumeFailedJobs = true,
    this.clearableKinds = const <CacheKind>[
      CacheKind.listing,
      CacheKind.detail,
      CacheKind.chapter,
      CacheKind.bookcase,
    ],
  });

  final CacheStats stats;
  final bool resumeFailedJobs;
  final List<CacheKind> clearableKinds;

  /// 允许清理的对象只有缓存条目本身。
  bool mayClear(CacheKind kind) => clearableKinds.contains(kind);
  bool get deletesLocalBooks => false;
  bool get deletesProgress => false;
  bool get removesFavorites => false;
}

/// 备份 payload 白名单 / 排除清单（docs/05 §5.7）。
const List<String> kBackupAllowlist = <String>[
  'books_meta',
  'progress',
  'groups',
  'reading_sessions',
];

const List<String> kBackupDenylist = <String>[
  'password',
  'cookie',
  'token',
  'apiKey',
  's3Secret',
  'secretRef',
];

enum BackupStateSpec { idle, testing, backingUp, restoring, exporting, failed, done }

/// WebDAV 默认关闭；关闭态连「测试连接」都不发请求。
class BackupSnapshotSpec {
  const BackupSnapshotSpec({
    this.enabled = false,
    this.state = BackupStateSpec.idle,
    this.remoteEntries = const <String>[],
    this.lastResult = '',
    this.httpsOnly = true,
  });

  final bool enabled;
  final BackupStateSpec state;
  final List<String> remoteEntries;
  final String lastResult;
  final bool httpsOnly;

  bool get zeroRequestWhenDisabled => !enabled;
  bool mayTestConnection() => enabled && httpsOnly;

  /// 导入连接与同步目的地分别配置，改连接不动目的地（CLOUD_IMPORT.md）。
  bool get importConnectionSeparateFromSyncTarget => true;
}

class BackupPayload {
  const BackupPayload(this.data);

  final Map<String, Object> data;

  /// 只放行白名单键；任何凭据键出现即整包拒绝。
  bool validate() {
    for (final String k in data.keys) {
      if (!kBackupAllowlist.contains(k)) return false;
    }
    for (final String k in kBackupDenylist) {
      if (data.containsKey(k)) return false;
    }
    return true;
  }
}

/// 数据与存储页：缓存管理 / 备份。
class DataStorageSpec {
  const DataStorageSpec({
    required this.cache,
    required this.backup,
    this.entryKeys = const <String>['uiCacheManagement', 'uiBackup'],
  });

  final CacheManageSpec cache;
  final BackupSnapshotSpec backup;
  final List<String> entryKeys;
}
