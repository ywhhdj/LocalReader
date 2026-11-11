import 'package:flutter/foundation.dart';

import '../../../l10n/legal_texts.dart';
import 'wenku8_compliance.dart';

/// 「云端（云端来源）」导航栏的数据源注册表
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

  // 第二十八轮：note 走 LegalTexts getter（读 ARB），不能再是 const。
  static List<BookSource> get sources => <BookSource>[
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
  static bool canAddCustomSource() => Wenku8Compliance.customSourcesAllowed;
}
