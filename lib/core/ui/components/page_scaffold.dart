import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';

/// 页面骨架：顶部 Hero 头与内容共用一条滚动轴，顶部不是固定 AppBar。
///
/// 三种构造：
///   * [LrPage]      少量已知组件，仍走 builder 懒构造，不一次性分配子树；
///   * [LrPage.builder] 长列表，按 index 懒构建（推荐）；
///   * [LrPage.slivers] 需要 SliverFillRemaining / 自定义 sliver 的页面。
///
/// `addAutomaticKeepAlives: false` 是第三十轮的性能口径：阅读类长列表
/// 不需要每个格子都保活，滚出视口就该释放；`addRepaintBoundaries: true`
/// 保留逐格重绘隔离。
class LrPage extends StatelessWidget {
  const LrPage({
    super.key,
    required this.header,
    required this.slivers,
    this.horizontalPadding = LrSpacing.l,
    this.bottomInset = 120,
  }) : itemCount = slivers?.length?? 0,
       itemBuilder = null,
       rawSlivers = null;

  const LrPage.builder({
    super.key,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.horizontalPadding = LrSpacing.l,
    this.bottomInset = 120,
  }) : slivers = null,
       rawSlivers = null;

  const LrPage.slivers({
    super.key,
    required this.header,
    required this.rawSlivers,
    this.horizontalPadding = LrSpacing.l,
    this.bottomInset = 120,
  }) : slivers = null,
       itemCount = 0,
       itemBuilder = null;

  final Widget header;
  final List<Widget>? slivers;
  final List<Widget>? rawSlivers;
  final int itemCount;
  final NullableIndexedWidgetBuilder? itemBuilder;
  final double horizontalPadding;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final List<Widget> body = <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
            horizontalPadding, LrSpacing.xl, horizontalPadding, 0),
        sliver: SliverToBoxAdapter(child: header),
      ),
    ];
    if (rawSlivers != null) {
      body.addAll(rawSlivers!);
    } else {
      body.add(SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => itemBuilder != null
                ? itemBuilder!(context, index)
                : slivers![index],
            childCount: itemBuilder != null ? itemCount : slivers!.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          ),
        ),
      ));
    }
    body.add(SliverToBoxAdapter(child: SizedBox(height: bottomInset)));
    return SafeArea(
      bottom: false,
      child: CustomScrollView(slivers: body),
    );
  }
}
