# Mac 本机构建

必须在 macOS 上构建，Linux 或 Linux Docker 容器不能运行 Xcode。Apple Silicon Mac 默认生成 arm64 包，Intel Mac 默认生成 x86_64 包；请使用与芯片对应的原生终端，不要通过 Rosetta 构建。

## 首次准备

安装完整 Xcode，启动 Xcode 完成首次组件安装与许可证确认。命令行需指向完整 Xcode：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

安装 [Homebrew](https://brew.sh/) 和 [rustup](https://rustup.rs/)，然后安装构建依赖：

```bash
brew install cmake pkg-config cocoapods autoconf automake libtool
```

## 克隆并编译

私有仓库需先配置你的 GitHub 访问权限。

```bash
git clone --recurse-submodules https://github.com/Cbetula/lanterndesk.git
cd lanterndesk
./scripts/build-macos.sh
```

脚本安装用户范围的 Rust 1.81.0 工具链；下载固定且校验 SHA-256 的 Flutter 3.24.5，及 Intel 构建需要的 NASM 2.16.03。vcpkg 固定为上游提交 `9e593bb18ea69cc5095e012465dcd675a822ed0d`，使用原项目 codec overlay。下载源和代理可通过 `FLUTTER_STORAGE_BASE_URL`、`HTTPS_PROXY` 等环境变量设置，校验和仍然强制检查。

工具链、依赖与工作副本保存在 `~/Library/Caches/lanterndesk-macos`，可用 `LANTERNDESK_MACOS_CACHE` 指定其他路径。不要同时使用同一个缓存目录运行多个构建。默认 3 个 Rust / vcpkg 编译任务，可通过 `CARGO_BUILD_JOBS` 调整。

编译在缓存中的源码副本执行，使用现有的 `packaging/linux/pubspec.lock`（同一 Flutter 3.24.5 依赖锁），不改动用户 checkout 的 Cargo/Dart 锁文件或已安装的 Flutter SDK。不运行 `flutter_rust_bridge_codegen`；使用已经校验的原始桥接归档，来源记录见 `packaging/linux/bridge-provenance.json`。

输出位于仓库 `dist/`：

- `lanterndesk-macos-arm64.dmg` 或 `lanterndesk-macos-x86_64.dmg`
- 对应的 `.dmg.sha256` 校验文件

要求 macOS 13+，启用软件视频编解码、文件剪贴板与 ScreenCaptureKit 音频路径。首次启动与权限说明位于 DMG 中的 `安装说明.txt`。

## 签名与验收范围

构建脚本使用 ad-hoc 临时签名并检查完整性，不使用上游的 Apple 开发者团队信息，不声明完成 Apple 公证。它会检查 bundle ID、CPU 架构、`--version` 和 DMG 完整性。实际桌面启动、屏幕共享授权及双机远控仍需要在你的 Mac 上验收。

GitHub Actions 中的 `LanternDesk macOS` 工作流运行相同脚本，分别在 Apple Silicon 与 Intel runner 上构建。手动运行时，`release_tag` 留空仅保存构建产物；填写新的 `lanterndesk-vX.Y.Z` 标签会在两种架构都成功后发布 Release。

## 现有文件的回归范围

- `flutter/macos/Runner/Configs/AppInfo.xcconfig`：应用名和 bundle ID 独立，生成 `LanternDesk.app`。
- `flutter/macos/Runner.xcodeproj/project.pbxproj`：同步产品引用与 bundle ID，去除上游开发者团队，最低系统改为 macOS 13，供当前原生依赖与 ScreenCaptureKit 构建。
- `flutter/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`：同步产物名称，让 Xcode 定位新应用。
- `flutter/macos/Runner/Info.plist`：注册独立的 `lanterndesk://` URL，避免抢占官方应用的链接处理。
- `flutter/macos/Podfile`：最低系统与应用一致。
- `README.md`：增加 Mac 构建入口与交付范围说明。

新增逻辑限于 Mac 构建脚本、说明及独立工作流。会话协议、Linux 构建、Rust 运行实现和子模块均不改动。
