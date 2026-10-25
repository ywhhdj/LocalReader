# Local Reader · 安卓本地小说 / 漫画阅读器

纯本地、无联网、无广告的阅读器。现代化大圆角 + 液态玻璃（Liquid Glass）UI，支持常见小说与漫画格式。

## 支持格式

| 类型 | 格式 |
|---|---|
| 小说 | EPUB（container/OPF/nav/ncx + 正文与图片抽取）、TXT（编码自动识别 + 章节切分） |
| 漫画 | CBZ / ZIP、图片文件夹、PDF（逐页渲染）、CBR/RAR（仅 RAR4 及更早） |
| PDF | 按**图片逐页**方式阅读：不重排字号、不支持选中复制与 TTS（详情页会显式提示） |

> 说明：PDF 以漫画方式逐页渲染是当前的**已知限制**——不引入第三方 PDF 库的前提下无法提取文本层。
> 需要字号重排、复制或朗读，请改用 EPUB / TXT。

## 权限与扫描（Android 11+ 必读）

- **方式一（推荐，无需全盘权限）**：首页「导入 → 选择目录…」用系统文件选择器授权目录，授权会持久化，重启后可一键重扫。
- **方式二**：授予「所有文件访问权限」（设置页 / 首页均有「去授权」入口），之后可直接扫描 `/sdcard` 等公共目录。
- Android 13+ 只申请 `READ_MEDIA_IMAGES`（阅读器只需要读取图片：漫画页与封面）；Android 12- 使用 `READ_EXTERNAL_STORAGE`；App 会在启动时申请。
  - 文档类书籍（EPUB/TXT/PDF）不在媒体库覆盖范围内，仍需走 SAF 或「所有文件访问」授权。
  - 已移除与本应用无关的 `READ_MEDIA_AUDIO`、`READ_MEDIA_VIDEO`、`POST_NOTIFICATIONS`。
- 无权限时导入对话框会明确提示当前状态；RAR5 / 加密包暂不支持（提示转 CBZ/ZIP）。
- `MANAGE_EXTERNAL_STORAGE` 保留：上架 Google Play 需按政策声明用途，默认路径仍是 SAF。

## 扩展能力

| 能力 | 状态 | 说明 |
|---|---|---|
| WebDAV 备份 | 默认关闭 | 备份书库元数据、进度、分组与阅读会话；支持测试连接、立即备份、远端列表恢复、导出到本地 |
| TTS 朗读 | 默认可用，音色下载 **默认关闭** | 小说阅读器顶栏「朗读」按钮，支持语速/音调、读完自动进入下一章；按批入队，暂停/续播精确到句 |
| 在线书源 | **默认关闭** | 需自行配置书源规则；关闭时不产生任何网络请求；结果只能另存为 TXT 到本地书库 |

> 隐私：`android:allowBackup="false"`（数据库可能含 WebDAV 账号，避免被 adb 备份导出）。
> `targetSdk 34` 默认禁止明文流量，WebDAV 请使用 https，否则会静默失败。

## 阅读体验

| 能力 | 说明 |
|---|---|
| 阅读背景 | 纸白 / 米黄 / 夜间 / 护眼，正文与面板文字色由背景亮度自动反推，任意背景下都保证对比度 |
| 翻页动画 | 平移 / 仿真（伪 3D 绕书脊翻转）/ 无动画；可在设置里整体关闭界面动效 |
| 分页排版 | 章节按屏幕尺寸实时分页，段落首行缩进、孤儿行控制、跨页续块不重复缩进 |
| 进度保存 | 滚动/翻页期间按固定间隔采样落库（含页内位置），退出前再兜底写一次 |
| 漫画阅读 | 预加载窗口、按页宽高比占位、话集目录跳转；屏幕常亮与音量键翻页可选 |

## 工程结构

```text
app/src/main/kotlin/com/demo/
  ├── App.kt                      启动（Coil / 崩溃兜底 / 容器 / 内存裁剪）
  ├── MainActivity.kt             单 Activity 入口
  ├── assembly/                   装配层：NavHost / DI 容器 / 退出清理
  ├── core/
  │   ├── model/                  领域模型（纯 Kotlin）
  │   ├── common/                 工具：Result/调度器/格式化/自然排序/内存工具/设备分级/编码探测
  │   ├── ui/                     设计系统：主题、液态玻璃组件、通用组件、动效配置
  │   └── database/               Room：Entity / DAO / 索引
  ├── domain/                     Repository 接口 + UseCase（纯 Kotlin，无 Android 依赖）
  ├── data/                       实现：文件扫描、EPUB/TXT/漫画/PDF 解析、封面与页面缓存、DataStore
  ├── feature/
  │   ├── shelf/                  首页书架 + 搜索 + 导入
  │   ├── detail/                 书籍详情
  │   ├── reader/                 小说阅读器 + 漫画阅读器
  │   ├── profile/                个人页与阅读统计
  │   └── settings/               设置、主题、动效与流畅度
  └── CrashGuard.kt               崩溃处理（含连续崩溃保护）
```

分层依赖严格单向：`app → feature → domain → core`，`data → domain`，feature 之间不互相依赖（导航目标由 app 注入）。

## 构建（需本地执行一次依赖下载）

```bash
# 1. 准备 JDK 17 + Android SDK（compileSdk 34），写入 local.properties: sdk.dir=/path/to/sdk
#    不要提交 gradle.properties 里的 org.gradle.java.home（已注释掉，换机器直接构建失败）

# 2. 补齐 Gradle Wrapper（本仓库不含二进制 jar）
gradle wrapper --gradle-version 8.7

# 3. 构建 Release APK
gradle clean
gradle :app:assembleRelease
# 输出：app/build/outputs/apk/release/app-release.apk
```

**签名**：仓库不含 keystore。`app/build.gradle` 会检测 `../keystore/release.jks` 与三项密码，
齐全则使用正式签名；缺失时 release 自动回退到 debug 签名，**保证以上命令可直接跑通**。
需要正式签名时自行生成：

```bash
keytool -genkeypair -v -keystore keystore/release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias localreader
# 并在 local.properties 写入：
# KEYSTORE_PASSWORD=xxx
# KEY_ALIAS=localreader
# KEY_PASSWORD=xxx
```

```bash
# 4. 安装到真机
./install.sh
```

## 本地数据库 SQLite
> 请根据指示 `schema.sql` 创建数据库。
>
> 注意：`AppDatabase` 当前 `version = 1` 且未登记迁移，实体变更后需同步维护 `schema.sql`
> 与 Room 导出的 `schemas/` JSON，否则 Room 会直接抛异常。

## 依赖说明

未使用（已移除）：Hilt/Dagger/Koin（手写容器）、OkHttp/Retrofit（纯本地）、Glide（Coil 更轻）、
jsoup（代码中无引用，移除后 APK 减小约 500KB）。
