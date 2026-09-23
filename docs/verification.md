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

## 1.1.1 动效与 PDF 阅读页

- 版本：1.1.1+4；交付文件：`artifacts/trail-capsule-1.1.1-arm64.apk`，21,880,464 字节，仅 ARM64。
- SHA-256：`5eec77c616da63cf0c62cd84b56778798531c77577668f7c396cd5b6a0711d48`。
- 底部四个栏目使用 280 ms 交叉淡化与轻微缩放，悬浮操作按钮同步过渡，并保留栏目滚动位置。
- Android PDF 阅读页的返回、标题、阅读画布与分页区域已统一为应用视觉；PDF 页面切换使用 180 ms 淡入。
- `flutter analyze`：通过；Flutter 自动测试：13 项通过；Android 应用模块原生测试：通过。
- release 构建、APK v2 签名验证与 16 KB ZIP 对齐检查通过；Manifest 版本 1.1.1+4、min SDK 26、target SDK 36。
- 本轮未改动或构建 iOS；当前无已连接 Android 设备，因此未执行真机视觉验收。

## 1.1.2 PDF 启动崩溃修复

- 版本：1.1.2+5；交付文件：`artifacts/trail-capsule-1.1.2-arm64.apk`，21,880,464 字节，仅 ARM64。
- SHA-256：`ca842211347effcbc9db2290458a5f96f0474ba6757c543fcd1a6bd3bc874706`。
- 回归测试在 API 35 复现到 `DecorView` 尚未建立时读取系统栏控制器导致的空指针；系统栏配置已移至 `setContentView` 之后。
- PDF 阅读页启动测试在 API 26 与 API 35 均通过；文件异常时活动保持打开并显示“无法预览”。
- `flutter analyze`、13 项 Flutter 自动测试及 4 项 Android 原生测试通过。
- release 构建、APK v2 签名验证与 16 KB ZIP 对齐检查通过；Manifest 版本 1.1.2+5、min SDK 26、target SDK 36。
- 本轮未改动或构建 iOS；当前无已连接 Android 设备，因此未执行真机视觉验收。

## 1.1.3 行程与资料体验优化

- 版本：1.1.3+6；ARM64 Android 安装包：`artifacts/trail-capsule-1.1.3-arm64.apk`，约 21.9 MB。
- SHA-256：`5cd54b5cccdfdd2c03ce9af5c46fc67592b0919997be568d6d1953f1c105a5b5`；APK v2 签名验证与 16 KB ZIP 对齐检查通过。
- Manifest：min SDK 26、target SDK 36、仅 ARM64。
- 行程资料关联改为多选；旧版 `itemId` 数据读取兼容，删除资料时会从所有行程关联中清理。
- 附件导入与收件箱归档支持选择分类，跳过时归入“其他”；中国时区界面名称改为“北京”。
- 首页增加左右滑动切换栏目，行程详情弹层在有无关联资料时均使用完整宽度。
- 本轮执行 Dart 格式化、Android release 构建和 APK 打包校验；未运行自动化测试、静态分析或 iOS 构建。真机视觉验收尚未执行。

## 1.1.4 奶油海岸视觉更新

- 全局 UI 与 PDF 阅读页统一切换为奶油底、橙色、薰衣草紫和薄荷绿配色；Android 启动图标配色同步。
- 版本：1.1.4+7；ARM64 Android 安装包：`artifacts/trail-capsule-1.1.4-arm64.apk`，21,881,152 字节（约 21.9 MB）。
- SHA-256：`56a03149f1f54251645f41daf80f9a2b4efef1b7ba3c157d179f48b79e777ffb`；APK v2 签名验证与 16 KB ZIP 对齐检查通过。
- Manifest：min SDK 26、target SDK 36、仅 ARM64。
- 本轮执行 Dart 格式化、Android release 构建与 APK 签名/对齐/Manifest 校验；未运行自动化测试、静态分析或真机视觉验收，未构建 iOS。

## 1.1.5 弹窗、导航与升级签名

