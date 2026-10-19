# LanternDesk Linux 中转部署

LanternDesk 可以直接用远端 ID 和远端密码连接，不需要注册或登录账号。自建服务器运行两个开源组件：`hbbs` 负责 ID 注册和连接协商，`hbbr` 在直接连接失败时转发流量。控制端与被控端都要使用同一套服务器配置；被控端仍需批准连接或提供密码。

## 克隆后，一条指令完成配置

在具有公网 IPv4 或域名的 Debian / Ubuntu Linux 服务器上执行。私有仓库需要先配置你的 GitHub 访问权限：

```bash
git clone --recurse-submodules https://github.com/Cbetula/lanterndesk.git
cd lanterndesk
sudo bash scripts/setup-relay.sh --host YOUR_SERVER_IP_OR_DOMAIN
```

将 `YOUR_SERVER_IP_OR_DOMAIN` 替换为客户端能够访问的服务器 IPv4 或域名，例如 `203.0.113.10` 或 `relay.example.com`。不要带 `https://` 或端口。域名应解析到服务器，不能使用 HTTP/CDN 代理。如果服务器位于路由器后，需要把下表端口转发到它。

脚本使用发行版软件包安装缺少的 Docker 和 Compose，启用 Docker 开机启动，拉取固定版本 `rustdesk/rustdesk-server:1.1.16`，然后启动中转与 ID 服务。两个容器都设置了自动重启。安装文件默认存放在 `/opt/lanterndesk-relay`，与 Git 仓库分离。重复运行保留现有密钥与数据库。

服务端需要允许以下入站端口；脚本不修改防火墙或云安全组：

| 协议 | 端口 | 用途 |
| --- | --- | --- |
| TCP | 21115 | NAT 类型检测 |
| TCP + UDP | 21116 | ID 注册、心跳及连接协商 |
| TCP | 21117 | 桌面流量中转 |

当前部署只开放桌面客户端端口，不开放 WebSocket 的 21118/21119 或专业版管理端口。端口用途参见 [RustDesk 官方 Docker 部署文档](https://rustdesk.com/docs/en/self-host/rustdesk-server-oss/docker/)。

## 客户端一次性配置

安装完成后，终端会输出以下内容：

- ID 服务器：`你的服务器:21116`
- 中转服务器：`你的服务器:21117`
- API 服务器：留空
- Key：服务器自动生成的公钥

在**两端** LanternDesk 的“设置 → 网络 → ID/中继服务器”中填入这些值。也可以复制 `/opt/lanterndesk-relay/client-config.txt` 的整行内容，再点击客户端的“导入服务器配置”。`client-config.json` 是同一配置的可读版本，也支持导入。导入格式与本项目 `flutter/lib/common.dart` 中 `ServerConfig.decode` 一致。

配置完成后连接远端 ID，使用远端显示的密码，或由远端确认连接。直接连接不可用时自动使用中转；若希望验证中转，可在客户端连接选项中开启“始终通过中继连接”。安装成功只说明本机服务已启动，公网端口仍需从另一台机器验证。

## 日常管理与备份

以下命令使用 Compose v2；如果脚本使用了发行版的 `docker-compose`，将 `docker compose` 换为 `docker-compose`。安装结束时也会输出适合当前机器的完整命令。

```bash
sudo docker compose --project-name lanterndesk-relay -f /opt/lanterndesk-relay/compose.yaml ps
sudo docker compose --project-name lanterndesk-relay -f /opt/lanterndesk-relay/compose.yaml logs --tail=100
sudo docker compose --project-name lanterndesk-relay -f /opt/lanterndesk-relay/compose.yaml restart
sudo docker compose --project-name lanterndesk-relay -f /opt/lanterndesk-relay/compose.yaml stop
```

迁移前先停止服务，完整备份 `/opt/lanterndesk-relay/data`，然后在新服务器恢复该目录。`id_ed25519` 是服务器私钥，`id_ed25519.pub` 是公钥；两个服务共用这对密钥，脚本不会删除或重新生成已存在的密钥。只有私钥或公钥时，脚本会报错并要求恢复完整备份。不要把 `data` 目录上传到 GitHub。

服务器地址变化时，用新 `--host` 再次运行安装命令，然后更新两端客户端配置。保持原密钥可避免客户端 Key 变化。

## 无安装预览与自定义目录

```bash
# 不需要 root，不安装软件、不连接 Docker、不启动服务。
bash scripts/setup-relay.sh --host relay.example.com --render-only

# 自定义持久化目录；之后重复部署须使用同一个目录。
sudo bash scripts/setup-relay.sh --host relay.example.com --dir /srv/lanterndesk-relay

bash scripts/setup-relay.sh --help
```

自动安装依赖需要 Debian / Ubuntu、`apt-get` 和 systemd。其他 Linux 发行版可先自行安装 Docker 与 Compose，再运行脚本。当前 `--host` 支持 IPv4 和域名，不接受 IPv6 字面地址。本脚本部署单台 ID/中转服务器，不能在同一主机并行部署多份占用相同端口的实例。

## 版本与协议依据

- [RustDesk Server 1.1.16 官方发行说明](https://github.com/rustdesk/rustdesk-server/releases/tag/1.1.16)：本部署固定使用该 OSS 版本，不随 `latest` 自动变化。
- [官方 Docker 部署说明](https://rustdesk.com/docs/en/self-host/rustdesk-server-oss/docker/)：服务职责、持久化目录及端口说明。
- [官方服务器配置说明](https://github.com/rustdesk/rustdesk-server/blob/master/docs/environment-variables.md#keys-and-encryption)：`-k _` 读取或生成本地密钥并启用客户端密钥验证。此部署对 `hbbs` 和 `hbbr` 都启用了该选项。
