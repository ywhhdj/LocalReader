#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ARB -> Dart catalog 同步与校验（第二十八轮）。

**唯一人工维护源**是 `lib/l10n/app_zh.arb` / `app_en.arb`。
改任何文案只改这两份 ARB，然后跑：

    py tool/sync_arb.py

脚本会：
  1. 校验两份 ARB 的 @@locale / 键集合 / 空值 / placeholder 对齐 / 英文值里的 CJK；
  2. 生成 `lib/l10n/l10n_catalog.g.dart`（GENERATED，不要手改）；
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
    zh, en = load(ZH), load(EN)
    errors: list[str] = []

    if zh.get("@@locale") != "zh_CN" or en.get("@@locale") != "en":
        errors.append("@@locale 必须是 zh_CN / en")
    if set(zh) != set(en):
        only_zh = sorted(set(zh) - set(en))
        only_en = sorted(set(en) - set(zh))
        errors.append(f"两份 ARB 键集合不一致：仅 zh {only_zh[:5]} / 仅 en {only_en[:5]}")

    keys = entity_keys(zh)
    en_keys = entity_keys(en)
    if keys != en_keys:
        errors.append("实体键顺序 / 集合不一致")
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
        pz, pe = sorted(set(PH.findall(zv))), sorted(set(PH.findall(ev)))
        if pz != pe:
            errors.append(f"{k}: 中英 placeholder 不一致 zh={pz} en={pe}")
        if pz:
            placeholders[k] = pz
            meta = zh.get("@" + k, {})
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
        for e in errors[:30]:
            print("[sync_arb][ERROR]", e)
        print(f"[sync_arb] 共 {len(errors)} 项校验失败，未生成 catalog。")
        return 1

    lines = [
        "// GENERATED FILE - DO NOT EDIT.",
        "// 由 tool/sync_arb.py 从 lib/l10n/app_zh.arb / app_en.arb 生成。",
        "// 唯一人工维护源是那两份 ARB：改文案请改 ARB 后重跑脚本。",
        "// 本文件是纯 Dart 常量表，不依赖 flutter gen-l10n，静态交付也能编译。",
        "",
        "/// 中文文案表（ARB `app_zh.arb` 的 Dart 镜像）。",
        "const Map<String, String> kZhCatalog = <String, String>{",
    ]
    for k in keys:
        lines.append(f"  {dart_string(k)}: {dart_string(zh_map[k])},")
    lines += [
        "};",
        "",
        "/// 英文文案表（ARB `app_en.arb` 的 Dart 镜像）。",
        "const Map<String, String> kEnCatalog = <String, String>{",
    ]
    for k in keys:
        lines.append(f"  {dart_string(k)}: {dart_string(en_map[k])},")
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
        f"/// ARB 实体键数量（自检 / 预览面板读取）。",
        f"const int kCatalogKeyCount = {len(keys)};",
        f"/// 带 placeholder 的键数量。",
        f"const int kCatalogPlaceholderKeyCount = {len(placeholders)};",
        f"/// 英文仍含中文片段、建议在 ARB 里人工润色的键数量（如实统计，不隐藏）。",
        f"const int kCatalogReviewKeyCount = {len(review)};",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")

    print(f"[sync_arb] 实体键 {len(keys)} / 列表 {len(lists)} / placeholder 键 {len(placeholders)}")
    print(f"[sync_arb] 英文含中文片段待润色：{len(review)} 键")
    print(f"[sync_arb] 已生成 {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
