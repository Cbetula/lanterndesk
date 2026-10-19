# Linux 构建

在 Linux x86_64 主机上安装 Docker Engine，确认当前用户可以运行 `docker info`，然后在项目根目录运行：

```bash
./scripts/build-linux.sh
```

脚本初始化 `libs/hbb_common` 子模块，在独立的 Ubuntu 24.04 容器中编译 Rust 库和 Flutter 桌面程序。宿主机不需要安装 Rust、Flutter 或开发库，也不需要修改系统软件。首次构建需要联网下载工具链和依赖，默认使用 8 个编译任务；可通过 `CARGO_BUILD_JOBS=4 ./scripts/build-linux.sh` 限制并行度。

工具链固定为 Rust 1.75.0、Flutter 3.24.5，下载文件均校验 SHA-256；Ubuntu 镜像也固定 digest。系统开发包由 Ubuntu 软件源提供。依赖缓存位于 `${XDG_CACHE_HOME:-$HOME/.cache}/lanterndesk-build`，可以用 `LANTERNDESK_BUILD_CACHE` 指定其他位置。脚本继承现有 HTTP/HTTPS 代理环境变量。

网络访问官方工具链仓库较慢时，可选用镜像；仍使用相同的原始文件校验和：

```bash
RUST_DIST_SERVER=https://rsproxy.cn \
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn \
./scripts/build-linux.sh
```

镜像地址参与 Docker 构建缓存；后续重建保持同一组变量可避免重复下载工具链。

输出文件：

* `dist/lanterndesk-linux-x86_64/`：完整程序目录，运行其中的 `./lanterndesk`。
* `dist/lanterndesk-linux-x86_64.tar.gz`：可分发压缩包。
* `dist/lanterndesk-linux-x86_64.tar.gz.sha256`：压缩包校验和。

## 运行环境

当前产物面向 Ubuntu 24.04 及兼容的 x86_64 Linux 桌面环境，要求 glibc 2.39 或更新版本。解压后保留可执行文件旁的 `data/` 和 `lib/` 目录。

构建使用上游已有的 `linux-pkg-config` 路径，启用 Flutter 与文件剪贴板，附带 VP8/VP9、AV1、Opus 和 YUV 转换所需的运行库。硬件视频编解码未启用。中转、直连和屏幕控制仍使用原有 RustDesk 实现。

常见 Linux 桌面已安装所需系统运行库。最小 Ubuntu 系统可运行：

```bash
sudo apt-get update
sudo apt-get install -y libgtk-3-0t64 libasound2t64 libpulse0 \
  libgstreamer-plugins-base1.0-0 libayatana-appindicator3-1 \
  libxcb-randr0 libxcb-shape0 libxcb-xfixes0 libxfixes3 libxtst6 \
  libssl3t64 libjpeg-turbo8
```

Wayland 屏幕共享还需要桌面环境对应的 `xdg-desktop-portal` 后端及 `gstreamer1.0-pipewire`，并遵循桌面的屏幕共享授权流程。此压缩包不会自动安装系统服务或更改用户的远控权限设置。

## 桥接文件来源

仓库携带 `bridge-53996e3c.zip`，是上游提交 `53996e3c404ea5083df0775057e4149e49102084` 对应的原始 CI 构建产物：

* [上游构建记录](https://github.com/rustdesk/rustdesk/actions/runs/39180666729)
* [GitHub 产物元数据](https://api.github.com/repos/rustdesk/rustdesk/actions/artifacts/12156082959)
* 产物名：`bridge-artifact`
* SHA-256：`fc50782895f49a1d25bf9439bbc59af116d9ba44f916fcf1d485e8a4873190a2`

下载内容已与 GitHub API 返回的 digest 核对。保留压缩包可以避免上游短期产物过期后无法构建；每次构建都会再次校验。构建脚本仅解压已有文件，并应用上游 `build.py` 的 Dart FFI 布尔类型修正及 Flutter 菜单补丁，不运行 `flutter_rust_bridge_codegen`。本分支未更改桥接函数接口。以后修改桥接接口时，必须同时更新经过核对的桥接文件及来源记录。

压缩包内包含项目 AGPL 许可证及附带系统库的版权/许可文件。

## Flutter 3.24.5 依赖锁

上游 `flutter/pubspec.lock` 没有记录清单中已有的 `flutter_test`，且部分测试依赖版本不符合上游 CI 使用的 Flutter 3.24.5 SDK 约束。Linux 构建使用本目录的 `pubspec.lock`，通过 Docker 只读文件挂载提供给容器，再执行 `flutter pub get --enforce-lockfile`。宿主机原来的锁文件始终保留；源码清单、Git 依赖提交和包下载源均不变。

该锁文件由 Flutter 3.24.5 从原锁文件解析得到，版本调整均来自 SDK 的测试依赖约束：

| 依赖 | 原锁版本 | Linux 构建版本 |
| --- | --- | --- |
| async | 2.13.0 | 2.11.0 |
| boolean_selector | 2.1.2 | 2.1.1 |
| matcher | 0.12.17 | 0.12.16+1 |
| source_span | 1.10.1 | 1.10.0 |
| stack_trace | 1.12.1 | 1.11.1 |
| stream_channel | 2.1.4 | 2.1.2 |
| string_scanner | 1.4.1 | 1.2.0 |
| term_glyph | 1.2.2 | 1.2.1 |
| test_api | 0.7.6 | 0.7.2 |

同时记录缺失的 SDK `flutter_test` 及其依赖：`fake_async 1.3.1`、`leak_tracker 10.0.5`、`leak_tracker_flutter_testing 3.0.5`、`leak_tracker_testing 3.0.1`、`vm_service 14.2.5`。`vector_math 2.1.4` 仅按现有清单标记为直接依赖，版本未变。
