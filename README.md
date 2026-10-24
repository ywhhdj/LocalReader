# Local Reader · 安卓本地小说 / 漫画阅读器

纯本地、无联网、无广告的阅读器。现代化大圆角 + 液态玻璃（Liquid Glass）UI，支持常见小说与漫画格式。

## 支持格式

| 类型 | 格式 |
|---|---|
| 小说 | EPUB（container/OPF/nav/ncx + 正文与图片抽取）、TXT（编码自动识别 + 章节切分）、PDF |
| 漫画 | CBZ / ZIP、图片文件夹、PDF（逐页渲染）、CBR/RAR |


## 权限与扫描（Android 11+ 必读）

- **方式一（推荐，无需全盘权限）**：首页「导入 → 选择目录…」用系统文件选择器授权目录，授权会持久化，重启后可一键重扫。
- **方式二**：授予「所有文件访问权限」（设置页 / 首页均有「去授权」入口），之后可直接扫描 `/sdcard` 等公共目录。
- Android 13+ 使用 `READ_MEDIA_*`，Android 12- 使用 `READ_EXTERNAL_STORAGE`；App 会在启动时申请。
- 无权限时导入对话框会明确提示当前状态；RAR/CBR 暂不支持（提示转 CBZ/ZIP）。

## 扩展能力

| 能力 | 状态 | 说明 |
|---|---|---|
| WebDAV 备份 | 默认关闭 | 备份书库元数据、进度、分组与阅读会话；支持测试连接、立即备份、远端列表恢复、导出到本地 |
| TTS 朗读 | 默认可用，音色下载 **默认关闭** | 小说阅读器顶栏「朗读」按钮，支持语速/音调、读完自动进入下一章 |
| 在线书源 | **默认关闭** | 需自行配置书源规则；关闭时不产生任何网络请求；结果只能另存为 TXT 到本地书库 |

## 阅读体验

| 能力 | 说明 |
|---|---|
| 阅读背景 | 纸白 / 米黄 / 夜间 / 护眼，正文与面板文字色由背景亮度自动反推，任意背景下都保证对比度 |
| 翻页动画 | 平移 / 仿真（伪 3D 绕书脊翻转）/ 无动画；可在设置里整体关闭界面动效 |
| 分页排版 | 章节按屏幕尺寸实时分页，段落首行缩进、孤儿行控制、跨页续块不重复缩进 |
| 漫画阅读 | 预加载窗口、按页宽高比占位、话集目录跳转；屏幕常亮与音量键翻页可选 |


## 工程结构

```text
LocalReader/
  ├── assembly/                   装配层：NavHost / DI 容器
  ├── core/
  │   ├── model/                  领域模型（纯 Kotlin）
  │   ├── common/                 工具：Result/调度器/格式化/自然排序/内存工具/设备分级
  │   ├── ui/                     设计系统：主题、液态玻璃组件、通用组件、动效配置
  │   └── database/               Room：Entity / DAO / 索引 / 迁移
  ├── domain/                     Repository 接口 + UseCase（纯 Kotlin，无 Android 依赖）
  ├── data/                       实现：文件扫描、EPUB/TXT/漫画/PDF 解析、封面与页面缓存、DataStore
  ├── feature/
  │   ├── shelf/                  首页书架 + 搜索 + 导入
  │   ├── detail/                 书籍详情
  │   ├── reader/                 小说阅读器 + 漫画阅读器
  │   ├── profile/                个人页与阅读统计
  │   └── settings/               设置、主题、动效与流畅度
  ├──MainActivity.kt              MainActivity 启动页
  ├──CrashGuard.kt                崩溃处理
  └──App.kt                       App 启动（含内存裁剪）
```

分层依赖严格单向：`app → feature → domain → core`，`data → domain`，feature 之间不互相依赖（导航目标由 app 注入）。

## 构建（需本地执行一次依赖下载）

```bash
# 1. 准备 JDK 17 + Android SDK（compileSdk 34），写入 local.properties: sdk.dir=/path/to/sdk
# 2. 补齐 Gradle Wrapper（本仓库不含二进制 jar）
gradle wrapper --gradle-version 8.7

# 3. 构建 Release APK
gradle clean
gradle :app:assembleRelease
# 输出：app/build/outputs/apk/release/app-release.apk

# 4. 安装到真机
./install.sh

# release（可选）：cp local.properties.example local.properties 并填写
./build.sh release
```

## 本地数据库 SQLite
> 请根据指示 `schema.sql` 创建数据库。