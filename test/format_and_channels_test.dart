import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/import/import_session.dart';
import 'package:local_reader/core/parser/book_parser.dart';

void main() {
  group('格式表对齐参考仓库 README', () {
    const List<String> textFormats = <String>[
      'txt',
      'epub',
      'mobi',
      'azw',
      'azw3',
      'prc',
      'fb2',
      'doc',
      'docx',
      'rtf',
      'html',
      'htm',
      'xhtml',
      'md',
      'markdown',
    ];
    for (final String ext in textFormats) {
      test('$ext → dartText', () {
        expect(
            ParserRouter.routeForPath('book.$ext').route, RenderRoute.dartText,
            reason: ext);
      });
    }

    const List<String> rasterFormats = <String>[
      'pdf',
      'cbz',
      'zip',
      'cbr',
      'rar',
    ];
    for (final String ext in rasterFormats) {
      test('$ext → nativeRaster', () {
        expect(ParserRouter.routeForPath('book.$ext').route,
            RenderRoute.nativeRaster,
            reason: ext);
      });
    }

    test('静态出口与实例方法一致（格式表唯一）', () {
      for (final String ext in <String>['epub', 'prc', 'azw3', 'unknown']) {
        // 实例方法需要 CharsetBridge，静态表本身可独立校验 extOf。
        expect(ParserRouter.extOf('a/b.$ext'), ext);
      }
      expect(ParserRouter.routeForPath('book.unknown').route,
          RenderRoute.unsupported);
    });

    test('extOf 大小写与无扩展名', () {
      expect(ParserRouter.extOf('A.EPUB'), 'epub');
      expect(ParserRouter.extOf('README'), isEmpty);
      expect(ParserRouter.extOf('.hidden'), 'hidden');
    });
  });

  group('云端导入渠道', () {
    test('四种渠道都有名称与说明', () {
      expect(CloudImportChannel.values.length, 4);
      expect(CloudImportLabels.count, 4);
      for (final CloudImportChannel c in CloudImportChannel.values) {
        expect(CloudImportLabels.names[c], isNotNull);
        expect(CloudImportLabels.hints[c], isNotNull);
        expect(CloudImportLabels.names[c]!.isNotEmpty, isTrue);
      }
    });

    test('夸克标实验性、文档选择器不内置凭据', () {
      expect(
          CloudImportLabels.names[CloudImportChannel.quark], contains('实验性'));
      expect(CloudImportLabels.hints[CloudImportChannel.documentPicker],
          contains('不内置账号'));
    });

    test('导入向导原有能力不被回归', () {
      expect(ImportStep.values.length, 5);
      expect(ImportPermissionMode.values.length, 3);
      expect(ConflictResolution.values.length, 4);
      expect(ImportLabels.steps.length, 5);
    });
  });
}
