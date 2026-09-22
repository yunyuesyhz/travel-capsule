# 旅途胶囊 · Travel Capsule

一个离线优先的 Flutter 旅行口袋：把资料、下一站和应急信息放在一起。无需登录，核心功能不依赖网络。

## 第一版功能

- 旅行：新建、编辑、切换、归档、恢复与删除；可选择一段明确标注的示例旅行。
- 资料袋：文字、链接、当地语言地址、图片与 PDF；分类、搜索、编辑、删除。
- 文件：导入时保存独立副本，单份最多 50 MB；图片缩放、原生 PDF 分页预览。
- 系统分享：Android 接收文字、链接、单个或多个图片/PDF，保存到待整理收件箱；支持归档到旅行。
- 下一站：置顶、正在进行、最近未来行程；支持完成/取消、关联资料与起止时区。夏令时异常需要明确选择。
- 大字地址卡和应急卡：离线展示、复制地址、联系人、保险、求助语，主动打开系统拨号界面。
- 备份与恢复：导出 ZIP（总内容最多 200 MB），校验附件 SHA-256，恢复为新旅行副本，不覆盖现有数据。

## 1.1 视觉焕新

- “晴空海岸”配色：浅天空背景、白色卡片、海洋蓝绿主操作，以及阳光橙行程强调。
- 首页下一站、资料类型、行程状态、应急卡与空状态重新分层，增加留白并减轻视觉重量。
- 编辑表单改用底部固定保存按钮；长表单和键盘弹出时仍可直接保存。
- 成功、错误、导入和删除提示改为明确的用户语言，危险操作使用独立珊瑚色并写明影响。
- Android 图标改为日出、海岸和旅行路线，支持自适应图标、圆形启动器图标与系统主题单色图标。

![旅途胶囊 1.1 图标](docs/screenshots/app-icon.png)

链接只保存 URL 和文字，不自动下载网页。图片/PDF 正文暂不参与搜索。没有账号、自动同步、OCR、在线翻译或实时交通信息。备份未加密，应保存到信任的位置；卸载应用会删除本地资料。

## 环境

已锁定 Flutter 3.47.5 / Dart 3.13.4，依赖版本见 `pubspec.lock`。Android 使用 AGP 9.1.0、Gradle 9.3.1、compile/target SDK 36、最低 Android 8.0（API 26），NDK 28.2.13676358。

本机开发工具位于被 Git 忽略的 `.tooling/`，不属于应用运行依赖。`scripts/flutterw` 使用本地完整 JDK 21（含 `jlink`）；其他电脑可安装同版 Flutter、完整 JDK 21 和 Android SDK，直接使用标准 `flutter` 命令。文件选择插件的 SDK 与 Kotlin 编译目标兼容配置位于 `android/build.gradle.kts`。

```sh
./scripts/flutterw pub get
./scripts/flutterw analyze
./scripts/flutterw test
./scripts/flutterw build apk --release --target-platform android-arm64
```

Android 构建输出：`build/app/outputs/flutter-apk/app-release.apk`。
当前视觉焕新版安装包：[下载 ARM64 APK](artifacts/trail-capsule-1.1.0-arm64.apk)，适用 Android 8.0 及以上 ARM64 手机；[校验值](artifacts/SHA256SUMS.txt)。
当前 release 配置使用本地调试签名，仅适合个人试用/内测；正式上架前需配置自己的发布密钥，不能把这份内测签名作为长期发布方案。

连接安卓手机并开启 USB 调试后，可执行：

```sh
.tooling/android-sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 验证

`test/` 有 13 项自动测试，覆盖：

- 下一站优先级、完成/取消和过期事项。
- 跨时区、夏令时缺失时间和重复时间。
- 源文件删除和数据库重新打开后的附件持久性。
- 备份恢复、路径穿越、附件缺失、失败写入回滚和孤立文件清理。
- 创建旅行、保存地址、打开大字卡；窄屏与 1.6 倍字体下四个页面布局。

`integration_test/smoke_test.dart` 提供设备集成测试，创建示例数据、验证附件和备份，`test_driver/integration_test.dart` 可保存界面截图。仅在专用测试设备运行，它会新增示例旅行及恢复副本。设备测试是否实际通过以 `docs/verification.md` 为准，不应把单元/组件测试等同于真机验收。

## 代码结构

- `lib/core/models.dart`：数据模型、下一站和时区规则。
- `lib/data/repository.dart`：Drift/SQLite、附件副本、哈希校验与备份。
- `lib/data/controller.dart`：原子保存、应用状态与原生收件箱交接。
- `lib/features/`：四个页面、编辑流程、查看与设置。
- `android/app/src/main/kotlin/`：系统分享接收和 PDF 查看器。
- `ios/Runner/`、`ios/ShareExtension/`：保留 iOS 主应用及分享扩展源码。本轮按要求只完成安卓构建，不承诺 iOS 构建或设备运行已通过。

SQLite 使用带版本的 `records` 表保存各类元数据，二进制附件放在应用管理目录。文件系统与数据库不共享事务，因此启动和提交后会清理孤立附件；Android 收件箱先落盘，再由 Dart 按任务 ID 幂等消费。

## 安卓验收建议

安装后选择“先看看示例旅行”，再用自己的旅行资料替换。建议依次检查：

1. 从文件选择器导入真实图片/PDF，删除原文件后再次打开。
2. 从相册、浏览器、文件应用分享到旅途胶囊，检查冷启动/已打开两种状态。
3. 开启飞行模式并重新打开应用，查看附件、地址卡和应急信息。
4. 新建跨时区行程，验证排序、置顶和完成状态。
5. 导出备份，恢复为新副本并检查附件；确认后再删除测试副本。

PDF 密码保护文件或损坏文件会提示无法预览；HEIC 等格式能否显示取决于系统解码能力，可转换为 JPG/PNG 再导入。资料存于应用沙箱，不将首版宣传为证件保险箱。
