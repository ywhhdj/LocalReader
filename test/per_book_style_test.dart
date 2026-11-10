import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/state/per_book_style.dart';
import 'package:local_reader/core/state/reader_style.dart';

void main() {
  group('按书排版覆盖', () {
    const ReaderStyle global = ReaderStyle();

    test('没有覆盖时完全沿用全局默认', () {
      final EffectiveReaderStyle e = EffectiveReaderStyle.resolve(
          global, const <String, PerBookStyle>{}, 'b-1');
      expect(e.fontSize, global.fontSize);
      expect(e.lineHeight, global.lineHeight);
      expect(e.isBookSpecific, isFalse);
    });

    test('书级覆盖只影响那本书，不复制全局默认值', () {
      const PerBookStyle o = PerBookStyle(fontSize: 22, lineHeight: 2.0);
      final Map<String, PerBookStyle> map = <String, PerBookStyle>{'b-1': o};
      expect(EffectiveReaderStyle.resolve(global, map, 'b-1').fontSize, 22);
      expect(EffectiveReaderStyle.resolve(global, map, 'b-2').fontSize,
          global.fontSize);
      // 没设的字段仍然是全局默认，不是第二份写死的快照。
      expect(EffectiveReaderStyle.resolve(global, map, 'b-1').fontFamily,
          'NotoSerifSC');
      expect(EffectiveReaderStyle.resolve(global, map, 'b-1').marginLeft, 20);
    });

    test('全局改字号时，未单独设置过的书跟着变', () {
      const PerBookStyle o = PerBookStyle(lineHeight: 1.9);
      const ReaderStyle bigger = ReaderStyle(fontSize: 24);
      final EffectiveReaderStyle e = EffectiveReaderStyle.resolve(
          bigger, const <String, PerBookStyle>{'b-1': o}, 'b-1');
      expect(e.fontSize, 24);
      expect(e.lineHeight, 1.9);
    });

    test('布局键只含排版字段，换背景不进键', () {
      const ReaderStyle a = ReaderStyle(background: ReaderBackground.paper);
      const ReaderStyle b = ReaderStyle(background: ReaderBackground.night);
      final String ka = EffectiveReaderStyle.resolve(
          a, const <String, PerBookStyle>{}, 'b-1').layoutKey;
      final String kb = EffectiveReaderStyle.resolve(
          b, const <String, PerBookStyle>{}, 'b-1').layoutKey;
      expect(ka, kb);
    });

    test('isEmpty / cleared / 序列化往返', () {
      const PerBookStyle o = PerBookStyle(
          fontFamily: 'NotoSerifSC', fontSize: 19, lineHeight: 1.7,
          marginLeft: 24, alignment: ReaderTextAlignment.center);
      expect(o.isEmpty, isFalse);
      expect(o.cleared().isEmpty, isTrue);
      final PerBookStyle back = PerBookStyle.fromMap(o.toMap());
      expect(back.fontFamily, 'NotoSerifSC');
      expect(back.fontSize, 19);
      expect(back.marginLeft, 24);
      expect(back.alignment, ReaderTextAlignment.center);
      expect(back.marginRight, isNull);
    });

    test('四边距可分别设置，互不影响', () {
      const PerBookStyle o = PerBookStyle(
          marginLeft: 12, marginTop: 8, marginRight: 16, marginBottom: 10);
      final EffectiveReaderStyle e = EffectiveReaderStyle.resolve(
          global, const <String, PerBookStyle>{'b': o}, 'b');
      expect(<double>[e.marginLeft, e.marginTop, e.marginRight, e.marginBottom],
          <double>[12, 8, 16, 10]);
    });
  });
}
