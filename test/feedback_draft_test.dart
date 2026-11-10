import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/support/feedback_draft.dart';
import 'package:local_reader/core/wenku/wenku8_compliance.dart';

void main() {
  group('四要素完整性', () {
    test('空草稿列出四个缺失字段', () {
      const FeedbackDraft d = FeedbackDraft();
      expect(d.isComplete, isFalse);
      expect(d.missingFields.length, 4);
      expect(d.missingFields, FeedbackDraft.requiredFieldLabels);
    });

    test('逐项补齐后 isComplete 变 true', () {
      FeedbackDraft d = const FeedbackDraft();
      expect(d.isComplete, isFalse);
      d = d.copyWith(appVersion: '1.0.0+1');
      expect(d.missingFields.length, 3);
      d = d.copyWith(device: 'Pixel 8');
      expect(d.missingFields.length, 2);
      d = d.copyWith(osVersion: 'Android 15');
      expect(d.missingFields.length, 1);
      d = d.copyWith(steps: '1. 打开书架 2. 切到云端');
      expect(d.isComplete, isTrue);
      expect(d.missingFields, isEmpty);
    });

    test('只填空白字符不算填写', () {
      const FeedbackDraft d = FeedbackDraft(appVersion: '   ');
      expect(d.missingFields, contains('应用版本'));
    });

    test('值语义与 copyWith 不改原对象', () {
      const FeedbackDraft a = FeedbackDraft(appVersion: '1');
      final FeedbackDraft b = a.copyWith(device: 'Pixel');
      expect(a.device, isEmpty);
      expect(b.appVersion, '1');
      expect(b.device, 'Pixel');
      expect(a == const FeedbackDraft(appVersion: '1'), isTrue);
    });
  });

  group('纯文本预览', () {
    test('包含四要素标签与代价说明', () {
      const FeedbackDraft d = FeedbackDraft(
        appVersion: '1.0.0+1',
        device: 'Pixel 8',
        osVersion: 'Android 15',
        steps: '1. 打开书架 2. 切到云端',
        details: '只在深色模式出现',
      );
      final String out = d.toPlainText();
      expect(out, contains(LegalTexts.feedbackPreviewTitle));
      expect(out, contains('应用版本：1.0.0+1'));
      expect(out, contains('设备：Pixel 8'));
      expect(out, contains('操作系统版本：Android 15'));
      expect(out, contains('复现步骤：'));
      expect(out, contains('补充说明：只在深色模式出现'));
      expect(out, contains(LegalTexts.feedbackNoCredentials));
    });

    test('空字段写「待填写」，不静默省略', () {
      final String out = const FeedbackDraft().toPlainText();
      expect(out, contains('（待填写）'));
    });

    test('预览一律过脱敏，密码 / Token 不原文出现', () {
      const FeedbackDraft d = FeedbackDraft(
        appVersion: '1.0.0+1',
        device: 'Pixel 8',
        osVersion: 'Android 15',
        steps: '复现时带了 token=abcdef123456',
      );
      final String out = d.toPlainText();
      expect(out, isNot(contains('abcdef123456')));
      expect(out, contains(Wenku8Compliance.redactedPlaceholder));
      expect(d.needsRedaction, isTrue);
    });

    test('静态边界：不写文件、不上传，只是字符串', () {
      const FeedbackDraft d = FeedbackDraft(appVersion: '1');
      expect(d.toPlainText(), isA<String>());
    });
  });
}
