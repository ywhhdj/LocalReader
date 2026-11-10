import '../../domain/repositories/book_repository.dart';
import 'wenku/wenku8_registry.dart';

/// 书架范围：本地书库 / 云端来源。页面只认这个枚举，
/// 不在页面里散写第二份 `bool _isCloud` 真相。
enum LibraryScope { local, cloud }

/// 书架布局三档；布局是页面局部 UI 状态，不写回 AppSettings。
enum ShelfLayout { shelf3d, grid, list }

class ShelfCategory {
  const ShelfCategory({
    required this.id,
    this.labelKey,
    this.literalLabel,
  }) : assert(labelKey != null || literalLabel != null);

  final String id;

  /// 可翻译文案走 ARB 键；专有名词 / 演示分组名用 literalLabel。
  final String? labelKey;
  final String? literalLabel;
}

class ShelfCategories {
  const ShelfCategories._();

  static const String allId = '__all__';

  /// 本地：按自定义分组（演示书库的 shelfTitles），另加「全部分类」。
  /// 演示分组名属于演示数据，不是可翻译文案，按第二十八轮边界保留。
  static List<ShelfCategory> local(String allLabelKey) => <ShelfCategory>[
        ShelfCategory(id: allId, labelKey: allLabelKey),
        for (final String t in DemoBookRepository.shelfTitles)
          ShelfCategory(id: t, literalLabel: t),
      ];

  /// 云端：按 Wenku8 站点分类；id 只用于筛选，不拼进请求 URL。
  static const List<ShelfCategory> wenku8 = <ShelfCategory>[
    ShelfCategory(id: 'all', labelKey: 'uiAllCategories'),
    ShelfCategory(id: 'fantasy', labelKey: 'wenkuCatFantasy'),
    ShelfCategory(id: 'school', labelKey: 'wenkuCatSchool'),
    ShelfCategory(id: 'romance', labelKey: 'wenkuCatRomance'),
    ShelfCategory(id: 'scifi', labelKey: 'wenkuCatScifi'),
    ShelfCategory(id: 'mystery', labelKey: 'wenkuCatMystery'),
    ShelfCategory(id: 'daily', labelKey: 'wenkuCatDaily'),
    ShelfCategory(id: 'other', labelKey: 'wenkuCatOther'),
  ];

  static List<ShelfCategory> forScope(LibraryScope scope, String allLabelKey) =>
      scope == LibraryScope.cloud ? wenku8 : local(allLabelKey);

  /// 云端来源固定两条，不提供添加自定义书源（合规口径）。
  /// 来源是产品专有名词（Wenku8 / 本地导入），按边界保留原文。
  static List<ShelfCategory> cloudSources() => <ShelfCategory>[
        for (final BookSource s in Wenku8Registry.sources)
          ShelfCategory(id: s.id, literalLabel: s.title),
      ];
}
