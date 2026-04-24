# LuCI App TeamTalk5

OpenWRT LuCI 管理界面，用于管理 TeamTalk5 即时通讯服务器的 Docker 容器。

## 支持的 Docker 镜像

本应用支持 **deepcomp/tt5srv** 镜像，这是 BearWare TeamTalk5 服务器的 Docker 镜像。

### 镜像特性

| 特性 | 支持情况 |
|------|----------|
| AMD64 (x86_64) | ✅ 支持 |
| ARM64 | ✅ 支持 |
| ARMHF (ARMv7) | ✅ 支持 |
| 网络模式 | Host 模式 |
| 配置文件 | /srv/ttd.json |

## 系统要求

- OpenWRT 18.06 或更高版本
- Docker 和 luci-lib-docker 软件包
- TeamTalk5 Docker 镜像：`deepcomp/tt5srv`

## 功能特性

- **Docker 环境检测**：自动检测 Docker 是否已安装
- **一键安装 Docker**：如果没有安装 Docker，提供安装按钮
- **镜像管理**：拉取、查看、删除 Docker 镜像
- **容器管理**：部署、启动、停止、重启、删除容器
- **配置管理**：配置时区、文件所有者、存储路径等
- **设置向导**：运行 TeamTalk5 设置向导创建新配置
- **状态监控**：实时查看服务运行状态
- **日志查看**：查看容器日志和服务器日志
- **多语言支持**：简体中文、英文

## 安装

### 依赖安装

```bash
opkg update
opkg install docker luci-lib-docker
```

### 编译进 OpenWRT

```bash
# 将此包放入 OpenWRT packages 目录
cd lede/package/feeds/packages
git clone https://github.com/your-repo/luci-app-teamtalk.git

# 编译
make menuconfig
# 选择 LuCI -> Applications -> luci-app-teamtalk
make -j$(nproc)
```

### 手动安装 ipk

```bash
opkg install luci-app-teamtalk_*.ipk
```

## 使用方法

1. 访问 OpenWRT Web 管理界面
2. 进入 **服务** -> **TeamTalk**
3. 如果 Docker 未安装，点击 **Install Docker** 按钮
4. 配置 TeamTalk 参数（时区、PUID、PGID、存储路径等）
5. 点击 **Pull Image** 下载 TeamTalk5 Docker 镜像
6. 如果没有配置文件，点击 **Run Setup Wizard** 运行设置向导
7. 点击 **Deploy Container** 部署并启动 TeamTalk5 服务

## 配置说明

### 基本设置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 启用 | off | 是否启动 TeamTalk |
| Docker 镜像 | deepcomp/tt5srv:latest | TeamTalk5 镜像 |
| 容器名称 | tt5srv | Docker 容器名 |
| 架构 | amd64 | 目标架构 |

### 服务器设置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 服务器名称 | TeamTalk Server | 服务器显示名称 |
| MOTD | Welcome to TeamTalk Server | 登录消息 |
| 最大用户数 | 1000 | 同时在线用户上限 |
| 用户超时 | 60 | 空闲用户断开时间（秒） |
| 自动保存 | 开启 | 自动保存配置变更 |

### 登录限制

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 登录尝试次数 | 0 | 0=无限制 |
| 单IP最大登录数 | 0 | 0=无限制 |
| 登录延迟 | 0 | 毫秒，0=无延迟 |

### 端口设置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| TCP 端口 | 10333 | TeamTalk TCP 服务端口 |
| UDP 端口 | 10333 | TeamTalk UDP 服务端口（语音） |
| 启用 HTTP | 关闭 | HTTP 管理界面开关 |
| HTTP 端口 | 10334 | HTTP 管理界面端口 |

### 文件存储设置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 文件根目录 | /mnt/teamtalk/srv/files | 文件存储根目录 |
| 最大磁盘使用 | 0 | MB，0=无限制 |
| 频道磁盘配额 | 0 | MB/频道，0=无限制 |

### 系统设置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 时区 | Asia/Shanghai | 服务器时区 |
| 文件所有者 UID | 1000 | 配置文件的用户ID |
| 文件所有者 GID | 1000 | 配置文件的组ID |

### 音频编码设置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| Codec Type | 3 (Opus) | 音频编码器类型 |
| Sample Rate | 48000 Hz | 采样率 |
| Channels | 2 (Stereo) | 声道数 |
| Bitrate | 128000 (128 Kbps) | 比特率 |
| Complexity | 10 | 编码复杂度 |

### 用户管理

| 功能 | 说明 |
|------|------|
| 添加用户 | 创建新用户账户 |
| 编辑用户 | 修改用户名、类型、初始频道 |
| 修改密码 | 更改用户密码 |
| 删除用户 | 删除用户账户 |
| 账户类型 | Admin (管理员) / User (普通用户) |

### 存储路径

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| SRV 目录 | /mnt/teamtalk/srv | TeamTalk 配置和数据目录 |

