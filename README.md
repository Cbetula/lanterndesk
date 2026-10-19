# LanternDesk 0.1.2 Linux desktop

Self-hosted ID/relay servers or direct IP only. No default public rendezvous, relay, or STUN services.

Source: [d21934428](https://github.com/Cbetula/lanterndesk/commit/d21934428). The archive contains the application, AGPL license and dependency notices.

首页 ID 下方新增 IP 栏，点击可复制 IP:端口，多网卡可滚动选择。未配置自建服务器时提示使用 IP 直连。固定密码只要求非空、两次输入一致，取消复杂度和长度限制，保留首尾空格。

Requires Ubuntu 24.04+ / x86_64. Extract the archive, keep `lib/` and `data/`, then run `./lanterndesk`. Direct IP listens on TCP 21118 by default and still requires a password or remote confirmation.

本次只更新 Linux 包。Mac 由维护者在 Mac 本机运行 `scripts/build-macos.sh` 后发布。

[Build and verification](https://github.com/Cbetula/lanterndesk/blob/main/docs/VALIDATION_ZH.md).
