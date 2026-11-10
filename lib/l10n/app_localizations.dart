import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// MaterialApp.onGenerateTitle 使用的应用标题
  ///
  /// In zh, this message translates to:
  /// **'本地阅读'**
  String get appTitle;

  /// No description provided for @feedbackNoCredentials.
  ///
  /// In zh, this message translates to:
  /// **''**
  String get feedbackNoCredentials;

  /// 关于与问题反馈段落 1
  ///
  /// In zh, this message translates to:
  /// **'支持 Android、iOS 与 HarmonyOS，不是 Wenku8 官方应用。'**
  String get aboutParagraph1;

  /// 关于与问题反馈段落 2
  ///
  /// In zh, this message translates to:
  /// **'应用完全免费、自愿支持；所有功能均免费，不销售会员、激活码或功能解锁，请警惕以本项目或开发者名义收费的行为。'**
  String get aboutParagraph2;

  /// 关于与问题反馈段落 3
  ///
  /// In zh, this message translates to:
  /// **'仅支持 Wenku8 与本地导入，不支持其他来源与自定义书源。'**
  String get aboutParagraph3;

  /// 关于与问题反馈段落 4
  ///
  /// In zh, this message translates to:
  /// **'小说、封面与插画归各权利人所有，源码许可证不授予内容权利；请只访问你有权使用的内容并遵守来源网站规则，勿绕过访问限制、破解 DRM，或未经许可复制、分发、售卖内容。'**
  String get aboutParagraph4;

  /// 关于与问题反馈段落 5
  ///
  /// In zh, this message translates to:
  /// **'提交问题时请附应用版本、设备、操作系统版本与复现步骤；请勿附带密码、Cookie 或 Token。'**
  String get aboutParagraph5;

  /// 关于与问题反馈段落 6
  ///
  /// In zh, this message translates to:
  /// **'第三方服务可能变更、限流或不可用。'**
  String get aboutParagraph6;

  /// 业务 / 合规 / 空状态文案：appDisclaimer
  ///
  /// In zh, this message translates to:
  /// **'本应用是第三方阅读客户端，用于阅读与管理本地书籍；不运营在线书库、不发布小说、不打包小说文件。在线内容与可用性由 Wenku8 决定，不提供因版权原因下架内容的在线访问。'**
  String get appDisclaimer;

  /// 业务 / 合规 / 空状态文案：nonOfficial
  ///
  /// In zh, this message translates to:
  /// **'支持 Android、iOS 与 HarmonyOS，不是 Wenku8 官方应用。'**
  String get nonOfficial;

  /// 业务 / 合规 / 空状态文案：freeStatement
  ///
  /// In zh, this message translates to:
  /// **'应用完全免费、自愿支持；所有功能均免费，不销售会员、激活码或功能解锁，请警惕以本项目或开发者名义收费的行为。'**
  String get freeStatement;

  /// 业务 / 合规 / 空状态文案：sources
  ///
  /// In zh, this message translates to:
  /// **'仅支持 Wenku8 与本地导入，不支持其他来源与自定义书源。'**
  String get sources;

  /// 业务 / 合规 / 空状态文案：contentRights
  ///
  /// In zh, this message translates to:
  /// **'小说、封面与插画归各权利人所有，源码许可证不授予内容权利；请只访问你有权使用的内容并遵守来源网站规则，勿绕过访问限制、破解 DRM，或未经许可复制、分发、售卖内容。'**
  String get contentRights;

  /// 业务 / 合规 / 空状态文案：thirdPartyService
  ///
  /// In zh, this message translates to:
  /// **'第三方服务可能变更、限流或不可用。'**
  String get thirdPartyService;

  /// 业务 / 合规 / 空状态文案：onlineAvailability
  ///
  /// In zh, this message translates to:
  /// **'在线内容与可用性由 Wenku8 决定；第三方服务可能变更、限流或不可用。'**
  String get onlineAvailability;

  /// 业务 / 合规 / 空状态文案：issueGuidance
  ///
  /// In zh, this message translates to:
  /// **'提交问题时请附应用版本、设备、操作系统版本与复现步骤；请勿附带密码、Cookie 或 Token。'**
  String get issueGuidance;

  /// 业务 / 合规 / 空状态文案：onlineEntryNote
  ///
  /// In zh, this message translates to:
  /// **'此处只展示在线列表、详情与目录元数据。阅读内容需由用户自行导入本地书库；应用不内置、不打包、不分发小说文件，也不提供因版权原因下架内容的在线访问。'**
  String get onlineEntryNote;

  /// 业务 / 合规 / 空状态文案：localOnlyNote
  ///
  /// In zh, this message translates to:
  /// **'默认为纯本地模式，关闭态下全应用不产生任何网络请求；在线目录与 WebDAV 均默认关闭。'**
  String get localOnlyNote;

  /// 业务 / 合规 / 空状态文案：importFormats
  ///
  /// In zh, this message translates to:
  /// **'TXT（编码自动识别 + 章节切分）· EPUB · CBZ/ZIP · 图片文件夹 · PDF（逐页渲染）· RAR4 及更早。'**
  String get importFormats;

  /// 业务 / 合规 / 空状态文案：archiveNotice
  ///
  /// In zh, this message translates to:
  /// **'RAR5 与加密压缩包暂不支持，请转换为 CBZ/ZIP。'**
  String get archiveNotice;

  /// 业务 / 合规 / 空状态文案：permissionNotice
  ///
  /// In zh, this message translates to:
  /// **'权限：Android 13+ 仅申请读取图片；文档类书籍不在媒体库覆盖范围内，仍需走系统文件选择器目录授权或「所有文件访问」。未申请音频、视频与通知权限。无权限时导入对话框会明确提示当前状态。'**
  String get permissionNotice;

  /// 业务 / 合规 / 空状态文案：importChannels
  ///
  /// In zh, this message translates to:
  /// **'可通过 OpenList / WebDAV 或夸克（实验性）导入；也可通过系统文档选择器访问 OneDrive、Google Drive 等服务。授权会持久化，重启后可一键重扫。'**
  String get importChannels;

  /// 业务 / 合规 / 空状态文案：importBody
  ///
  /// In zh, this message translates to:
  /// **'\$importFormats\n\$archiveNotice\n\n\$permissionNotice\n\n\$importChannels\n\n\$localOnlyNote'**
  String get importBody;

  /// 业务 / 合规 / 空状态文案：importTitle
  ///
  /// In zh, this message translates to:
  /// **'导入书籍'**
  String get importTitle;

  /// 业务 / 合规 / 空状态文案：importWizardTitle
  ///
  /// In zh, this message translates to:
  /// **'导入向导'**
  String get importWizardTitle;

  /// 业务 / 合规 / 空状态文案：importWizardStaticNote
  ///
  /// In zh, this message translates to:
  /// **'静态交付模式：授权与扫描均为本地演示数据，不调用系统文件选择器、不读取文件字节、不解压、不联网；真实 SAF 持久化与文件扫描需三端平台能力（❄️ 冻结）。'**
  String get importWizardStaticNote;

  /// 业务 / 合规 / 空状态文案：importRar5Reason
  ///
  /// In zh, this message translates to:
  /// **'RAR5 暂不支持，请转换为 CBZ/ZIP 后重新扫描。'**
  String get importRar5Reason;

  /// 业务 / 合规 / 空状态文案：importEncryptedReason
  ///
  /// In zh, this message translates to:
  /// **'加密压缩包暂不支持，请转换为 CBZ/ZIP 后重新扫描。'**
  String get importEncryptedReason;

  /// 业务 / 合规 / 空状态文案：importUnsupportedReason
  ///
  /// In zh, this message translates to:
  /// **'未登记的格式，静态阶段不猜测内容，请确认扩展名。'**
  String get importUnsupportedReason;

  /// 业务 / 合规 / 空状态文案：importNoModeHint
  ///
  /// In zh, this message translates to:
  /// **'先选择一种授权方式，再继续。'**
  String get importNoModeHint;

  /// 业务 / 合规 / 空状态文案：importNoGrantHint
  ///
  /// In zh, this message translates to:
  /// **'尚未确认授权；静态阶段只记录选择，不会申请系统权限。'**
  String get importNoGrantHint;

  /// 业务 / 合规 / 空状态文案：importScanEmpty
  ///
  /// In zh, this message translates to:
  /// **'这个目录没有可导入的书籍文件。'**
  String get importScanEmpty;

  /// 业务 / 合规 / 空状态文案：importNoAcceptedHint
  ///
  /// In zh, this message translates to:
  /// **'没有可导入的文件；请先处理不支持的格式，再重新扫描。'**
  String get importNoAcceptedHint;

  /// 业务 / 合规 / 空状态文案：importConflictNote
  ///
  /// In zh, this message translates to:
  /// **'同名书籍已存在。演示书库只读，「替换」与「合并记录」会记为延后处理；「两者都保留」会生成一份副本。'**
  String get importConflictNote;

  /// 业务 / 合规 / 空状态文案：importDoneNote
  ///
  /// In zh, this message translates to:
  /// **'导入结果仅写入内存书库，重启后恢复演示数据；不改动只读演示书籍。'**
  String get importDoneNote;

  /// 业务 / 合规 / 空状态文案：importWizardEntry
  ///
  /// In zh, this message translates to:
  /// **'打开导入向导'**
  String get importWizardEntry;

  /// 业务 / 合规 / 空状态文案：emptyLibraryTitle
  ///
  /// In zh, this message translates to:
  /// **'书库还是空的'**
  String get emptyLibraryTitle;

  /// 业务 / 合规 / 空状态文案：emptyLibraryBody
  ///
  /// In zh, this message translates to:
  /// **'通过系统文件选择器授权目录后导入本地书籍；支持 TXT / EPUB / CBZ / PDF 等格式。文档类书籍不在媒体库覆盖范围内，需要目录授权或「所有文件访问」。'**
  String get emptyLibraryBody;

  /// 业务 / 合规 / 空状态文案：noResultTitle
  ///
  /// In zh, this message translates to:
  /// **'没有找到这本书'**
  String get noResultTitle;

  /// 业务 / 合规 / 空状态文案：noResultBody
  ///
  /// In zh, this message translates to:
  /// **'试试更短的书名、作者名，或切换到其他关键词。搜索只在本地书库内进行，不产生网络请求。'**
  String get noResultBody;

  /// 业务 / 合规 / 空状态文案：demoDataNote
  ///
  /// In zh, this message translates to:
  /// **'当前为演示数据；编辑结果仅保存在内存，重启后恢复。'**
  String get demoDataNote;

  /// 业务 / 合规 / 空状态文案：excerptLocalNote
  ///
  /// In zh, this message translates to:
  /// **'摘录只保存在本地内存，不上传、不联网；重启后恢复演示数据。'**
  String get excerptLocalNote;

  /// 业务 / 合规 / 空状态文案：excerptExportNote
  ///
  /// In zh, this message translates to:
  /// **'导出仅生成本地纯文本预览，不写文件、不调用系统分享、不上传；落盘与分享需平台能力，静态阶段不实施。'**
  String get excerptExportNote;

  /// 业务 / 合规 / 空状态文案：excerptReadOnlyNote
  ///
  /// In zh, this message translates to:
  /// **'演示摘录只读；你可以编辑批注、更换划线色或删除自己采集的条目。'**
  String get excerptReadOnlyNote;

  /// 业务 / 合规 / 空状态文案：excerptEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'还没有摘录'**
  String get excerptEmptyTitle;

  /// 业务 / 合规 / 空状态文案：excerptEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'去阅读器点选正文中的一行或多行，点顶栏书签即可摘录。'**
  String get excerptEmptyBody;

  /// 业务 / 合规 / 空状态文案：excerptNoResultTitle
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的摘录'**
  String get excerptNoResultTitle;

  /// 业务 / 合规 / 空状态文案：excerptNoResultBody
  ///
  /// In zh, this message translates to:
  /// **'试试更短的关键词，或清掉按书 / 划线色 / 范围的筛选条件。'**
  String get excerptNoResultBody;

  /// 业务 / 合规 / 空状态文案：comicPlaceholderNote
  ///
  /// In zh, this message translates to:
  /// **'当前为按宽高比占位；真实页像素需三端 BookRenderBridge，静态阶段不解码图片。'**
  String get comicPlaceholderNote;

  /// 业务 / 合规 / 空状态文案：comicTocNote
  ///
  /// In zh, this message translates to:
  /// **'话集由归档内目录名 / 文件名识别，不解压、不读文件内容；未识别的页归入「未分话」，不会静默丢弃。识别不全会显示识别率。'**
  String get comicTocNote;

  /// 业务 / 合规 / 空状态文案：comicLocalNote
  ///
  /// In zh, this message translates to:
  /// **'漫画阅读与分话目录全在本地完成，不联网、不上传；页像素渲染需平台能力（❄️ 冻结）。'**
  String get comicLocalNote;

  /// 业务 / 合规 / 空状态文案：favoriteLocalNote
  ///
  /// In zh, this message translates to:
  /// **'收藏只保存在本地内存，不联网、不上传；重启后恢复演示收藏。'**
  String get favoriteLocalNote;

  /// 业务 / 合规 / 空状态文案：favoriteEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏'**
  String get favoriteEmptyTitle;

  /// 业务 / 合规 / 空状态文案：favoriteEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'在书籍详情或阅读器顶栏点星标，就能把书收进这里。'**
  String get favoriteEmptyBody;

  /// 业务 / 合规 / 空状态文案：favoritesOnlyHint
  ///
  /// In zh, this message translates to:
  /// **'只看收藏'**
  String get favoritesOnlyHint;

  /// 业务 / 合规 / 空状态文案：screenshotNote
  ///
  /// In zh, this message translates to:
  /// **'界面截图使用演示书籍数据，应用界面为中文。'**
  String get screenshotNote;

  /// 业务 / 合规 / 空状态文案：keepsakeTitle
  ///
  /// In zh, this message translates to:
  /// **'纪念物'**
  String get keepsakeTitle;

  /// 业务 / 合规 / 空状态文案：calendarMonthTitle
  ///
  /// In zh, this message translates to:
  /// **'阅读日历 · 整月'**
  String get calendarMonthTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeStaticNote
  ///
  /// In zh, this message translates to:
  /// **'纪念物由阅读统计与摘录自动生成，不手写演示条目；只保存在本地内存，不上传、不联网。五种季节手账配色可在书架页切换，桌面小组件本体需三端原生'**
  String get keepsakeStaticNote;

  /// 业务 / 合规 / 空状态文案：calendarStaticNote
  ///
  /// In zh, this message translates to:
  /// **'月度日历由近 35 天演示热力与摘录聚合而来，周一起始、固定 6 周网格；跨月补格只用于对齐，不计入月度合计。静态阶段不读取真实阅读数据库。'**
  String get calendarStaticNote;

  /// 业务 / 合规 / 空状态文案：keepsakeEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'还没有纪念物'**
  String get keepsakeEmptyTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'继续阅读、达成目标或摘下一句话，纪念物就会自动出现在这里。'**
  String get keepsakeEmptyBody;

  /// 业务 / 合规 / 空状态文案：calendarNoRecordNote
  ///
  /// In zh, this message translates to:
  /// **'这一天还没有阅读记录'**
  String get calendarNoRecordNote;

  /// 业务 / 合规 / 空状态文案：calendarOutOfRangeNote
  ///
  /// In zh, this message translates to:
  /// **'已到演示数据覆盖的月份边界'**
  String get calendarOutOfRangeNote;

  /// 业务 / 合规 / 空状态文案：calendarOpenMonth
  ///
  /// In zh, this message translates to:
  /// **'查看整月'**
  String get calendarOpenMonth;

  /// 业务 / 合规 / 空状态文案：calendarBackToThisMonth
  ///
  /// In zh, this message translates to:
  /// **'回到本月'**
  String get calendarBackToThisMonth;

  /// 业务 / 合规 / 空状态文案：calendarAllMonths
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get calendarAllMonths;

  /// 业务 / 合规 / 空状态文案：localizationTitle
  ///
  /// In zh, this message translates to:
  /// **'文案表与语言预览'**
  String get localizationTitle;

  /// 业务 / 合规 / 空状态文案：localizationPreviewTitle
  ///
  /// In zh, this message translates to:
  /// **'按语言预览文案'**
  String get localizationPreviewTitle;

  /// 业务 / 合规 / 空状态文案：localizationDefaultNote
  ///
  /// In zh, this message translates to:
  /// **'默认中文 · 不跟随系统语言'**
  String get localizationDefaultNote;

  /// 业务 / 合规 / 空状态文案：localizationStaticNote
  ///
  /// In zh, this message translates to:
  /// **'发布版界面为中文（参考仓库 README：The app interface is in Chinese）。静态阶段只核对多语言表结构与回退口径，不自动跟随系统语言、不逐页切换界面文案；页面仍读中文常量这一份默认 bundle。完整逐页本地化需逐个页面接入，属后续候选。'**
  String get localizationStaticNote;

  /// 业务 / 合规 / 空状态文案：comicSpreadTitle
  ///
  /// In zh, this message translates to:
  /// **'双页与翻页方向'**
  String get comicSpreadTitle;

  /// 业务 / 合规 / 空状态文案：comicBlankSlotNote
  ///
  /// In zh, this message translates to:
  /// **'补白槽 · 非缺页'**
  String get comicBlankSlotNote;

  /// 业务 / 合规 / 空状态文案：comicVerticalLockNote
  ///
  /// In zh, this message translates to:
  /// **'竖向连续滚动没有左右概念，已自动锁定为「单页 · 左 → 右」。切到横向跨页翻页后，双页与右 → 左偏好才会生效。'**
  String get comicVerticalLockNote;

  /// 业务 / 合规 / 空状态文案：comicSpreadStaticNote
  ///
  /// In zh, this message translates to:
  /// **'双页跨页只编排页序与视觉槽位：封面独占一跨，奇数页补白并明示为「补白槽 · 非缺页」，不静默吞页、不伪造图片。右 → 左只改变跨内左右顺序与翻页前进方向，不改变阅读顺序。静态阶段仍按宽高比占位，不解码图片、不读文件字节；页像素与真机手势需三端 BookRenderBridge（❄️ 冻结）。'**
  String get comicSpreadStaticNote;

  /// 业务 / 合规 / 空状态文案：bookExcerptTitle
  ///
  /// In zh, this message translates to:
  /// **'这本书的摘录'**
  String get bookExcerptTitle;

  /// 业务 / 合规 / 空状态文案：bookExcerptEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'这本书还没有摘录'**
  String get bookExcerptEmptyTitle;

  /// 业务 / 合规 / 空状态文案：bookExcerptEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'在阅读器里点选一行正文，再点顶栏书签即可摘录；摘完回到这里就能看到。也可以清空筛选，查看全部书籍的摘录。'**
  String get bookExcerptEmptyBody;

  /// 业务 / 合规 / 空状态文案：bookExcerptScopedNote
  ///
  /// In zh, this message translates to:
  /// **'当前只看这一本书，点「全部书」可查看全部摘录。筛选按 bookId，书名在详情页编辑后不会让筛选失效。'**
  String get bookExcerptScopedNote;

  /// 业务 / 合规 / 空状态文案：bookExcerptPinnedNote
  ///
  /// In zh, this message translates to:
  /// **'这本书暂时没有摘录，仍保留在按书筛选里并标注 0 条，不会变成看不见的筛选条件。'**
  String get bookExcerptPinnedNote;

  /// 业务 / 合规 / 空状态文案：bookExcerptStaticNote
  ///
  /// In zh, this message translates to:
  /// **'详情入口只传 bookId，由摘录管理页自行筛选，feature 之间不互相依赖。摘录只存内存、不联网、不落盘；桌面小组件与持久化仍 ❄️ 冻结。'**
  String get bookExcerptStaticNote;

  /// 业务 / 合规 / 空状态文案：bookExcerptMissingNote
  ///
  /// In zh, this message translates to:
  /// **'这本书不在当前书库（可能已移除，或来自上次的导入数据）。摘录仍按 bookId 匹配，点「全部书」可查看其它书籍的摘录。'**
  String get bookExcerptMissingNote;

  /// 业务 / 合规 / 空状态文案：excerptSearchTitleNote
  ///
  /// In zh, this message translates to:
  /// **'书名搜索同时匹配书库当前名称与摘录捕获时的旧名；改名后搜新旧名都能找到。'**
  String get excerptSearchTitleNote;

  /// 业务 / 合规 / 空状态文案：excerptExportSnapshotNote
  ///
  /// In zh, this message translates to:
  /// **'导出正文保留摘录捕获时的书名快照，保证历史导出可复核；页面展示、搜索、排序与分组使用书库当前名称。'**
  String get excerptExportSnapshotNote;

  /// 业务 / 合规 / 空状态文案：keepsakeAllKinds
  ///
  /// In zh, this message translates to:
  /// **'全部类型'**
  String get keepsakeAllKinds;

  /// 业务 / 合规 / 空状态文案：keepsakeOpenLibrary
  ///
  /// In zh, this message translates to:
  /// **'查看全部纪念物'**
  String get keepsakeOpenLibrary;

  /// 业务 / 合规 / 空状态文案：keepsakeLibraryTitle
  ///
  /// In zh, this message translates to:
  /// **'纪念物册'**
  String get keepsakeLibraryTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeFilterHint
  ///
  /// In zh, this message translates to:
  /// **'类型与月份可叠加筛选；类型旁的条数只随月份与关键词变化，不因已选类型归零。'**
  String get keepsakeFilterHint;

  /// 业务 / 合规 / 空状态文案：keepsakeKindEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'这一类还没有纪念物'**
  String get keepsakeKindEmptyTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeKindEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'纪念物由阅读记录与摘录自动生成，达到条件后会出现在这里。也可以清空筛选查看其它类型。'**
  String get keepsakeKindEmptyBody;

  /// 业务 / 合规 / 空状态文案：keepsakeNoResultTitle
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的纪念物'**
  String get keepsakeNoResultTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeNoResultBody
  ///
  /// In zh, this message translates to:
  /// **'换个类型、月份或关键词试试；也可以清空筛选条件查看全部纪念物。'**
  String get keepsakeNoResultBody;

  /// 业务 / 合规 / 空状态文案：keepsakeFilterStaticNote
  ///
  /// In zh, this message translates to:
  /// **'纪念物只从统计快照与摘录聚合，页面不缓存、只存内存、不联网、不落盘；桌面小组件本体 ❄️ 冻结。'**
  String get keepsakeFilterStaticNote;

  /// 业务 / 合规 / 空状态文案：keepsakeWidgetKindNote
  ///
  /// In zh, this message translates to:
  /// **'内容选「纪念物」时，可为每个小组件单独指定一种类型；留空则显示全部。多个小组件各自独立。'**
  String get keepsakeWidgetKindNote;

  /// 业务 / 合规 / 空状态文案：keepsakeMonthPreviewNote
  ///
  /// In zh, this message translates to:
  /// **'「本月」取统计快照的固定基准日，与热力图、纪念物册同月；桌面小组件本体仍 ❄️ 冻结，这里只是应用内预览。'**
  String get keepsakeMonthPreviewNote;

  /// 业务 / 合规 / 空状态文案：keepsakeMonthPreviewOpen
  ///
  /// In zh, this message translates to:
  /// **'查看本月纪念物'**
  String get keepsakeMonthPreviewOpen;

  /// 业务 / 合规 / 空状态文案：keepsakeMonthEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'本月还没有纪念物。它由阅读记录与摘录自动生成，达标后会出现在这里。'**
  String get keepsakeMonthEmptyBody;

  /// 业务 / 合规 / 空状态文案：keepsakeMonthKindEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'本月有纪念物，但没有这一类。清空类型筛选可看本月全部纪念物。'**
  String get keepsakeMonthKindEmptyBody;

  /// 业务 / 合规 / 空状态文案：keepsakeMonthNoResultBody
  ///
  /// In zh, this message translates to:
  /// **'本月当前筛选没有命中项，换个类型或清空筛选试试。'**
  String get keepsakeMonthNoResultBody;

  /// 业务 / 合规 / 空状态文案：comicWideSoloTitle
  ///
  /// In zh, this message translates to:
  /// **'宽幅页独占一跨'**
  String get comicWideSoloTitle;

  /// 业务 / 合规 / 空状态文案：comicWideSoloNote
  ///
  /// In zh, this message translates to:
  /// **'横幅 / 跨页彩图不与邻页并排；前后页各自补白，补白槽写明「宽幅页独占一跨 · 非缺页」。'**
  String get comicWideSoloNote;

  /// 业务 / 合规 / 空状态文案：comicWideSoloSingleNote
  ///
  /// In zh, this message translates to:
  /// **'单页模式下每页本来就独占，此偏好保留但不产生视觉差异。'**
  String get comicWideSoloSingleNote;

  /// 业务 / 合规 / 空状态文案：excerptAnchorRestoreNote
  ///
  /// In zh, this message translates to:
  /// **'换行号后按「位置精确 → 位置一致文字已变 → 本章文本唯一」三级还原；多处相同文本不自动高亮，避免画错位置。'**
  String get excerptAnchorRestoreNote;

  /// 业务 / 合规 / 空状态文案：keepsakeDayEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'这一天还没有纪念物'**
  String get keepsakeDayEmptyTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeDayEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'回到阅读日历换一天看看，或清除日期筛选查看整月纪念物。'**
  String get keepsakeDayEmptyBody;

  /// 业务 / 合规 / 空状态文案：keepsakeDayFilterNote
  ///
  /// In zh, this message translates to:
  /// **'只看这一天 · 清除后回到整月'**
  String get keepsakeDayFilterNote;

  /// 业务 / 合规 / 空状态文案：calendarOpenMonthKeepsakes
  ///
  /// In zh, this message translates to:
  /// **'查看本月纪念物'**
  String get calendarOpenMonthKeepsakes;

  /// 业务 / 合规 / 空状态文案：calendarOpenDayKeepsakes
  ///
  /// In zh, this message translates to:
  /// **'查看当天纪念物'**
  String get calendarOpenDayKeepsakes;

  /// 业务 / 合规 / 空状态文案：calendarCrossMonthNote
  ///
  /// In zh, this message translates to:
  /// **'跨月补格只用于对齐周起始，不提供当天深链'**
  String get calendarCrossMonthNote;

  /// 业务 / 合规 / 空状态文案：calendarInvalidDateNote
  ///
  /// In zh, this message translates to:
  /// **'日期格式无效，无法定位到阅读日历'**
  String get calendarInvalidDateNote;

  /// 业务 / 合规 / 空状态文案：keepsakeOpenCalendarDay
  ///
  /// In zh, this message translates to:
  /// **'在日历中查看'**
  String get keepsakeOpenCalendarDay;

  /// 业务 / 合规 / 空状态文案：keepsakeOpenCalendarMonth
  ///
  /// In zh, this message translates to:
  /// **'查看整月日历'**
  String get keepsakeOpenCalendarMonth;

  /// 业务 / 合规 / 空状态文案：comicSpineGutterTitle
  ///
  /// In zh, this message translates to:
  /// **'双页书脊留白'**
  String get comicSpineGutterTitle;

  /// 业务 / 合规 / 空状态文案：comicSpineGutterNote
  ///
  /// In zh, this message translates to:
  /// **'只在两页真实页并排时绘制书脊：中间留白按槽宽比例计算并夹在 8–28px，左右页内侧各叠一层渐暗，模拟装订；封面 / 宽幅 / 补白跨不画书脊。'**
  String get comicSpineGutterNote;

  /// 业务 / 合规 / 空状态文案：comicSpineShadeTitle
  ///
  /// In zh, this message translates to:
  /// **'书脊渐暗强度'**
  String get comicSpineShadeTitle;

  /// 业务 / 合规 / 空状态文案：comicSpineShadeNote
  ///
  /// In zh, this message translates to:
  /// **'强度按槽宽自动选档（窄屏含蓄、宽屏加强），目标色按阅读背景亮度反推：浅底用黑色阴影，深底改用折减的浅色内高光，避免夜间模式下黑叠黑看不见。这是固定视觉规则，不是用户可调设置；静态阶段只做模型，未接真机调参。'**
  String get comicSpineShadeNote;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeTitle
  ///
  /// In zh, this message translates to:
  /// **'日期范围'**
  String get keepsakeDateRangeTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeHint
  ///
  /// In zh, this message translates to:
  /// **'YYYY-MM-DD'**
  String get keepsakeDateRangeHint;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeNote
  ///
  /// In zh, this message translates to:
  /// **'闭区间，起止可只填一端；起日晚于止日会自动交换。设置范围会清除「只看某天」与「整月」，避免筛选条件互相打架。'**
  String get keepsakeDateRangeNote;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeInvalid
  ///
  /// In zh, this message translates to:
  /// **'日期格式无效，请输入 YYYY-MM-DD（例如 2026-11-08）'**
  String get keepsakeDateRangeInvalid;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeFilterNote
  ///
  /// In zh, this message translates to:
  /// **'只看这段日期 · 清除后回到全部纪念物'**
  String get keepsakeDateRangeFilterNote;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeAll
  ///
  /// In zh, this message translates to:
  /// **'全部日期'**
  String get keepsakeDateRangeAll;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeThisMonth
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get keepsakeDateRangeThisMonth;

  /// 业务 / 合规 / 空状态文案：keepsakeDateRangeLast7
  ///
  /// In zh, this message translates to:
  /// **'最近 7 天'**
  String get keepsakeDateRangeLast7;

  /// 业务 / 合规 / 空状态文案：keepsakeRangeEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'这段日期还没有纪念物'**
  String get keepsakeRangeEmptyTitle;

  /// 业务 / 合规 / 空状态文案：keepsakeRangeEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'换一段日期或清除范围筛选，也可以回到阅读日历按天查看。'**
  String get keepsakeRangeEmptyBody;

  /// 业务 / 合规 / 空状态文案：calendarOpenDayExcerpts
  ///
  /// In zh, this message translates to:
  /// **'查看当天摘录'**
  String get calendarOpenDayExcerpts;

  /// 业务 / 合规 / 空状态文案：excerptDayFilterNote
  ///
  /// In zh, this message translates to:
  /// **'只看这一天 · 清除后回到全部摘录'**
  String get excerptDayFilterNote;

  /// 业务 / 合规 / 空状态文案：excerptDayEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'这一天还没有摘录'**
  String get excerptDayEmptyTitle;

  /// 业务 / 合规 / 空状态文案：excerptDayEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'回到阅读日历换一天看看，或清除日期筛选回到全部摘录。'**
  String get excerptDayEmptyBody;

  /// 业务 / 合规 / 空状态文案：excerptDayScopedTitle
  ///
  /// In zh, this message translates to:
  /// **'当日摘录'**
  String get excerptDayScopedTitle;

  /// 业务 / 合规 / 空状态文案：wenkuOnlySources
  ///
  /// In zh, this message translates to:
  /// **'仅支持 Wenku8 在线目录与用户自行导入的本地书籍；不支持其它来源，也不支持自定义书源。'**
  String get wenkuOnlySources;

  /// 业务 / 合规 / 空状态文案：wenkuContentOwnership
  ///
  /// In zh, this message translates to:
  /// **'小说、封面与插画归各自权利人所有；源码许可不授予任何内容权利。'**
  String get wenkuContentOwnership;

  /// 业务 / 合规 / 空状态文案：wenkuNoWithdrawn
  ///
  /// In zh, this message translates to:
  /// **'不运营在线书库、不发布小说、不打包小说文件，也不提供因版权原因下架的内容。'**
  String get wenkuNoWithdrawn;

  /// 业务 / 合规 / 空状态文案：wenkuNoCircumvention
  ///
  /// In zh, this message translates to:
  /// **'仅访问你有权使用的公开内容并遵守来源网站规则；不绕过访问限制、不破坏 DRM，不复制、分发或售卖内容。'**
  String get wenkuNoCircumvention;

  /// 业务 / 合规 / 空状态文案：wenkuThirdParty
  ///
  /// In zh, this message translates to:
  /// **'第三方服务可能变更、限制请求频率或暂时不可用；列表与内容可用性以 Wenku8 为准。'**
  String get wenkuThirdParty;

  /// 业务 / 合规 / 空状态文案：wenkuNoCredentials
  ///
  /// In zh, this message translates to:
  /// **'反馈与问题报告里请勿包含密码、Cookie 或 Token；生成预览时会自动移除常见凭据字段。'**
  String get wenkuNoCredentials;

  /// 业务 / 合规 / 空状态文案：wenkuSourceNote
  ///
  /// In zh, this message translates to:
  /// **'唯一的在线来源。只读取列表与目录元数据，章节正文由 Wenku8 在使用时提供；本应用不缓存、不打包。'**
  String get wenkuSourceNote;

  /// 业务 / 合规 / 空状态文案：wenkuLocalSourceNote
  ///
  /// In zh, this message translates to:
  /// **'书籍文件由你自己导入，支持本地书库的全部格式与目录授权方式。'**
  String get wenkuLocalSourceNote;

  /// 业务 / 合规 / 空状态文案：wenkuCustomSourceNote
  ///
  /// In zh, this message translates to:
  /// **'自定义书源不提供；来源列表固定为 Wenku8 与本地导入两项。'**
  String get wenkuCustomSourceNote;

  /// 业务 / 合规 / 空状态文案：wenkuShelfTabLocal
  ///
  /// In zh, this message translates to:
  /// **'本地书库'**
  String get wenkuShelfTabLocal;

  /// 业务 / 合规 / 空状态文案：wenkuShelfTabCloud
  ///
  /// In zh, this message translates to:
  /// **'云端来源'**
  String get wenkuShelfTabCloud;

  /// 业务 / 合规 / 空状态文案：wenkuCloudTitle
  ///
  /// In zh, this message translates to:
  /// **'云端来源'**
  String get wenkuCloudTitle;

  /// 业务 / 合规 / 空状态文案：wenkuCloudSubtitle
  ///
  /// In zh, this message translates to:
  /// **'选一个来源，看看有什么可读'**
  String get wenkuCloudSubtitle;

  /// 业务 / 合规 / 空状态文案：wenkuSourceNavTitle
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get wenkuSourceNavTitle;

  /// 业务 / 合规 / 空状态文案：wenkuFeedTitle
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get wenkuFeedTitle;

  /// 业务 / 合规 / 空状态文案：wenkuSearchHint
  ///
  /// In zh, this message translates to:
  /// **'搜索书名 / 作者'**
  String get wenkuSearchHint;

  /// 业务 / 合规 / 空状态文案：wenkuStatusNote
  ///
  /// In zh, this message translates to:
  /// **'只读取列表与目录元数据；下架内容不展示，章节正文不在本应用内缓存。'**
  String get wenkuStatusNote;

  /// 业务 / 合规 / 空状态文案：wenkuLockedTitle
  ///
  /// In zh, this message translates to:
  /// **'在线目录尚未开启'**
  String get wenkuLockedTitle;

  /// 业务 / 合规 / 空状态文案：wenkuLockedBody
  ///
  /// In zh, this message translates to:
  /// **'纯本地模式下全应用零网络请求，连演示目录也不会读取。开启后可浏览 Wenku8 列表、详情与章节目录，并把书加入本地书库。'**
  String get wenkuLockedBody;

  /// 业务 / 合规 / 空状态文案：wenkuUnlockButton
  ///
  /// In zh, this message translates to:
  /// **'开启在线目录'**
  String get wenkuUnlockButton;

  /// 业务 / 合规 / 空状态文案：wenkuBookAdd
  ///
  /// In zh, this message translates to:
  /// **'加入本地书库'**
  String get wenkuBookAdd;

  /// 业务 / 合规 / 空状态文案：wenkuBookAdded
  ///
  /// In zh, this message translates to:
  /// **'已在本地书库'**
  String get wenkuBookAdded;

  /// 业务 / 合规 / 空状态文案：wenkuDetailTitle
  ///
  /// In zh, this message translates to:
  /// **'书籍详情'**
  String get wenkuDetailTitle;

  /// 业务 / 合规 / 空状态文案：wenkuDetailSynopsis
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get wenkuDetailSynopsis;

  /// 业务 / 合规 / 空状态文案：wenkuDetailToc
  ///
  /// In zh, this message translates to:
  /// **'卷与章节目录'**
  String get wenkuDetailToc;

  /// 业务 / 合规 / 空状态文案：wenkuDetailChapterNote
  ///
  /// In zh, this message translates to:
  /// **'章节正文由 Wenku8 在使用时提供。'**
  String get wenkuDetailChapterNote;

  /// 业务 / 合规 / 空状态文案：wenkuDetailStaticNote
  ///
  /// In zh, this message translates to:
  /// **'静态阶段只登记元数据壳，不下载、不缓存、不打包小说正文；加入本地后可像其它本地书一样管理。'**
  String get wenkuDetailStaticNote;

  /// 业务 / 合规 / 空状态文案：wenkuEmptyTitle
  ///
  /// In zh, this message translates to:
  /// **'这个目录暂时没有书'**
  String get wenkuEmptyTitle;

  /// 业务 / 合规 / 空状态文案：wenkuEmptyBody
  ///
  /// In zh, this message translates to:
  /// **'换个榜单或搜索别的书名试试；第三方目录也可能暂时不可用。'**
  String get wenkuEmptyBody;

  /// 业务 / 合规 / 空状态文案：wenkuRefresh
  ///
  /// In zh, this message translates to:
  /// **'刷新目录'**
  String get wenkuRefresh;

  /// 业务 / 合规 / 空状态文案：wenkuAddedNote
  ///
  /// In zh, this message translates to:
  /// **'已加入本地书库，切回「本地书库」即可看到。'**
  String get wenkuAddedNote;

  /// 业务 / 合规 / 空状态文案：feedbackTitle
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get feedbackTitle;

  /// 业务 / 合规 / 空状态文案：feedbackSubtitle
  ///
  /// In zh, this message translates to:
  /// **'带上四要素，问题更容易被定位'**
  String get feedbackSubtitle;

  /// 业务 / 合规 / 空状态文案：feedbackPreviewTitle
  ///
  /// In zh, this message translates to:
  /// **'问题反馈 · 纯文本预览'**
  String get feedbackPreviewTitle;

  /// 业务 / 合规 / 空状态文案：feedbackMissing
  ///
  /// In zh, this message translates to:
  /// **'还需填写：'**
  String get feedbackMissing;

  /// 业务 / 合规 / 空状态文案：feedbackStaticNote
  ///
  /// In zh, this message translates to:
  /// **'只生成纯文本供复制，不上传、不打开 Issue 页面、不写文件。请自行检查后再提交。'**
  String get feedbackStaticNote;

  /// 业务 / 合规 / 空状态文案：supportTitle
  ///
  /// In zh, this message translates to:
  /// **'全功能免费'**
  String get supportTitle;

  /// 业务 / 合规 / 空状态文案：supportBody
  ///
  /// In zh, this message translates to:
  /// **'所有功能免费，不售卖会员、激活码或功能解锁；支持完全自愿。请警惕以本项目或开发者名义收费的行为。'**
  String get supportBody;

  /// 业务 / 合规 / 空状态文案：profileHeroTitle
  ///
  /// In zh, this message translates to:
  /// **'我  的'**
  String get profileHeroTitle;

  /// 业务 / 合规 / 空状态文案：profileHeroSubtitle
  ///
  /// In zh, this message translates to:
  /// **'把阅读调成自己喜欢的样子'**
  String get profileHeroSubtitle;

  /// 业务 / 合规 / 空状态文案：profileSectionAppearance
  ///
  /// In zh, this message translates to:
  /// **'外观与阅读'**
  String get profileSectionAppearance;

  /// 业务 / 合规 / 空状态文案：profileSectionSources
  ///
  /// In zh, this message translates to:
  /// **'来源与在线'**
  String get profileSectionSources;

  /// 业务 / 合规 / 空状态文案：profileSectionLibrary
  ///
  /// In zh, this message translates to:
  /// **'书库与导入'**
  String get profileSectionLibrary;

  /// 业务 / 合规 / 空状态文案：profileSectionFavorites
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get profileSectionFavorites;

  /// 业务 / 合规 / 空状态文案：profileSectionSupport
  ///
  /// In zh, this message translates to:
  /// **'支持与反馈'**
  String get profileSectionSupport;

  /// 业务 / 合规 / 空状态文案：profileSectionAbout
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get profileSectionAbout;

  /// 业务 / 合规 / 空状态文案：cloudChannelsTitle
  ///
  /// In zh, this message translates to:
  /// **'云端导入渠道'**
  String get cloudChannelsTitle;

  /// 业务 / 合规 / 空状态文案：cloudChannelsNote
  ///
  /// In zh, this message translates to:
  /// **'OpenList、WebDAV、夸克网盘（实验性）与系统文档选择器（OneDrive / Google Drive 等）。渠道只是入口选择，不内置账号与凭据；真实授权与文件读取在静态阶段冻结。'**
  String get cloudChannelsNote;

  /// 业务 / 合规 / 空状态文案：mergeRecordsNote
  ///
  /// In zh, this message translates to:
  /// **'手动合并与同步原书、阅读记录的策略已在导入向导中登记；静态阶段只记为待办决策，不改写演示书库。'**
  String get mergeRecordsNote;

  /// 业务 / 合规 / 空状态文案：wenkuFormatsNote
  ///
  /// In zh, this message translates to:
  /// **'格式已对齐参考仓库：TXT / EPUB / MOBI / AZW / AZW3 / PRC / FB2 / PDF / DOC / DOCX / RTF / HTML / Markdown / ZIP。老式二进制格式静态阶段只登记路由，真实解码器冻结。'**
  String get wenkuFormatsNote;

  /// 业务 / 合规 / 空状态文案：unlockModeTitle
  ///
  /// In zh, this message translates to:
  /// **'静态模式已解锁'**
  String get unlockModeTitle;

  /// 业务 / 合规 / 空状态文案：unlockModeBody
  ///
  /// In zh, this message translates to:
  /// **'Wenku8 接入链路已切换为真实 HTTP 数据源；纯本地模式仍是默认，锁定态全应用零请求。'**
  String get unlockModeBody;

  /// 业务 / 合规 / 空状态文案：wenkuRealSourceNote
  ///
  /// In zh, this message translates to:
  /// **'真实数据源与演示源共用同一契约；接 SDK 后按同一注入口替换，页面与合规层不改。'**
  String get wenkuRealSourceNote;

  /// 业务 / 合规 / 空状态文案：wenkuEndpointNote
  ///
  /// In zh, this message translates to:
  /// **'URL 只在站点适配层构造；公开资料未给出官方页面结构文档，路径模板需按实际站点核对。'**
  String get wenkuEndpointNote;

  /// 业务 / 合规 / 空状态文案：wenkuChallengeNote
  ///
  /// In zh, this message translates to:
  /// **'来源要求访问验证；请到 Wenku8 官网完成后再试，本应用不绕过验证。'**
  String get wenkuChallengeNote;

  /// 业务 / 合规 / 空状态文案：wenkuWithdrawnNote
  ///
  /// In zh, this message translates to:
  /// **'因版权原因不可读的内容不展示、不缓存、不提供访问。'**
  String get wenkuWithdrawnNote;

  /// 业务 / 合规 / 空状态文案：wenkuRateLimitNote
  ///
  /// In zh, this message translates to:
  /// **'来源已限流；请稍后再试，不要反复刷新，避免给来源带去额外压力。'**
  String get wenkuRateLimitNote;

  /// 业务 / 合规 / 空状态文案：wenkuUnavailableNote
  ///
  /// In zh, this message translates to:
  /// **'第三方服务可能变更、限流或暂时不可用，请稍后再试。'**
  String get wenkuUnavailableNote;

  /// 业务 / 合规 / 空状态文案：wenkuUpstreamChangedNote
  ///
  /// In zh, this message translates to:
  /// **'来源页面结构已变化，需按实际公开页面更新解析规则，不把乱码当内容。'**
  String get wenkuUpstreamChangedNote;

  /// 业务 / 合规 / 空状态文案：wenkuNoRelayNote
  ///
  /// In zh, this message translates to:
  /// **'不实现中继、代理、Cookie、登录、伪造 appver 或伪装浏览器 UA；不绕过访问限制。'**
  String get wenkuNoRelayNote;

  /// 业务 / 合规 / 空状态文案：wenkuChapterNote
  ///
  /// In zh, this message translates to:
  /// **'只读取你点开的单章，不整本下载、不打包、不缓存分发。'**
  String get wenkuChapterNote;

  /// 业务 / 合规 / 空状态文案：wenkuLocalVerifyNote
  ///
  /// In zh, this message translates to:
  /// **'本地验证：flutter pub get → flutter analyze → flutter test → flutter run；先确认站点可达与页面结构。'**
  String get wenkuLocalVerifyNote;

  /// 业务 / 合规 / 空状态文案：wenkuSdkAbsentNote
  ///
  /// In zh, this message translates to:
  /// **'当前交付环境未安装 Flutter/Dart SDK；本轮交付可编译源码与规格，编译和真机验证需在你的开发环境执行。'**
  String get wenkuSdkAbsentNote;

  /// 业务 / 合规 / 空状态文案：wenkuPlatformPermissionNote
  ///
  /// In zh, this message translates to:
  /// **'Android INTERNET / iOS ATS / 鸿蒙 INTERNET 权限骨架已落盘，需按各平台工程模板核对。'**
  String get wenkuPlatformPermissionNote;

  /// 业务 / 合规 / 空状态文案：wenkuLoginTitle
  ///
  /// In zh, this message translates to:
  /// **'登录 Wenku8'**
  String get wenkuLoginTitle;

  /// 业务 / 合规 / 空状态文案：wenkuLoginUsername
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get wenkuLoginUsername;

  /// 业务 / 合规 / 空状态文案：wenkuLoginPassword
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get wenkuLoginPassword;

  /// 业务 / 合规 / 空状态文案：wenkuLoginAction
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get wenkuLoginAction;

  /// 业务 / 合规 / 空状态文案：wenkuLogoutAction
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get wenkuLogoutAction;

  /// 业务 / 合规 / 空状态文案：wenkuLoginCredentialNote
  ///
  /// In zh, this message translates to:
  /// **'凭据仅保存在本次运行的内存中，不写入磁盘、不进入日志与反馈；退出或关闭应用后立即失效。'**
  String get wenkuLoginCredentialNote;

  /// 业务 / 合规 / 空状态文案：wenkuLoginLoggedOut
  ///
  /// In zh, this message translates to:
  /// **'尚未登录，可继续浏览公开目录；登录后才能读取个人书架。'**
  String get wenkuLoginLoggedOut;

  /// 业务 / 合规 / 空状态文案：wenkuLoginFailed
  ///
  /// In zh, this message translates to:
  /// **'登录未完成，请确认账号与来源站点状态；页面异常不会被当作密码错误。'**
  String get wenkuLoginFailed;

  /// 业务 / 合规 / 空状态文案：wenkuLoginSessionExpired
  ///
  /// In zh, this message translates to:
  /// **'登录态已失效，请重新登录。'**
  String get wenkuLoginSessionExpired;

  /// 业务 / 合规 / 空状态文案：wenkuLoginHostNote
  ///
  /// In zh, this message translates to:
  /// **'来源域名可在 wenku8.net 与 wenku8.com 之间切换；两者均为来源站点，本应用不提供其它书源。'**
  String get wenkuLoginHostNote;

  /// 业务 / 合规 / 空状态文案：wenkuSourceClosedNote
  ///
  /// In zh, this message translates to:
  /// **'来源页面返回站点关闭或公告内容，没有可用的登录表单；本应用不会向该页面提交账号密码。'**
  String get wenkuSourceClosedNote;

  /// 业务 / 合规 / 空状态文案：wenkuEndpointsPendingNote
  ///
  /// In zh, this message translates to:
  /// **'登录 / 书架 / 搜索 / 榜单 / 详情 / 章节路径按提供的页面清单配置，尚未经过页面解析验证，需在真机上按实际站点核对。'**
  String get wenkuEndpointsPendingNote;

  /// 业务 / 合规 / 空状态文案：wenkuLoginNoSession
  ///
  /// In zh, this message translates to:
  /// **'当前为离线演示数据源，没有登录会话；切换到真实来源后可登录。'**
  String get wenkuLoginNoSession;

  /// UI 短标签 | 原文：本地阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本地阅读'**
  String get uiLocalReader;

  /// UI 短标签 | 原文：书架 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get uiShelf;

  /// UI 短标签 | 原文：轻小说文库 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'轻小说文库'**
  String get uiLightNovels;

  /// UI 短标签 | 原文：统计 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get uiStats;

  /// UI 短标签 | 原文：我的 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get uiProfile;

  /// UI 短标签 | 原文：知道了 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get uiGotIt;

  /// UI 短标签 | 原文：应用语言 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'应用语言'**
  String get uiAppLanguage;

  /// UI 短标签 | 原文：跟随系统 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get uiFollowSystem;

  /// UI 短标签 | 原文：简体中文 | 来源：精确 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get uiPhrase008;

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get uiEnglish;

  /// UI 短标签 | 原文：跟随系统时按官方 supportedLocales 解析；未支持的语言回退简体中文。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'跟随系统时按官方 supportedLocales 解析；未支持的语言回退简体中文。'**
  String get uiWhenFollowingTheSystemFlutterResolvesTheLocale;

  /// UI 短标签 | 原文：Map<Locale, LegalTextBundle> · ${LocalizedLegalTexts.supportedLocales.length} 种语 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'Map<Locale, LegalTextBundle> · {p0} 种语言'**
  String uiMapLocaleLegaltextbundleLanguages(String p0);

  /// UI 短标签 | 原文： · ${LocalizedLegalTexts.keyCount} 键 + ${LocalizedLegalTexts.listCount} 列表 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **' · {p0} 键 + {p1} 列表'**
  String uiKeysLists(String p0, String p1);

  /// UI 短标签 | 原文：覆盖度校验 · ${_preview.label} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'覆盖度校验 · {p0}'**
  String uiCoverageCheck(String p0);

  /// UI 短标签 | 原文：缺项 ${missing.length} · 多余键 ${extra.length} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'缺项 {p0} · 多余键 {p1}'**
  String uiItems(String p0, String p1);

  /// UI 短标签 | 原文：${v.chapterCount} 章 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 章'**
  String uiChapters(String p0);

  /// UI 短标签 | 原文：取消收藏 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get uiRemoveFavorite;

  /// UI 短标签 | 原文：收藏这本书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'收藏这本书'**
  String get uiFavoriteThisBook;

  /// UI 短标签 | 原文：已加入收藏 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已加入收藏'**
  String get uiAddedToFavorites;

  /// UI 短标签 | 原文：已取消收藏 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get uiRemovedFromFavorites;

  /// UI 短标签 | 原文：编辑书籍信息 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'编辑书籍信息'**
  String get uiEditBookInfo;

  /// UI 短标签 | 原文：章节目录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'章节目录'**
  String get uiTableOfContents;

  /// UI 短标签 | 原文：继续阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'继续阅读'**
  String get uiContinueReading;

  /// UI 短标签 | 原文：开始阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'开始阅读'**
  String get uiStartReading;

  /// UI 短标签 | 原文：未分卷 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'未分卷'**
  String get uiNoVolume;

  /// UI 短标签 | 原文：第 ${book.volumeOrder} 卷 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'第 {p0} 卷'**
  String uiVolume(String p0);

  /// UI 短标签 | 原文：本地书库 · ${book.shelf} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'本地书库 · {p0}'**
  String uiLocalLibrary(String p0);

  /// UI 短标签 | 原文：阅读进度 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get uiReadingProgress;

  /// UI 短标签 | 原文：上次读到约第 ${DemoDocumentFactory.resumeChapter(book) + 1} 章 · 演示数据 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'上次读到约第 {p0} 章 · 演示数据'**
  String uiChaptersSampleData(String p0);

  /// UI 短标签 | 原文：尚未开始阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'尚未开始阅读'**
  String get uiNotStartedYet;

  /// UI 短标签 | 原文：目录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get uiContents;

  /// UI 短标签 | 原文：共 ${chapters.length} 章 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 章'**
  String uiTotalChapters(String p0);

  /// UI 短标签 | 原文：查看全部 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get uiViewAll;

  /// UI 短标签 | 原文：上次读到 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'上次读到'**
  String get uiLastRead;

  /// UI 短标签 | 原文：${excerpts.length} 条 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 条'**
  String uiItems2(String p0);

  /// UI 短标签 | 原文：书籍信息 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书籍信息'**
  String get uiBookInfo;

  /// UI 短标签 | 原文：来源 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get uiSource;

  /// UI 短标签 | 原文：用户本地导入 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'用户本地导入'**
  String get uiImportedLocally;

  /// UI 短标签 | 原文：格式 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get uiFormat;

  /// UI 短标签 | 原文：章节 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get uiChapters2;

  /// UI 短标签 | 原文：话集 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'话集'**
  String get uiEpisodes;

  /// UI 短标签 | 原文：$episodeCount 话 · 共 $comicPageCount 页 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 话 · 共 {p1} 页'**
  String uiEpisodesPages(String p0, String p1);

  /// UI 短标签 | 原文：授权 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'授权'**
  String get uiAuthorization;

  /// UI 短标签 | 原文：系统文件选择器目录授权 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'系统文件选择器目录授权'**
  String get uiSystemFilePickerDirectoryAuthorization;

  /// UI 短标签 | 原文：文档类书籍不在媒体库覆盖范围内，需走系统文件选择器或「所有文件访问」。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'文档类书籍不在媒体库覆盖范围内，需走系统文件选择器或「所有文件访问」。'**
  String get uiScope;

  /// UI 短标签 | 原文：关于内容 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'关于内容'**
  String get uiAboutContent;

  /// UI 短标签 | 原文：书名 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get uiTitle;

  /// UI 短标签 | 原文：作者 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get uiAuthor;

  /// UI 短标签 | 原文：封面色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'封面色'**
  String get uiCoverColor;

  /// UI 短标签 | 原文：卷序 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'卷序'**
  String get uiVolumeOrder;

  /// UI 短标签 | 原文：第 $i 卷 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'第 {p0} 卷'**
  String uiVolume2(String p0);

  /// UI 短标签 | 原文：静态演示：修改仅保存在内存，重启后恢复演示数据。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'静态演示：修改仅保存在内存，重启后恢复演示数据。'**
  String get uiStaticDemoSaveSampleData;

  /// UI 短标签 | 原文：取消 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get uiCancel;

  /// UI 短标签 | 原文：保存 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get uiSave;

  /// UI 短标签 | 原文：书名不能为空 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书名不能为空'**
  String get uiTitleCannotBeEmpty;

  /// UI 短标签 | 原文：${book.title} · 目录 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 目录'**
  String uiContents2(String p0);

  /// UI 短标签 | 原文：搜索章节名 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'搜索章节名'**
  String get uiSearchChapterTitles;

  /// UI 短标签 | 原文：共 ${document.chapters.length} 章 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 章'**
  String uiTotalChapters2(String p0);

  /// UI 短标签 | 原文：点选章节跳转 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'点选章节跳转'**
  String get uiTapAChapterToJump;

  /// UI 短标签 | 原文：没有匹配的章节 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的章节'**
  String get uiNoMatchingChapters;

  /// UI 短标签 | 原文：目录与正文由同一份 BookDocument 生成，章节序号与阅读器严格一致。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'目录与正文由同一份 BookDocument 生成，章节序号与阅读器严格一致。'**
  String get uiContentsBodyTextBookdocumentChapters;

  /// UI 短标签 | 原文：当前为演示数据；接入真实解析器后由 TocEntry 提供章节与锚点。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'当前为演示数据；接入真实解析器后由 TocEntry 提供章节与锚点。'**
  String get uiCurrentSampleDataTocentryChapters;

  /// UI 短标签 | 原文：${chapter.blocks.length} 个内容块 · 演示正文 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个内容块 · 演示正文'**
  String uiItemscontentBodyText(String p0);

  /// UI 短标签 | 原文：当前阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前阅读'**
  String get uiCurrentlyReading;

  /// UI 短标签 | 原文：编辑摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'编辑摘录'**
  String get uiEditExcerpt;

  /// UI 短标签 | 原文：划线颜色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'划线颜色'**
  String get uiHighlightColor;

  /// UI 短标签 | 原文：批注 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'批注'**
  String get uiNote;

  /// UI 短标签 | 原文：清空输入框即可移除批注 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'清空输入框即可移除批注'**
  String get uiClearTheFieldToRemoveTheNote;

  /// UI 短标签 | 原文：保存修改 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'保存修改'**
  String get uiSaveChanges;

  /// UI 短标签 | 原文：导出预览 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导出预览'**
  String get uiExportPreview;

  /// UI 短标签 | 原文：摘录管理 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'摘录管理'**
  String get uiExcerptLibrary;

  /// UI 短标签 | 原文：导出当前结果（纯文本预览） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导出当前结果（纯文本预览）'**
  String get uiExportCurrentResultsPlainTextPreview;

  /// UI 短标签 | 原文：正文 / 书名 / 章节 / 批注 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'正文 / 书名 / 章节 / 批注'**
  String get uiTextTitleChapterNote;

  /// UI 短标签 | 原文：全部书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'全部书'**
  String get uiAllBooks;

  /// UI 短标签 | 原文：共 ${summary.total} 条 · 我摘的 ${summary.userCount} 条 ·  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 条 · 我摘的 {p1} 条 · '**
  String uiTotalYours(String p0, String p1);

  /// UI 短标签 | 原文：有批注 ${summary.withNoteCount} 条 · 命中 ${results.length} 条 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'有批注 {p0} 条 · 命中 {p1} 条'**
  String uiNoteItemsItems(String p0, String p1);

  /// UI 短标签 | 原文：范围 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'范围'**
  String get uiScope2;

  /// UI 短标签 | 原文：按书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'按书'**
  String get uiByBook;

  /// UI 短标签 | 原文：划线色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'划线色'**
  String get uiHighlight;

  /// UI 短标签 | 原文：全部色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'全部色'**
  String get uiAllColors;

  /// UI 短标签 | 原文：排序 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get uiSort;

  /// UI 短标签 | 原文：分组 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get uiGroup;

  /// UI 短标签 | 原文：指定书籍 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'指定书籍'**
  String get uiSelectedBook;

  /// UI 短标签 | 原文：当天 ${_filter.dateKey} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'当天 {p0}'**
  String uiDays(String p0);

  /// UI 短标签 | 原文：关键词「${_filter.query}」 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'关键词「{p0}」'**
  String uiKeyword(String p0);

  /// UI 短标签 | 原文：已删除这条摘录 | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **'已删除这条摘录'**
  String get uiExcerptDeleted;

  /// UI 短标签 | 原文：这条摘录不可删除 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'这条摘录不可删除'**
  String get uiItemsexcerpts;

  /// UI 短标签 | 原文：我摘的 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'我摘的'**
  String get uiYours;

  /// UI 短标签 | 原文：演示 · 只读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'演示 · 只读'**
  String get uiSampleReadOnly;

  /// UI 短标签 | 原文：编辑批注 / 划线色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'编辑批注 / 划线色'**
  String get uiEditNoteHighlight;

  /// UI 短标签 | 原文：删除摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'删除摘录'**
  String get uiDeleteExcerpt;

  /// UI 短标签 | 原文：清除日期筛选 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'清除日期筛选'**
  String get uiClearDateFilter;

  /// UI 短标签 | 原文：查看全部书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'查看全部书'**
  String get uiAllBooks2;

  /// UI 短标签 | 原文：清空筛选条件 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'清空筛选条件'**
  String get uiClearFilters;

  /// UI 短标签 | 原文：导入前先看一眼 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入前先看一眼'**
  String get uiReviewBeforeImporting;

  /// UI 短标签 | 原文：支持格式 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'支持格式'**
  String get uiSupportedFormats;

  /// UI 短标签 | 原文：压缩包 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'压缩包'**
  String get uiArchives;

  /// UI 短标签 | 原文：权限 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'权限'**
  String get uiPermissions;

  /// UI 短标签 | 原文：导入渠道 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入渠道'**
  String get uiImportChannels;

  /// UI 短标签 | 原文：联网 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'联网'**
  String get uiOnline;

  /// UI 短标签 | 原文：选择授权方式 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'选择授权方式'**
  String get uiChooseAnAuthorizationMethod;

  /// UI 短标签 | 原文：已确认授权 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已确认授权'**
  String get uiAuthorizationConfirmed;

  /// UI 短标签 | 原文：模拟确认授权 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'模拟确认授权'**
  String get uiSimulateAuthorization;

  /// UI 短标签 | 原文：授权会持久化，重启后可一键重扫（静态演示） | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'授权会持久化，重启后可一键重扫（静态演示）'**
  String get uiAuthorizationStaticDemo;

  /// UI 短标签 | 原文：扫描结果 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'扫描结果'**
  String get uiScanResults;

  /// UI 短标签 | 原文：共扫描 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'共扫描'**
  String get uiScanned;

  /// UI 短标签 | 原文：可导入 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'可导入'**
  String get uiImportable;

  /// UI 短标签 | 原文：不支持 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'不支持'**
  String get uiUnsupported;

  /// UI 短标签 | 原文：未登记 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'未登记'**
  String get uiUnregistered;

  /// UI 短标签 | 原文：同名冲突 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'同名冲突'**
  String get uiNameConflict;

  /// UI 短标签 | 原文：没有同名冲突 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'没有同名冲突'**
  String get uiNoNameConflicts;

  /// UI 短标签 | 原文：处理同名书籍 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'处理同名书籍'**
  String get uiResolveDuplicateNames;

  /// UI 短标签 | 原文：全部${ImportLabels.resolutions[r]} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'全部{p0}'**
  String uiAll(String p0);

  /// UI 短标签 | 原文：与书库《${conflict.existing.title}》同名 · ${conflict.candidate.format} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'与书库《{p0}》同名 · {p1}'**
  String uiDuplicateOf(String p0, String p1);

  /// UI 短标签 | 原文：导入摘要 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入摘要'**
  String get uiImportSummary;

  /// UI 短标签 | 原文：扫描文件 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'扫描文件'**
  String get uiScannedFiles;

  /// UI 短标签 | 原文：${commit.totalCandidates} 个 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个'**
  String uiItems3(String p0);

  /// UI 短标签 | 原文：将写入书架 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'将写入书架'**
  String get uiToBeAdded;

  /// UI 短标签 | 原文：${commit.addedCount} 册 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 册'**
  String uiBooks(String p0);

  /// UI 短标签 | 原文：跳过 / 不支持 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'跳过 / 不支持'**
  String get uiSkippedUnsupported;

  /// UI 短标签 | 原文：${commit.skipped + commit.unsupported} 个 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个'**
  String uiItems4(String p0);

  /// UI 短标签 | 原文：${commit.conflictCount} 项 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 项'**
  String uiItems5(String p0);

  /// UI 短标签 | 原文：延后处理 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'延后处理'**
  String get uiDeferred;

  /// UI 短标签 | 原文：${commit.deferredCount} 项 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 项'**
  String uiItems6(String p0);

  /// UI 短标签 | 原文：将新增 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'将新增'**
  String get uiToBeAdded2;

  /// UI 短标签 | 原文：上一步 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get uiBack;

  /// UI 短标签 | 原文：写回书架并关闭 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'写回书架并关闭'**
  String get uiWriteToShelfAndClose;

  /// UI 短标签 | 原文：下一步 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get uiNext;

  /// UI 短标签 | 原文：阅读与字体 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读与字体'**
  String get uiReadingFonts;

  /// UI 短标签 | 原文：动效与朗读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'动效与朗读'**
  String get uiMotionReadAloud;

  /// UI 短标签 | 原文：统计与报告 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'统计与报告'**
  String get uiStatsReports;

  /// UI 短标签 | 原文：书架与导入 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书架与导入'**
  String get uiShelfImport;

  /// UI 短标签 | 原文：工程与合规 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'工程与合规'**
  String get uiBuildCompliance;

  /// UI 短标签 | 原文：功能总览 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'功能总览'**
  String get uiFeatureOverview;

  /// UI 短标签 | 原文：参考仓库功能对齐 · 第二十四轮 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'参考仓库功能对齐 · 第二十四轮'**
  String get uiReferenceRepoFeatureAlignment;

  /// UI 短标签 | 原文：以下偏好全部挂在全局状态，按书设置与全局默认分开；静态阶段只保存选择，不下载字体、不发请求、不写文件。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'以下偏好全部挂在全局状态，按书设置与全局默认分开；静态阶段只保存选择，不下载字体、不发请求、不写文件。'**
  String get uiAllGlobalDefaultStaticStageSaveChars;

  /// UI 短标签 | 原文：按书保存排版 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'按书保存排版'**
  String get uiPerBookLayout;

  /// UI 短标签 | 原文：每本书可独立保存字体 / 字号 / 字重 / 字距 / 行高 / 四边距；null 表示沿用全局默认。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'每本书可独立保存字体 / 字号 / 字重 / 字距 / 行高 / 四边距；null 表示沿用全局默认。'**
  String get uiSaveCharsFontSizeCharsCharsLineHeightNullGloba;

  /// UI 短标签 | 原文：书库为空 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书库为空'**
  String get uiLibraryIsEmpty;

  /// UI 短标签 | 原文：当前：${effective.fontFamily} · ${effective.fontSize.toStringAsFixed(1)} pt ·  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'当前：{p0} · {p1} pt · '**
  String uiCurrentPt(String p0, String p1);

  /// UI 短标签 | 原文：行高 ${effective.lineHeight.toStringAsFixed(2)} ·  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'行高 {p0} · '**
  String uiLineHeight(String p0);

  /// UI 短标签 | 原文：${effective.isBookSpecific ? "书级覆盖" : "全局默认"} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase141(String p0);

  /// UI 短标签 | 原文：为这本书设大字 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'为这本书设大字'**
  String get uiUseLargerTextForThisBook;

  /// UI 短标签 | 原文：清除书级覆盖 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'清除书级覆盖'**
  String get uiClearPerBookOverrides;

  /// UI 短标签 | 原文：字体目录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'字体目录'**
  String get uiFontCatalog;

  /// UI 短标签 | 原文：阅读字体按需下载、离线可用、可移除、不预装；应用字体与阅读器字体分开选。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'阅读字体按需下载、离线可用、可移除、不预装；应用字体与阅读器字体分开选。'**
  String get uiCharsRemoveCharsChars;

  /// UI 短标签 | 原文：导入字体 · 思源黑体 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入字体 · 思源黑体'**
  String get uiImportFontSourceHanSans;

  /// UI 短标签 | 原文：登记导入 TTF/OTF | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'登记导入 TTF/OTF'**
  String get uiRegisterImportedTtfOtf;

  /// UI 短标签 | 原文：标记按需包已装 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'标记按需包已装'**
  String get uiMarkOnDemandPackInstalled;

  /// UI 短标签 | 原文：静态阶段只登记元数据；FontLoader 注册、下载与移除文件属平台层（❄️ 冻结）。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'静态阶段只登记元数据；FontLoader 注册、下载与移除文件属平台层（❄️ 冻结）。'**
  String get uiStaticStageFontloaderBooksRemove;

  /// UI 短标签 | 原文：配色来源 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'配色来源'**
  String get uiColorSource;

  /// UI 短标签 | 原文：阅读器独立配色：对比度 ${scheme.contrast.toStringAsFixed(2)}:1 ·  | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'阅读器独立配色：对比度 {p0}:1 · '**
  String uiContrast1(String p0);

  /// UI 短标签 | 原文：${scheme.meetsMinimum ? "达到" : "未达到"} WCAG AA 正文 4.5 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} WCAG AA 正文 4.5'**
  String uiWcagAaBodyText45(String p0);

  /// UI 短标签 | 原文：应用字体 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'应用字体'**
  String get uiAppFont;

  /// UI 短标签 | 原文：阅读字体 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读字体'**
  String get uiReadingFont;

  /// UI 短标签 | 原文：移除当前字体 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'移除当前字体'**
  String get uiRemoveCurrentFont;

  /// UI 短标签 | 原文：系统动态色（Monet） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'系统动态色（Monet）'**
  String get uiSystemDynamicColorMonet;

  /// UI 短标签 | 原文：自定义强调色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'自定义强调色'**
  String get uiCustomAccentColor;

  /// UI 短标签 | 原文：从封面取色 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'从封面取色'**
  String get uiPickFromCover;

  /// UI 短标签 | 原文：翻页与自动阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'翻页与自动阅读'**
  String get uiPageTurnAutoRead;

  /// UI 短标签 | 原文：翻页速度 ×${m.turnSpeed.toStringAsFixed(1)} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'翻页速度 ×{p0}'**
  String uiPages(String p0);

  /// UI 短标签 | 原文：整体界面动效 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'整体界面动效'**
  String get uiInterfaceMotion;

  /// UI 短标签 | 原文：开 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'开'**
  String get uiOn;

  /// UI 短标签 | 原文：关：自动锁为无动画并停下自动阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'关：自动锁为无动画并停下自动阅读'**
  String get uiOffLocksToNoAnimationAndStopsAutoRead;

  /// UI 短标签 | 原文：自动阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'自动阅读'**
  String get uiAutoRead;

  /// UI 短标签 | 原文：间隔 ${m.autoReadIntervalMs} ms · 关动效时自动停 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'间隔 {p0} ms · 关动效时自动停'**
  String uiIntervalMsAutoStopsWhenMotionIsOff(String p0);

  /// UI 短标签 | 原文：连续章过渡 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'连续章过渡'**
  String get uiContinuousChapterTransition;

  /// UI 短标签 | 原文：音量键翻页 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'音量键翻页'**
  String get uiVolumeKeyPaging;

  /// UI 短标签 | 原文：双语与朗读语言 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'双语与朗读语言'**
  String get uiBilingualReadAloudLanguages;

  /// UI 短标签 | 原文：按书选显示语言；朗读语言分别选、每种语言一个 voice，没有匹配语音模型的语言直接跳过。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'按书选显示语言；朗读语言分别选、每种语言一个 voice，没有匹配语音模型的语言直接跳过。'**
  String get uiReadAloudLanguagesItemsVoice;

  /// UI 短标签 | 原文：实际会朗读：${b.speakable().map((ReadingLanguage l) => BilingualPrefs.labels[l]).join( | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'实际会朗读：{p0}'**
  String uiReadAloud(String p0);

  /// UI 短标签 | 原文：${b.speakable().isEmpty ? "（无可用语音，已跳过）" : ""} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase171(String p0);

  /// UI 短标签 | 原文：静态阶段只维护偏好；真实语音模型枚举、音色下载与音量键事件属平台层（❄️ 冻结）。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'静态阶段只维护偏好；真实语音模型枚举、音色下载与音量键事件属平台层（❄️ 冻结）。'**
  String get uiStaticStageKeepsakes;

  /// UI 短标签 | 原文：五种视图 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'五种视图'**
  String get uiFiveViews;

  /// UI 短标签 | 原文：周期（预设 / 自定义范围） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'周期（预设 / 自定义范围）'**
  String get uiPeriodPresetsCustomRange;

  /// UI 短标签 | 原文：八种报告布局 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'八种报告布局'**
  String get uiEightReportLayouts;

  /// UI 短标签 | 原文：实际呈现字段：${payload.sections.map((ReportSection s) => ReportPayload.sectionLabels[s | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'实际呈现字段：{p0}'**
  String uiChars(String p0);

  /// UI 短标签 | 原文：${payload.sections.isEmpty ? "（无数据，全部省略）" : ""} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase177(String p0);

  /// UI 短标签 | 原文：预览与导出共用同一份内容： | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'预览与导出共用同一份内容：'**
  String get uiTotalContent;

  /// UI 短标签 | 原文：静态阶段导出只生成字符串；写文件与系统分享属平台层（❄️ 冻结）。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'静态阶段导出只生成字符串；写文件与系统分享属平台层（❄️ 冻结）。'**
  String get uiStaticStageChars;

  /// UI 短标签 | 原文：今天 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get uiToday;

  /// UI 短标签 | 原文：本周 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get uiThisWeek;

  /// UI 短标签 | 原文：本月 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get uiThisMonth;

  /// UI 短标签 | 原文：今年 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get uiThisYear;

  /// UI 短标签 | 原文：全部 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get uiAll2;

  /// UI 短标签 | 原文：自定义 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get uiCustom;

  /// UI 短标签 | 原文：书架视图与筛选 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书架视图与筛选'**
  String get uiShelfViewFilters;

  /// UI 短标签 | 原文：本地书库并入书架 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本地书库并入书架'**
  String get uiMergeLocalLibraryIntoShelf;

  /// UI 短标签 | 原文：当前筛选命中 ${prefs.apply(state.allBooks).length} / ${state.allBooks.length} 册； | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'当前筛选命中 {p0} / {p1} 册；'**
  String uiCurrentBooks(String p0, String p1);

  /// UI 短标签 | 原文：列表模式下轮播参数自动锁回默认。 | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **'列表模式下轮播参数自动锁回默认。'**
  String get uiCarouselParametersLockBackToDefaultInListMode;

  /// UI 短标签 | 原文：导入前审阅与同系列卷合并 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入前审阅与同系列卷合并'**
  String get uiPreImportReviewSeriesVolumeMerge;

  /// UI 短标签 | 原文：三种来源：${ImportReview.sourceLabels.values.join(" / ")}； | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'三种来源：{p0}；'**
  String uiSource2(String p0);

  /// UI 短标签 | 原文：策略：${ImportReview.policyLabels.values.join(" / ")}。 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'策略：{p0}。'**
  String uiPolicy(String p0);

  /// UI 短标签 | 原文：当前：${ImportReview.sourceLabels[_importSource]} →  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'当前：{p0} → '**
  String uiCurrent(String p0);

  /// UI 短标签 | 原文：${ImportReview.policyLabels[_policy]} →  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} → '**
  String uiPhrase194(String p0);

  /// UI 短标签 | 原文：落到既有冲突策略 ${const ImportReview().withPolicy(VolumeMergePolicy.mergeBySeries).reso | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'落到既有冲突策略 {p0} 等四项之一。'**
  String uiItems7(String p0);

  /// UI 短标签 | 原文：WebDAV 备份（默认关闭） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 备份（默认关闭）'**
  String get uiWebdavBackupOffByDefault;

  /// UI 短标签 | 原文：备份内容：${BackupSnapshot.payloadLabels.join(" / ")}。 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'备份内容：{p0}。'**
  String uiContent(String p0);

  /// UI 短标签 | 原文：关闭态连「测试连接」都不发请求。 | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **'关闭态连「测试连接」都不发请求。'**
  String get uiWhenOffEvenTestConnectionMakesNoRequest;

  /// UI 短标签 | 原文：启用备份 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'启用备份'**
  String get uiEnableBackup;

  /// UI 短标签 | 原文：静态演示：未发出任何网络请求 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'静态演示：未发出任何网络请求'**
  String get uiStaticDemoNoNetworkRequestWasMade;

  /// UI 短标签 | 原文：静态阶段只演示状态机；WebDavClient、远端列表与导出落盘属平台层（❄️ 冻结）。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'静态阶段只演示状态机；WebDavClient、远端列表与导出落盘属平台层（❄️ 冻结）。'**
  String get uiStaticStageWebdavclient;

  /// UI 短标签 | 原文：Android 权限分级 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'Android 权限分级'**
  String get uiAndroidPermissionTiers;

  /// UI 短标签 | 原文：已移除：${AndroidPermissionProfile.removed.join(", ")} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'已移除：{p0}'**
  String uiRemove(String p0);

  /// UI 短标签 | 原文：连续崩溃保护 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'连续崩溃保护'**
  String get uiCrashLoopProtection;

  /// UI 短标签 | 原文：阈值 ${guard.policy.threshold} 次 / ${guard.policy.window.inMinutes} 分钟内 →  | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'阈值 {p0} 次 / {p1} 分钟内 → '**
  String uiMinutes(String p0, String p1);

  /// UI 短标签 | 原文：进${guard.policy.safeModeLabel}；跳过：${CrashGuard.skippedInSafeMode.join("、")}。 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'进{p0}；跳过：{p1}。'**
  String uiSkipped(String p0, String p1);

  /// UI 短标签 | 原文：静态交付边界 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'静态交付边界'**
  String get uiStaticDeliveryBoundary;

  /// UI 短标签 | 原文：本轮新增能力全部为纯 Dart 模型 + 应用内配置：不下载字体、不读文件字节、 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'本轮新增能力全部为纯 Dart 模型 + 应用内配置：不下载字体、不读文件字节、'**
  String get uiAllDartCharsChars;

  /// UI 短标签 | 原文：不发网络请求、不注册平台回调、不写相册。逐页接入多语言仍按用户指定预留到最后。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'不发网络请求、不注册平台回调、不写相册。逐页接入多语言仍按用户指定预留到最后。'**
  String get uiBooksBooksPages;

  /// UI 短标签 | 原文：应用版本 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'应用版本'**
  String get uiAppVersion;

  /// UI 短标签 | 原文：例如 1.0.0+1 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'例如 1.0.0+1'**
  String get uiEG1001;

  /// UI 短标签 | 原文：设备 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get uiDevice;

  /// UI 短标签 | 原文：例如 Pixel 8 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'例如 Pixel 8'**
  String get uiEGPixel8;

  /// UI 短标签 | 原文：操作系统版本 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'操作系统版本'**
  String get uiOsVersion;

  /// UI 短标签 | 原文：例如 Android 15 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'例如 Android 15'**
  String get uiEGAndroid15;

  /// UI 短标签 | 原文：复现步骤 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'复现步骤'**
  String get uiStepsToReproduce;

  /// UI 短标签 | 原文：补充说明（可选） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'补充说明（可选）'**
  String get uiAdditionalNotesOptional;

  /// UI 短标签 | 原文：其它观察 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'其它观察'**
  String get uiOtherObservations;

  /// UI 短标签 | 原文：本地书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本地书'**
  String get uiLocalBooks;

  /// UI 短标签 | 原文：收藏 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get uiFavorites;

  /// UI 短标签 | 原文：今日分钟 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'今日分钟'**
  String get uiMinutesToday;

  /// UI 短标签 | 原文：连续 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'连续'**
  String get uiStreak;

  /// UI 短标签 | 原文：书库 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书库'**
  String get uiLibrary;

  /// UI 短标签 | 原文：纯本地模式 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'纯本地模式'**
  String get uiPureLocalMode;

  /// UI 短标签 | 原文：开启时全应用不产生任何网络请求 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'开启时全应用不产生任何网络请求'**
  String get uiWhenOnTheAppMakesNoNetworkRequests;

  /// UI 短标签 | 原文：界面动效 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'界面动效'**
  String get uiInterfaceMotion2;

  /// UI 短标签 | 原文：翻页动画 / 书架视差 / 玻璃过渡 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'翻页动画 / 书架视差 / 玻璃过渡'**
  String get uiPageTurnAnimationShelfParallaxGlassTransitions;

  /// UI 短标签 | 原文：TTS 朗读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'TTS 朗读'**
  String get uiTtsReadAloud;

  /// UI 短标签 | 原文：分句队列 · 语速音调 · 读完自动下一章 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'分句队列 · 语速音调 · 读完自动下一章'**
  String get uiSentenceQueueRatePitchAutoNextChapter;

  /// UI 短标签 | 原文：阅读排版 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读排版'**
  String get uiReadingLayout;

  /// UI 短标签 | 原文：${reader.fontSize.round()} pt · ${reader.backgroundLabel} · ${reader.pageTurnLab | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0} pt · {p1} · {p2}翻页'**
  String uiPtPages(String p0, String p1, String p2);

  /// UI 短标签 | 原文： · 对比度 ${reader.bodyContrast.toStringAsFixed(1)}:1 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **' · 对比度 {p0}:1'**
  String uiContrast12(String p0);

  /// UI 短标签 | 原文：按书排版 · 字体目录 · 报告布局 · 备份 · 权限与崩溃保护 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'按书排版 · 字体目录 · 报告布局 · 备份 · 权限与崩溃保护'**
  String get uiPerBookLayoutFontsReportsBackupPermissions;

  /// UI 短标签 | 原文：表单登录 · 个人书架 · 会话与来源域名 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'表单登录 · 个人书架 · 会话与来源域名'**
  String get uiFormLoginBookcaseSessionSourceDomain;

  /// UI 短标签 | 原文：在线目录（Wenku8） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'在线目录（Wenku8）'**
  String get uiOnlineDirectoryWenku8;

  /// UI 短标签 | 原文：纯本地模式下已锁定 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'纯本地模式下已锁定'**
  String get uiLockedByPureLocalMode;

  /// UI 短标签 | 原文：仅列表与目录元数据，不内置小说文件 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'仅列表与目录元数据，不内置小说文件'**
  String get uiListingsAndTocMetadataOnlyNoBundledNovels;

  /// UI 短标签 | 原文：WebDAV 备份 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 备份'**
  String get uiWebdavBackup;

  /// UI 短标签 | 原文：书库元数据 / 进度 / 分组 / 阅读会话 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书库元数据 / 进度 / 分组 / 阅读会话'**
  String get uiLibraryMetadataProgressGroupsSessions;

  /// UI 短标签 | 原文：关闭纯本地模式后，在线开关才会解锁；关闭态全应用零网络请求。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'关闭纯本地模式后，在线开关才会解锁；关闭态全应用零网络请求。'**
  String get uiPureLocalMode2;

  /// UI 短标签 | 原文：格式说明 · 目录授权 · 扫描 · 冲突处理 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'格式说明 · 目录授权 · 扫描 · 冲突处理'**
  String get uiFormatsAuthorizationScanConflicts;

  /// UI 短标签 | 原文：导入格式 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入格式'**
  String get uiImportFormats;

  /// UI 短标签 | 原文：${favorites.length} 条 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 条'**
  String uiItems8(String p0);

  /// UI 短标签 | 原文：已移除的书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已移除的书'**
  String get uiRemovedBook;

  /// UI 短标签 | 原文：${FavoriteTargetLabels.labels[entry.target]} · 点击跳转 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 点击跳转'**
  String uiTapToOpen(String p0);

  /// UI 短标签 | 原文：话集目录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'话集目录'**
  String get uiEpisodeList;

  /// UI 短标签 | 原文：${toc.episodeCount} 话 · ${toc.pageCount} 页 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 话 · {p1} 页'**
  String uiEpisodesPages2(String p0, String p1);

  /// UI 短标签 | 原文：识别率 ${(toc.recognitionRate * 100).round()}% ·  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'识别率 {p0}% · '**
  String uiRecognitionRate(String p0);

  /// UI 短标签 | 原文：未识别的 ${toc.pageCount - toc.recognizedPages} 页已归入「未分话」 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'未识别的 {p0} 页已归入「未分话」'**
  String uiUnrecognizedPagesEpisodes(String p0);

  /// UI 短标签 | 原文：全部页都已归入话集 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'全部页都已归入话集'**
  String get uiAllPagesAreGroupedIntoEpisodes;

  /// UI 短标签 | 原文：当前 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get uiCurrent2;

  /// UI 短标签 | 原文：未识别 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'未识别'**
  String get uiUnrecognized;

  /// UI 短标签 | 原文：${episode.pageRangeLabel} · ${episode.pageCount} 页 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1} 页'**
  String uiPages2(String p0, String p1);

  /// UI 短标签 | 原文：摘录这一段 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'摘录这一段'**
  String get uiCaptureThisPassage;

  /// UI 短标签 | 原文：${selection.count} 行 · ${preview.length} 字 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 行 · {p1} 字'**
  String uiLinesChars(String p0, String p1);

  /// UI 短标签 | 原文：（没有可摘录的文字） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'（没有可摘录的文字）'**
  String get uiNoTextAvailableToCapture;

  /// UI 短标签 | 原文： · 跨段落 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **' · 跨段落'**
  String get uiSpreads;

  /// UI 短标签 | 原文：批注（可选） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'批注（可选）'**
  String get uiNoteOptional;

  /// UI 短标签 | 原文：写点什么，会附在摘录后面 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'写点什么，会附在摘录后面'**
  String get uiWriteSomethingToAppendToTheExcerpt;

  /// UI 短标签 | 原文：选区跨越了段落，换行处已直接拼接；如需分句可少选几行。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'选区跨越了段落，换行处已直接拼接；如需分句可少选几行。'**
  String get uiSpreadsLinesSentencesLines;

  /// UI 短标签 | 原文：这段已经摘过了，统计页里可以看到。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'这段已经摘过了，统计页里可以看到。'**
  String get uiStatsPages;

  /// UI 短标签 | 原文：保存摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'保存摘录'**
  String get uiSaveExcerpt;

  /// UI 短标签 | 原文：本页需要原生渲染能力，当前平台尚未接入。 ${snap.error} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'本页需要原生渲染能力，当前平台尚未接入。\n{p0}'**
  String uiPagesCurrent(String p0);

  /// UI 短标签 | 原文：演示平台 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'演示平台'**
  String get uiDemoPlatform;

  /// UI 短标签 | 原文：摘录选中的正文行 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'摘录选中的正文行'**
  String get uiCaptureSelectedLines;

  /// UI 短标签 | 原文：朗读（分句队列） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'朗读（分句队列）'**
  String get uiReadAloudSentenceQueue;

  /// UI 短标签 | 原文：排版设置 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'排版设置'**
  String get uiLayoutSettings;

  /// UI 短标签 | 原文：上一章 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'上一章'**
  String get uiPreviousChapter;

  /// UI 短标签 | 原文：${_pageIndex + 1} / ${result.pages.length} · 第 ${_chapterIndex + 1} / ${_documen | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} / {p1} · 第 {p2} / {p3} 章'**
  String uiChapter(String p0, String p1, String p2, String p3);

  /// UI 短标签 | 原文：已选 ${_selection.count} 行 · 点顶栏书签保存摘录 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'已选 {p0} 行 · 点顶栏书签保存摘录'**
  String uiLinesSaveexcerpts(String p0);

  /// UI 短标签 | 原文：下一章 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'下一章'**
  String get uiNextChapter;

  /// UI 短标签 | 原文：插图占位 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'插图占位'**
  String get uiIllustrationPlaceholder;

  /// UI 短标签 | 原文：漫画页暂不支持按行摘录，话集目录请用旁边「目录」按钮 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'漫画页暂不支持按行摘录，话集目录请用旁边「目录」按钮'**
  String get uiPagesLinesexcerptsEpisodeListContents;

  /// UI 短标签 | 原文：先点选正文中的一行或多行，再点书签保存摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'先点选正文中的一行或多行，再点书签保存摘录'**
  String get uiSelectOneOrMoreLinesThenTapTheBookmarkToSaveAn;

  /// UI 短标签 | 原文：这段已经摘过了，统计页里可以看到 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'这段已经摘过了，统计页里可以看到'**
  String get uiStatsPages2;

  /// UI 短标签 | 原文：已保存到摘录卡 · 统计页可查看 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已保存到摘录卡 · 统计页可查看'**
  String get uiSavedToExcerptCardsSeeStats;

  /// UI 短标签 | 原文：固定版式页 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'固定版式页'**
  String get uiFixedLayoutPage;

  /// UI 短标签 | 原文：PDF / 漫画 / 图片型 EPUB 走 BookRenderBridge：  | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'PDF / 漫画 / 图片型 EPUB 走 BookRenderBridge：\n'**
  String get uiPdfEpubViaBookrenderbridge;

  /// UI 短标签 | 原文：· render(handle, index, targetSize) 按目标像素出页，不做 4K 再缩  | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'· render(handle, index, targetSize) 按目标像素出页，不做 4K 再缩\n'**
  String get uiRenderHandleIndexTargetsizePages4k;

  /// UI 短标签 | 原文：· 连续翻页用 textureId + Texture(textureId:)  | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'· 连续翻页用 textureId + Texture(textureId:)\n'**
  String get uiPagesTextureidTextureTextureid;

  /// UI 短标签 | 原文：· 单页快照用编码位图 Image.memory  | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'· 单页快照用编码位图 Image.memory\n'**
  String get uiPagesImageMemory;

  /// UI 短标签 | 原文：· ComicPrefetchWindow 批量 prefetch / evict，不在滚动回调里逐帧跨 channel | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'· ComicPrefetchWindow 批量 prefetch / evict，不在滚动回调里逐帧跨 channel'**
  String get uiComicprefetchwindowPrefetchEvictSpreadsChannel;

  /// UI 短标签 | 原文：目标尺寸：${pageSize.width.round()} × ${pageSize.height.round()} 逻辑像素 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'目标尺寸：{p0} × {p1} 逻辑像素'**
  String uiSize(String p0, String p1);

  /// UI 短标签 | 原文：当前页面未注入目录导航 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前页面未注入目录导航'**
  String get uiTocNavigationIsNotWiredIntoThisPage;

  /// UI 短标签 | 原文：漫画 / 固定版式没有可重排正文，朗读仅适用于小说 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'漫画 / 固定版式没有可重排正文，朗读仅适用于小说'**
  String get uiComicsFixedLayoutsHaveNoReflowableTextReadAlou;

  /// UI 短标签 | 原文：已暂停在第 ${queue.cursor + 1} / ${queue.length} 句；再次点击从该句续播 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'已暂停在第 {p0} / {p1} 句；再次点击从该句续播'**
  String uiSentencesSentences(String p0, String p1);

  /// UI 短标签 | 原文：${_chapter.title} · 从第 ${queue.cursor + 1} / $_sentenceCount 句开始 · ${rate.toStri | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 从第 {p1} / {p2} 句开始 · {p3}×'**
  String uiSentences(String p0, String p1, String p2, String p3);

  /// UI 短标签 | 原文：已读完全书 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已读完全书'**
  String get uiFinishedTheWholeBook;

  /// UI 短标签 | 原文：恢复默认 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get uiResetToDefault;

  /// UI 短标签 | 原文：正文 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get uiBodyText;

  /// UI 短标签 | 原文：字号 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get uiFontSize;

  /// UI 短标签 | 原文：行高 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'行高'**
  String get uiLineHeight2;

  /// UI 短标签 | 原文：首行缩进 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'首行缩进'**
  String get uiFirstLineIndent;

  /// UI 短标签 | 原文：段间距 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'段间距'**
  String get uiParagraphSpacing;

  /// UI 短标签 | 原文：阅读背景 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读背景'**
  String get uiReadingBackground;

  /// UI 短标签 | 原文：正文与面板文字色由背景亮度自动反推 · 当前对比度  | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'正文与面板文字色由背景亮度自动反推 · 当前对比度 '**
  String get uiBodyTextCharsCurrentcontrast;

  /// UI 短标签 | 原文：${s.bodyContrast.toStringAsFixed(2)} : 1（WCAG AA 正文 ≥ 4.5） | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} : 1（WCAG AA 正文 ≥ 4.5）'**
  String uiWcagAaBodyText452(String p0);

  /// UI 短标签 | 原文：翻页与动效 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'翻页与动效'**
  String get uiPageTurnMotion;

  /// UI 短标签 | 原文：开启时可选择平移 / 仿真翻页 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'开启时可选择平移 / 仿真翻页'**
  String get uiChooseSlideSimulatedPageTurnWhenEnabled;

  /// UI 短标签 | 原文：已整体关闭动效，翻页动效被锁定为「无动画」 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已整体关闭动效，翻页动效被锁定为「无动画」'**
  String get uiMotionIsOffSoPageTurnIsLockedToNone;

  /// UI 短标签 | 原文：归一化规则集中在 AppSettings.normalized()： | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **'归一化规则集中在 AppSettings.normalized()：'**
  String get uiNormalizationIsCentralizedInAppsettingsNormali;

  /// UI 短标签 | 原文：关闭界面动效会自动把翻页动效置为 none，页面不各自解释。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'关闭界面动效会自动把翻页动效置为 none，页面不各自解释。'**
  String get uiTurningMotionOffLocksPageTurnToNonePagesNeverR;

  /// UI 短标签 | 原文：漫画阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'漫画阅读'**
  String get uiComicReading;

  /// UI 短标签 | 原文：朗读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get uiReadAloud2;

  /// UI 短标签 | 原文：语速 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get uiRate;

  /// UI 短标签 | 原文：音调 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'音调'**
  String get uiPitch;

  /// UI 短标签 | 原文：分句队列 · 读完自动进入下一章 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'分句队列 · 读完自动进入下一章'**
  String get uiSentenceQueueAutoNextChapter;

  /// UI 短标签 | 原文：阅读辅助（需平台能力） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读辅助（需平台能力）'**
  String get uiReadingAidsPlatformCapability;

  /// UI 短标签 | 原文：屏幕常亮 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'屏幕常亮'**
  String get uiKeepScreenOn;

  /// UI 短标签 | 原文：静态交付模式下，以上两项只记录偏好，需三端原生能力才能生效（❄️ 冻结）。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'静态交付模式下，以上两项只记录偏好，需三端原生能力才能生效（❄️ 冻结）。'**
  String get uiItems9;

  /// UI 短标签 | 原文：修改仅保存在内存，重启后恢复默认。接入持久化后由 SettingsStore 统一落库。 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'修改仅保存在内存，重启后恢复默认。接入持久化后由 SettingsStore 统一落库。'**
  String get uiSaveSettingsstore;

  /// UI 短标签 | 原文：弱 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get uiWeak;

  /// UI 短标签 | 原文：中 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get uiMedium;

  /// UI 短标签 | 原文：强 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get uiStrong;

  /// UI 短标签 | 原文：漫画 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'漫画'**
  String get uiComics;

  /// UI 短标签 | 原文：第 ${spreadIndex + 1} / ${_layout.spreadCount} 跨 ·  | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'第 {p0} / {p1} 跨 · '**
  String uiSpread(String p0, String p1);

  /// UI 短标签 | 原文：${ComicModeLabels.labels[widget.style.comicReadMode]} | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase317(String p0);

  /// UI 短标签 | 原文：切换到横向翻页 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'切换到横向翻页'**
  String get uiSwitchToHorizontalPaging;

  /// UI 短标签 | 原文：切换到竖向连续 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'切换到竖向连续'**
  String get uiSwitchToVerticalScroll;

  /// UI 短标签 | 原文：跨页模式：${ComicSpreadLabels.mode[widget.style.comicSpreadMode]} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'跨页模式：{p0}'**
  String uiSpreadsPages(String p0);

  /// UI 短标签 | 原文：翻页方向：$directionLabel | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'翻页方向：{p0}'**
  String uiPages3(String p0);

  /// UI 短标签 | 原文：P${item.pageIndex + 1} · 宽高比 ${item.aspectRatio.toStringAsFixed(2)} 占位 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'P{p0} · 宽高比 {p1} 占位'**
  String uiPAspectRatioPlaceholder(String p0, String p1);

  /// UI 短标签 | 原文：${book.author} · ${book.volumeCount} 卷 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1} 卷'**
  String uiVolumes(String p0, String p1);

  /// UI 短标签 | 原文：搜索本地书库 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'搜索本地书库'**
  String get uiSearchLocalLibrary;

  /// UI 短标签 | 原文：书名 / 作者 / 格式 / 分组 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书名 / 作者 / 格式 / 分组'**
  String get uiTitleAuthorFormatGroup;

  /// UI 短标签 | 原文：全部 ${results.length} 册 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'全部 {p0} 册'**
  String uiAllBooks3(String p0);

  /// UI 短标签 | 原文：找到 ${results.length} 册 · 「$_query」 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'找到 {p0} 册 · 「{p1}」'**
  String uiFoundBooks(String p0, String p1);

  /// UI 短标签 | 原文：${books.length} 册 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 册'**
  String uiBooks2(String p0);

  /// UI 短标签 | 原文： · 第 ${book.volumeOrder} 卷 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **' · 第 {p0} 卷'**
  String uiVolumes2(String p0);

  /// UI 短标签 | 原文：了解如何导入 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'了解如何导入'**
  String get uiHowImportingWorks;

  /// UI 短标签 | 原文：清空关键词 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'清空关键词'**
  String get uiClearKeyword;

  /// UI 短标签 | 原文：书  架 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'书  架'**
  String get uiShelf2;

  /// UI 短标签 | 原文：把想读的，放在伸手可及的地方 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'把想读的，放在伸手可及的地方'**
  String get uiKeepWhatYouWantToReadWithinReach;

  /// UI 短标签 | 原文：—  共 ${repo.cached.length} 册 · 收藏 ${state.favoriteCount} 册 ·  | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'—  共 {p0} 册 · 收藏 {p1} 册 · '**
  String uiTotalBooksBooks(String p0, String p1);

  /// UI 短标签 | 原文：${state.shelfCounts().length} 个分组 · 按卷序 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0} 个分组 · 按卷序'**
  String uiItemsgroupVolumeOrder(String p0);

  /// UI 短标签 | 原文：搜索书名 / 作者 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'搜索书名 / 作者'**
  String get uiSearchTitleAuthor;

  /// UI 短标签 | 原文：查看全部结果 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'查看全部结果'**
  String get uiViewAllResults;

  /// UI 短标签 | 原文：只看已收藏的 ${state.favoriteCount} 册 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'只看已收藏的 {p0} 册'**
  String uiBooks3(String p0);

  /// UI 短标签 | 原文：点星标可在详情页 / 阅读器收藏 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'点星标可在详情页 / 阅读器收藏'**
  String get uiTapTheStarOnTheDetailOrReaderPageToFavorite;

  /// UI 短标签 | 原文：当前页面未注入搜索页导航 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前页面未注入搜索页导航'**
  String get uiSearchNavigationIsNotWiredIntoThisPage;

  /// UI 短标签 | 原文：当前页面未注入详情导航 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前页面未注入详情导航'**
  String get uiDetailNavigationIsNotWiredIntoThisPage;

  /// UI 短标签 | 原文：当前页面未注入导入入口 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前页面未注入导入入口'**
  String get uiImportEntryIsNotWiredIntoThisPage;

  /// UI 短标签 | 原文：视觉样式 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'视觉样式'**
  String get uiVisualStyle;

  /// UI 短标签 | 原文：共 $total 册 · 按卷序 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 册 · 按卷序'**
  String uiTotalBooksVolumeOrder(String p0);

  /// UI 短标签 | 原文：第 ${b.volumeOrder} 卷 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'第 {p0} 卷'**
  String uiVolume3(String p0);

  /// UI 短标签 | 原文：查看全部书籍 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'查看全部书籍'**
  String get uiViewAllBooks;

  /// UI 短标签 | 原文：上一月 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'上一月'**
  String get uiPreviousMonth;

  /// UI 短标签 | 原文：下一月 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'下一月'**
  String get uiNextMonth;

  /// UI 短标签 | 原文：本月阅读 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本月阅读'**
  String get uiThisMonth2;

  /// UI 短标签 | 原文：阅读天数 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读天数'**
  String get uiReadingDays;

  /// UI 短标签 | 原文：${month.readDays} 天 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 天'**
  String uiDays2(String p0);

  /// UI 短标签 | 原文：纪念物 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'纪念物'**
  String get uiKeepsakes;

  /// UI 短标签 | 原文：${month.keepsakeCount} 枚 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 枚'**
  String uiKeepsakes2(String p0);

  /// UI 短标签 | 原文：摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'摘录'**
  String get uiExcerpts;

  /// UI 短标签 | 原文：${month.excerptCount} 条 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} 条'**
  String uiItems10(String p0);

  /// UI 短标签 | 原文：少 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'少'**
  String get uiLow;

  /// UI 短标签 | 原文：多 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'多'**
  String get uiHigh;

  /// UI 短标签 | 原文：跨月补格 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'跨月补格'**
  String get uiAdjacentMonthCells;

  /// UI 短标签 | 原文：当天的纪念物 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当天的纪念物'**
  String get uiKeepsakesThatDay;

  /// UI 短标签 | 原文：当天摘下的话 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当天摘下的话'**
  String get uiExcerptsThatDay;

  /// UI 短标签 | 原文：上一枚纪念物 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'上一枚纪念物'**
  String get uiPreviousKeepsake;

  /// UI 短标签 | 原文：换一枚纪念物 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'换一枚纪念物'**
  String get uiNextKeepsake;

  /// UI 短标签 | 原文：你摘的 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'你摘的'**
  String get uiYours2;

  /// UI 短标签 | 原文：标题 / 说明 / 类型 / 书名 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'标题 / 说明 / 类型 / 书名'**
  String get uiTitleNoteTypeBook;

  /// UI 短标签 | 原文：类型 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get uiType;

  /// UI 短标签 | 原文：月份 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'月份'**
  String get uiMonth;

  /// UI 短标签 | 原文：共 ${summary.total} 枚 · ${summary.monthCount} 个月 ·  | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 枚 · {p1} 个月 · '**
  String uiTotalKeepsakesItems(String p0, String p1);

  /// UI 短标签 | 原文：来自你摘的 ${summary.userExcerptCount} 枚 · 命中 ${results.length} 枚 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'来自你摘的 {p0} 枚 · 命中 {p1} 枚'**
  String uiKeepsakesKeepsakes(String p0, String p1);

  /// UI 短标签 | 原文：$title · ${items.length} 枚 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1} 枚'**
  String uiKeepsakes3(String p0, String p1);

  /// UI 短标签 | 原文：阅读统计 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读统计'**
  String get uiReadingStats;

  /// UI 短标签 | 原文：小组件 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'小组件'**
  String get uiWidgets;

  /// UI 短标签 | 原文：把时间读成可以翻回去的页 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'把时间读成可以翻回去的页'**
  String get uiTurnReadingTimeIntoPagesYouCanFlipBackThrough;

  /// UI 短标签 | 原文：今日阅读 · 目标 $snapshot.goalMinutes 分钟 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'今日阅读 · 目标 {p0}.goalMinutes 分钟'**
  String uiGoalminutesMinutes(String p0);

  /// UI 短标签 | 原文：分钟 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get uiMinutes2;

  /// UI 短标签 | 原文：连续 ${snapshot.streakDays} 天 · 本周 ${snapshot.weekLabel} ·  | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'连续 {p0} 天 · 本周 {p1} · '**
  String uiDaysThisWeek(String p0, String p1);

  /// UI 短标签 | 原文：书库 ${snapshot.totalBooks} 册 · 摘录 $userExcerptCount 条 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'书库 {p0} 册 · 摘录 {p1} 条'**
  String uiBooksExcerptsItems(String p0, String p1);

  /// UI 短标签 | 原文：继续阅读《${recent.title}》 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'继续阅读《{p0}》'**
  String uiContinueReading2(String p0);

  /// UI 短标签 | 原文：阅读热力 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读热力'**
  String get uiReadingHeatmap;

  /// UI 短标签 | 原文：近 5 周 · ${snapshot.days.length} 天 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'近 5 周 · {p0} 天'**
  String uiDays3(String p0);

  /// UI 短标签 | 原文：阅读日历 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'阅读日历'**
  String get uiReadingCalendar;

  /// UI 短标签 | 原文：摘  录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'摘  录'**
  String get uiExcerpts2;

  /// UI 短标签 | 原文：共 ${excerpts.length} 条 · 你摘的 $userExcerptCount 条 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 条 · 你摘的 {p1} 条'**
  String uiTotalItemsItems(String p0, String p1);

  /// UI 短标签 | 原文：管理 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get uiManage;

  /// UI 短标签 | 原文：还没有摘录，去阅读器点选几行正文吧。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'还没有摘录，去阅读器点选几行正文吧。'**
  String get uiNoExcerptsYetSelectAFewLinesInTheReaderToStart;

  /// UI 短标签 | 原文：演示数据 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'演示数据'**
  String get uiSampleData;

  /// UI 短标签 | 原文：上一条 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'上一条'**
  String get uiPrevious;

  /// UI 短标签 | 原文：换一条摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'换一条摘录'**
  String get uiNextExcerpt;

  /// UI 短标签 | 原文：删除这条摘录 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'删除这条摘录'**
  String get uiDeleteThisExcerpt;

  /// UI 短标签 | 原文：已配置 ${state.widgetSpecs.length} 个小组件 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'已配置 {p0} 个小组件'**
  String uiItemswidgets(String p0);

  /// UI 短标签 | 原文：${days[i].key} · ${days[i].minutes} 分钟 | 来源：模板
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1} 分钟'**
  String uiMinutes3(String p0, String p1);

  /// UI 短标签 | 原文：小组件配置 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'小组件配置'**
  String get uiWidgets2;

  /// UI 短标签 | 原文：共 ${specs.length} 个 · 可同时放置多个 · 每个独立配置 | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'共 {p0} 个 · 可同时放置多个 · 每个独立配置'**
  String uiTotalItemsItemsItems(String p0);

  /// UI 短标签 | 原文：深色预览 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'深色预览'**
  String get uiDarkPreview;

  /// UI 短标签 | 原文：浅色预览 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'浅色预览'**
  String get uiLightPreview;

  /// UI 短标签 | 原文：添加一个小组件 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'添加一个小组件'**
  String get uiAddAWidget;

  /// UI 短标签 | 原文：关于桌面小组件 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'关于桌面小组件'**
  String get uiAboutDesktopWidgets;

  /// UI 短标签 | 原文：本面板只保存应用内配置与预览。桌面小组件本体不是 Flutter 能绘制的： | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'本面板只保存应用内配置与预览。桌面小组件本体不是 Flutter 能绘制的：'**
  String get uiSaveWidgetsFlutter;

  /// UI 短标签 | 原文：Android 用应用内配置，iOS 用 WidgetKit 系统编辑控件，HarmonyOS 用卡片配置， | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **'Android 用应用内配置，iOS 用 WidgetKit 系统编辑控件，HarmonyOS 用卡片配置，'**
  String get uiAndroidUsesInAppConfigIosUsesWidgetkitEditCont;

  /// UI 短标签 | 原文：三端均需原生实现并读取这里序列化后的数据。 | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **'三端均需原生实现并读取这里序列化后的数据。'**
  String get uiAllThreePlatformsNeedNativeImplementationsRead;

  /// UI 短标签 | 原文： · 显示进度 | 来源：片段
  ///
  /// In zh, this message translates to:
  /// **' · 显示进度'**
  String get uiShowProgress;

  /// UI 短标签 | 原文：内容 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get uiContent2;

  /// UI 短标签 | 原文：纪念物类型（每个小组件独立） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'纪念物类型（每个小组件独立）'**
  String get uiKeepsakeTypePerWidget;

  /// UI 短标签 | 原文：尺寸 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'尺寸'**
  String get uiSize2;

  /// UI 短标签 | 原文：季节样式（独立于应用换肤） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'季节样式（独立于应用换肤）'**
  String get uiSeasonStyleIndependentOfAppTheme;

  /// UI 短标签 | 原文：显示进度 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'显示进度'**
  String get uiShowProgress2;

  /// UI 短标签 | 原文：移除 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get uiRemove2;

  /// UI 短标签 | 原文：本月纪念物预览 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'本月纪念物预览'**
  String get uiThisMonthKeepsakePreview;

  /// UI 短标签 | 原文：在线目录未开启，未发出任何请求。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'在线目录未开启，未发出任何请求。'**
  String get uiOnlineDirectoryIsOffNoRequestWasMade;

  /// UI 短标签 | 原文：个人书架：${listing.books.length} 册 · ${listing.note} | 来源：模板 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'个人书架：{p0} 册 · {p1}'**
  String uiItemsShelfBooks(String p0, String p1);

  /// UI 短标签 | 原文：来源域名 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'来源域名'**
  String get uiSourceDomain;

  /// UI 短标签 | 原文：请稍候… | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'请稍候…'**
  String get uiPleaseWait;

  /// UI 短标签 | 原文：读取个人书架 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'读取个人书架'**
  String get uiReadPersonalBookcase;

  /// UI 短标签 | 原文：正在处理… | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'正在处理…'**
  String get uiWorking;

  /// UI 短标签 | 原文：已登录；后续请求会携带来源下发的会话 Cookie。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'已登录；后续请求会携带来源下发的会话 Cookie。'**
  String get uiSignedInLaterRequestsCarryTheSessionCookieIssu;

  /// UI 短标签 | 原文：在线目录与本地书库，各自独立 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'在线目录与本地书库，各自独立'**
  String get uiOnlineDirectoryAndLocalLibraryStayIndependent;

  /// UI 短标签 | 原文：启用在线目录（Wenku8） | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'启用在线目录（Wenku8）'**
  String get uiEnableOnlineDirectoryWenku8;

  /// UI 短标签 | 原文：当前为纯本地模式，全应用不产生任何网络请求。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'当前为纯本地模式，全应用不产生任何网络请求。'**
  String get uiPureLocalModeIsOnTheAppMakesNoNetworkRequests;

  /// UI 短标签 | 原文：如需开启，请先在「我的」页关闭纯本地模式。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'如需开启，请先在「我的」页关闭纯本地模式。'**
  String get uiTurnOffPureLocalModeOnTheProfilePageFirst;

  /// UI 短标签 | 原文：关闭时本应用保持纯本地运行，不产生任何网络请求。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'关闭时本应用保持纯本地运行，不产生任何网络请求。'**
  String get uiWhenOffTheAppStaysFullyLocalAndMakesNoNetworkR;

  /// UI 短标签 | 原文：开启后仅访问 Wenku8 的在线列表与目录元数据。 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'开启后仅访问 Wenku8 的在线列表与目录元数据。'**
  String get uiWhenOnOnlyWenku8ListingsAndTocMetadataAreRead;

  /// UI 短标签 | 原文：表单登录 · 个人书架 · 来源域名切换 | 来源：片段 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'表单登录 · 个人书架 · 来源域名切换'**
  String get uiItemsShelfSource;

  /// UI 短标签 | 原文：导入到本地方库 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'导入到本地方库'**
  String get uiImportIntoLocalLibrary;

  /// UI 短标签 | 原文：TXT / EPUB / CBZ / PDF / 图片文件夹 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'TXT / EPUB / CBZ / PDF / 图片文件夹'**
  String get uiTxtEpubCbzPdfImageFolders;

  /// UI 短标签 | 原文：示例作品 · 目录预览 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'示例作品 · 目录预览'**
  String get uiSampleWorkTocPreview;

  /// UI 短标签 | 原文：示意数据 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'示意数据'**
  String get uiSampleData2;

  /// UI 短标签 | 原文：示例作品 · 卷列表 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'示例作品 · 卷列表'**
  String get uiSampleWorkVolumeList;

  /// UI 短标签 | 原文：示例作品 · 详情 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'示例作品 · 详情'**
  String get uiSampleWorkDetail;

  /// UI 短标签 | 原文：元数据 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'元数据'**
  String get uiMetadata;

  /// UI 短标签 | 原文：关于内容与来源 | 来源：精确
  ///
  /// In zh, this message translates to:
  /// **'关于内容与来源'**
  String get uiAboutContentAndSources;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'书级覆盖'**
  String get uiBookOverride;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'全局默认'**
  String get uiGlobalDefault;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'达到'**
  String get uiMeetsMinimum;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'未达到'**
  String get uiBelowMinimum;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'（无可用语音，已跳过）'**
  String get uiNoVoiceSkipped;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'（无数据，全部省略）'**
  String get uiNoDataOmitted;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'（中英对齐）'**
  String get uiAligned;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'（未对齐）'**
  String get uiMisaligned;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get uiEnabled;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get uiDisabled;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'浅色内高光'**
  String get uiLightInnerHighlight;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'黑色阴影'**
  String get uiBlackShadow;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'番外'**
  String get uiSpecialEpisode;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'书脊'**
  String get uiSpine;

  /// 插值表达式内部的中文子字面量
  ///
  /// In zh, this message translates to:
  /// **'宽幅独占'**
  String get uiWideSolo;

  /// UI 短标签（嵌套插值补齐） | 原文：多：${extra.join('、')} | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'多：{p0}'**
  String uiPhrase000(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：缺：${missing.join('、')} | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'缺：{p0}'**
  String uiPhrase001(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${entry['author']} · 示意数据
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 示意数据'**
  String uiSampleDataN1(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${state.onlineEnabled ? '已开启' : '未开启'}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase003(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${context.t('freeStatement')} · 当前在线目录： | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 当前在线目录：'**
  String uiCurrentContents(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${context.t('noResultBody')} 关键词：「$query」 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n关键词：「{p1}」'**
  String uiPhrase005(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：${context.t('noResultBody')} 当前关键词：「$query」 | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'{p0}\n当前关键词：「{p1}」'**
  String uiCurrentN1(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：${_verticalMode ? '' : ' · $directionLabel'}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase007(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文： · 关于段落 ${bundle.list('aboutParagraphs').length} 条
  ///
  /// In zh, this message translates to:
  /// **' · 关于段落 {p0} 条'**
  String uiAboutParagraphsItems(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：渐暗 $level · ${spec.onDarkBackground ? '浅色内高光' : '黑色阴影'}
  ///
  /// In zh, this message translates to:
  /// **'渐暗 {p0} · {p1}'**
  String uiShade(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：${_spineShadeLabel.isEmpty ? '' : ' · $_spineShadeLabel'}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase010(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${episode.kind == ComicEpisodeKind.special ? ' · 番外' : ''}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase011(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${book.volumeOrder == 0 ? '' : ' · 第 ${book.volumeOrder} 卷'}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase012(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${LocalizedLegalTexts.paragraphsAligned() ? '（中英对齐）' : '（未对齐）'}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase013(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：${visible.length} 枚${scopeLabel.isEmpty ? '' : ' · $scopeLabel'}
  ///
  /// In zh, this message translates to:
  /// **'{p0} 枚{p1}'**
  String uiKeepsakesN1(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：近 7 天 · 共 ${snapshot.totalPages} 页 · ${context.t('demoDataNote')} | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'近 7 天 · 共 {p0} 页 · {p1}'**
  String uiDaysTotalPages(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：${context.t('bookExcerptTitle')} · 《$scopedTitle》 · $scopedCount 条
  ///
  /// In zh, this message translates to:
  /// **'{p0} · 《{p1}》 · {p2} 条'**
  String uiItemsN1(String p0, String p1, String p2);

  /// UI 短标签（嵌套插值补齐） | 原文：${_layout.wideSpreadCount > 0 ? ' · 宽幅独占 ${_layout.wideSpreadCount} 跨' : ''}
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase017(String p0);

  /// UI 短标签（嵌套插值补齐） | 原文：$chapterCount 章 · ${book.volumeOrder == 0 ? '未分卷' : '第 ${book.volumeOrder} 卷'}
  ///
  /// In zh, this message translates to:
  /// **'{p0} 章 · {p1}'**
  String uiChaptersN1(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：已写入 $added 册${commit.deferredCount > 0 ? ' · ${commit.deferredCount} 项延后处理' : '' | x-review: 英文由片段兜底固化，仍含中文片段，建议人工润色
  ///
  /// In zh, this message translates to:
  /// **'已写入 {p0} 册{p1}'**
  String uiBooksN1(String p0, String p1);

  /// UI 短标签（嵌套插值补齐） | 原文：${context.t('wenkuDetailToc')} · ${detail.volumes.length} 卷 / ${detail.chapterCo
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1} 卷 / {p2} 章'**
  String uiVolumesChapters(String p0, String p1, String p2);

  /// UI 短标签（嵌套插值补齐） | 原文：${ComicSpreadGutter.spineCount(_layout) > 0 ? ' · 书脊 ${ComicSpreadGutter.spineCo
  ///
  /// In zh, this message translates to:
  /// **'{p0}'**
  String uiPhrase021(String p0);

  /// 相邻字符串拼接合并后的 UI 行模板（第二十八轮）
  ///
  /// In zh, this message translates to:
  /// **'《{p0}》· {p1}{p2}'**
  String uiExcerptCaptureSource(String p0, String p1, String p2);

  /// 相邻字符串拼接合并后的 UI 行模板（第二十八轮）
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1}{p2}'**
  String uiBookMetaLine(String p0, String p1, String p2);

  /// 相邻字符串拼接合并后的 UI 行模板（第二十八轮）
  ///
  /// In zh, this message translates to:
  /// **'{p0} · {p1}{p2}{p3}'**
  String uiWidgetSpecLine(String p0, String p1, String p2, String p3);

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **'第 {p0} 卷'**
  String uiVolumeN(String p0);

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **' · 第 {p0} 卷'**
  String uiVolumePrefixN(String p0);

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **' · {p0} 项延后处理'**
  String uiDeferredN(String p0);

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **' · 番外'**
  String get uiSpecialEpisodePrefix;

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **' · 宽幅独占 {p0} 跨'**
  String uiWideSoloN(String p0);

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **' · 书脊 {p0} 跨'**
  String uiSpineN(String p0);

  /// 第二十八轮：从插值表达式 / 语言名收进 ARB
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get uiSimplifiedChinese;

  /// 本地化资源面板：文案唯一源说明
  ///
  /// In zh, this message translates to:
  /// **'文案源：lib/l10n/app_zh.arb 与 app_en.arb；改文案只改这两份，再跑 tool/sync_arb.py。'**
  String get uiArbSourceNote;

  /// 本地化资源面板：ARB 统计
  ///
  /// In zh, this message translates to:
  /// **'{p0} 键 · {p1} 模板 · {p2} 待润色'**
  String uiArbStats(String p0, String p1, String p2);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
