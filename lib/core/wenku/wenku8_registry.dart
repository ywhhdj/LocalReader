import 'package:flutter/foundation.dart';

import '../content/legal_texts.dart';
import 'wenku8_compliance.dart';

/// 「云端（云端来源）」导航栏的数据源注册表（第二十二轮）。
///
/// 用户要求书架页有「本地 / 云端（云端来源）」导航；云端这一侧**只列来源，
/// 不列用户自己加的书源**。参考仓库 README 明确：仅 Wenku8 与本地导入，
/// 其它来源与自定义书源不再支持。所以这里固定两条、不提供 add / remove。
enum BookSourceKind { online, local }

@immutable
class BookSource {
  const BookSource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.note,
  });

  final String id;
  final String title;
  final String subtitle;
  final BookSourceKind kind;
  final String note;

  bool get isOnline => kind == BookSourceKind.online;
}

class Wenku8Registry {
  const Wenku8Registry._();

  static final List<BookSource> sources = <BookSource>[
    BookSource(
      id: Wenku8Compliance.wenku8SourceId,
      title: 'Wenku8',
      subtitle: '在线目录 · 列表与章节元数据',
      kind: BookSourceKind.online,
      note: LegalTexts.wenkuSourceNote,
    ),
    BookSource(
      id: Wenku8Compliance.localImportSourceId,
      title: '本地导入',
      subtitle: '用户自行导入的书籍文件',
      kind: BookSourceKind.local,
      note: LegalTexts.wenkuLocalSourceNote,
    ),
  ];

  static const int count = 2;

  static BookSource? byId(String id) {
    for (final BookSource s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 自定义书源在产品层面不提供；页面不会渲染「添加书源」按钮，
  /// 这里保留纯函数供规格单测与静态自检双重验证。
  static bool canAddCustomSource() => Wenku8Compliance.customSourcesAllowed;
}
