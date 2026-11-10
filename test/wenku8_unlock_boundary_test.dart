import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/wenku/demo_wenku8_source.dart';
import 'package:local_reader/core/wenku/http_wenku8_source.dart';
import 'package:local_reader/core/wenku/wenku8_bootstrap.dart';
import 'package:local_reader/core/wenku/wenku8_compliance.dart';
import 'package:local_reader/core/wenku/wenku8_registry.dart';
import 'package:local_reader/core/wenku/wenku8_source.dart';

void main() {
  group('解锁后装配：默认真实源，可切回演示源', () {
    test('build() 默认给 HttpWenku8Source', () {
      final Wenku8Source s = Wenku8Bootstrap.build();
      expect(s, isA<HttpWenku8Source>());
      expect(s.sourceId, Wenku8Compliance.wenku8SourceId);
      Wenku8Bootstrap.dispose(s);
    });

    test('useDemo 切回确定性演示源，dispose 不误伤', () {
      final Wenku8Source s = Wenku8Bootstrap.build(useDemo: true);
      expect(s, isA<DemoWenku8Source>());
      expect(() => Wenku8Bootstrap.dispose(s), returnsNormally);
    });

    test('真实源实现可选章节能力，演示源不实现', () {
      final Wenku8Source real = Wenku8Bootstrap.build();
      expect(real, isA<Wenku8ChapterSource>());
      expect(Wenku8Bootstrap.build(useDemo: true),
          isNot(isA<Wenku8ChapterSource>()));
      Wenku8Bootstrap.dispose(real);
    });
  });

  group('解锁不推翻既有护栏', () {
    test('来源仍固定两项、自定义书源仍禁用', () {
      expect(Wenku8Registry.count, 2);
      expect(Wenku8Registry.canAddCustomSource(), isFalse);
      expect(Wenku8Compliance.customSourcesAllowed, isFalse);
    });

    test('下架过滤与凭据脱敏仍生效', () {
      expect(Wenku8Compliance.withoutWithdrawn(DemoWenku8Source.allBooks).length,
          5);
      expect(Wenku8Compliance.redact('token=abcdef123456'),
          contains(Wenku8Compliance.redactedPlaceholder));
    });

    test('锁定态状态仍存在，纯本地默认零请求口径不变', () {
      expect(Wenku8Status.values, contains(Wenku8Status.lockedByPureLocal));
      expect(Wenku8StatusLabels.isUsable(Wenku8Status.lockedByPureLocal),
          isFalse);
    });
  });
}
