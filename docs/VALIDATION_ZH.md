# LanternDesk 交付与回归范围

基线：RustDesk `53996e3c404ea5083df0775057e4149e49102084`；子模块 `libs/hbb_common` 保持 `5d52530b636fb296a324260b074780cf559e0093`，没有引入额外上游提交。验证日期：2026-10-19。

## 已验证

- `bash deploy/relay/test-setup.sh`：通过。覆盖命令帮助、无副作用配置预览及无效参数拒绝。
- 中转配置通过 Docker Compose 1.29.2 校验；真实启动 `rustdesk/rustdesk-server:1.1.16` 的 `hbbs` / `hbbr`。测试只映射随机本机回环端口。
- `hbbs` 的两个 TCP 入口正确返回 NAT 检测协议响应。
- `hbbr` 拒绝错误密钥；两个使用正确公钥和相同会话 UUID 的连接成功配对，并逐字节转发测试消息。
- 重复启动容器后服务器公钥校验和不变；客户端 JSON / 导入字符串转换往返一致。
- 测试容器、网络和临时密钥已清理；未修改宿主机的防火墙或服务。
- 官方桥接归档的 SHA-256 与 GitHub 产物元数据一致，Rust / Flutter SDK 下载校验通过；没有运行桥接生成器。

- Rust release 库与 Flutter Linux release 桌面程序编译成功。`flutter pub get --enforce-lockfile` 使用打包目录的专用锁文件通过，原 `Cargo.lock` 与 `flutter/pubspec.lock` 保持逐字节不变。
- 压缩包大小 32,002,062 字节；SHA-256 为 `440e7714b7779f76bfffa97ecf3a9a2eacdaa9521834fed2c1464d520b8702e3`。随包校验文件验证通过，压缩包没有符号链接，程序和 Rust 库的动态依赖均能解析。
- 打包程序 `--version` 返回 `1.5.1`，退出码为 0；这是保留的上游内部版本，本项目首发标签为 `lanterndesk-v0.1.0`。
- 使用独立 XDG 目录、Xvfb 和 DBus 会话启动，Flutter 日志到达 `_globalFFI init end` 和主窗口激活事件，程序持续运行 50 秒后由测试超时正常终止，未发生程序崩溃、缺失动态库或 Dart 异常。虚拟显示环境出现 portal、keyring 和 DRI 警告；实际桌面的屏幕共享权限仍需实机验证。
- 隔离启动生成 LanternDesk 自己的配置与 IPC 路径，没有使用原版 RustDesk 设置。

## 仅自建服务器／IP 直连（0.1.2）

- `cargo test --locked --release --lib --features flutter,linux-pkg-config,unix-file-copy-paste lantern::tests`：3 项通过，覆盖空配置无公共回退、拒绝公共服务器、自建地址的端口及优先级。
- 使用隔离 Docker 网络、独立配置、Xvfb／DBus 和 `strace` 启动实际 Linux 包，分别检查空配置、带有旧公共地址及已启用公共 STUN 选项的配置、自建 hbbs/hbbr 配置。三个场景均监听 TCP 21118，直连均收到 45 字节的认证握手；跟踪期间没有公共服务的 DNS 查询或外部网络目标。
- 自建 hbbs/hbbr 使用固定的 1.1.16 镜像，客户端成功注册公钥；服务器和客户端测试容器、网络均已清理。临时测试使用独立密钥，未改动用户的密码或服务器设置。
- 首次移除公共服务默认值的 Linux 包 SHA-256：`d5ced67de05ecbe858ab4381c1f99993ac68de7cca71b62b0c529a09d7333c3e`；下方首页和密码更新后的包已替代此包。
- 当前保留 IP 直连、自建 ID 协商和自建中继。IPv6 打洞与 WebRTC 因隐含公共 STUN 依赖而禁用；直接输入 IPv6 地址仍走原 IP 直连路径。真实跨设备桌面控制与系统权限仍需实机验收。

## 首页 IP 与固定密码更新验证

