// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖

import 'package:Local_reader/core/model/navigation_spec.dart' show StatsDockView;

enum AccountLoginState { loggedOut, loggedIn, pureLocalLocked }

/// 未登录：左侧品牌 logo 图标，右侧主标题「登录文库账号」，
/// 副标题「登录后同步云书架」，整卡点击拉起 Wenku8LoginSheet。
class AccountCardSpec {
  const AccountCardSpec({this.state = AccountLoginState.loggedOut});

  final AccountLoginState state;

  bool get showBrandLogo => state != AccountLoginState.loggedIn;
  bool get showAvatar => state == AccountLoginState.loggedIn;

  String get titleKey {
    switch (state) {
      case AccountLoginState.loggedOut:
        return 'uiLoginWenkuAccount';
      case AccountLoginState.loggedIn:
        return 'uiAccountName';
      case AccountLoginState.pureLocalLocked:
        return 'uiLoginWenkuAccount';
    }
  }

  String get subtitleKey {
    switch (state) {
      case AccountLoginState.loggedOut:
        return 'uiLoginToSyncCloud';
      case AccountLoginState.loggedIn:
        return 'uiSyncStatus';
      case AccountLoginState.pureLocalLocked:
        return 'uiSwitchToOnlineToLogin';
    }
  }

  /// 纯本地锁定态明示「切到联网模式后可登录」，不提交凭据。
  bool get canSubmitCredentials =>
      state == AccountLoginState.loggedOut;

  String get onTapTarget => state == AccountLoginState.loggedIn
      ? '/account'
      : 'Wenku8LoginSheet';
}

/// 「我的」页从上到下：HeaderNav → 账户卡（第一项）→ 五个入口卡。
class MinePageSpec {
  const MinePageSpec({
    this.account = const AccountCardSpec(),
    this.entries = const <String>['stats', 'bookmarks', 'settings', 'about', 'sponsor'],
  });

  final AccountCardSpec account;
  final List<String> entries;

  bool get accountIsFirstBelowHeaderNav => true;
}

enum StatsRange { days7, days30, days90, days365, custom }

int rangeDaysOf(StatsRange r) {
  switch (r) {
    case StatsRange.days7:
      return 7;
    case StatsRange.days30:
      return 30;
    case StatsRange.days90:
      return 90;
    case StatsRange.days365:
      return 365;
    case StatsRange.custom:
      return -1; // 由自定义区间弹窗决定
  }
}

/// 统计页底部 Dock：总览 / 图表 / 书目 / 记号 / 触摸。
/// 空分类从 Dock 省略；「触摸」始终保留；全空时总览只显示一处阅读引导。
class StatsDockSpec {
  const StatsDockSpec({
    this.active = StatsDockView.overview,
    this.range = StatsRange.days30,
    this.dataViews = const <StatsDockView>{
      StatsDockView.overview,
      StatsDockView.charts,
      StatsDockView.books,
      StatsDockView.marks,
      StatsDockView.touch,
    },
    this.scrollOffsets = const <StatsDockView, double>{},
  });

  final StatsDockView active;
  final StatsRange range;
  final Set<StatsDockView> dataViews;
  final Map<StatsDockView, double> scrollOffsets;

  /// touch 永远在；其余按「本期有无数据」决定，不画 0 值空图。
  List<StatsDockView> availableViews() {
    final List<StatsDockView> out = <StatsDockView>[];
    for (final StatsDockView v in StatsDockView.values) {
      if (v == StatsDockView.touch || dataViews.contains(v)) out.add(v);
    }
    return out;
  }

  /// 切换保留各自滚动位置；再点当前项回到顶部；当前项变空则回到总览。
  StatsDockSpec switchTo(StatsDockView target, {double currentOffset = 0}) {
    final Map<StatsDockView, double> offsets =
        Map<StatsDockView, double>.from(scrollOffsets)
          ..[active] = currentOffset;
    final bool same = target == active;
    final bool stillAvailable = availableViews().contains(target);
    final StatsDockView next =
        !stillAvailable ? StatsDockView.overview : target;
    return StatsDockSpec(
      active: next,
      range: range,
      dataViews: dataViews,
      scrollOffsets: same
          ? (Map<StatsDockView, double>.from(offsets)..[next] = 0)
          : offsets,
    );
  }

  double offsetFor(StatsDockView v) => scrollOffsets[v] ?? 0;

  /// 全空：总览只显示一处阅读引导，不画空图；「区间记录」与「当前快照」分开。
  bool get allEmptyExceptTouch =>
      dataViews.where((StatsDockView v) => v != StatsDockView.touch).isEmpty;
}
