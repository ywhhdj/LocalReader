# Liquid Reader · 安卓本地小说 / 漫画阅读器

纯本地、无联网、无广告的阅读器。现代化大圆角 + 液态玻璃（Liquid Glass）UI，支持常见小说与漫画格式。

## 支持格式

| 类型 | 格式 |
|---|---|
| 小说 | EPUB（container/OPF/nav/ncx + 正文与图片抽取）、TXT（编码自动识别 + 章节切分）、PDF |
| 漫画 | CBZ / ZIP、图片文件夹、PDF（逐页渲染）、CBR/RAR（接口预留，提示转 CBZ） |

## 新特性

- **详情页目录可跳转**：小说目录按「卷」分组（卷名一行、卷内章节缩进且去掉卷名前缀），点击直接跳到该章；章节较多时可打开右侧目录抽屉浏览完整目录。
- **详情页话集可跳转**：漫画话集真正加载出话列表（此前为空），点击任一话从该话首页开始；话名旁显示话内页数。
- **小说首行缩进改为排版实现**：不再往正文里插入全角空格，复制正文不再带多余空格，跨页续块不再重复缩进，字号/行距变化后缩进同步。
- **设置面板新增「目录」入口**：阅读器设置面板可直接拉出目录抽屉点章跳转，目录与设置面板互斥不再互相遮挡。
- **稳定性与性能**：修正「上一话」按钮判定、话内页数显示、进度条拖动时的重复解析与写库、书架分页触发与并发覆盖；磁盘缓存整理节流、容量统计缓存、小说章节缓存双上限、内存紧张时清空图片缓存。


## 权限与扫描（Android 11+ 必读）

- **方式一（推荐，无需全盘权限）**：首页「导入 → 选择目录…」用系统文件选择器授权目录，授权会持久化，重启后可一键重扫。
- **方式二**：授予「所有文件访问权限」（设置页 / 首页均有「去授权」入口），之后可直接扫描 `/sdcard` 等公共目录。
- Android 13+ 使用 `READ_MEDIA_*`，Android 12- 使用 `READ_EXTERNAL_STORAGE`；App 会在启动时申请。
- 无权限时导入对话框会明确提示当前状态；RAR/CBR 暂不支持（提示转 CBZ/ZIP）。

## 扩展能力（均可关闭）

| 能力 | 状态 | 说明 |
|---|---|---|
| WebDAV 备份 | 默认关闭 | 备份书库元数据、进度、分组与阅读会话；支持测试连接、立即备份、远端列表恢复、导出到本地 |
| TTS 朗读 | 默认可用 | 小说阅读器顶栏「朗读」按钮，支持语速/音调、读完自动进入下一章 |
| 在线书源 | **默认关闭** | 需自行配置书源规则；关闭时不产生任何网络请求；结果只能另存为 TXT 到本地书库 |

## 工程结构

```text
LiquidReader/
  ├── app/                        装配层：NavHost / DI 容器
  ├── core/
  │   ├── model/                  领域模型（纯 Kotlin）
  │   ├── common/                 工具：Result/调度器/格式化/自然排序/内存工具
  │   ├── ui/                     设计系统：主题、液态玻璃组件、通用组件
  │   └── database/               Room：Entity / DAO / 索引 / 迁移
  ├── domain/                     Repository 接口 + UseCase（纯 Kotlin，无 Android 依赖）
  ├── data/                       实现：文件扫描、EPUB/TXT/漫画/PDF 解析、封面与页面缓存、DataStore
  ├── feature/
  │   ├── shelf/                  首页书架 + 搜索 + 导入
  │   ├── detail/                 书籍详情
  │   ├── reader/                 小说阅读器 + 漫画阅读器
  │   ├── profile/                个人页与阅读统计
  │   └── settings/               设置与主题
  ├──MainActivity.kt              MainActivity 启动页
  └──App.kt                       App 启动
```

分层依赖严格单向：`app → feature → domain → core`，`data → domain`，feature 之间不互相依赖（导航目标由 app 注入）。

## 构建（需本地执行一次依赖下载）

```bash
# 1. 准备 JDK 17 + Android SDK（compileSdk 34），写入 local.properties: sdk.dir=/path/to/sdk
# 2. 补齐 Gradle Wrapper（本仓库不含二进制 jar）
gradle wrapper --gradle-version 8.7

# 3. 构建 debug APK
gradle clean
gradle :app:assembleDebug
# 输出：app/build/outputs/apk/debug/app-debug.apk

# 4. 安装到真机
./install.sh

# release（可选）：cp keystore.properties.example keystore.properties 并填写
./build.sh release
```