- `flutter test --no-pub test/lantern_password_test.dart`：2 项通过。
- 修改涉及的 Dart 文件静态分析通过，无错误／警告，只有 9 项既有 API 弃用提示。Linux Rust release 与 Flutter release 重新编译通过。
- 使用原生桥接直接检查：空配置与公共地址返回未配置、自建地址返回已配置；无需重启即可响应服务器、直连端口和开关变化；枚举返回本机非回环 IPv4。测试使用独立配置。
- 更新后的实际桌面包在带旧公共地址配置、自建 hbbs/hbbr 两种隔离场景中均通过启动与 TCP 21118 认证握手检查（45 字节），自建场景注册成功。网络跟踪未发现公共服务查询或外部目标，应用日志无 Dart 异常；测试资源已清理。
- 当前 Linux 压缩包 31,814,539 字节，SHA-256：`33c409333ee98ee43a723f41776eb3ea347aba5aadefedc25ca7ae3beeda1d01`，校验通过，`--version` 返回 `1.5.1`。本机已重启为此包，Flutter 初始化完成、TCP 21118 正常监听。
- 未完成双机桌面控制实测；IP 栏目前展示 IPv4，IPv6 仍可手动输入连接。Mac 当前源码由维护者自行编译与发布。

## macOS 0.1.1 构建验证（旧版）

