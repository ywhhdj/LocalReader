import 'package:flutter/foundation.dart';

/// 阅读动效与自动阅读（第二十四轮）。
///
/// 参考仓库 README：「paragraph-continuation, slide, cover, or no animation,
/// and adjust page-turn speed」「volume-key page turns, auto-reading, and
/// continuous chapter transitions」。
///
/// 归一化沿用第六轮定下的裁决点：`motion=false`（整体关界面动效）时，
/// **所有动效参数锁回最静的值**，页面不自己解释规则。
enum ReaderTransition { paragraphContinuation, slide, cover, none }

@immutable
class ReaderMotion {
  const ReaderMotion({
    this.transition = ReaderTransition.slide,
    this.turnSpeed = 1.0,
    this.autoRead = false,
    this.autoReadIntervalMs = 4000,
    this.continuousChapter = true,
    this.volumeKeyTurnPage = true,
    this.globalMotion = true,
  });

  final ReaderTransition transition;
  final double turnSpeed;
  final bool autoRead;
  final int autoReadIntervalMs;
  final bool continuousChapter;
  final bool volumeKeyTurnPage;
  final bool globalMotion;

  static const Map<ReaderTransition, String> labels = <ReaderTransition, String>{
    ReaderTransition.paragraphContinuation: '段落续接',
    ReaderTransition.slide: '平移',
    ReaderTransition.cover: '覆盖',
    ReaderTransition.none: '无动画',
  };

  ReaderMotion copyWith({
    ReaderTransition? transition,
    double? turnSpeed,
    bool? autoRead,
    int? autoReadIntervalMs,
    bool? continuousChapter,
    bool? volumeKeyTurnPage,
    bool? globalMotion,
  }) =>
      ReaderMotion(
        transition: transition ?? this.transition,
        turnSpeed: turnSpeed ?? this.turnSpeed,
        autoRead: autoRead ?? this.autoRead,
        autoReadIntervalMs: autoReadIntervalMs ?? this.autoReadIntervalMs,
        continuousChapter: continuousChapter ?? this.continuousChapter,
        volumeKeyTurnPage: volumeKeyTurnPage ?? this.volumeKeyTurnPage,
        globalMotion: globalMotion ?? this.globalMotion,
      );

  /// 唯一归一化：整体动效关闭 → 无动画、速度锁 1、不自动阅读。
  /// 自动阅读本身不是「界面动效」，但它会持续翻页，关动效时也一并停下，
  /// 否则会出现「设了关动效却还在自动翻页」的状态分裂。
  ReaderMotion normalized() => globalMotion
      ? copyWith(
          turnSpeed: turnSpeed.clamp(0.5, 2.0).toDouble(),
          autoReadIntervalMs: autoReadIntervalMs.clamp(1500, 15000),
        )
      : copyWith(
          transition: ReaderTransition.none,
          turnSpeed: 1.0,
          autoRead: false,
        );

  bool get isAutoReading => normalized().autoRead;

  @override
  bool operator ==(Object other) =>
      other is ReaderMotion &&
      other.transition == transition &&
      other.turnSpeed == turnSpeed &&
      other.autoRead == autoRead &&
      other.autoReadIntervalMs == autoReadIntervalMs &&
      other.continuousChapter == continuousChapter &&
      other.volumeKeyTurnPage == volumeKeyTurnPage &&
      other.globalMotion == globalMotion;

  @override
  int get hashCode => Object.hash(
        transition, turnSpeed, autoRead, autoReadIntervalMs,
        continuousChapter, volumeKeyTurnPage, globalMotion,
      );
}
