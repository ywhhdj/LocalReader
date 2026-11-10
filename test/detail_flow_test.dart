import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/data/demo_document.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/state/book_overrides.dart';

/// 规格单测（静态交付模式下不运行）：锁定详情页 / 目录跳转共用的数据契约。
BookSummary sample({double progress = 0}) => BookSummary(
      id: 'b01',
      title: '雪国的旅行者',
      author: '川端 雪',
      spineColor: const Color(0xFF4A6180),
      shelf: '最近阅读',
      progress: progress,
    );

void main() {
  group('DemoDocumentFactory 单一数据源', () {
    test('章节数与 chapterTitles 一致', () {
      final doc = DemoDocumentFactory.from(sample());
      expect(doc.chapters.length, DemoDocumentFactory.chapterTitles.length);
    });

    test('目录条目与章节逐条对应', () {
      final doc = DemoDocumentFactory.from(sample());
      expect(doc.toc.length, doc.chapters.length);
      for (int i = 0; i < doc.toc.length; i++) {
        expect(doc.toc[i].chapterIndex, i);
        expect(doc.toc[i].label, doc.chapters[i].title);
      }
    });

    test('章节 ordinal 与序号一致，标题不重复', () {
      final doc = DemoDocumentFactory.from(sample());
      for (int i = 0; i < doc.chapters.length; i++) {
        expect(doc.chapters[i].ordinal, i);
      }
      expect(
          doc.chapters.map((c) => c.title).toSet().length, doc.chapters.length);
    });

    test('书名编辑后文档标题跟随，id 保持不变', () {
      final a = DemoDocumentFactory.from(sample());
      final b = DemoDocumentFactory.from(sample().copyWith(title: '新书名'));
      expect(a.id, b.id);
      expect(b.title, '新书名');
    });
  });

  group('续读章节估算', () {
    test('未读从第一章开始', () {
      expect(DemoDocumentFactory.resumeChapter(sample(progress: 0)), 0);
    });
    test('读完定位到最后一章', () {
      expect(
        DemoDocumentFactory.resumeChapter(sample(progress: 1)),
        DemoDocumentFactory.chapterTitles.length - 1,
      );
    });
    test('越界进度被夹住且不产生负数', () {
      expect(DemoDocumentFactory.resumeChapter(sample(progress: 2.5)),
          DemoDocumentFactory.chapterTitles.length - 1);
      expect(DemoDocumentFactory.resumeChapter(sample(progress: -1)), 0);
    });
  });

  group('BookSummary.copyWith', () {
    test('id 不变，仅覆盖给定字段', () {
      final a = sample(progress: 0.62);
      final b = a.copyWith(title: '改名', volumeOrder: 3);
      expect(b.id, a.id);
      expect(b.title, '改名');
      expect(b.volumeOrder, 3);
      expect(b.author, a.author);
      expect(b.progress, 0.62);
      expect(a.title, '雪国的旅行者', reason: '原对象不可变');
    });
  });

  group('BookOverride.merge', () {
    test('新值覆盖旧值，未提供的字段保留', () {
      const a = BookOverride(title: '甲', author: '乙', volumeOrder: 1);
      const b = BookOverride(title: '丙');
      final m = a.merge(b);
      expect(m.title, '丙');
      expect(m.author, '乙');
      expect(m.volumeOrder, 1);
    });
  });

  group('路由参数', () {
    test('ReaderArgs 默认从第一章开始', () {
      const args = ReaderArgs(
          book: BookSummary(
        id: 'x',
        title: 'x',
        author: 'x',
        spineColor: Color(0xFF000000),
        shelf: 's',
      ));
      expect(args.chapterIndex, 0);
    });
    test('TocArgs 携带当前章节', () {
      const args = TocArgs(
        book: BookSummary(
            id: 'x',
            title: 'x',
            author: 'x',
            spineColor: Color(0xFF000000),
            shelf: 's'),
        currentChapter: 4,
      );
      expect(args.currentChapter, 4);
    });
  });

  group('设置持久化归一化', () {
    test('InMemorySettingsStore 保存脏组合时自动清零联网项', () async {
      final store = InMemorySettingsStore();
      await store.save(const AppSettings(
          pureLocal: true, onlineDirectory: true, webdav: true));
      final loaded = await store.load();
      expect(loaded.onlineDirectory, isFalse);
      expect(loaded.webdav, isFalse);
      expect(loaded.networkingAllowed, isFalse);
    });
  });
}
