# 第一版验证记录

- Flutter 3.47.5 / Dart 3.13.4。
- `flutter analyze`：已通过。
- `flutter test`：13 项通过（含后台备份压缩后的回归）。
- iOS 分享扩展 Swift 独立类型检查曾通过；完整 iOS 构建与运行未完成。用户已要求停止 iOS 构建，本轮不再继续。
- Android release APK：2026-09-22 构建成功。完整 JDK 21；Android 8.0+（min SDK 26）、target SDK 36；仅 ARM64。
- 交付文件：`artifacts/trail-capsule-1.0.0-arm64.apk`，21,845,876 字节（约 21.8 MB）。
- SHA-256：`de56ee953bf4dd9f57370947d3a9615fcfe9fcbd5dca24b21a349d9e1046e513`。
- `apksigner verify`：通过 APK v2 签名验证，使用 Android Debug 内测密钥。
- `zipalign -c -P 16 4`：通过。4 个 ARM64 原生库的全部 ELF LOAD 段对齐均不少于 16 KB。
- Manifest 静态检查：应用名称、版本 1.0.0+1、启动 Activity 与 SDK 版本符合配置；无网络或广泛存储权限。
- 构建兼容修复：完整 JDK 提供 `jlink`；file_picker 10.1.9 统一至 compile SDK 36 和 Kotlin JVM 11；限制 APK ABI 为 ARM64，避免第三方库使安装包错误声明其他架构支持。
- 构建仍提示旧插件 KGP 迁移警告；当前锁定工具链构建通过，未来升级 Flutter 前需升级相关插件。
- Android 真机/模拟器验收：尚未执行。

## 1.0.1 附件打开修复

- 修复 Android 私有目录可能以 `/data/data/...` 与 `/data/user/0/...` 两种等价路径出现时，合法 PDF 被误判为“文件路径无效”的问题。
- 文件与允许目录均规范化后再比较；仍要求附件真实存在、可读、位于应用私有目录且扩展名为 PDF。
- Android 路径策略回归测试：2 项通过，覆盖等价规范路径，以及相似目录前缀、缺失文件和错误扩展名的拒绝逻辑。
- 修复包：`artifacts/trail-capsule-1.0.1-arm64.apk`，21,845,876 字节；版本 1.0.1+2，仅 ARM64。
- SHA-256：`d1e28cd00b90cd5bf8aac421c945f535b931ac5c145cc33d730c02164bbf951f`。
- release 构建、APK v2 签名验证、16 KB ZIP 对齐检查均通过。

## 1.1.0 Android 视觉焕新

- 版本：1.1.0+3；交付文件：`artifacts/trail-capsule-1.1.0-arm64.apk`，21,880,468 字节，仅 ARM64。
- SHA-256：`824c4661500f19c7162da67b808b96dfe58032af35c4126929aeab7ba3048d86`。
- `flutter analyze`：通过；Flutter 自动测试：13 项通过；Android 路径策略测试：2 项通过。
- APK v2 签名验证与 16 KB ZIP 对齐检查通过；min SDK 26、target SDK 36。
- Android Manifest 已解析到自适应 XML 启动图标；提供 API 26 自适应/圆形资源和 API 33 单色主题资源。
- 本轮未改动或构建 iOS；当前无已连接 Android 设备，因此未执行真机视觉验收。
