#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ARB -> Dart catalog 同步与校验（含派生常量）。

**唯一人工维护源**是 `lib/l10n/app_zh.arb` / `app_en.arb`。
改任何文案只改这两份 ARB，然后跑：

    python tool/sync_arb.py           # 生成 l10n_catalog.g.dart
    python tool/sync_arb.py --check   # 只校验 catalog 是否最新（CI 用）

脚本会：
  1. 校验两份 ARB 的 @@locale / 键集合 / 空值 / placeholder 对齐 / 英文值里的 CJK；
  2. 生成 `lib/l10n/l10n_catalog.g.dart`（GENERATED，不要手改）；
     内含译文表 + 列表 + 派生常量（键数 / placeholder 数 / 待润色数 /
     业务键 / UI 键），下游无需再手抄；
  3. 打印统计（含「英文仍含中文片段、建议润色」的键数，如实不隐藏）。

生成物是纯 Dart 常量表，不依赖 `flutter gen-l10n`，所以零 SDK 的静态交付
也能编译与自检；本地 `flutter pub get` 会另行生成官方 `AppLocalizations`
（见 `l10n.yaml`），两者互不覆盖。
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZH = ROOT / "lib/l10n/app_zh.arb"
EN = ROOT / "lib/l10n/app_en.arb"
OUT = ROOT / "lib/l10n/l10n_catalog.g.dart"

CJK = re.compile(r"[\u4e00-\u9fff]")
PH = re.compile(r"\{(p\d+)\}")
UI_PREFIX = "ui"


def dart_string(s: str) -> str:
    """Python str -> Dart 双引号字符串字面量（转义 $ 避免被当插值）。"""
    return json.dumps(s, ensure_ascii=False).replace("$", r"\$")


