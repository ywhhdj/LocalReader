import '../comic/comic_toc.dart';
import '../models/book_document.dart';
import 'book_repository.dart';

/// 演示文档工厂：详情页、章节目录、阅读器共用**同一份**章节数据。
///
/// 之前阅读器在自己文件里造单章文档，目录页若另造一份就会出现
/// 「目录显示 6 章、阅读器只有 1 章」的错位。静态阶段把数据单一化，
/// 未来接真实解析器时只需替换本工厂，三处页面零改动。
class DemoDocumentFactory {
  const DemoDocumentFactory._();

  static const List<String> chapterTitles = <String>[
    '第一章  纸白',
    '第二章  斜光',
    '第三章  摘录卡',
    '第四章  未寄出的信',
    '第五章  雨后的目录',
    '第六章  冬寂之前',
    '番外  书架背面',
  ];

  static const List<String> _openings = <String>[
    '把想读的，放在伸手可及的地方。书架上的书脊被斜斜的光切出一道浅边。',
    '她把摘录卡夹进那一页，纸白微微发黄，像放久了的信。',
    '窗外的雨停得很轻，屋里只剩下一小片安静。',
    '目录翻到最后一页时，才发现有些名字从来没有被写上去。',
    '钟摆在隔壁响了六下，纸上的字却没有跟着往前走。',
    '雪落下来的时候，图书馆把灯一盏一盏熄了。',
    '书架背面贴着一张旧便签，字迹淡得几乎要看不见。',
  ];

  static const String _quote = '「书页翻过去的时候，屋里只剩下一小片安静。」';

  static String _longParagraph(String seed) => List<String>.generate(
        12,
        (int i) => '$seed窗外的光慢慢挪过桌角，像谁把一句话说了一半又收了回去。',
      ).join('');

  static BookDocument from(BookSummary book) {
    // 漫画走分话目录 + 原生栅格化占位；与小说共用同一份工厂，
    // 详情页 / 目录页 / 阅读器不会各造一份文档。
    if (book.isComic) return DemoComicFactory.document(book);
    return BookDocument(
      id: 'demo_${book.id}',
      title: book.title,
      author: book.author,
      sourcePath: '/local/import/${book.id}.txt',
      sourceFormat: SourceFormat.txt,
      encoding: 'utf8',
      chapters: <Chapter>[
        for (int i = 0; i < chapterTitles.length; i++)
          _chapter(i, book.title),
      ],
      toc: <TocEntry>[
        for (int i = 0; i < chapterTitles.length; i++)
          TocEntry(label: chapterTitles[i], chapterIndex: i, blockIndex: 0),
      ],
    );
  }

  static Chapter _chapter(int index, String bookTitle) {
    final String title = chapterTitles[index];
    final String opening = _openings[index % _openings.length];
    return Chapter(
      id: 'c$index',
      title: title,
      ordinal: index,
      blocks: <ContentBlock>[
        ContentBlock(kind: BlockKind.heading, text: title, level: 1, keepWithNext: true),
        ContentBlock(kind: BlockKind.paragraph, text: '$opening（《$bookTitle》，演示正文）'),
        const ContentBlock(kind: BlockKind.paragraph, text: '这一段足够短，用来观察段落末尾是否会孤零零地落在下一页。'),
        ContentBlock(kind: BlockKind.paragraph, text: _longParagraph('第 ${index + 1} 章。')),
        const ContentBlock(kind: BlockKind.quote, text: _quote),
        const ContentBlock(kind: BlockKind.paragraph, text: '她没有把那句话说完，只是把书合上，留了一道很浅的折痕。'),
        if (index.isEven)
          ContentBlock(kind: BlockKind.paragraph, text: _longParagraph('续。')),
        if (index == chapterTitles.length - 1)
          const ContentBlock(kind: BlockKind.paragraph, text: '全书完。'),
      ],
    );
  }

  /// 由阅读进度估算续读章节。真实实现应读 PageAnchor 而不是按百分比猜。
  static int resumeChapter(BookSummary book) {
    final int last = chapterTitles.length - 1;
    return (book.progress * last).round().clamp(0, last).toInt();
  }
}

/// 漫画演示数据：故意混入中文数字话号、番外、以及两页没有话集信息的散页，
/// 用来验证「分话识别 + 识别率提示 + 未分话兜底」三条口径。
/// 静态阶段这些只是路径字符串，不解压、不解码任何图片。
class DemoComicFactory {
  const DemoComicFactory._();

  static const List<String> paths = <String>[
    '雨街漫画志/第1话/001.jpg',
    '雨街漫画志/第1话/002.jpg',
    '雨街漫画志/第1话/010.jpg',
    '雨街漫画志/第2话/001.jpg',
    '雨街漫画志/第2话/002.jpg',
    '雨街漫画志/第十话/001.jpg',
    '雨街漫画志/第十话/002.jpg',
    '雨街漫画志/番外  后日谈/001.jpg',
    '雨街漫画志/001.jpg',
    '雨街漫画志/002.jpg',
  ];

  static ComicToc toc() => ComicTocParser.fromPaths(paths);

  /// 确定性占位宽高比：真实实现读 PageInfo.aspectRatio（❄️ 冻结）。
  static List<double> aspectRatios(int count) => List<double>.unmodifiable(
        List<double>.generate(
          count,
          (int i) => 0.62 + (i % 5) * 0.045,
        ),
      );

  static BookDocument document(BookSummary book) {
    final ComicToc toc_ = toc();
    return BookDocument(
      id: 'demo_${book.id}',
      title: book.title,
      author: book.author,
      sourcePath: '/local/import/${book.id}.cbz',
      sourceFormat: SourceFormat.cbz,
      chapters: const <Chapter>[],
      requiresNativeRender: true,
      comicToc: toc_,
    );
  }
}
