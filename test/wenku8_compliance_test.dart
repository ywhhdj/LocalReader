import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/wenku/demo_wenku8_source.dart';
import 'package:local_reader/core/wenku/wenku8_compliance.dart';
import 'package:local_reader/core/wenku/wenku8_models.dart';
import 'package:local_reader/core/wenku/wenku8_registry.dart';

void main() {
  group('来源注册：只有两项，不支持自定义书源', () {
    test('恰好 Wenku8 与本地导入', () {
      expect(Wenku8Registry.sources.length, 2);
      expect(Wenku8Registry.count, 2);
      expect(Wenku8Registry.sources.first.id, 'wenku8');
      expect(Wenku8Registry.sources.last.id, 'local-import');
      expect(Wenku8Registry.sources.first.isOnline, isTrue);
      expect(Wenku8Registry.sources.last.isOnline, isFalse);
    });

    test('byId 与 isSupportedSource 对齐', () {
      for (final BookSource s in Wenku8Registry.sources) {
        expect(Wenku8Registry.byId(s.id), s);
        expect(Wenku8Compliance.isSupportedSource(s.id), isTrue);
      }
      expect(Wenku8Registry.byId('custom'), isNull);
      expect(Wenku8Compliance.isSupportedSource('custom'), isFalse);
      expect(Wenku8Registry.canAddCustomSource(), isFalse);
      expect(Wenku8Compliance.customSourcesAllowed, isFalse);
    });

    test('六条合规规则都有文案', () {
      expect(Wenku8Compliance.rules.length, 6);
      for (final String r in Wenku8Compliance.rules) {
        expect(r.isNotEmpty, isTrue);
      }
      expect(Wenku8Compliance.rules, contains(LegalTexts.wenkuNoWithdrawn));
    });
  });

  group('下架内容过滤', () {
    test('全量过滤后没有 withdrawn 条目，且返回不可变列表', () {
      final List<Wenku8Book> out =
          Wenku8Compliance.withoutWithdrawn(DemoWenku8Source.allBooks);
      expect(out.length, 5);
      expect(out.every((Wenku8Book b) => b.isAvailable), isTrue);
      expect(() => out.add(DemoWenku8Source.allBooks.first),
          throwsUnsupportedError);
    });

    test('空输入安全', () {
      expect(Wenku8Compliance.withoutWithdrawn(const <Wenku8Book>[]), isEmpty);
    });
  });

  group('凭据脱敏（Issue 不带密码 / Cookie / Token）', () {
    test('常见键值形式被替换', () {
      for (final String raw in <String>[
        'password=abc123456',
        'Cookie: sessionid=abcdef123456',
        'token: eyJhbGciOiJIUzI1NiJ9',
        'Authorization: Bearer abcdefgh12345678',
        'api_key=zzzz1234',
      ]) {
        final String out = Wenku8Compliance.redact(raw);
        expect(out, contains(Wenku8Compliance.redactedPlaceholder),
            reason: raw);
        expect(out, isNot(contains('abc123456')), reason: raw);
      }
    });

    test('独立 Bearer / Basic 凭据串也被拦', () {
      expect(
        Wenku8Compliance.redact('请求头 Bearer abcdefgh12345678 失败'),
        isNot(contains('abcdefgh12345678')),
      );
    });

    test('正常文本不被改动', () {
      const String plain = '在书架页点第三本书后崩溃，Android 15，版本 1.0.0+1';
      expect(Wenku8Compliance.redact(plain), plain);
    });

    test('大小写不敏感', () {
      expect(Wenku8Compliance.redact('PASSWORD=Secret123'),
          contains(Wenku8Compliance.redactedPlaceholder));
    });

    test('containsCredential 保守检测', () {
      expect(Wenku8Compliance.containsCredential('token=abc'), isTrue);
      expect(Wenku8Compliance.containsCredential('普通复现步骤'), isFalse);
    });
  });
}
