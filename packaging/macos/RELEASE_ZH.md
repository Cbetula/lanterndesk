LanternDesk（灯塔桌面）仅使用自己的 ID／中继服务器或 IP 直连。此版修正了旧版本保留 RustDesk 公共服务器默认值的问题，并禁用依赖公共 STUN 的 IPv6 打洞和 WebRTC。

未配置服务器时可输入被控端的可达 IP 直连（默认 TCP 21118）。设备 ID 连接必须配置自己的 hbbs/hbbr；空配置、旧公共地址缓存和 `<id>@public` 均不会回退到公共服务器。仍然需要访问密码或被控端确认。

[Linux x86_64 编译包](https://github.com/Cbetula/lanterndesk/raw/refs/tags/codex/private-network-artifacts/lanterndesk-v0.1.2-linux-x86_64.tar.gz) · [Linux SHA-256](https://github.com/Cbetula/lanterndesk/raw/refs/tags/codex/private-network-artifacts/lanterndesk-v0.1.2-linux-x86_64.tar.gz.sha256)。Linux 包面向 Ubuntu 24.04+，解压后运行目录内的 `./lanterndesk`。

macOS 安装包：

- Apple Silicon（M 系列）：下载 `lanterndesk-macos-arm64.dmg`。
- Intel Mac：下载 `lanterndesk-macos-x86_64.dmg`。
- 系统要求：macOS 13 或更新版本；使用软件视频编解码。
- 内部版本沿用上游 `1.5.1`。

打开 DMG，将 `LanternDesk.app` 拖入“应用程序”。此包使用 ad-hoc 临时签名，未经过 Apple Developer ID 签名和公证；首次启动可能需要在“系统设置 → 隐私与安全性”中手动允许。无需关闭系统安全保护。

被控 Mac 需授予屏幕录制与辅助功能权限，键鼠输入异常时按提示开启输入监控。两端使用自建中转时填入相同 ID 服务器、中继服务器与公钥，API 服务器留空。

在包含下载文件的目录校验：

```bash
shasum -a 256 -c lanterndesk-macos-arm64.dmg.sha256
# Intel 包改用对应 x86_64 校验文件。
```

构建检查包括应用身份、可执行文件架构、版本号、临时签名完整性、DMG 完整性与 SHA-256；不代表完成真实双机远控或系统权限流程验收。

[Mac 本机构建说明](https://github.com/Cbetula/lanterndesk/blob/main/packaging/macos/README.md) · [Linux 中转部署](https://github.com/Cbetula/lanterndesk/blob/main/docs/RELAY_ZH.md)
