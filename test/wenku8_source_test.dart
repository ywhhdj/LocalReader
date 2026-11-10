import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/wenku/demo_wenku8_source.dart';
import 'package:local_reader/core/wenku/wenku8_models.dart';
import 'package:local_reader/core/wenku/wenku8_source.dart';

void main() {
  const DemoWenku8Source source = DemoWenku8Source();

  group('Wenku8Query 归一化', () {
    test('空关键词 + 普通榜单保持原样', () {
      expect(
        const Wenku8Query(feed: Wenku8FeedKind.ranking).normalized().feed,
        Wenku8FeedKind.ranking,
      );
    });

    test('有关键词强制切到 search，避免「排行榜 + 关键词」自相矛盾', () {
      final Wenku8Query q = const Wenku8Query(
        feed: Wenku8FeedKind.ranking,
        keyword: '  雪国  ',
      ).normalized();
      expect(q.feed, Wenku8FeedKind.search);
      expect(q.keyword, '雪国');
    });

    test('search 榜单但没关键词 → 回落推荐', () {
      expect(
        const Wenku8Query(feed: Wenku8FeedKind.search).normalized().feed,
        Wenku8FeedKind.recommendation,
      );
    });

    test('值语义', () {
      expect(const Wenku8Query(keyword: 'a'), const Wenku8Query(keyword: 'a'));
      expect(const Wenku8Query(keyword: 'a'),
          isNot(const Wenku8Query(keyword: 'b')));
    });
  });

  group('状态机标签', () {
    test('七种状态都有标题与说明', () {
      for (final Wenku8Status s in Wenku8Status.values) {
        expect(Wenku8StatusLabels.titles[s], isNotNull);
        expect(Wenku8StatusLabels.hints[s], isNotNull);
        expect(Wenku8StatusLabels.titles[s]!.isNotEmpty, isTrue);
      }
      expect(Wenku8Status.values.length, 8);
    });

    test('只有 ok 可用；限流 / 不可用 / 结构变化都不算成功', () {
      expect(Wenku8StatusLabels.isUsable(Wenku8Status.ok), isTrue);
      for (final Wenku8Status s in <Wenku8Status>[
        Wenku8Status.rateLimited,
        Wenku8Status.unavailable,
        Wenku8Status.upstreamChanged,
        Wenku8Status.restricted,
        Wenku8Status.lockedByPureLocal,
        Wenku8Status.loading,
        Wenku8Status.idle,
      ]) {
        expect(Wenku8StatusLabels.isUsable(s), isFalse, reason: s.name);
      }
    });

    test('五种榜单都有标签与提示', () {
      for (final Wenku8FeedKind f in Wenku8FeedKind.values) {
        expect(Wenku8FeedLabels.labels[f], isNotNull);
        expect(Wenku8FeedLabels.hints[f], isNotNull);
      }
    });
  });

  group('DemoWenku8Source 演示目录', () {
    test('全量过滤掉下架条目', () {
      expect(source.sourceId, 'wenku8');
      expect(DemoWenku8Source.allBooks.length, 6);
      expect(DemoWenku8Source.available.length, 5);
      expect(
        DemoWenku8Source.available.every((Wenku8Book b) => b.isAvailable),
        isTrue,
      );
    });

    test('榜单各自给书，状态一律 ok', () async {
      for (final Wenku8FeedKind f in Wenku8FeedKind.values) {
        final Wenku8Listing l =
            await source.listing(Wenku8Query(feed: f));
        expect(l.status, Wenku8Status.ok);
        expect(l.books, isNotEmpty, reason: f.name);
        expect(l.books.every((Wenku8Book b) => !b.withdrawn), isTrue);
      }
    });

    test('最近更新按 updatedKey 倒序，排行榜与推荐顺序不同', () async {
      final Wenku8Listing recent = await source.listing(
          const Wenku8Query(feed: Wenku8FeedKind.recent));
      for (int i = 1; i < recent.books.length; i++) {
        expect(
          recent.books[i - 1].updatedKey
              .compareTo(recent.books[i].updatedKey),
          greaterThanOrEqualTo(0),
        );
      }
      final Wenku8Listing rank = await source.listing(
          const Wenku8Query(feed: Wenku8FeedKind.ranking));
      expect(rank.books.first.id, isNot(recent.books.first.id));
    });

    test('已完结只留带该标签的书', () async {
      final Wenku8Listing l = await source.listing(
          const Wenku8Query(feed: Wenku8FeedKind.completed));
      expect(l.books.every((Wenku8Book b) => b.tags.contains('已完结')),
          isTrue);
      expect(l.books.length, 2);
    });

    test('搜索命中标题与作者，且归一为 search 榜单', () async {
      final Wenku8Listing l = await source.listing(
          const Wenku8Query(feed: Wenku8FeedKind.ranking, keyword: '雪国'));
      expect(l.feed, Wenku8FeedKind.search);
      expect(l.books.length, 1);
      expect(l.books.first.title, '雪国的旅行者');
      final Wenku8Listing byAuthor = await source.listing(
          const Wenku8Query(keyword: '海野'));
      expect(byAuthor.books.single.title, '与星群同行的午后');
      expect((await source.listing(const Wenku8Query(keyword: '不存在'))).books,
          isEmpty);
    });

    test('详情给卷与章，下架 / 未知 id 返回 null', () async {
      final Wenku8Detail? d = await source.detail('wk-101');
      expect(d, isNotNull);
      expect(d!.volumes.length, 12);
      expect(d.chapterCount, 48);
      expect(d.volumes.first.chapters.first.volumeIndex, 1);
      expect(await source.detail('wk-106'), isNull);
      expect(await source.detail('unknown'), isNull);
    });

    test('列表与详情都不携带正文字段（元数据壳）', () async {
      final Wenku8Detail d = (await source.detail('wk-102'))!;
      expect(d.synopsis, contains('演示元数据'));
      expect(d.synopsis, contains('不缓存'));
    });
  });
}
