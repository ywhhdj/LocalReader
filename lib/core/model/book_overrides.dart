import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 书籍元数据编辑覆盖层：对应参考仓库「Edit titles, authors, covers, and volume order」。
/// 静态交付模式下只覆盖内存中的演示数据，不改原始 BookRepository（它保持只读真相）。
@immutable
class BookOverride {
  const BookOverride({
    this.title,
    this.author,
    this.spineColor,
    this.volumeOrder,
  });

  final String? title;
  final String? author;
  final Color? spineColor;
  final int? volumeOrder;

  BookOverride merge(BookOverride other) => BookOverride(
        title: other.title ?? title,
        author: other.author ?? author,
        spineColor: other.spineColor ?? spineColor,
        volumeOrder: other.volumeOrder ?? volumeOrder,
      );
}
