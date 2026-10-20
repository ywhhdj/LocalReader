# Liquid Reader · 安卓本地小说 / 漫画阅读器

纯本地、无联网、无广告的阅读器。现代化大圆角 + 液态玻璃（Liquid Glass）UI，支持常见小说与漫画格式。

## 支持格式

| 类型 | 格式 |
|---|---|
| 小说 | EPUB（container/OPF/nav/ncx + 正文与图片抽取）、TXT（编码自动识别 + 章节切分）、PDF |
| 漫画 | CBZ / ZIP、图片文件夹、PDF（逐页渲染）、CBR/RAR（接口预留，提示转 CBZ） |

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
./build.sh debug
# 输出：app/build/outputs/apk/debug/app-debug.apk

# 4. 安装到真机
./install.sh

# release（可选）：cp keystore.properties.example keystore.properties 并填写
./build.sh release
```

## 关键设计

- **首页**：顶部玻璃导航栏（Logo 位 / 搜索胶囊 / 主题切换 / 设置）+ 分组 Chips +「继续阅读」「最近添加」横向区块 + 书架网格（分页，24/页）。
- **个人页**：总时长 / 连续天数 / 藏书量、今日概览、近 7 天柱状图（Canvas 自绘）、小说漫画时长占比环形图、最近读完。
- **液态玻璃**：半透明底色 + API31 实时模糊（低版本自动降级）+ 渐变高光描边 + 顶部反光；设置页可一键关闭（低配机省电）。
- **内存优化**：书架分页与区块条数上限；Coil 内存缓存 15%、RGB_565、按视图尺寸采样；封面统一 ≤450px WebP（LRU 300）；漫画 ±N 页窗口加载，窗口外释放；EPUB 章节惰性解析 + LRU 10 章；ZipFile/PdfRenderer 在 `DisposableEffect` 关闭；扫描分块事务且可取消。

## 文档索引

- [00-架构设计](docs/00-架构设计.md)
- [01-工程结构与构建](docs/01-工程结构与构建.md) · [02-数据模型与数据库](docs/02-数据模型与数据库.md) · [03-文件扫描与导入](docs/03-文件扫描与导入.md)
- [04-EPUB解析](docs/04-EPUB解析.md) · [05-漫画解析](docs/05-漫画解析.md) · [06-TXT与编码识别](docs/06-TXT与编码识别.md)
- [07-首页书架与搜索](docs/07-首页书架与搜索.md) · [08-书籍详情](docs/08-书籍详情.md) · [09-小说阅读器](docs/09-小说阅读器.md) · [10-漫画阅读器](docs/10-漫画阅读器.md)
- [11-个人页与统计](docs/11-个人页与统计.md) · [12-设置与主题](docs/12-设置与主题.md) · [13-性能与内存优化](docs/13-性能与内存优化.md) · [14-构建与真机测试](docs/14-构建与真机测试.md)
- [PLAN 开发计划](docs/PLAN.md)
