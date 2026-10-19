LanternDesk（灯塔桌面）macOS 版，无需注册或登录账户，兼容 RustDesk 的 ID、密码/确认与中转协议。

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