def load(path: pathlib.Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        sys.exit(f"[sync_arb] 读取 {path} 失败：{e}")


def entity_keys(d: dict) -> list[str]:
    return [k for k in d if not k.startswith("@") and k != "@@locale"]


def main() -> int:
    check_only = "--check" in sys.argv[1:]

    zh, en = load(ZH), load(EN)
    errors: list[str] = []

    print(f"[sync_arb] 读取 {ZH.relative_to(ROOT)} / {EN.relative_to(ROOT)}")
    print(f"[sync_arb] zh 条目 {len(zh)} · en 条目 {len(en)}")

    if zh.get("@@locale") != "zh" or en.get("@@locale") != "en":
        errors.append("@@locale 必须是 zh / en")

    zh_all = set(zh)
    en_all = set(en)
    if zh_all != en_all:
        only_zh = sorted(zh_all - en_all)
        only_en = sorted(en_all - zh_all)
        errors.append(
            f"两份 ARB 键集合不一致：仅 zh {only_zh[:8]} / 仅 en {only_en[:8]}"
        )

    keys = entity_keys(zh)
    en_keys = entity_keys(en)
    if set(keys) != set(en_keys):
        errors.append("实体键集合不一致")
    if len(keys) != len(set(keys)):
        errors.append("ARB 存在重复键")

    zh_map: dict[str, str] = {}
    en_map: dict[str, str] = {}
    review: list[str] = []
    placeholders: dict[str, list[str]] = {}

    for k in keys:
        zv, ev = zh.get(k), en.get(k)
        if not isinstance(zv, str) or not zv:
            errors.append(f"{k}: 中文值为空或非字符串")
            continue
        if not isinstance(ev, str) or not ev:
            errors.append(f"{k}: 英文值为空或非字符串")
            continue
        zh_map[k], en_map[k] = zv, ev

        pz = sorted(set(PH.findall(zv)))
        pe = sorted(set(PH.findall(ev)))
        if pz != pe:
            errors.append(f"{k}: 中英 placeholder 不一致 zh={pz} en={pe}")
        if pz:
            placeholders[k] = pz
            meta = zh.get("@" + k, {}) or {}
            declared = set((meta.get("placeholders") or {}).keys())
            if declared != set(pz):
                errors.append(f"{k}: @placeholders 声明 {sorted(declared)} != {pz}")

        if CJK.search(ev):
            review.append(k)

    # 列表型文案：显式登记表，避免把列表拆成散键后失去聚合语义。
    lists = {
        "aboutParagraphs": [f"aboutParagraph{i}" for i in range(1, 7)],
    }
    for lk, members in lists.items():
        for m in members:
            if m not in zh_map:
                errors.append(f"列表 {lk} 的成员 {m} 不在 ARB")

    if errors:
        for e in errors:
            print("[sync_arb][ERROR]", e)
        print(f"[sync_arb] 共 {len(errors)} 项校验失败。")
        return 1

    print(
        f"[sync_arb] 校验通过：实体键 {len(keys)} · 列表 {len(lists)} · "
        f"placeholder 键 {len(placeholders)} · 待润色 {len(review)}"
    )

    business = [k for k in keys if not k.startswith(UI_PREFIX)]
    ui_keys = [k for k in keys if k.startswith(UI_PREFIX)]

    lines: list[str] = [
        "// GENERATED FILE - DO NOT EDIT.",
        "// 由 tool/sync_arb.py 从 lib/l10n/app_zh.arb / app_en.arb 生成。",
        "// 唯一人工维护源是那两份 ARB：改文案请改 ARB 后重跑脚本。",
        "// 本文件是纯 Dart 常量表，不依赖 flutter gen-l10n，静态交付也能编译。",
        "",
        "/// 中文文案表（ARB `app_zh.arb` 的 Dart 镜像）。",
        "const Map<String, String> kZhCatalog = <String, String>{",
    ]
    lines += [f"  {dart_string(k)}: {dart_string(zh_map[k])}," for k in keys]
    lines += [
        "};",
        "",
        "/// 英文文案表（ARB `app_en.arb` 的 Dart 镜像）。",
        "const Map<String, String> kEnCatalog = <String, String>{",
    ]
    lines += [f"  {dart_string(k)}: {dart_string(en_map[k])}," for k in keys]
    lines += [
        "};",
        "",
        "/// 列表型文案：键 -> ARB 里的成员键（顺序即展示顺序）。",
        "const Map<String, List<String>> kCatalogLists = <String, List<String>>{",
    ]
    for lk, members in lists.items():
        inner = ", ".join(dart_string(m) for m in members)
        lines.append(f"  {dart_string(lk)}: <String>[{inner}],")
    lines += [
        "};",
        "",
        "/// ARB 实体键数量（自检 / 预览面板读取）。",
        f"const int kCatalogKeyCount = {len(keys)};",
        "",
        "/// 带 placeholder 的键数量。",
        f"const int kCatalogPlaceholderKeyCount = {len(placeholders)};",
        "",
        "/// 英文仍含中文片段、建议在 ARB 里人工润色的键数量（如实统计，不隐藏）。",
        f"const int kCatalogReviewKeyCount = {len(review)};",
        "",
        "/// 业务键（不以 `ui` 前缀开头），供 LegalTexts / 自检 / 预览面板使用。",
        "const List<String> kBusinessKeys = <String>[",
        *[f"  {dart_string(k)}," for k in business],
        "];",
        "",
        "/// UI 短标签键（`ui` 前缀）。",
        "const List<String> kUiKeys = <String>[",
        *[f"  {dart_string(k)}," for k in ui_keys],
        "];",
        "",
    ]
    rendered = "\n".join(lines)

    if check_only:
        existing = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if existing != rendered:
            print(
                f"[sync_arb][ERROR] {OUT.relative_to(ROOT)} 已过期，"
                f"请重跑 `python tool/sync_arb.py`"
            )
            return 2
        print(f"[sync_arb] {OUT.relative_to(ROOT)} 与 ARB 一致 ✓")
        return 0

    OUT.write_text(rendered, encoding="utf-8")
    print(f"[sync_arb] 已生成 {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())