/// 对应原项目 `core/common/自然排序`：卷序「第 2 卷」不能排到「第 10 卷」后面。
///
/// 纯函数：把字符串切成「数字段 / 非数字段」，数字段按数值比，中文数字先归一。
/// 书名分组、卷序、话号三处共用这一个比较器，不各写一份正则。
const Map<String, int> _cnDigits = <String, int>{
  '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
  '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
};

int _cnNumberToInt(String s) {
  if (s.isEmpty) return 0;
  if (s == '十') return 10;
  final int ten = s.indexOf('十');
  if (ten >= 0) {
    final int left = ten == 0 ? 1 : (_cnDigits[s[ten - 1]] ?? 0);
    final int right = ten + 1 < s.length ? (_cnDigits[s[ten + 1]] ?? 0) : 0;
    return left * 10 + right;
  }
  int value = 0;
  for (final String ch in s.split('')) {
    final int? d = _cnDigits[ch];
    if (d == null) return int.tryParse(s) ?? 0;
    value = value * 10 + d;
  }
  return value;
}

int _pieceValue(String piece) {
  final int? arabic = int.tryParse(piece);
  if (arabic != null) return arabic;
  return _cnNumberToInt(piece);
}

bool _isNumericPiece(String piece) =>
    int.tryParse(piece) != null ||
    piece.split('').every((String ch) => _cnDigits.containsKey(ch) || ch == '十');

List<String> _pieces(String s) {
  final List<String> out = <String>[];
  final StringBuffer buf = StringBuffer();
  bool? digit;
  for (final String ch in s.split('')) {
    final bool isDigit = int.tryParse(ch) != null ||
        _cnDigits.containsKey(ch) ||
        ch == '十';
    if (digit != null && isDigit != digit) {
      out.add(buf.toString());
      buf.clear();
    }
    digit = isDigit;
    buf.write(ch);
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

int naturalCompare(String a, String b) {
  final List<String> pa = _pieces(a);
  final List<String> pb = _pieces(b);
  final int n = pa.length < pb.length ? pa.length : pb.length;
  for (int i = 0; i < n; i++) {
    final String x = pa[i];
    final String y = pb[i];
    if (_isNumericPiece(x) && _isNumericPiece(y)) {
      final int c = _pieceValue(x).compareTo(_pieceValue(y));
      if (c != 0) return c;
    } else {
      final int c = x.compareTo(y);
      if (c != 0) return c;
    }
  }
  return pa.length.compareTo(pb.length);
}