- 分类选择底单指定屏幕全宽；底部栏改为暖色半透明模糊背景，并开启正文延伸绘制；自绘 Tab 图标、选中底色和标签的过渡动画。
- 版本：1.1.5+8；ARM64 APK：`artifacts/trail-capsule-1.1.5-arm64.apk`，21,815,616 字节。
- SHA-256：`ae6b145532945431fcec8735e7ac628dfd66b6e6203555acd45abb96e181b061`。APK v2 签名、16 KB ZIP 对齐、Manifest 版本与 ABI 检查通过。
- Release 固定使用本地私钥 `.tooling/signing/current-release.keystore`；证书 SHA-256 `ed5e9f134d20d2878189f4977515f24c1c5da44a0d744520ae748a69185bc71c`，与 1.1.3/1.1.4 相同。构建脚本会拒绝证书变更，且不得提交或删除该私钥。
- 1.1.0–1.1.2 使用旧证书；从这些版本升级到 1.1.5 仍需一次性卸载后安装。后续 1.1.5 起保持证书一致。
- 执行 Dart 格式化与 Android release 构建；未运行自动化测试或静态分析。ADB 无法在当前环境启动，未执行真机覆盖安装及视觉验收；未构建 iOS。
- 本轮执行 Dart 格式化与 Android release 构建；未运行自动化测试、静态分析或真机视觉验收，未构建 iOS。

## 1.1.6 磨砂质感与提示动效

- 版本：1.1.6+9；ARM64 APK：`artifacts/trail-capsule-1.1.6-arm64.apk`，21,815,672 字节。
- SHA-256：`52f5bf4d6f74428a9bab7d1926e9067b870ef18426983ab07e8461b373d9c404`。APK v2 签名、16 KB ZIP 对齐和发布证书一致性检查通过。
- 首页卡片、快捷入口、编辑面板和按钮增加半透明磨砂背景；橙色主操作统一使用白字。上传/复制提示使用深色磨砂条，出现 460 ms、消失 320 ms。
- `flutter analyze --no-pub`、Dart 格式化和 13 项 Flutter 自动测试通过；Release 构建成功。Manifest 为 1.1.6+9、min SDK 26、target SDK 36、仅 ARM64。
- 当前无可用 Android 设备用于真机视觉验收；未构建 iOS。

## 1.1.7 磨砂与提示动画修正

- 版本：1.1.7+10；ARM64 APK：`artifacts/trail-capsule-1.1.7-arm64.apk`，21,750,136 字节。
- SHA-256：`30e18802b5127f30dde0b074d965cada5de7197b37168785df25e81d4af10f71`。APK v2 签名、16 KB ZIP 对齐和发布证书一致性检查通过；与 1.1.6 同证书，可覆盖升级。
- 磨砂卡片、按钮增强背景模糊与半透明层次。提示条改为自绘 OverlayEntry，明确使用 480 ms 上滑/淡入/缩放，自动显示 3 秒后用 300 ms 反向动画退出。
- 新增提示动画 widget test，确认淡入及退出过程中的透明度变化；完整 14 项测试以串行模式通过。`flutter analyze --no-pub` 与 Dart 格式化通过。
- 当前无可用 Android 设备用于真机视觉验收；未构建 iOS。

## 1.1.8 提示条文字样式修正

- 版本：1.1.8+11；ARM64 APK：`artifacts/trail-capsule-1.1.8-arm64.apk`，21,750,136 字节。
- SHA-256：`ac1667f5f9faf04f21920e457573d7d46780615b50d8ff70d3989f67c3b0fc51`。APK v2 签名、16 KB ZIP 对齐和发布证书一致性检查通过；签名与 1.1.7 相同。
- 浮层提示文字改用透明 Material 容器并显式设置无装饰，消除 Flutter 默认浮层文字样式带来的黄色双下划线。
- 提示条组件测试验证文字无装饰且进出场动画保持有效；Dart 格式化、`flutter analyze --no-pub` 和 Android Release 构建通过。
- 当前无可用 Android 设备用于真机视觉验收；未构建 iOS。

## 1.1.9 点击回弹动效

- 版本：1.1.9+12；ARM64 APK：`artifacts/trail-capsule-1.1.9-arm64.apk`，21,815,672 字节。
- SHA-256：`ccbc0dd13a64faa718574c0ffe343f4781dad7603dca70f0182506632fb00033`。APK v2 签名、16 KB ZIP 对齐和发布证书一致性检查通过；签名与 1.1.8 相同，可覆盖安装。
- 按钮、可点击卡片、列表选项、分类标签和底部 Tab 加入按压缩小、松开回弹；手指拖动超过阈值会解除按压状态。原生 PDF 浏览器的返回与翻页按钮加入同类动效。
- 新增回弹交互测试，验证按钮点击与卡片拖动；完整 16 项 Flutter 测试、`flutter analyze --no-pub`、Dart 格式化与 Android Release 构建通过。Manifest 为 1.1.9+12、min SDK 26、target SDK 36、仅 ARM64。
- 当前无可用 Android 设备用于真机视觉验收；未构建 iOS。
