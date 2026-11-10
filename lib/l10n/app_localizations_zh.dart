// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '本地阅读';

  @override
  String get feedbackNoCredentials => '';

  @override
  String get aboutParagraph1 => '支持 Android、iOS 与 HarmonyOS，不是 Wenku8 官方应用。';

  @override
  String get aboutParagraph2 =>
      '应用完全免费、自愿支持；所有功能均免费，不销售会员、激活码或功能解锁，请警惕以本项目或开发者名义收费的行为。';

  @override
  String get aboutParagraph3 => '仅支持 Wenku8 与本地导入，不支持其他来源与自定义书源。';

  @override
  String get aboutParagraph4 =>
      '小说、封面与插画归各权利人所有，源码许可证不授予内容权利；请只访问你有权使用的内容并遵守来源网站规则，勿绕过访问限制、破解 DRM，或未经许可复制、分发、售卖内容。';

  @override
  String get aboutParagraph5 =>
      '提交问题时请附应用版本、设备、操作系统版本与复现步骤；请勿附带密码、Cookie 或 Token。';

  @override
  String get aboutParagraph6 => '第三方服务可能变更、限流或不可用。';

  @override
  String get appDisclaimer =>
      '本应用是第三方阅读客户端，用于阅读与管理本地书籍；不运营在线书库、不发布小说、不打包小说文件。在线内容与可用性由 Wenku8 决定，不提供因版权原因下架内容的在线访问。';

  @override
  String get nonOfficial => '支持 Android、iOS 与 HarmonyOS，不是 Wenku8 官方应用。';

  @override
  String get freeStatement =>
      '应用完全免费、自愿支持；所有功能均免费，不销售会员、激活码或功能解锁，请警惕以本项目或开发者名义收费的行为。';

  @override
  String get sources => '仅支持 Wenku8 与本地导入，不支持其他来源与自定义书源。';

  @override
  String get contentRights =>
      '小说、封面与插画归各权利人所有，源码许可证不授予内容权利；请只访问你有权使用的内容并遵守来源网站规则，勿绕过访问限制、破解 DRM，或未经许可复制、分发、售卖内容。';

  @override
  String get thirdPartyService => '第三方服务可能变更、限流或不可用。';

  @override
  String get onlineAvailability => '在线内容与可用性由 Wenku8 决定；第三方服务可能变更、限流或不可用。';

  @override
  String get issueGuidance =>
      '提交问题时请附应用版本、设备、操作系统版本与复现步骤；请勿附带密码、Cookie 或 Token。';

  @override
  String get onlineEntryNote =>
      '此处只展示在线列表、详情与目录元数据。阅读内容需由用户自行导入本地书库；应用不内置、不打包、不分发小说文件，也不提供因版权原因下架内容的在线访问。';

  @override
  String get localOnlyNote => '默认为纯本地模式，关闭态下全应用不产生任何网络请求；在线目录与 WebDAV 均默认关闭。';

  @override
  String get importFormats =>
      'TXT（编码自动识别 + 章节切分）· EPUB · CBZ/ZIP · 图片文件夹 · PDF（逐页渲染）· RAR4 及更早。';

  @override
  String get archiveNotice => 'RAR5 与加密压缩包暂不支持，请转换为 CBZ/ZIP。';

  @override
  String get permissionNotice =>
      '权限：Android 13+ 仅申请读取图片；文档类书籍不在媒体库覆盖范围内，仍需走系统文件选择器目录授权或「所有文件访问」。未申请音频、视频与通知权限。无权限时导入对话框会明确提示当前状态。';

  @override
  String get importChannels =>
      '可通过 OpenList / WebDAV 或夸克（实验性）导入；也可通过系统文档选择器访问 OneDrive、Google Drive 等服务。授权会持久化，重启后可一键重扫。';

  @override
  String get importBody =>
      '\$importFormats\n\$archiveNotice\n\n\$permissionNotice\n\n\$importChannels\n\n\$localOnlyNote';

  @override
  String get importTitle => '导入书籍';

  @override
  String get importWizardTitle => '导入向导';

  @override
  String get importWizardStaticNote =>
      '静态交付模式：授权与扫描均为本地演示数据，不调用系统文件选择器、不读取文件字节、不解压、不联网；真实 SAF 持久化与文件扫描需三端平台能力（❄️ 冻结）。';

  @override
  String get importRar5Reason => 'RAR5 暂不支持，请转换为 CBZ/ZIP 后重新扫描。';

  @override
  String get importEncryptedReason => '加密压缩包暂不支持，请转换为 CBZ/ZIP 后重新扫描。';

  @override
  String get importUnsupportedReason => '未登记的格式，静态阶段不猜测内容，请确认扩展名。';

  @override
  String get importNoModeHint => '先选择一种授权方式，再继续。';

  @override
  String get importNoGrantHint => '尚未确认授权；静态阶段只记录选择，不会申请系统权限。';

  @override
  String get importScanEmpty => '这个目录没有可导入的书籍文件。';

  @override
  String get importNoAcceptedHint => '没有可导入的文件；请先处理不支持的格式，再重新扫描。';

  @override
  String get importConflictNote =>
      '同名书籍已存在。演示书库只读，「替换」与「合并记录」会记为延后处理；「两者都保留」会生成一份副本。';

  @override
  String get importDoneNote => '导入结果仅写入内存书库，重启后恢复演示数据；不改动只读演示书籍。';

  @override
  String get importWizardEntry => '打开导入向导';

  @override
  String get emptyLibraryTitle => '书库还是空的';

  @override
  String get emptyLibraryBody =>
      '通过系统文件选择器授权目录后导入本地书籍；支持 TXT / EPUB / CBZ / PDF 等格式。文档类书籍不在媒体库覆盖范围内，需要目录授权或「所有文件访问」。';

  @override
  String get noResultTitle => '没有找到这本书';

  @override
  String get noResultBody => '试试更短的书名、作者名，或切换到其他关键词。搜索只在本地书库内进行，不产生网络请求。';

  @override
  String get demoDataNote => '当前为演示数据；编辑结果仅保存在内存，重启后恢复。';

  @override
  String get excerptLocalNote => '摘录只保存在本地内存，不上传、不联网；重启后恢复演示数据。';

  @override
  String get excerptExportNote =>
      '导出仅生成本地纯文本预览，不写文件、不调用系统分享、不上传；落盘与分享需平台能力，静态阶段不实施。';

  @override
  String get excerptReadOnlyNote => '演示摘录只读；你可以编辑批注、更换划线色或删除自己采集的条目。';

  @override
  String get excerptEmptyTitle => '还没有摘录';

  @override
  String get excerptEmptyBody => '去阅读器点选正文中的一行或多行，点顶栏书签即可摘录。';

  @override
  String get excerptNoResultTitle => '没有匹配的摘录';

  @override
  String get excerptNoResultBody => '试试更短的关键词，或清掉按书 / 划线色 / 范围的筛选条件。';

  @override
  String get comicPlaceholderNote =>
      '当前为按宽高比占位；真实页像素需三端 BookRenderBridge，静态阶段不解码图片。';

  @override
  String get comicTocNote =>
      '话集由归档内目录名 / 文件名识别，不解压、不读文件内容；未识别的页归入「未分话」，不会静默丢弃。识别不全会显示识别率。';

  @override
  String get comicLocalNote => '漫画阅读与分话目录全在本地完成，不联网、不上传；页像素渲染需平台能力（❄️ 冻结）。';

  @override
  String get favoriteLocalNote => '收藏只保存在本地内存，不联网、不上传；重启后恢复演示收藏。';

  @override
  String get favoriteEmptyTitle => '还没有收藏';

  @override
  String get favoriteEmptyBody => '在书籍详情或阅读器顶栏点星标，就能把书收进这里。';

  @override
  String get favoritesOnlyHint => '只看收藏';

  @override
  String get screenshotNote => '界面截图使用演示书籍数据，应用界面为中文。';

  @override
  String get keepsakeTitle => '纪念物';

  @override
  String get calendarMonthTitle => '阅读日历 · 整月';

  @override
  String get keepsakeStaticNote =>
      '纪念物由阅读统计与摘录自动生成，不手写演示条目；只保存在本地内存，不上传、不联网。五种季节手账配色可在书架页切换，桌面小组件本体需三端原生';

  @override
  String get calendarStaticNote =>
      '月度日历由近 35 天演示热力与摘录聚合而来，周一起始、固定 6 周网格；跨月补格只用于对齐，不计入月度合计。静态阶段不读取真实阅读数据库。';

  @override
  String get keepsakeEmptyTitle => '还没有纪念物';

  @override
  String get keepsakeEmptyBody => '继续阅读、达成目标或摘下一句话，纪念物就会自动出现在这里。';

  @override
  String get calendarNoRecordNote => '这一天还没有阅读记录';

  @override
  String get calendarOutOfRangeNote => '已到演示数据覆盖的月份边界';

  @override
  String get calendarOpenMonth => '查看整月';

  @override
  String get calendarBackToThisMonth => '回到本月';

  @override
  String get calendarAllMonths => '全部';

  @override
  String get localizationTitle => '文案表与语言预览';

  @override
  String get localizationPreviewTitle => '按语言预览文案';

  @override
  String get localizationDefaultNote => '默认中文 · 不跟随系统语言';

  @override
  String get localizationStaticNote =>
      '发布版界面为中文（参考仓库 README：The app interface is in Chinese）。静态阶段只核对多语言表结构与回退口径，不自动跟随系统语言、不逐页切换界面文案；页面仍读中文常量这一份默认 bundle。完整逐页本地化需逐个页面接入，属后续候选。';

  @override
  String get comicSpreadTitle => '双页与翻页方向';

  @override
  String get comicBlankSlotNote => '补白槽 · 非缺页';

  @override
  String get comicVerticalLockNote =>
      '竖向连续滚动没有左右概念，已自动锁定为「单页 · 左 → 右」。切到横向跨页翻页后，双页与右 → 左偏好才会生效。';

  @override
  String get comicSpreadStaticNote =>
      '双页跨页只编排页序与视觉槽位：封面独占一跨，奇数页补白并明示为「补白槽 · 非缺页」，不静默吞页、不伪造图片。右 → 左只改变跨内左右顺序与翻页前进方向，不改变阅读顺序。静态阶段仍按宽高比占位，不解码图片、不读文件字节；页像素与真机手势需三端 BookRenderBridge（❄️ 冻结）。';

  @override
  String get bookExcerptTitle => '这本书的摘录';

  @override
  String get bookExcerptEmptyTitle => '这本书还没有摘录';

  @override
  String get bookExcerptEmptyBody =>
      '在阅读器里点选一行正文，再点顶栏书签即可摘录；摘完回到这里就能看到。也可以清空筛选，查看全部书籍的摘录。';

  @override
  String get bookExcerptScopedNote =>
      '当前只看这一本书，点「全部书」可查看全部摘录。筛选按 bookId，书名在详情页编辑后不会让筛选失效。';

  @override
  String get bookExcerptPinnedNote =>
      '这本书暂时没有摘录，仍保留在按书筛选里并标注 0 条，不会变成看不见的筛选条件。';

  @override
  String get bookExcerptStaticNote =>
      '详情入口只传 bookId，由摘录管理页自行筛选，feature 之间不互相依赖。摘录只存内存、不联网、不落盘；桌面小组件与持久化仍 ❄️ 冻结。';

  @override
  String get bookExcerptMissingNote =>
      '这本书不在当前书库（可能已移除，或来自上次的导入数据）。摘录仍按 bookId 匹配，点「全部书」可查看其它书籍的摘录。';

  @override
  String get excerptSearchTitleNote => '书名搜索同时匹配书库当前名称与摘录捕获时的旧名；改名后搜新旧名都能找到。';

  @override
  String get excerptExportSnapshotNote =>
      '导出正文保留摘录捕获时的书名快照，保证历史导出可复核；页面展示、搜索、排序与分组使用书库当前名称。';

  @override
  String get keepsakeAllKinds => '全部类型';

  @override
  String get keepsakeOpenLibrary => '查看全部纪念物';

  @override
  String get keepsakeLibraryTitle => '纪念物册';

  @override
  String get keepsakeFilterHint => '类型与月份可叠加筛选；类型旁的条数只随月份与关键词变化，不因已选类型归零。';

  @override
  String get keepsakeKindEmptyTitle => '这一类还没有纪念物';

  @override
  String get keepsakeKindEmptyBody =>
      '纪念物由阅读记录与摘录自动生成，达到条件后会出现在这里。也可以清空筛选查看其它类型。';

  @override
  String get keepsakeNoResultTitle => '没有符合条件的纪念物';

  @override
  String get keepsakeNoResultBody => '换个类型、月份或关键词试试；也可以清空筛选条件查看全部纪念物。';

  @override
  String get keepsakeFilterStaticNote =>
      '纪念物只从统计快照与摘录聚合，页面不缓存、只存内存、不联网、不落盘；桌面小组件本体 ❄️ 冻结。';

  @override
  String get keepsakeWidgetKindNote =>
      '内容选「纪念物」时，可为每个小组件单独指定一种类型；留空则显示全部。多个小组件各自独立。';

  @override
  String get keepsakeMonthPreviewNote =>
      '「本月」取统计快照的固定基准日，与热力图、纪念物册同月；桌面小组件本体仍 ❄️ 冻结，这里只是应用内预览。';

  @override
  String get keepsakeMonthPreviewOpen => '查看本月纪念物';

  @override
  String get keepsakeMonthEmptyBody => '本月还没有纪念物。它由阅读记录与摘录自动生成，达标后会出现在这里。';

  @override
  String get keepsakeMonthKindEmptyBody => '本月有纪念物，但没有这一类。清空类型筛选可看本月全部纪念物。';

  @override
  String get keepsakeMonthNoResultBody => '本月当前筛选没有命中项，换个类型或清空筛选试试。';

  @override
  String get comicWideSoloTitle => '宽幅页独占一跨';

  @override
  String get comicWideSoloNote =>
      '横幅 / 跨页彩图不与邻页并排；前后页各自补白，补白槽写明「宽幅页独占一跨 · 非缺页」。';

  @override
  String get comicWideSoloSingleNote => '单页模式下每页本来就独占，此偏好保留但不产生视觉差异。';

  @override
  String get excerptAnchorRestoreNote =>
      '换行号后按「位置精确 → 位置一致文字已变 → 本章文本唯一」三级还原；多处相同文本不自动高亮，避免画错位置。';

  @override
  String get keepsakeDayEmptyTitle => '这一天还没有纪念物';

  @override
  String get keepsakeDayEmptyBody => '回到阅读日历换一天看看，或清除日期筛选查看整月纪念物。';

  @override
  String get keepsakeDayFilterNote => '只看这一天 · 清除后回到整月';

  @override
  String get calendarOpenMonthKeepsakes => '查看本月纪念物';

  @override
  String get calendarOpenDayKeepsakes => '查看当天纪念物';

  @override
  String get calendarCrossMonthNote => '跨月补格只用于对齐周起始，不提供当天深链';

  @override
  String get calendarInvalidDateNote => '日期格式无效，无法定位到阅读日历';

  @override
  String get keepsakeOpenCalendarDay => '在日历中查看';

  @override
  String get keepsakeOpenCalendarMonth => '查看整月日历';

  @override
  String get comicSpineGutterTitle => '双页书脊留白';

  @override
  String get comicSpineGutterNote =>
      '只在两页真实页并排时绘制书脊：中间留白按槽宽比例计算并夹在 8–28px，左右页内侧各叠一层渐暗，模拟装订；封面 / 宽幅 / 补白跨不画书脊。';

  @override
  String get comicSpineShadeTitle => '书脊渐暗强度';

  @override
  String get comicSpineShadeNote =>
      '强度按槽宽自动选档（窄屏含蓄、宽屏加强），目标色按阅读背景亮度反推：浅底用黑色阴影，深底改用折减的浅色内高光，避免夜间模式下黑叠黑看不见。这是固定视觉规则，不是用户可调设置；静态阶段只做模型，未接真机调参。';

  @override
  String get keepsakeDateRangeTitle => '日期范围';

  @override
  String get keepsakeDateRangeHint => 'YYYY-MM-DD';

  @override
  String get keepsakeDateRangeNote =>
      '闭区间，起止可只填一端；起日晚于止日会自动交换。设置范围会清除「只看某天」与「整月」，避免筛选条件互相打架。';

  @override
  String get keepsakeDateRangeInvalid => '日期格式无效，请输入 YYYY-MM-DD（例如 2026-11-08）';

  @override
  String get keepsakeDateRangeFilterNote => '只看这段日期 · 清除后回到全部纪念物';

  @override
  String get keepsakeDateRangeAll => '全部日期';

  @override
  String get keepsakeDateRangeThisMonth => '本月';

  @override
  String get keepsakeDateRangeLast7 => '最近 7 天';

  @override
  String get keepsakeRangeEmptyTitle => '这段日期还没有纪念物';

  @override
  String get keepsakeRangeEmptyBody => '换一段日期或清除范围筛选，也可以回到阅读日历按天查看。';

  @override
  String get calendarOpenDayExcerpts => '查看当天摘录';

  @override
  String get excerptDayFilterNote => '只看这一天 · 清除后回到全部摘录';

  @override
  String get excerptDayEmptyTitle => '这一天还没有摘录';

  @override
  String get excerptDayEmptyBody => '回到阅读日历换一天看看，或清除日期筛选回到全部摘录。';

  @override
  String get excerptDayScopedTitle => '当日摘录';

  @override
  String get wenkuOnlySources =>
      '仅支持 Wenku8 在线目录与用户自行导入的本地书籍；不支持其它来源，也不支持自定义书源。';

  @override
  String get wenkuContentOwnership => '小说、封面与插画归各自权利人所有；源码许可不授予任何内容权利。';

  @override
  String get wenkuNoWithdrawn => '不运营在线书库、不发布小说、不打包小说文件，也不提供因版权原因下架的内容。';

  @override
  String get wenkuNoCircumvention =>
      '仅访问你有权使用的公开内容并遵守来源网站规则；不绕过访问限制、不破坏 DRM，不复制、分发或售卖内容。';

  @override
  String get wenkuThirdParty => '第三方服务可能变更、限制请求频率或暂时不可用；列表与内容可用性以 Wenku8 为准。';

  @override
  String get wenkuNoCredentials =>
      '反馈与问题报告里请勿包含密码、Cookie 或 Token；生成预览时会自动移除常见凭据字段。';

  @override
  String get wenkuSourceNote =>
      '唯一的在线来源。只读取列表与目录元数据，章节正文由 Wenku8 在使用时提供；本应用不缓存、不打包。';

  @override
  String get wenkuLocalSourceNote => '书籍文件由你自己导入，支持本地书库的全部格式与目录授权方式。';

  @override
  String get wenkuCustomSourceNote => '自定义书源不提供；来源列表固定为 Wenku8 与本地导入两项。';

  @override
  String get wenkuShelfTabLocal => '本地书库';

  @override
  String get wenkuShelfTabCloud => '云端来源';

  @override
  String get wenkuCloudTitle => '云端来源';

  @override
  String get wenkuCloudSubtitle => '选一个来源，看看有什么可读';

  @override
  String get wenkuSourceNavTitle => '来源';

  @override
  String get wenkuFeedTitle => '目录';

  @override
  String get wenkuSearchHint => '搜索书名 / 作者';

  @override
  String get wenkuStatusNote => '只读取列表与目录元数据；下架内容不展示，章节正文不在本应用内缓存。';

  @override
  String get wenkuLockedTitle => '在线目录尚未开启';

  @override
  String get wenkuLockedBody =>
      '纯本地模式下全应用零网络请求，连演示目录也不会读取。开启后可浏览 Wenku8 列表、详情与章节目录，并把书加入本地书库。';

  @override
  String get wenkuUnlockButton => '开启在线目录';

  @override
  String get wenkuBookAdd => '加入本地书库';

  @override
  String get wenkuBookAdded => '已在本地书库';

  @override
  String get wenkuDetailTitle => '书籍详情';

  @override
  String get wenkuDetailSynopsis => '简介';

  @override
  String get wenkuDetailToc => '卷与章节目录';

  @override
  String get wenkuDetailChapterNote => '章节正文由 Wenku8 在使用时提供。';

  @override
  String get wenkuDetailStaticNote =>
      '静态阶段只登记元数据壳，不下载、不缓存、不打包小说正文；加入本地后可像其它本地书一样管理。';

  @override
  String get wenkuEmptyTitle => '这个目录暂时没有书';

  @override
  String get wenkuEmptyBody => '换个榜单或搜索别的书名试试；第三方目录也可能暂时不可用。';

  @override
  String get wenkuRefresh => '刷新目录';

  @override
  String get wenkuAddedNote => '已加入本地书库，切回「本地书库」即可看到。';

  @override
  String get feedbackTitle => '问题反馈';

  @override
  String get feedbackSubtitle => '带上四要素，问题更容易被定位';

  @override
  String get feedbackPreviewTitle => '问题反馈 · 纯文本预览';

  @override
  String get feedbackMissing => '还需填写：';

  @override
  String get feedbackStaticNote => '只生成纯文本供复制，不上传、不打开 Issue 页面、不写文件。请自行检查后再提交。';

  @override
  String get supportTitle => '全功能免费';

  @override
  String get supportBody => '所有功能免费，不售卖会员、激活码或功能解锁；支持完全自愿。请警惕以本项目或开发者名义收费的行为。';

  @override
  String get profileHeroTitle => '我  的';

  @override
  String get profileHeroSubtitle => '把阅读调成自己喜欢的样子';

  @override
  String get profileSectionAppearance => '外观与阅读';

  @override
  String get profileSectionSources => '来源与在线';

  @override
  String get profileSectionLibrary => '书库与导入';

  @override
  String get profileSectionFavorites => '我的收藏';

  @override
  String get profileSectionSupport => '支持与反馈';

  @override
  String get profileSectionAbout => '关于';

  @override
  String get cloudChannelsTitle => '云端导入渠道';

  @override
  String get cloudChannelsNote =>
      'OpenList、WebDAV、夸克网盘（实验性）与系统文档选择器（OneDrive / Google Drive 等）。渠道只是入口选择，不内置账号与凭据；真实授权与文件读取在静态阶段冻结。';

  @override
  String get mergeRecordsNote =>
      '手动合并与同步原书、阅读记录的策略已在导入向导中登记；静态阶段只记为待办决策，不改写演示书库。';

  @override
  String get wenkuFormatsNote =>
      '格式已对齐参考仓库：TXT / EPUB / MOBI / AZW / AZW3 / PRC / FB2 / PDF / DOC / DOCX / RTF / HTML / Markdown / ZIP。老式二进制格式静态阶段只登记路由，真实解码器冻结。';

  @override
  String get unlockModeTitle => '静态模式已解锁';

  @override
  String get unlockModeBody =>
      'Wenku8 接入链路已切换为真实 HTTP 数据源；纯本地模式仍是默认，锁定态全应用零请求。';

  @override
  String get wenkuRealSourceNote => '真实数据源与演示源共用同一契约；接 SDK 后按同一注入口替换，页面与合规层不改。';

  @override
  String get wenkuEndpointNote => 'URL 只在站点适配层构造；公开资料未给出官方页面结构文档，路径模板需按实际站点核对。';

  @override
  String get wenkuChallengeNote => '来源要求访问验证；请到 Wenku8 官网完成后再试，本应用不绕过验证。';

  @override
  String get wenkuWithdrawnNote => '因版权原因不可读的内容不展示、不缓存、不提供访问。';

  @override
  String get wenkuRateLimitNote => '来源已限流；请稍后再试，不要反复刷新，避免给来源带去额外压力。';

  @override
  String get wenkuUnavailableNote => '第三方服务可能变更、限流或暂时不可用，请稍后再试。';

  @override
  String get wenkuUpstreamChangedNote => '来源页面结构已变化，需按实际公开页面更新解析规则，不把乱码当内容。';

  @override
  String get wenkuNoRelayNote =>
      '不实现中继、代理、Cookie、登录、伪造 appver 或伪装浏览器 UA；不绕过访问限制。';

  @override
  String get wenkuChapterNote => '只读取你点开的单章，不整本下载、不打包、不缓存分发。';

  @override
  String get wenkuLocalVerifyNote =>
      '本地验证：flutter pub get → flutter analyze → flutter test → flutter run；先确认站点可达与页面结构。';

  @override
  String get wenkuSdkAbsentNote =>
      '当前交付环境未安装 Flutter/Dart SDK；本轮交付可编译源码与规格，编译和真机验证需在你的开发环境执行。';

  @override
  String get wenkuPlatformPermissionNote =>
      'Android INTERNET / iOS ATS / 鸿蒙 INTERNET 权限骨架已落盘，需按各平台工程模板核对。';

  @override
  String get wenkuLoginTitle => '登录 Wenku8';

  @override
  String get wenkuLoginUsername => '用户名';

  @override
  String get wenkuLoginPassword => '密码';

  @override
  String get wenkuLoginAction => '登录';

  @override
  String get wenkuLogoutAction => '退出登录';

  @override
  String get wenkuLoginCredentialNote =>
      '凭据仅保存在本次运行的内存中，不写入磁盘、不进入日志与反馈；退出或关闭应用后立即失效。';

  @override
  String get wenkuLoginLoggedOut => '尚未登录，可继续浏览公开目录；登录后才能读取个人书架。';

  @override
  String get wenkuLoginFailed => '登录未完成，请确认账号与来源站点状态；页面异常不会被当作密码错误。';

  @override
  String get wenkuLoginSessionExpired => '登录态已失效，请重新登录。';

  @override
  String get wenkuLoginHostNote =>
      '来源域名可在 wenku8.net 与 wenku8.com 之间切换；两者均为来源站点，本应用不提供其它书源。';

  @override
  String get wenkuSourceClosedNote =>
      '来源页面返回站点关闭或公告内容，没有可用的登录表单；本应用不会向该页面提交账号密码。';

  @override
  String get wenkuEndpointsPendingNote =>
      '登录 / 书架 / 搜索 / 榜单 / 详情 / 章节路径按提供的页面清单配置，尚未经过页面解析验证，需在真机上按实际站点核对。';

  @override
  String get wenkuLoginNoSession => '当前为离线演示数据源，没有登录会话；切换到真实来源后可登录。';

  @override
  String get uiLocalReader => '本地阅读';

  @override
  String get uiShelf => '书架';

  @override
  String get uiLightNovels => '轻小说文库';

  @override
  String get uiStats => '统计';

  @override
  String get uiProfile => '我的';

  @override
  String get uiGotIt => '知道了';

  @override
  String get uiAppLanguage => '应用语言';

  @override
  String get uiFollowSystem => '跟随系统';

  @override
  String get uiPhrase008 => '简体中文';

  @override
  String get uiEnglish => 'English';

  @override
  String get uiWhenFollowingTheSystemFlutterResolvesTheLocale =>
      '跟随系统时按官方 supportedLocales 解析；未支持的语言回退简体中文。';

  @override
  String uiMapLocaleLegaltextbundleLanguages(String p0) {
    return 'Map<Locale, LegalTextBundle> · $p0 种语言';
  }

  @override
  String uiKeysLists(String p0, String p1) {
    return ' · $p0 键 + $p1 列表';
  }

  @override
  String uiCoverageCheck(String p0) {
    return '覆盖度校验 · $p0';
  }

  @override
  String uiItems(String p0, String p1) {
    return '缺项 $p0 · 多余键 $p1';
  }

  @override
  String uiChapters(String p0) {
    return '$p0 章';
  }

  @override
  String get uiRemoveFavorite => '取消收藏';

  @override
  String get uiFavoriteThisBook => '收藏这本书';

  @override
  String get uiAddedToFavorites => '已加入收藏';

  @override
  String get uiRemovedFromFavorites => '已取消收藏';

  @override
  String get uiEditBookInfo => '编辑书籍信息';

  @override
  String get uiTableOfContents => '章节目录';

  @override
  String get uiContinueReading => '继续阅读';

  @override
  String get uiStartReading => '开始阅读';

  @override
  String get uiNoVolume => '未分卷';

  @override
  String uiVolume(String p0) {
    return '第 $p0 卷';
  }

  @override
  String uiLocalLibrary(String p0) {
    return '本地书库 · $p0';
  }

  @override
  String get uiReadingProgress => '阅读进度';

  @override
  String uiChaptersSampleData(String p0) {
    return '上次读到约第 $p0 章 · 演示数据';
  }

  @override
  String get uiNotStartedYet => '尚未开始阅读';

  @override
  String get uiContents => '目录';

  @override
  String uiTotalChapters(String p0) {
    return '共 $p0 章';
  }

  @override
  String get uiViewAll => '查看全部';

  @override
  String get uiLastRead => '上次读到';

  @override
  String uiItems2(String p0) {
    return '$p0 条';
  }

  @override
  String get uiBookInfo => '书籍信息';

  @override
  String get uiSource => '来源';

  @override
  String get uiImportedLocally => '用户本地导入';

  @override
  String get uiFormat => '格式';

  @override
  String get uiChapters2 => '章节';

  @override
  String get uiEpisodes => '话集';

  @override
  String uiEpisodesPages(String p0, String p1) {
    return '$p0 话 · 共 $p1 页';
  }

  @override
  String get uiAuthorization => '授权';

  @override
  String get uiSystemFilePickerDirectoryAuthorization => '系统文件选择器目录授权';

  @override
  String get uiScope => '文档类书籍不在媒体库覆盖范围内，需走系统文件选择器或「所有文件访问」。';

  @override
  String get uiAboutContent => '关于内容';

  @override
  String get uiTitle => '书名';

  @override
  String get uiAuthor => '作者';

  @override
  String get uiCoverColor => '封面色';

  @override
  String get uiVolumeOrder => '卷序';

  @override
  String uiVolume2(String p0) {
    return '第 $p0 卷';
  }

  @override
  String get uiStaticDemoSaveSampleData => '静态演示：修改仅保存在内存，重启后恢复演示数据。';

  @override
  String get uiCancel => '取消';

  @override
  String get uiSave => '保存';

  @override
  String get uiTitleCannotBeEmpty => '书名不能为空';

  @override
  String uiContents2(String p0) {
    return '$p0 · 目录';
  }

  @override
  String get uiSearchChapterTitles => '搜索章节名';

  @override
  String uiTotalChapters2(String p0) {
    return '共 $p0 章';
  }

  @override
  String get uiTapAChapterToJump => '点选章节跳转';

  @override
  String get uiNoMatchingChapters => '没有匹配的章节';

  @override
  String get uiContentsBodyTextBookdocumentChapters =>
      '目录与正文由同一份 BookDocument 生成，章节序号与阅读器严格一致。';

  @override
  String get uiCurrentSampleDataTocentryChapters =>
      '当前为演示数据；接入真实解析器后由 TocEntry 提供章节与锚点。';

  @override
  String uiItemscontentBodyText(String p0) {
    return '$p0 个内容块 · 演示正文';
  }

  @override
  String get uiCurrentlyReading => '当前阅读';

  @override
  String get uiEditExcerpt => '编辑摘录';

  @override
  String get uiHighlightColor => '划线颜色';

  @override
  String get uiNote => '批注';

  @override
  String get uiClearTheFieldToRemoveTheNote => '清空输入框即可移除批注';

  @override
  String get uiSaveChanges => '保存修改';

  @override
  String get uiExportPreview => '导出预览';

  @override
  String get uiExcerptLibrary => '摘录管理';

  @override
  String get uiExportCurrentResultsPlainTextPreview => '导出当前结果（纯文本预览）';

  @override
  String get uiTextTitleChapterNote => '正文 / 书名 / 章节 / 批注';

  @override
  String get uiAllBooks => '全部书';

  @override
  String uiTotalYours(String p0, String p1) {
    return '共 $p0 条 · 我摘的 $p1 条 · ';
  }

  @override
  String uiNoteItemsItems(String p0, String p1) {
    return '有批注 $p0 条 · 命中 $p1 条';
  }

  @override
  String get uiScope2 => '范围';

  @override
  String get uiByBook => '按书';

  @override
  String get uiHighlight => '划线色';

  @override
  String get uiAllColors => '全部色';

  @override
  String get uiSort => '排序';

  @override
  String get uiGroup => '分组';

  @override
  String get uiSelectedBook => '指定书籍';

  @override
  String uiDays(String p0) {
    return '当天 $p0';
  }

  @override
  String uiKeyword(String p0) {
    return '关键词「$p0」';
  }

  @override
  String get uiExcerptDeleted => '已删除这条摘录';

  @override
  String get uiItemsexcerpts => '这条摘录不可删除';

  @override
  String get uiYours => '我摘的';

  @override
  String get uiSampleReadOnly => '演示 · 只读';

  @override
  String get uiEditNoteHighlight => '编辑批注 / 划线色';

  @override
  String get uiDeleteExcerpt => '删除摘录';

  @override
  String get uiClearDateFilter => '清除日期筛选';

  @override
  String get uiAllBooks2 => '查看全部书';

  @override
  String get uiClearFilters => '清空筛选条件';

  @override
  String get uiReviewBeforeImporting => '导入前先看一眼';

  @override
  String get uiSupportedFormats => '支持格式';

  @override
  String get uiArchives => '压缩包';

  @override
  String get uiPermissions => '权限';

  @override
  String get uiImportChannels => '导入渠道';

  @override
  String get uiOnline => '联网';

  @override
  String get uiChooseAnAuthorizationMethod => '选择授权方式';

  @override
  String get uiAuthorizationConfirmed => '已确认授权';

  @override
  String get uiSimulateAuthorization => '模拟确认授权';

  @override
  String get uiAuthorizationStaticDemo => '授权会持久化，重启后可一键重扫（静态演示）';

  @override
  String get uiScanResults => '扫描结果';

  @override
  String get uiScanned => '共扫描';

  @override
  String get uiImportable => '可导入';

  @override
  String get uiUnsupported => '不支持';

  @override
  String get uiUnregistered => '未登记';

  @override
  String get uiNameConflict => '同名冲突';

  @override
  String get uiNoNameConflicts => '没有同名冲突';

  @override
  String get uiResolveDuplicateNames => '处理同名书籍';

  @override
  String uiAll(String p0) {
    return '全部$p0';
  }

  @override
  String uiDuplicateOf(String p0, String p1) {
    return '与书库《$p0》同名 · $p1';
  }

  @override
  String get uiImportSummary => '导入摘要';

  @override
  String get uiScannedFiles => '扫描文件';

  @override
  String uiItems3(String p0) {
    return '$p0 个';
  }

  @override
  String get uiToBeAdded => '将写入书架';

  @override
  String uiBooks(String p0) {
    return '$p0 册';
  }

  @override
  String get uiSkippedUnsupported => '跳过 / 不支持';

  @override
  String uiItems4(String p0) {
    return '$p0 个';
  }

  @override
  String uiItems5(String p0) {
    return '$p0 项';
  }

  @override
  String get uiDeferred => '延后处理';

  @override
  String uiItems6(String p0) {
    return '$p0 项';
  }

  @override
  String get uiToBeAdded2 => '将新增';

  @override
  String get uiBack => '上一步';

  @override
  String get uiWriteToShelfAndClose => '写回书架并关闭';

  @override
  String get uiNext => '下一步';

  @override
  String get uiReadingFonts => '阅读与字体';

  @override
  String get uiMotionReadAloud => '动效与朗读';

  @override
  String get uiStatsReports => '统计与报告';

  @override
  String get uiShelfImport => '书架与导入';

  @override
  String get uiBuildCompliance => '工程与合规';

  @override
  String get uiFeatureOverview => '功能总览';

  @override
  String get uiReferenceRepoFeatureAlignment => '参考仓库功能对齐 · 第二十四轮';

  @override
  String get uiAllGlobalDefaultStaticStageSaveChars =>
      '以下偏好全部挂在全局状态，按书设置与全局默认分开；静态阶段只保存选择，不下载字体、不发请求、不写文件。';

  @override
  String get uiPerBookLayout => '按书保存排版';

  @override
  String get uiSaveCharsFontSizeCharsCharsLineHeightNullGloba =>
      '每本书可独立保存字体 / 字号 / 字重 / 字距 / 行高 / 四边距；null 表示沿用全局默认。';

  @override
  String get uiLibraryIsEmpty => '书库为空';

  @override
  String uiCurrentPt(String p0, String p1) {
    return '当前：$p0 · $p1 pt · ';
  }

  @override
  String uiLineHeight(String p0) {
    return '行高 $p0 · ';
  }

  @override
  String uiPhrase141(String p0) {
    return '$p0';
  }

  @override
  String get uiUseLargerTextForThisBook => '为这本书设大字';

  @override
  String get uiClearPerBookOverrides => '清除书级覆盖';

  @override
  String get uiFontCatalog => '字体目录';

  @override
  String get uiCharsRemoveCharsChars => '阅读字体按需下载、离线可用、可移除、不预装；应用字体与阅读器字体分开选。';

  @override
  String get uiImportFontSourceHanSans => '导入字体 · 思源黑体';

  @override
  String get uiRegisterImportedTtfOtf => '登记导入 TTF/OTF';

  @override
  String get uiMarkOnDemandPackInstalled => '标记按需包已装';

  @override
  String get uiStaticStageFontloaderBooksRemove =>
      '静态阶段只登记元数据；FontLoader 注册、下载与移除文件属平台层（❄️ 冻结）。';

  @override
  String get uiColorSource => '配色来源';

  @override
  String uiContrast1(String p0) {
    return '阅读器独立配色：对比度 $p0:1 · ';
  }

  @override
  String uiWcagAaBodyText45(String p0) {
    return '$p0 WCAG AA 正文 4.5';
  }

  @override
  String get uiAppFont => '应用字体';

  @override
  String get uiReadingFont => '阅读字体';

  @override
  String get uiRemoveCurrentFont => '移除当前字体';

  @override
  String get uiSystemDynamicColorMonet => '系统动态色（Monet）';

  @override
  String get uiCustomAccentColor => '自定义强调色';

  @override
  String get uiPickFromCover => '从封面取色';

  @override
  String get uiPageTurnAutoRead => '翻页与自动阅读';

  @override
  String uiPages(String p0) {
    return '翻页速度 ×$p0';
  }

  @override
  String get uiInterfaceMotion => '整体界面动效';

  @override
  String get uiOn => '开';

  @override
  String get uiOffLocksToNoAnimationAndStopsAutoRead => '关：自动锁为无动画并停下自动阅读';

  @override
  String get uiAutoRead => '自动阅读';

  @override
  String uiIntervalMsAutoStopsWhenMotionIsOff(String p0) {
    return '间隔 $p0 ms · 关动效时自动停';
  }

  @override
  String get uiContinuousChapterTransition => '连续章过渡';

  @override
  String get uiVolumeKeyPaging => '音量键翻页';

  @override
  String get uiBilingualReadAloudLanguages => '双语与朗读语言';

  @override
  String get uiReadAloudLanguagesItemsVoice =>
      '按书选显示语言；朗读语言分别选、每种语言一个 voice，没有匹配语音模型的语言直接跳过。';

  @override
  String uiReadAloud(String p0) {
    return '实际会朗读：$p0';
  }

  @override
  String uiPhrase171(String p0) {
    return '$p0';
  }

  @override
  String get uiStaticStageKeepsakes =>
      '静态阶段只维护偏好；真实语音模型枚举、音色下载与音量键事件属平台层（❄️ 冻结）。';

  @override
  String get uiFiveViews => '五种视图';

  @override
  String get uiPeriodPresetsCustomRange => '周期（预设 / 自定义范围）';

  @override
  String get uiEightReportLayouts => '八种报告布局';

  @override
  String uiChars(String p0) {
    return '实际呈现字段：$p0';
  }

  @override
  String uiPhrase177(String p0) {
    return '$p0';
  }

  @override
  String get uiTotalContent => '预览与导出共用同一份内容：';

  @override
  String get uiStaticStageChars => '静态阶段导出只生成字符串；写文件与系统分享属平台层（❄️ 冻结）。';

  @override
  String get uiToday => '今天';

  @override
  String get uiThisWeek => '本周';

  @override
  String get uiThisMonth => '本月';

  @override
  String get uiThisYear => '今年';

  @override
  String get uiAll2 => '全部';

  @override
  String get uiCustom => '自定义';

  @override
  String get uiShelfViewFilters => '书架视图与筛选';

  @override
  String get uiMergeLocalLibraryIntoShelf => '本地书库并入书架';

  @override
  String uiCurrentBooks(String p0, String p1) {
    return '当前筛选命中 $p0 / $p1 册；';
  }

  @override
  String get uiCarouselParametersLockBackToDefaultInListMode =>
      '列表模式下轮播参数自动锁回默认。';

  @override
  String get uiPreImportReviewSeriesVolumeMerge => '导入前审阅与同系列卷合并';

  @override
  String uiSource2(String p0) {
    return '三种来源：$p0；';
  }

  @override
  String uiPolicy(String p0) {
    return '策略：$p0。';
  }

  @override
  String uiCurrent(String p0) {
    return '当前：$p0 → ';
  }

  @override
  String uiPhrase194(String p0) {
    return '$p0 → ';
  }

  @override
  String uiItems7(String p0) {
    return '落到既有冲突策略 $p0 等四项之一。';
  }

  @override
  String get uiWebdavBackupOffByDefault => 'WebDAV 备份（默认关闭）';

  @override
  String uiContent(String p0) {
    return '备份内容：$p0。';
  }

  @override
  String get uiWhenOffEvenTestConnectionMakesNoRequest => '关闭态连「测试连接」都不发请求。';

  @override
  String get uiEnableBackup => '启用备份';

  @override
  String get uiStaticDemoNoNetworkRequestWasMade => '静态演示：未发出任何网络请求';

  @override
  String get uiStaticStageWebdavclient =>
      '静态阶段只演示状态机；WebDavClient、远端列表与导出落盘属平台层（❄️ 冻结）。';

  @override
  String get uiAndroidPermissionTiers => 'Android 权限分级';

  @override
  String uiRemove(String p0) {
    return '已移除：$p0';
  }

  @override
  String get uiCrashLoopProtection => '连续崩溃保护';

  @override
  String uiMinutes(String p0, String p1) {
    return '阈值 $p0 次 / $p1 分钟内 → ';
  }

  @override
  String uiSkipped(String p0, String p1) {
    return '进$p0；跳过：$p1。';
  }

  @override
  String get uiStaticDeliveryBoundary => '静态交付边界';

  @override
  String get uiAllDartCharsChars => '本轮新增能力全部为纯 Dart 模型 + 应用内配置：不下载字体、不读文件字节、';

  @override
  String get uiBooksBooksPages => '不发网络请求、不注册平台回调、不写相册。逐页接入多语言仍按用户指定预留到最后。';

  @override
  String get uiAppVersion => '应用版本';

  @override
  String get uiEG1001 => '例如 1.0.0+1';

  @override
  String get uiDevice => '设备';

  @override
  String get uiEGPixel8 => '例如 Pixel 8';

  @override
  String get uiOsVersion => '操作系统版本';

  @override
  String get uiEGAndroid15 => '例如 Android 15';

  @override
  String get uiStepsToReproduce => '复现步骤';

  @override
  String get uiAdditionalNotesOptional => '补充说明（可选）';

  @override
  String get uiOtherObservations => '其它观察';

  @override
  String get uiLocalBooks => '本地书';

  @override
  String get uiFavorites => '收藏';

  @override
  String get uiMinutesToday => '今日分钟';

  @override
  String get uiStreak => '连续';

  @override
  String get uiLibrary => '书库';

  @override
  String get uiPureLocalMode => '纯本地模式';

  @override
  String get uiWhenOnTheAppMakesNoNetworkRequests => '开启时全应用不产生任何网络请求';

  @override
  String get uiInterfaceMotion2 => '界面动效';

  @override
  String get uiPageTurnAnimationShelfParallaxGlassTransitions =>
      '翻页动画 / 书架视差 / 玻璃过渡';

  @override
  String get uiTtsReadAloud => 'TTS 朗读';

  @override
  String get uiSentenceQueueRatePitchAutoNextChapter => '分句队列 · 语速音调 · 读完自动下一章';

  @override
  String get uiReadingLayout => '阅读排版';

  @override
  String uiPtPages(String p0, String p1, String p2) {
    return '$p0 pt · $p1 · $p2翻页';
  }

  @override
  String uiContrast12(String p0) {
    return ' · 对比度 $p0:1';
  }

  @override
  String get uiPerBookLayoutFontsReportsBackupPermissions =>
      '按书排版 · 字体目录 · 报告布局 · 备份 · 权限与崩溃保护';

  @override
  String get uiFormLoginBookcaseSessionSourceDomain => '表单登录 · 个人书架 · 会话与来源域名';

  @override
  String get uiOnlineDirectoryWenku8 => '在线目录（Wenku8）';

  @override
  String get uiLockedByPureLocalMode => '纯本地模式下已锁定';

  @override
  String get uiListingsAndTocMetadataOnlyNoBundledNovels => '仅列表与目录元数据，不内置小说文件';

  @override
  String get uiWebdavBackup => 'WebDAV 备份';

  @override
  String get uiLibraryMetadataProgressGroupsSessions =>
      '书库元数据 / 进度 / 分组 / 阅读会话';

  @override
  String get uiPureLocalMode2 => '关闭纯本地模式后，在线开关才会解锁；关闭态全应用零网络请求。';

  @override
  String get uiFormatsAuthorizationScanConflicts => '格式说明 · 目录授权 · 扫描 · 冲突处理';

  @override
  String get uiImportFormats => '导入格式';

  @override
  String uiItems8(String p0) {
    return '$p0 条';
  }

  @override
  String get uiRemovedBook => '已移除的书';

  @override
  String uiTapToOpen(String p0) {
    return '$p0 · 点击跳转';
  }

  @override
  String get uiEpisodeList => '话集目录';

  @override
  String uiEpisodesPages2(String p0, String p1) {
    return '$p0 话 · $p1 页';
  }

  @override
  String uiRecognitionRate(String p0) {
    return '识别率 $p0% · ';
  }

  @override
  String uiUnrecognizedPagesEpisodes(String p0) {
    return '未识别的 $p0 页已归入「未分话」';
  }

  @override
  String get uiAllPagesAreGroupedIntoEpisodes => '全部页都已归入话集';

  @override
  String get uiCurrent2 => '当前';

  @override
  String get uiUnrecognized => '未识别';

  @override
  String uiPages2(String p0, String p1) {
    return '$p0 · $p1 页';
  }

  @override
  String get uiCaptureThisPassage => '摘录这一段';

  @override
  String uiLinesChars(String p0, String p1) {
    return '$p0 行 · $p1 字';
  }

  @override
  String get uiNoTextAvailableToCapture => '（没有可摘录的文字）';

  @override
  String get uiSpreads => ' · 跨段落';

  @override
  String get uiNoteOptional => '批注（可选）';

  @override
  String get uiWriteSomethingToAppendToTheExcerpt => '写点什么，会附在摘录后面';

  @override
  String get uiSpreadsLinesSentencesLines => '选区跨越了段落，换行处已直接拼接；如需分句可少选几行。';

  @override
  String get uiStatsPages => '这段已经摘过了，统计页里可以看到。';

  @override
  String get uiSaveExcerpt => '保存摘录';

  @override
  String uiPagesCurrent(String p0) {
    return '本页需要原生渲染能力，当前平台尚未接入。\n$p0';
  }

  @override
  String get uiDemoPlatform => '演示平台';

  @override
  String get uiCaptureSelectedLines => '摘录选中的正文行';

  @override
  String get uiReadAloudSentenceQueue => '朗读（分句队列）';

  @override
  String get uiLayoutSettings => '排版设置';

  @override
  String get uiPreviousChapter => '上一章';

  @override
  String uiChapter(String p0, String p1, String p2, String p3) {
    return '$p0 / $p1 · 第 $p2 / $p3 章';
  }

  @override
  String uiLinesSaveexcerpts(String p0) {
    return '已选 $p0 行 · 点顶栏书签保存摘录';
  }

  @override
  String get uiNextChapter => '下一章';

  @override
  String get uiIllustrationPlaceholder => '插图占位';

  @override
  String get uiPagesLinesexcerptsEpisodeListContents =>
      '漫画页暂不支持按行摘录，话集目录请用旁边「目录」按钮';

  @override
  String get uiSelectOneOrMoreLinesThenTapTheBookmarkToSaveAn =>
      '先点选正文中的一行或多行，再点书签保存摘录';

  @override
  String get uiStatsPages2 => '这段已经摘过了，统计页里可以看到';

  @override
  String get uiSavedToExcerptCardsSeeStats => '已保存到摘录卡 · 统计页可查看';

  @override
  String get uiFixedLayoutPage => '固定版式页';

  @override
  String get uiPdfEpubViaBookrenderbridge =>
      'PDF / 漫画 / 图片型 EPUB 走 BookRenderBridge：\n';

  @override
  String get uiRenderHandleIndexTargetsizePages4k =>
      '· render(handle, index, targetSize) 按目标像素出页，不做 4K 再缩\n';

  @override
  String get uiPagesTextureidTextureTextureid =>
      '· 连续翻页用 textureId + Texture(textureId:)\n';

  @override
  String get uiPagesImageMemory => '· 单页快照用编码位图 Image.memory\n';

  @override
  String get uiComicprefetchwindowPrefetchEvictSpreadsChannel =>
      '· ComicPrefetchWindow 批量 prefetch / evict，不在滚动回调里逐帧跨 channel';

  @override
  String uiSize(String p0, String p1) {
    return '目标尺寸：$p0 × $p1 逻辑像素';
  }

  @override
  String get uiTocNavigationIsNotWiredIntoThisPage => '当前页面未注入目录导航';

  @override
  String get uiComicsFixedLayoutsHaveNoReflowableTextReadAlou =>
      '漫画 / 固定版式没有可重排正文，朗读仅适用于小说';

  @override
  String uiSentencesSentences(String p0, String p1) {
    return '已暂停在第 $p0 / $p1 句；再次点击从该句续播';
  }

  @override
  String uiSentences(String p0, String p1, String p2, String p3) {
    return '$p0 · 从第 $p1 / $p2 句开始 · $p3×';
  }

  @override
  String get uiFinishedTheWholeBook => '已读完全书';

  @override
  String get uiResetToDefault => '恢复默认';

  @override
  String get uiBodyText => '正文';

  @override
  String get uiFontSize => '字号';

  @override
  String get uiLineHeight2 => '行高';

  @override
  String get uiFirstLineIndent => '首行缩进';

  @override
  String get uiParagraphSpacing => '段间距';

  @override
  String get uiReadingBackground => '阅读背景';

  @override
  String get uiBodyTextCharsCurrentcontrast => '正文与面板文字色由背景亮度自动反推 · 当前对比度 ';

  @override
  String uiWcagAaBodyText452(String p0) {
    return '$p0 : 1（WCAG AA 正文 ≥ 4.5）';
  }

  @override
  String get uiPageTurnMotion => '翻页与动效';

  @override
  String get uiChooseSlideSimulatedPageTurnWhenEnabled => '开启时可选择平移 / 仿真翻页';

  @override
  String get uiMotionIsOffSoPageTurnIsLockedToNone => '已整体关闭动效，翻页动效被锁定为「无动画」';

  @override
  String get uiNormalizationIsCentralizedInAppsettingsNormali =>
      '归一化规则集中在 AppSettings.normalized()：';

  @override
  String get uiTurningMotionOffLocksPageTurnToNonePagesNeverR =>
      '关闭界面动效会自动把翻页动效置为 none，页面不各自解释。';

  @override
  String get uiComicReading => '漫画阅读';

  @override
  String get uiReadAloud2 => '朗读';

  @override
  String get uiRate => '语速';

  @override
  String get uiPitch => '音调';

  @override
  String get uiSentenceQueueAutoNextChapter => '分句队列 · 读完自动进入下一章';

  @override
  String get uiReadingAidsPlatformCapability => '阅读辅助（需平台能力）';

  @override
  String get uiKeepScreenOn => '屏幕常亮';

  @override
  String get uiItems9 => '静态交付模式下，以上两项只记录偏好，需三端原生能力才能生效（❄️ 冻结）。';

  @override
  String get uiSaveSettingsstore =>
      '修改仅保存在内存，重启后恢复默认。接入持久化后由 SettingsStore 统一落库。';

  @override
  String get uiWeak => '弱';

  @override
  String get uiMedium => '中';

  @override
  String get uiStrong => '强';

  @override
  String get uiComics => '漫画';

  @override
  String uiSpread(String p0, String p1) {
    return '第 $p0 / $p1 跨 · ';
  }

  @override
  String uiPhrase317(String p0) {
    return '$p0';
  }

  @override
  String get uiSwitchToHorizontalPaging => '切换到横向翻页';

  @override
  String get uiSwitchToVerticalScroll => '切换到竖向连续';

  @override
  String uiSpreadsPages(String p0) {
    return '跨页模式：$p0';
  }

  @override
  String uiPages3(String p0) {
    return '翻页方向：$p0';
  }

  @override
  String uiPAspectRatioPlaceholder(String p0, String p1) {
    return 'P$p0 · 宽高比 $p1 占位';
  }

  @override
  String uiVolumes(String p0, String p1) {
    return '$p0 · $p1 卷';
  }

  @override
  String get uiSearchLocalLibrary => '搜索本地书库';

  @override
  String get uiTitleAuthorFormatGroup => '书名 / 作者 / 格式 / 分组';

  @override
  String uiAllBooks3(String p0) {
    return '全部 $p0 册';
  }

  @override
  String uiFoundBooks(String p0, String p1) {
    return '找到 $p0 册 · 「$p1」';
  }

  @override
  String uiBooks2(String p0) {
    return '$p0 册';
  }

  @override
  String uiVolumes2(String p0) {
    return ' · 第 $p0 卷';
  }

  @override
  String get uiHowImportingWorks => '了解如何导入';

  @override
  String get uiClearKeyword => '清空关键词';

  @override
  String get uiShelf2 => '书  架';

  @override
  String get uiKeepWhatYouWantToReadWithinReach => '把想读的，放在伸手可及的地方';

  @override
  String uiTotalBooksBooks(String p0, String p1) {
    return '—  共 $p0 册 · 收藏 $p1 册 · ';
  }

  @override
  String uiItemsgroupVolumeOrder(String p0) {
    return '$p0 个分组 · 按卷序';
  }

  @override
  String get uiSearchTitleAuthor => '搜索书名 / 作者';

  @override
  String get uiViewAllResults => '查看全部结果';

  @override
  String uiBooks3(String p0) {
    return '只看已收藏的 $p0 册';
  }

  @override
  String get uiTapTheStarOnTheDetailOrReaderPageToFavorite =>
      '点星标可在详情页 / 阅读器收藏';

  @override
  String get uiSearchNavigationIsNotWiredIntoThisPage => '当前页面未注入搜索页导航';

  @override
  String get uiDetailNavigationIsNotWiredIntoThisPage => '当前页面未注入详情导航';

  @override
  String get uiImportEntryIsNotWiredIntoThisPage => '当前页面未注入导入入口';

  @override
  String get uiVisualStyle => '视觉样式';

  @override
  String uiTotalBooksVolumeOrder(String p0) {
    return '共 $p0 册 · 按卷序';
  }

  @override
  String uiVolume3(String p0) {
    return '第 $p0 卷';
  }

  @override
  String get uiViewAllBooks => '查看全部书籍';

  @override
  String get uiPreviousMonth => '上一月';

  @override
  String get uiNextMonth => '下一月';

  @override
  String get uiThisMonth2 => '本月阅读';

  @override
  String get uiReadingDays => '阅读天数';

  @override
  String uiDays2(String p0) {
    return '$p0 天';
  }

  @override
  String get uiKeepsakes => '纪念物';

  @override
  String uiKeepsakes2(String p0) {
    return '$p0 枚';
  }

  @override
  String get uiExcerpts => '摘录';

  @override
  String uiItems10(String p0) {
    return '$p0 条';
  }

  @override
  String get uiLow => '少';

  @override
  String get uiHigh => '多';

  @override
  String get uiAdjacentMonthCells => '跨月补格';

  @override
  String get uiKeepsakesThatDay => '当天的纪念物';

  @override
  String get uiExcerptsThatDay => '当天摘下的话';

  @override
  String get uiPreviousKeepsake => '上一枚纪念物';

  @override
  String get uiNextKeepsake => '换一枚纪念物';

  @override
  String get uiYours2 => '你摘的';

  @override
  String get uiTitleNoteTypeBook => '标题 / 说明 / 类型 / 书名';

  @override
  String get uiType => '类型';

  @override
  String get uiMonth => '月份';

  @override
  String uiTotalKeepsakesItems(String p0, String p1) {
    return '共 $p0 枚 · $p1 个月 · ';
  }

  @override
  String uiKeepsakesKeepsakes(String p0, String p1) {
    return '来自你摘的 $p0 枚 · 命中 $p1 枚';
  }

  @override
  String uiKeepsakes3(String p0, String p1) {
    return '$p0 · $p1 枚';
  }

  @override
  String get uiReadingStats => '阅读统计';

  @override
  String get uiWidgets => '小组件';

  @override
  String get uiTurnReadingTimeIntoPagesYouCanFlipBackThrough => '把时间读成可以翻回去的页';

  @override
  String uiGoalminutesMinutes(String p0) {
    return '今日阅读 · 目标 $p0.goalMinutes 分钟';
  }

  @override
  String get uiMinutes2 => '分钟';

  @override
  String uiDaysThisWeek(String p0, String p1) {
    return '连续 $p0 天 · 本周 $p1 · ';
  }

  @override
  String uiBooksExcerptsItems(String p0, String p1) {
    return '书库 $p0 册 · 摘录 $p1 条';
  }

  @override
  String uiContinueReading2(String p0) {
    return '继续阅读《$p0》';
  }

  @override
  String get uiReadingHeatmap => '阅读热力';

  @override
  String uiDays3(String p0) {
    return '近 5 周 · $p0 天';
  }

  @override
  String get uiReadingCalendar => '阅读日历';

  @override
  String get uiExcerpts2 => '摘  录';

  @override
  String uiTotalItemsItems(String p0, String p1) {
    return '共 $p0 条 · 你摘的 $p1 条';
  }

  @override
  String get uiManage => '管理';

  @override
  String get uiNoExcerptsYetSelectAFewLinesInTheReaderToStart =>
      '还没有摘录，去阅读器点选几行正文吧。';

  @override
  String get uiSampleData => '演示数据';

  @override
  String get uiPrevious => '上一条';

  @override
  String get uiNextExcerpt => '换一条摘录';

  @override
  String get uiDeleteThisExcerpt => '删除这条摘录';

  @override
  String uiItemswidgets(String p0) {
    return '已配置 $p0 个小组件';
  }

  @override
  String uiMinutes3(String p0, String p1) {
    return '$p0 · $p1 分钟';
  }

  @override
  String get uiWidgets2 => '小组件配置';

  @override
  String uiTotalItemsItemsItems(String p0) {
    return '共 $p0 个 · 可同时放置多个 · 每个独立配置';
  }

  @override
  String get uiDarkPreview => '深色预览';

  @override
  String get uiLightPreview => '浅色预览';

  @override
  String get uiAddAWidget => '添加一个小组件';

  @override
  String get uiAboutDesktopWidgets => '关于桌面小组件';

  @override
  String get uiSaveWidgetsFlutter => '本面板只保存应用内配置与预览。桌面小组件本体不是 Flutter 能绘制的：';

  @override
  String get uiAndroidUsesInAppConfigIosUsesWidgetkitEditCont =>
      'Android 用应用内配置，iOS 用 WidgetKit 系统编辑控件，HarmonyOS 用卡片配置，';

  @override
  String get uiAllThreePlatformsNeedNativeImplementationsRead =>
      '三端均需原生实现并读取这里序列化后的数据。';

  @override
  String get uiShowProgress => ' · 显示进度';

  @override
  String get uiContent2 => '内容';

  @override
  String get uiKeepsakeTypePerWidget => '纪念物类型（每个小组件独立）';

  @override
  String get uiSize2 => '尺寸';

  @override
  String get uiSeasonStyleIndependentOfAppTheme => '季节样式（独立于应用换肤）';

  @override
  String get uiShowProgress2 => '显示进度';

  @override
  String get uiRemove2 => '移除';

  @override
  String get uiThisMonthKeepsakePreview => '本月纪念物预览';

  @override
  String get uiOnlineDirectoryIsOffNoRequestWasMade => '在线目录未开启，未发出任何请求。';

  @override
  String uiItemsShelfBooks(String p0, String p1) {
    return '个人书架：$p0 册 · $p1';
  }

  @override
  String get uiSourceDomain => '来源域名';

  @override
  String get uiPleaseWait => '请稍候…';

  @override
  String get uiReadPersonalBookcase => '读取个人书架';

  @override
  String get uiWorking => '正在处理…';

  @override
  String get uiSignedInLaterRequestsCarryTheSessionCookieIssu =>
      '已登录；后续请求会携带来源下发的会话 Cookie。';

  @override
  String get uiOnlineDirectoryAndLocalLibraryStayIndependent =>
      '在线目录与本地书库，各自独立';

  @override
  String get uiEnableOnlineDirectoryWenku8 => '启用在线目录（Wenku8）';

  @override
  String get uiPureLocalModeIsOnTheAppMakesNoNetworkRequests =>
      '当前为纯本地模式，全应用不产生任何网络请求。';

  @override
  String get uiTurnOffPureLocalModeOnTheProfilePageFirst =>
      '如需开启，请先在「我的」页关闭纯本地模式。';

  @override
  String get uiWhenOffTheAppStaysFullyLocalAndMakesNoNetworkR =>
      '关闭时本应用保持纯本地运行，不产生任何网络请求。';

  @override
  String get uiWhenOnOnlyWenku8ListingsAndTocMetadataAreRead =>
      '开启后仅访问 Wenku8 的在线列表与目录元数据。';

  @override
  String get uiItemsShelfSource => '表单登录 · 个人书架 · 来源域名切换';

  @override
  String get uiImportIntoLocalLibrary => '导入到本地方库';

  @override
  String get uiTxtEpubCbzPdfImageFolders => 'TXT / EPUB / CBZ / PDF / 图片文件夹';

  @override
  String get uiSampleWorkTocPreview => '示例作品 · 目录预览';

  @override
  String get uiSampleData2 => '示意数据';

  @override
  String get uiSampleWorkVolumeList => '示例作品 · 卷列表';

  @override
  String get uiSampleWorkDetail => '示例作品 · 详情';

  @override
  String get uiMetadata => '元数据';

  @override
  String get uiAboutContentAndSources => '关于内容与来源';

  @override
  String get uiBookOverride => '书级覆盖';

  @override
  String get uiGlobalDefault => '全局默认';

  @override
  String get uiMeetsMinimum => '达到';

  @override
  String get uiBelowMinimum => '未达到';

  @override
  String get uiNoVoiceSkipped => '（无可用语音，已跳过）';

  @override
  String get uiNoDataOmitted => '（无数据，全部省略）';

  @override
  String get uiAligned => '（中英对齐）';

  @override
  String get uiMisaligned => '（未对齐）';

  @override
  String get uiEnabled => '已开启';

  @override
  String get uiDisabled => '未开启';

  @override
  String get uiLightInnerHighlight => '浅色内高光';

  @override
  String get uiBlackShadow => '黑色阴影';

  @override
  String get uiSpecialEpisode => '番外';

  @override
  String get uiSpine => '书脊';

  @override
  String get uiWideSolo => '宽幅独占';

  @override
  String uiPhrase000(String p0) {
    return '多：$p0';
  }

  @override
  String uiPhrase001(String p0) {
    return '缺：$p0';
  }

  @override
  String uiSampleDataN1(String p0) {
    return '$p0 · 示意数据';
  }

  @override
  String uiPhrase003(String p0) {
    return '$p0';
  }

  @override
  String uiCurrentContents(String p0) {
    return '$p0 · 当前在线目录：';
  }

  @override
  String uiPhrase005(String p0, String p1) {
    return '$p0\n关键词：「$p1」';
  }

  @override
  String uiCurrentN1(String p0, String p1) {
    return '$p0\n当前关键词：「$p1」';
  }

  @override
  String uiPhrase007(String p0) {
    return '$p0';
  }

  @override
  String uiAboutParagraphsItems(String p0) {
    return ' · 关于段落 $p0 条';
  }

  @override
  String uiShade(String p0, String p1) {
    return '渐暗 $p0 · $p1';
  }

  @override
  String uiPhrase010(String p0) {
    return '$p0';
  }

  @override
  String uiPhrase011(String p0) {
    return '$p0';
  }

  @override
  String uiPhrase012(String p0) {
    return '$p0';
  }

  @override
  String uiPhrase013(String p0) {
    return '$p0';
  }

  @override
  String uiKeepsakesN1(String p0, String p1) {
    return '$p0 枚$p1';
  }

  @override
  String uiDaysTotalPages(String p0, String p1) {
    return '近 7 天 · 共 $p0 页 · $p1';
  }

  @override
  String uiItemsN1(String p0, String p1, String p2) {
    return '$p0 · 《$p1》 · $p2 条';
  }

  @override
  String uiPhrase017(String p0) {
    return '$p0';
  }

  @override
  String uiChaptersN1(String p0, String p1) {
    return '$p0 章 · $p1';
  }

  @override
  String uiBooksN1(String p0, String p1) {
    return '已写入 $p0 册$p1';
  }

  @override
  String uiVolumesChapters(String p0, String p1, String p2) {
    return '$p0 · $p1 卷 / $p2 章';
  }

  @override
  String uiPhrase021(String p0) {
    return '$p0';
  }

  @override
  String uiExcerptCaptureSource(String p0, String p1, String p2) {
    return '《$p0》· $p1$p2';
  }

  @override
  String uiBookMetaLine(String p0, String p1, String p2) {
    return '$p0 · $p1$p2';
  }

  @override
  String uiWidgetSpecLine(String p0, String p1, String p2, String p3) {
    return '$p0 · $p1$p2$p3';
  }

  @override
  String uiVolumeN(String p0) {
    return '第 $p0 卷';
  }

  @override
  String uiVolumePrefixN(String p0) {
    return ' · 第 $p0 卷';
  }

  @override
  String uiDeferredN(String p0) {
    return ' · $p0 项延后处理';
  }

  @override
  String get uiSpecialEpisodePrefix => ' · 番外';

  @override
  String uiWideSoloN(String p0) {
    return ' · 宽幅独占 $p0 跨';
  }

  @override
  String uiSpineN(String p0) {
    return ' · 书脊 $p0 跨';
  }

  @override
  String get uiSimplifiedChinese => '简体中文';

  @override
  String get uiArbSourceNote =>
      '文案源：lib/l10n/app_zh.arb 与 app_en.arb；改文案只改这两份，再跑 tool/sync_arb.py。';

  @override
  String uiArbStats(String p0, String p1, String p2) {
    return '$p0 键 · $p1 模板 · $p2 待润色';
  }
}
