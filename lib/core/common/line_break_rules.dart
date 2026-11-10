/// 中文排版禁则：行首禁则（标点不能出现在行首）与行末禁则（开符号不能留在行末）。
/// 纯函数、零依赖，便于单测；由 PaginationEngine._breakLines 在断行后二次校正。
class LineBreakRules {
  const LineBreakRules._();

  /// 行首禁则：这些字符不能出现在下一行的第一个位置。
  static const Set<int> noLineStart = <int>{
    0xFF0C, // ，
    0x3001, // 、
    0x3002, // 。
    0xFF0E, // ．
    0xFF1A, // ：
    0xFF1B, // ；
    0xFF01, // ！
    0xFF1F, // ？
    0x2026, // …
    0x2014, // —
    0xFF09, // ）
    0x0029, // )
    0x300B, // 》
    0x300D, // 」
    0x300F, // 』
    0x3011, // 】
    0x3009, // 〉
    0x201D, // ”
    0x2019, // ’
    0xFF5D, // ｝
    0x002C, // ,
    0x002E, // .
    0x003A, // :
    0x003B, // ;
    0x0021, // !
    0x003F, // ?
  };

  /// 行末禁则：这些开符号不能留在本行末尾，必须带到下一行。
  static const Set<int> noLineEnd = <int>{
    0xFF08, // （
    0x0028, // (
    0x300A, // 《
    0x300C, // 「
    0x300E, // 『
    0x3010, // 【
    0x3008, // 〈
    0x201C, // “
    0x2018, // ‘
    0xFF5B, // ｛
  };

  static bool isNoLineStart(int codeUnit) => noLineStart.contains(codeUnit);
  static bool isNoLineEnd(int codeUnit) => noLineEnd.contains(codeUnit);

  /// 断行后校正 end。返回的 end 恒 > start，保证 PaginationEngine 不陷入死循环。
  ///
  /// 处理策略（保守且可预测，不追求标点悬挂）：
  ///  - 若下一个字符是行首禁则标点 → 回退一字，让该标点跟在前一个字之后到下一行；
  ///  - 若本行最后一字是行末禁则开符号 → 同样回退一字，把开符号带到下一行行首。
  ///
  /// TODO(P2 进阶)：标点悬挂（hanging punctuation）允许半角标点超出版心 0.5em，
  /// 可避免回退带来的行尾参差；需要排版层支持 overflow 绘制。
  static int adjustEnd(String text, int start, int end) {
    if (end <= start) return end;
    if (end >= text.length) {
      // 文本末尾没有「下一行」，只需处理行末禁则
      return _pullBackOpenBracket(text, start, end);
    }

    int adjusted = end;
    if (isNoLineStart(text.codeUnitAt(end))) {
      adjusted = end - 1;
    }
    adjusted = _pullBackOpenBracket(text, start, adjusted);
    return adjusted > start ? adjusted : start + 1;
  }

  static int _pullBackOpenBracket(String text, int start, int end) {
    if (end <= start + 1) return end;
    if (isNoLineEnd(text.codeUnitAt(end - 1))) return end - 1;
    return end;
  }
}