- 构建源码：`d57f0dff9da4be62701e93b050cb2a4ffe4836a8`；[GitHub Actions 记录](https://github.com/Cbetula/lanterndesk/actions/runs/39226767953)。Apple Silicon 与 Intel 均通过原生 Rust release、Flutter / Xcode 应用构建和 DMG 打包。
- 两端均通过 bundle ID `io.github.cbetula.lanterndesk`、程序版本 `1.5.1`、主程序与服务的 CPU 架构检查；ad-hoc 签名通过 `codesign --verify --deep --strict`，音频输入 entitlement 检查通过。
- 两个 DMG 均通过 `hdiutil verify`，附有各自的 SHA-256 文件；[macOS 下载](https://github.com/Cbetula/lanterndesk/releases/tag/lanterndesk-v0.1.1)。
- 构建使用固定 Flutter / Rust / NASM / vcpkg 版本、原桥接归档和已有 Dart 依赖锁；未运行桥接生成器，未修改源码锁文件或子模块。
- 最低系统 macOS 13，使用软件视频编解码。未使用 Apple Developer ID 签名或公证；未完成真实 Mac 桌面启动、系统权限、双机远控及开机服务的实机验收。

## 现有文件与运行路径的改动

| 现有文件 | 改动范围及必要原因 |
| --- | --- |
| `src/lib.rs` | 声明新的 `lantern` 模块，使品牌默认值集中在独立文件。 |
| `src/common.rs` | 在现有自定义客户端初始化入口加入一行调用，设置应用名并关闭现成的账户入口。该入口覆盖桌面、服务及 Flutter 初始化。 |
| `src/lantern.rs` | 0.1.2 将显式自建服务器选择集中于此，空配置不返回服务器，默认开启可关闭的 IP 监听，并禁用公共 STUN 相关选项。 |
| `src/common.rs`（0.1.2） | NAT、在线查询和 TCP API 代理改用显式服务器；空配置停止探测，移除公共 API 默认值，禁止后台 IPv6 公共 STUN 探测。保留原有消息及连接实现。 |
| `src/client.rs` | IP 直连保留原路径；ID 连接在未配置服务器时给出明确提示，拒绝公共 ID／中继地址，避免显式 `@public` 绕过。 |
| `src/ipc.rs` | 服务端和 UI 使用同一自建服务器选择，空列表保持为空，过滤旧进程返回的公共地址，避免 IPC 回退恢复公共默认值。 |
| `src/rendezvous_mediator.rs` | 仅向显式自建地址注册；拒绝公共中继地址，并在被控端也禁止自动启动依赖公共 STUN 的 WebRTC。 |
| `src/ui_interface.rs` | 移动端服务器列表和更改设备 ID 使用同一选择；无 ID 服务时返回配置提示，避免将空服务器列表误当作成功。 |
| `src/lang/*.rs`（除 `en.rs`） | 追加一条配置提示键，提供简体中文，其余留空；既有译文不变。 |
| `src/server/dbus.rs` | 使用独立的 Linux DBus 名称，防止与原版同时运行时连接请求发到另一款程序；同步修正文档示例命令。 |
| `flutter/linux/CMakeLists.txt` | 修改 Linux 可执行文件名与 GTK 应用 ID，让系统识别 LanternDesk。内部桥接库名称不变。 |
| `.gitignore` | 排除编译产物 `dist/`，避免二进制包进入源码提交。 |
| `README.md` | 在原文前添加本项目定位、构建和中转指令，并保留上游说明与归属。 |
| `.github/workflows/flutter-nightly.yml` | 移除自动定时触发，避免新私有仓库自动运行上游全平台发布任务；保留手动入口。 |
| `.github/workflows/update-webpki-roots.yml` | 移除自动定时触发，避免未经配置的副本定期创建更新分支；保留手动入口。 |
| `flutter/macos/Runner/Configs/AppInfo.xcconfig` | 独立应用名和 bundle ID，输出 LanternDesk.app。 |
| `flutter/macos/Runner.xcodeproj/project.pbxproj` | 同步产品与 bundle ID，移除上游开发者团队，最低系统设为 macOS 13 以匹配原生依赖及 ScreenCaptureKit。 |
| `flutter/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | 同步应用产物名称，供 Xcode 构建和启动定位。 |
| `flutter/macos/Runner/Info.plist` | 注册独立的 lanterndesk URL scheme，避免与官方应用冲突。 |
| `flutter/macos/Podfile` | 原生插件最低系统与 Mac 应用保持一致。 |

新逻辑集中在 `src/lantern.rs`、`scripts/`、`deploy/relay/`、`packaging/` 和独立的 macOS 构建工作流。0.1.2 的回归范围是服务器选择、空配置处理、传输开关，以及下列首页和密码界面。会话消息、密码哈希与认证协议、输入注入和屏幕捕获沿用原实现。不改动共享类型、函数签名或子模块，原版目录保持干净。

### 首页 IP 和固定密码改动

| 现有文件／运行路径 | 必要改动 |
| --- | --- |
| `src/lantern.rs` | 新增只读网络信息，返回本机 IPv4、直连端口和开关。 |
| `src/platform/mod.rs` | 声明独立的 `lantern_network` 模块；Unix 使用本机 `getifaddrs` 枚举，避免默认路由库探测公共 IP。Windows 使用已有的系统网卡 API 封装。 |
| `src/flutter_ffi.rs` | 现有通用查询增加两个键，将网络信息及是否配置自建 ID 服务器传给界面；桥接接口不变。 |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | ID 下方新增可复制、可滚动的 IP 栏，复用原定时刷新；固定密码保存取消复杂度、长度和空格裁剪规则，保留非空、确认匹配、保存失败提示和显式移除。移动端复用的密码对话框同步生效。 |
| `flutter/lib/desktop/pages/connection_page.dart` | 无自建 ID 服务器时显示 IP 直连提示，状态文字允许换行以免溢出；已有服务停止提示优先。 |
| `flutter/lib/common/widgets/dialog.dart` | 远程认证输入保留原密码首尾空格，确保新允许的密码可用于连接。操作系统登录输入沿用原处理。 |
| `flutter/lib/web/bridge.dart` | 新查询在不支持本机网卡的 Web 端返回兼容值，保持原显示路径。 |
| `src/lang/*.rs` | 仅追加四个新提示，简体中文提供译文，其余留空。 |

新增密码校验集中在 `flutter/lib/common/lantern_password.dart`，`flutter/test/lantern_password_test.dart` 两项测试覆盖短密码、纯数字、Unicode、空格及长密码可保存，空密码与确认不一致被拒绝。此轮没有编译 Mac 版，相关工作流已取消，后续由维护者在 Mac 编译并发布。

## 当前范围

- 交付目标为 Ubuntu 24.04+、x86_64 的便携 Flutter 桌面程序，使用软件视频编解码；没有启用硬件编解码。
- 未提供公网服务器，因此没有代为部署公网中转；实际公网防火墙、安全组、双机桌面连接和 Wayland 权限流程仍需在目标环境验证。
- macOS 已完成上述双架构构建检查，实机验收仍待完成；Windows 及移动端保留上游源码，本次没有编译或实机验收。
- 自建中转仍需在两个客户端导入一次服务器配置。免账户不等于免远端授权，访问密码 / 对端确认沿用原版。