## 网络模式

本镜像使用 **Host 网络模式** (`network_mode: host`)，这意味着：

- TeamTalk5 服务器直接使用主机网络
- 不需要进行端口映射
- TeamTalk 默认端口：
  - TCP 10333 - TeamTalk 主服务
  - UDP 10333 - TeamTalk 语音服务
  - TCP 10334 - HTTP 管理界面

## 设置向导

如果还没有 TeamTalk5 配置文件，可以运行设置向导：

```bash
docker run -v $PWD/srv:/srv --rm -it --entrypoint tt5srv deepcomp/tt5srv:latest -wizard -wd /srv
```

设置向导会要求输入：
- 服务器名称
- 管理账户用户名和密码
- 音频编码器设置
- 是否启用视频
- 等

## 目录结构

```
luci-app-teamtalk/
├── Makefile                      # OpenWRT 包 Makefile
├── luasrc/
│   └── view/
│       └── teamtalk/             # 视图模板
│           ├── header.htm
│           ├── index.htm
│           ├── status.htm        # 状态页面
│           ├── config.htm        # 配置页面
│           ├── users.htm         # 用户管理
│           ├── logs.htm          # 日志查看
│           └── docker_action.htm # Docker 操作
├── usr/
│   └── lib/
│       └── lua/
│           └── luci/
│               ├── controller/
│               │   └── teamtalk.lua    # 控制器
│               └── model/
│                   └── cbi/
│                       └── teamtalk.lua  # CBI 模型
├── htdocs/
│   └── adminkit/
│       └── js/
│           └── teamtalk.js       # 前端 JavaScript
├── root/
│   ├── etc/
│   │   └── config/
│   │       └── teamtalk          # UCI 配置文件
│   ├── etc/
│   │   └── init.d/
│   │       └── teamtalk          # 初始化脚本
│   └── usr/
│       └── libexec/
│           └── teamtalk/
│               └── teamtalk-helper.sh  # 辅助脚本
└── po/
    ├── zh-cn/
    │   └── teamtalk.po           # 中文翻译
    └── en/
        └── teamtalk.po           # 英文翻译
```

## API 接口

可通过 AJAX 调用以下接口：

```
/admin/services/teamtalk/docker_action?action=check_docker
/admin/services/teamtalk/docker_action?action=install_docker
/admin/services/teamtalk/docker_action?action=pull&image=<image_name>
/admin/services/teamtalk/docker_action?action=deploy
/admin/services/teamtalk/docker_action?action=setup_wizard
/admin/services/teamtalk/docker_action?action=start&name=<container_name>
/admin/services/teamtalk/docker_action?action=stop&name=<container_name>
/admin/services/teamtalk/docker_action?action=restart&name=<container_name>
/admin/services/teamtalk/docker_action?action=remove&name=<container_name>
/admin/services/teamtalk/docker_action?action=get_logs&lines=<number>
/admin/services/teamtalk/docker_action?action=status
/admin/services/teamtalk/docker_action?action=get_config_file
/admin/services/teamtalk/docker_action?action=exec&cmd=<command>
```

## 默认端口

| 服务 | 端口 | 协议 |
|------|------|------|
| TeamTalk 主服务 | 10333 | TCP/UDP |
| HTTP 管理界面 | 10334 | TCP |

## 语言切换

在 OpenWRT Web 界面的 **系统** -> **语言** 中切换界面语言。

## 常见问题

### Q: Docker 安装失败怎么办？

A: 检查网络连接，确保 OpenWRT 可以访问外网下载软件包：
```bash
opkg update
opkg install docker
```

### Q: 端口被占用怎么办？

A: 在配置页面可以使用以下功能：
1. 点击 **Check Now** 检查当前端口是否可用
2. 点击 **Find Available Port** 自动查找可用端口
3. 修改端口配置后重新部署

或者手动检查：
```bash
netstat -tln | grep 10333
netstat -ulnp | grep 10333
```

### Q: 如何查看详细日志？

A: 在 TeamTalk 日志页面查看，或使用命令：
```bash
docker logs tt5srv
```

### Q: 如何在 x86_64 OpenWRT 上运行？

A: 可以运行。Docker 容器运行在宿主机的内核上，与 OpenWRT 的 musl libc 无关。x86_64 架构能完全支持 amd64 镜像。

### Q: ARM 架构的 OpenWRT 能运行吗？

A: 可以。这个镜像支持 amd64、arm64、armhf 三种架构。根据你的设备架构选择对应版本。

## 许可证

Apache-2.0

## 参考项目

- [TeamTalk5 Docker Image](https://hub.docker.com/r/deepcomp/tt5srv) - BearWare TeamTalk5 服务器 Docker 镜像
- [BearWare TeamTalk](https://bearware.dk/teamtalk/) - 官方 TeamTalk 网站
- [LuCI](https://github.com/openwrt/luci) - OpenWRT Web 管理界面
