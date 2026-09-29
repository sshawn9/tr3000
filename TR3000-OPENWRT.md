# Cudy TR3000：官方 OpenWrt 使用与恢复参考

适用设备：Cudy TR3000 v1，官方 `cudy,tr3000-v1-ubootmod` 布局。

基础参考版本：OpenWrt `v25.12.5`。容量示例取自 2026-09-16 的设备实测；第 6 节补充 2026-09-30 从该版引导更新到自编译 BL2 的操作记录。当前容量以设备输出为准，其他版本的行为需核对对应源码。

普通系统升级见第 4 节，电脑网络与 TFTP 服务准备见第 5 节，无串口、通过 SSH 安排 U-Boot 更新 BL2 见第 6 节。

## 1. 设备身份与固件选择

选固件时，需要同时匹配硬件型号和已经使用的启动布局。

| 项目 | 本机对应值 | 用途 |
| --- | --- | --- |
| 硬件 | Cudy TR3000 v1，128 MiB NAND、512 MiB RAM | 判断实际设备，不将参数推广到其他硬件版本 |
| OpenWrt target/subtarget | `mediatek/filogic` | 查找官方镜像、编译目标 |
| 系统板名 | `cudy,tr3000-v1-ubootmod` | 在运行中的系统上核对布局身份 |
| 镜像设备名 | `cudy_tr3000-v1-ubootmod` | 核对镜像文件名；这里使用下划线，板名使用逗号 |
| 正式系统根设备 | 启动参数为 `root=/dev/fit0 rootwait` | 帮助识别正式系统的启动路径 |

在路由器上查看：

```sh
ubus call system board
cat /tmp/sysinfo/board_name
cat /proc/cmdline
```

同样写着 TR3000 的镜像，若不对应 `v1-ubootmod`，不能只凭型号相似就使用。普通系统升级使用匹配此设备的 sysupgrade 镜像，不需要重写 BL2/FIP，也不需要手动格式化 UBI。

源码依据：[设备 DTS](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts)、[镜像定义中的 `Device/cudy_tr3000-v1-ubootmod`](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/image/filogic.mk)。

## 2. 四种镜像分别做什么

| 文件后缀 | 实际作用 | 使用场景 |
| --- | --- | --- |
| `squashfs-sysupgrade.itb` | 安装内核和正式系统文件 | 当前官方布局下的系统升级、重新安装 |
| `initramfs-recovery.itb` | 启动一个以 RAM 为根文件系统的临时系统 | 正式系统不能启动时进行检查、备份和修复 |
| `preloader.bin` | BL2，早期启动和硬件初始化组件，包括 DDR 参数 | 日常系统升级不使用；确需更新内存初始化参数时见第 6 节 |
| `bl31-uboot.fip` | BL31、U-Boot 等引导组件的封装 | 引导链维护资料，日常系统升级不使用 |

`.itb` 是 FIT 镜像封装；恢复镜像和正式镜像虽然扩展名相同，用途并不相同。RAM 系统中的 `/tmp` 和其他内存文件会随重启消失；从 RAM 系统启动成功，也不等于正式固件已经安装到 NAND。

官方发布目录：[OpenWrt 25.12.5 / mediatek / filogic](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/)。这只是一个固定版本的来源，选其他版本时应使用对应版本的镜像、校验表和升级说明。

### 25.12.5 镜像识别基线

以下文件共有前缀 `openwrt-25.12.5-mediatek-filogic-cudy_tr3000-v1-ubootmod-`。下列大小和 SHA256 仅适用于这些官方发布文件，不适用于自编译镜像。

| 后缀 | 文件大小（字节） | SHA256 |
| --- | ---: | --- |
| [preloader.bin](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/openwrt-25.12.5-mediatek-filogic-cudy_tr3000-v1-ubootmod-preloader.bin) | 230232 | `e6669e18443c547c2feb44266ea524d7d6e2d32e546a6046e57c3845c941f9b8` |
| [bl31-uboot.fip](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/openwrt-25.12.5-mediatek-filogic-cudy_tr3000-v1-ubootmod-bl31-uboot.fip) | 804580 | `8213c5e4c5a4d81a6408fbf8d04d24f14e63b94b3cb2b2d8193b9e4e852f5eb4` |
| [initramfs-recovery.itb](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/openwrt-25.12.5-mediatek-filogic-cudy_tr3000-v1-ubootmod-initramfs-recovery.itb) | 9240576 | `5445b29a99501b5fb844445cd566a68395f15bfa0c487898f0d3fc1b75d534ae` |
| [squashfs-sysupgrade.itb](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/openwrt-25.12.5-mediatek-filogic-cudy_tr3000-v1-ubootmod-squashfs-sysupgrade.itb) | 11129118 | `b7341cf1c21f17f3e7e5871661cc333ef41d079cb405d74916f4e0c16fdae527` |

来源：[官方校验表](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/sha256sums)。哈希用于核对文件字节是否一致；它不能单独证明固件适合当前设备或配置。

## 3. NAND 分区、UBI 卷和可写空间

### 分区是固定的区域

下表为 OpenWrt v25.12.5 的设备分区布局。实际操作前应按分区名称和当前系统输出确认 MTD 编号。

| MTD 编号 | 名称 | 起点 | 长度 | 内容 |
| --- | --- | --- | --- | --- |
| mtd0 | BL2 | `0x000000` | `0x100000`，1 MiB | 早期引导程序 |
| mtd1 | u-boot-env | `0x100000` | `0x080000`，512 KiB | 保留的独立分区；本版官方 U-Boot 的环境存储使用下方 UBI 卷 |
| mtd2 | Factory | `0x180000` | `0x200000`，2 MiB | 无线 EEPROM、校准资料 |
| mtd3 | bdinfo | `0x380000` | `0x040000`，256 KiB | 设备信息，包括 MAC 地址来源 |
| mtd4 | FIP | `0x3c0000` | `0x200000`，2 MiB | 引导组件 |
| mtd5 | ubi | `0x5c0000` | `0x7a40000`，122.25 MiB | 环境卷、正式固件和可写数据所在区域 |

`Factory` 和 `bdinfo` 中有本设备专属资料，重新编译通用固件不能生成这些内容。设备树从 Factory 读取无线 EEPROM，从 bdinfo 的 `0xde00` 偏移读取 MAC 地址基值。

源码依据：[共用设备树](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dtsi)、[ubootmod 分区定义](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts)。

### UBI 卷是 `ubi` 分区里面的逻辑存储

| 卷名 | 作用 |
| --- | --- |
| `ubootenv`、`ubootenv2` | U-Boot 环境及冗余副本 |
| `fit` | 正式系统镜像，供启动过程及 `/dev/fit0` 使用 |
| `rootfs_data` | 持久化修改，包括配置、额外安装的软件和文件 |
| `recovery` | 某些恢复操作可能创建的恢复镜像卷；不是每台机器都必须有 |

卷编号和大小不应写死为后续操作条件。2026-09-16 的实测是：环境卷 ID 0/1，各 248 KiB；`fit` 为 ID 2，88 个 LEB；`rootfs_data` 为 ID 3，860 个 LEB。LEB 是 UBI 可供上层使用的逻辑擦除块，当时每个为 124 KiB。

环境数据长度和卷的分配容量是两个概念。本版 TR3000 的环境数据长度为 `0x1f000`，即 124 KiB；申请一个 128 KiB 的 UBI 卷时，因为容量按 124 KiB 的 LEB 向上取整，实际会分配 2 个 LEB，显示为 248 KiB。U-Boot 自动创建环境卷时申请的 1 MiB 是预留策略，不代表环境数据必须占满 1 MiB。不能只因为环境卷显示 248 KiB，就判断它小于要求或需要重建。

源码依据：[U-Boot 环境长度配置](https://github.com/u-boot/u-boot/blob/v2025.10/env/Kconfig)、[UBI 环境读写实现](https://github.com/u-boot/u-boot/blob/v2025.10/env/ubi.c)、[OpenWrt 环境访问参数](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-tools/uboot-envtools/files/uboot-envtools.sh)。

当时 `df` 显示 `/overlay` 总量约 **94.3 MiB**，验收时可用约 **89.5 MiB**。122.25 MiB 是整个 UBI 分区，里面还要容纳固件、环境、坏块预留和文件系统开销；它不是净可写容量。更换固件后，固件体积和可写容量都可能改变。

在路由器上检查当前值：

```sh
cat /proc/mtd
ubinfo -a
mount
df -h /overlay
```

`ubinfo` 需要系统已有对应工具。命令不存在时不能据此判断 UBI 损坏，可先查看 `/proc/mtd`、挂载信息和 `/sys/class/ubi/`。

### NAND 读取结果的含义

NAND 分区长度不一定等于导出文件长度，需要结合读取工具的坏块处理方式判断：

| 项目 | 含义 |
| --- | --- |
| `skipbad` | 跳过驱动报告的坏块，只输出好块数据，因此文件可能比完整分区短 |
| `padbad` | 用 `0xFF` 为坏块占位，保留后续数据在当前 MTD 视图中的偏移；不包含坏块原有内容，也不修复坏块 |
| OOB | NAND 页附带的纠错、坏块标记等区域；省略 OOB 的转储不包含这些数据 |
| 运行中的 UBI | 内容可能在读取期间变化，顺序读取不能保证得到同一时刻的完整状态 |

工具看到的是内核驱动暴露的 MTD 数据视图。如果存在坏块映射层，报告和偏移还受该层影响，不能直接等同于裸芯片物理布局。使用 `nanddump --help` 确认安装版本的默认选项；不能只凭文件大小判断读取成功，也不能为了凑齐大小而改变坏块模式。

源码依据：[mtd-utils 的 nanddump 实现](https://github.com/sigma-star/mtd-utils/blob/master/nand-utils/nanddump.c)。

## 4. 官方布局下的日常升级

准备内容是当前设备备份、匹配的 sysupgrade 镜像和校验信息。镜像可以由电脑下载或编译，再通过局域网传给路由器，路由器本身不必能访问公网。

### 备份当前设置

路由器端：

```sh
sysupgrade -l
sysupgrade -b /tmp/tr3000-config.tar.gz
sha256sum /tmp/tr3000-config.tar.gz
```

`-l` 列出本次配置备份包含哪些文件，`-b` 创建归档，两者都不会刷写固件。这不是完整磁盘备份：应用数据库、订阅、自建目录等是否包含，要根据输出核对；软件包列表也不等于软件包程序本身。

把归档下载到电脑并核对哈希。只留在路由器 `/tmp` 的备份会在重启后消失。

### 上传并检查镜像

电脑端示例；将 `192.168.1.1` 换成当前正式系统地址，将本地文件换成实际选定的镜像：

```bash
sha256sum /absolute/path/to/firmware.itb
scp -O /absolute/path/to/firmware.itb root@192.168.1.1:/tmp/firmware.itb
```

`scp -O` 使用传统 SCP 协议，适用于目标未提供 SFTP 子系统、但提供 SCP 的情况。地址、端口和 SSH 身份按当前实际连接配置填写。

路由器端：

```sh
sha256sum /tmp/firmware.itb
sysupgrade -T /tmp/firmware.itb
```

两端哈希应一致，官方镜像还应对照对应发布版本的校验表。`-T` 只检查、不刷写；检查通过不能替代对板型、布局和版本兼容性的核对，也不能保证配置及第三方软件全部兼容。检查失败时查明原因，不用 `-F` 绕过。

### 是否保留配置由本次升级目的决定

以下是两种不同的执行方式，只选择其中一种；执行会启动实际升级并中断服务。

| 命令 | 实际结果 | 适用条件 |
| --- | --- | --- |
| `sysupgrade /tmp/firmware.itb` | 按 sysupgrade 的备份规则保留配置 | 目标版本支持该升级路径，且准备继续使用现有设置 |
| `sysupgrade -n /tmp/firmware.itb` | 不保留现有配置，使用新镜像内置设置 | 准备重新配置，或此次升级明确要求不保留设置 |

“保留配置”不等于保留原来所有额外安装的软件；`-n` 也不会抹掉自编译镜像本身内置的定制设置。升级后访问地址取决于保留的配置或镜像默认值，不一定是 `192.168.1.1`。

本板型的升级入口调用 `fit_do_upgrade`，再根据设备树中的 `rootdisk` 定位到 `ubi` 分区的 `fit` 卷，进入 NAND 升级流程。让匹配的官方升级程序处理卷更新，不额外执行首次迁移时的 BL2/FIP 写入或整区格式化操作。

源码依据：[sysupgrade 参数与备份逻辑](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/sbin/sysupgrade)、[平台入口](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh)、[FIT 升级实现](https://github.com/openwrt/openwrt/blob/v25.12.5/package/utils/fitblk/files/fit.sh)、[NAND 升级实现](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/lib/upgrade/nand.sh)。

## 5. 电脑网络与 TFTP 服务准备

TFTP 的作用是让仍能工作的 U-Boot 从电脑取得指定文件；后续是启动恢复系统还是写入 BL2，由 U-Boot 执行的命令决定。电脑必须提前准备好文件、有线地址和服务；仅在电脑启动 TFTP 服务，不会让一台正常启动的路由器自动进入恢复或刷写流程。

以下是已安装引导版本对应源码中的恢复默认值；第 6 节更新 BL2 时使用另一文件名。后续若修改过 U-Boot 环境，应以实际环境为准。

| 项目 | 默认值或要求 |
| --- | --- |
| U-Boot 的路由器地址 | `192.168.1.1` |
| 电脑 TFTP 地址 | `192.168.1.254/24` |
| 连接方式 | 电脑直连 TR3000 的 1G LAN 口 |
| 请求文件名 | `openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-initramfs-recovery.itb` |
| 文件内容 | 对应设备的 initramfs 恢复镜像，不能用 sysupgrade 镜像冒充 |

这个请求文件名**没有版本号**。例如把下载的 `openwrt-25.12.5-…-initramfs-recovery.itb` 复制到 TFTP 目录时，要改成表中的固定名称，文件内容不变。

### 电脑网络

为直连网卡配置 `192.168.1.254/24`，不为它增加默认网关；电脑正常上网可以继续走其他接口。使用 NetworkManager 时，`ipv4.never-default=yes` 可以避免这条连接成为默认路由。

以下命令适用于使用 NetworkManager 管理网络的电脑，以 `enp2s0` 为网卡名、`tr3000-direct` 为连接配置名。网卡名应按实际设备替换，连接配置名可自定义。

先查看实际网卡和已有连接：

```bash
nmcli device status
nmcli connection show
```

若尚未创建 `tr3000-direct`，在电脑上执行以下命令；`ifname` 后填写实际直连网卡。若已有同名连接，先用 `nmcli connection show tr3000-direct` 核对配置，不要重复创建。

```bash
sudo nmcli connection add \
  type ethernet \
  ifname enp2s0 \
  con-name tr3000-direct \
  ipv4.method manual \
  ipv4.addresses 192.168.1.254/24 \
  ipv4.never-default yes \
  ipv6.method disabled \
  connection.autoconnect yes \
  connection.autoconnect-priority 100
```

这会创建持久保存的直连配置，使用固定 IPv4 地址，不设置默认网关或 DNS，并禁用该连接的 IPv6。自动连接和优先级用于让网线断开后重新接通时优先选择它；不会主动替换同一网卡上已经激活的其他配置。

**已有连接也要检查自动连接设置。** 本次已有的 `tr3000-direct` 原来是 `autoconnect=no`、优先级 `0`，不能因为它已经存在，就跳过下面这一步。先记录原值，再为刷写期间启用自动连接：

```bash
nmcli -f connection.autoconnect,connection.autoconnect-priority,ipv4.addresses \
  connection show tr3000-direct
sudo nmcli connection modify tr3000-direct \
  connection.autoconnect yes connection.autoconnect-priority 100
```

本次正式系统通过 `root@10.0.0.1` 登录，电脑直连配置同时包含 `192.168.1.254/24` 和 `10.0.0.2/24`：前者用于 U-Boot TFTP，后者用于刷写前后的 SSH。U-Boot 地址不随 OpenWrt 的 LAN 地址改变。若当前连接缺少后一个地址，且确认 `10.0.0.2` 未被其他设备使用，再补充：

```bash
sudo nmcli connection modify tr3000-direct +ipv4.addresses 10.0.0.2/24
```

已有该地址时不重复添加；使用其他 LAN 网段的设备应换成对应地址。

插好 LAN 网线后，显式启用该连接，再检查地址和路由。启用操作会将这张网卡切换到直连配置：

```bash
sudo nmcli connection up tr3000-direct
nmcli -f NAME,DEVICE connection show --active
ip -4 addr show enp2s0
ip -4 route get 192.168.1.1 from 192.168.1.254
ip rule show
```

路由结果应走直连网卡。VPN、代理 TUN、其他网卡的同网段地址可能改变实际路径，不能只看网卡有没有 IP。路由器重启造成断链后，电脑还需要恢复该地址，TFTP 服务才能继续响应；正式操作前可用拔插 LAN 网线验证这一点。

若重启后没有 TFTP 请求，检查直连地址是否仍在、连接是否切回日常 DHCP 配置。没有启用自动连接可能导致断链后选错连接，但不能仅凭这一步遗漏就认定故障原因。结束后的恢复命令见本节“停止服务与清理临时规则”。

参数依据：[nmcli 命令说明](https://networkmanager.dev/docs/api/latest/nmcli.html)、[NetworkManager IPv4 设置](https://networkmanager.dev/docs/api/latest/settings-ipv4.html)、[自动连接与优先级](https://networkmanager.dev/docs/api/latest/settings-connection.html)。

### 准备文件与启动服务

电脑端；先替换第一行的恢复镜像路径：

```bash
recovery_image=/absolute/path/to/initramfs-recovery.itb
mkdir -p /tmp/tr3000-tftp
install -m 644 "$recovery_image" \
  /tmp/tr3000-tftp/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-initramfs-recovery.itb
sha256sum "$recovery_image" \
  /tmp/tr3000-tftp/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-initramfs-recovery.itb
```

两份文件的哈希应一致。以上是准备恢复镜像的示例；只更新 BL2 时，按第 6 节准备 preloader 即可，无需额外放入恢复镜像。

下面使用 dnsmasq 提供 TFTP 服务。电脑需要已有 dnsmasq；NixOS 可通过 `nix shell nixpkgs#dnsmasq --command bash` 临时进入带有该工具的环境。首次获取工具可能需要电脑联网，应在切换到没有默认网关的直连配置前完成。

先用 `ss -lun 'sport = :69 or sport = :10069'` 确认端口情况，再在单独终端启动；`enp2s0` 按实际网卡替换：

```bash
sudo "$(command -v dnsmasq)" \
  --keep-in-foreground \
  --conf-file=/dev/null \
  --port=0 \
  --interface=enp2s0 \
  --bind-dynamic \
  --enable-tftp=enp2s0 \
  --tftp-root=/tmp/tr3000-tftp \
  --tftp-port-range=10069,10069 \
  --pid-file=/tmp/tr3000-tftp.pid \
  --log-facility=-
```

这些参数只提供 TFTP，不启用 DNS 或 DHCP。UDP 69 接收初始请求，UDP 10069 是此示例指定的传输端口；只开放 69 可能导致“有请求却传不完”。防火墙需对直连接口放行相应流量。防火墙后端、链名和规则位置以电脑实际配置为准。

`--bind-dynamic` 用于跟随 Linux 接口地址变化。服务应在路由器进入恢复路径前运行，观察日志中的请求文件名和传输完成情况。选项说明见 [dnsmasq 官方手册](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)。

本次 dnsmasq 2.93 的启动日志中，`DNS disabled`、`TFTP root is /tmp/tr3000-tftp` 表示服务已启动；`restricting maximum simultaneous TFTP transfers to 1` 是单一传输端口带来的并发限制，不是错误。这些日志都不代表路由器已经下载文件。

修复网卡配置后，原服务仍运行时通常可以继续使用，不必重复启动。检查：

```bash
ss -lun 'sport = :69'
```

应看到 `192.168.1.254:69`。没有传输时，UDP 10069 不一定处于监听状态；不能据此认定服务异常。若目标地址没有监听，先检查网卡地址，再决定是否重启该实例。

### 确认 NixOS 防火墙后端与放行规则

本次电脑的 `iptables --version` 输出为 `iptables v1.8.13 (nf_tables)`，运行中的 `firewall.service` 使用 iptables 命令创建 `nixos-fw` 等链。这是 **iptables-nft 兼容接口使用 nftables 内核后端**，仍适用下面的 iptables 命令；不能把它与 NixOS 原生 nftables 防火墙配置混为一谈。

在电脑查看版本和服务定义：

```bash
iptables --version
systemctl cat firewall.service
```

以下示例仅适用于采用 NixOS iptables 防火墙、且实际存在 `nixos-fw` 和 `nixos-fw-accept` 两条链的电脑。先查看：

```bash
sudo iptables -w -nvL nixos-fw --line-numbers
sudo iptables -w -S nixos-fw
sudo iptables -w -S nixos-fw-accept
```

检查是否存在目标为 `nixos-fw-accept` 或 `ACCEPT`、入口为 `enp2s0` 或所有接口、协议为 UDP 且覆盖 69 和 10069 的规则。端口可以分别放行；接口全部放行的规则也可能覆盖它们。还要结合规则顺序和其他匹配条件判断，不能仅搜索端口数字。服务启动脚本不能代替对实时规则的检查。

确认后，只对直连网卡放行 TFTP 所需端口。将 `enp2s0` 换成实际接口；若已有下面这条规则，不要重复添加：

```bash
sudo iptables -w -I nixos-fw 1 -i enp2s0 -p udp \
  -m multiport --dports 69,10069 \
  -m comment --comment tr3000-tftp -j nixos-fw-accept
```

这是一条临时规则，防火墙重载可能清除它。若使用原生 nftables 防火墙，先用 `sudo nft list ruleset` 确认实际表、链与规则，不创建同名空链来套用命令。

如果需要长期保留，可以在 NixOS 配置中声明接口级端口，再按本机原有方式 rebuild；一次刷写不必同时采用临时规则和持久配置：

```nix
networking.firewall.interfaces.enp2s0.allowedUDPPorts = [ 69 10069 ];
```

源码依据：[NixOS iptables 防火墙模块](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/firewall-iptables.nix)；该分支会更新，应以电脑使用的 NixOS 版本为准。

### 验证完整传输

路由器已经运行、与电脑处于同一有线子网且已有 `atftp` 时，可以先下载一次恢复镜像，验证服务器、文件名和防火墙通路。这个测试只传文件，不启动镜像、不写闪存。

路由器端：

```sh
atftp --get \
  --remote-file openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-initramfs-recovery.itb \
  --local-file /tmp/tr3000-tftp-test.itb \
  192.168.1.254
sha256sum /tmp/tr3000-tftp-test.itb
```

结果应与电脑提供的恢复镜像哈希相同。仅 ping 通或日志出现一次请求，不代表整个文件已经传完。拔插 LAN 网线、等待地址恢复后再测试，可以检查断链后的服务可用性；这仍不代替实际 U-Boot 启动检查。

命令依据：[atftp 手册](https://manpages.debian.org/testing/atftp/atftp.1.en.html)。

### 停止服务与清理临时规则

本次使用 `--keep-in-foreground` 时按 Ctrl+C，终端显示 `^C`，但 dnsmasq 没有退出。该选项保留普通运行模式，不能把它等同于 `--no-daemon` 调试模式；[官方手册](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)说明 SIGINT 在调试模式下才保留终止进程的含义。这里使用 **SIGTERM** 停止指定实例，不以 `^C` 或终端是否返回提示符判断成功。

BL2 回读哈希匹配且系统正常启动后，可以停止提供该文件。先在电脑的另一个终端查看 PID 和启动参数：

```bash
tftp_pid=$(sudo cat /tmp/tr3000-tftp.pid)
ps -p "$tftp_pid" -o pid=,args=
```

确认该进程是上面启动的 dnsmasq，且参数包含 `--tftp-root=/tmp/tr3000-tftp`，再在同一个终端执行：

```bash
sudo kill -TERM "$tftp_pid"
ss -lun 'sport = :69 or sport = :10069'
```

PID 文件缺失、进程已退出或参数不匹配时，按当前进程状态查找，不把文件中的数字直接当作有效目标。确认本次服务已停止后，才能进行不依赖 TFTP 的启动验收。

如果添加过上一节的临时规则，用完全对应的条件删除它；接口名与添加时保持一致：

```bash
sudo iptables -w -D nixos-fw -i enp2s0 -p udp \
  -m multiport --dports 69,10069 \
  -m comment --comment tr3000-tftp -j nixos-fw-accept
```

最后恢复刷写前的网络偏好。本次 `tr3000-direct` 原值是关闭自动连接、优先级为 0：

```bash
sudo nmcli connection modify tr3000-direct \
  connection.autoconnect no connection.autoconnect-priority 0
```

这只影响后续自动连接，不会立即切换当前连接。若还要立即恢复本次使用的日常联网配置：

```bash
sudo nmcli connection up tr3000-internet
```

其他电脑应使用自己的日常连接名，并恢复之前记录的自动连接设置；不需要删除 `tr3000-direct`。

### 恢复分支的实际边界

该版 U-Boot 的默认启动顺序包含正式 `fit`、已有 `recovery` 和 TFTP 回退。启动阶段检测到 Reset 按键也有恢复分支；按键是否触发取决于引导阶段的检测，不能从该分支直接推导固定的按住时长。

TFTP 不等于始终只读：`boot_tftp` 是下载后启动；`boot_tftp_recovery` 在 `replacevol` 条件满足时还会写入 `recovery` 卷，而相应写入流程会移除 `rootfs_data`。环境卷初始化失败也有擦除 UBI 的回退分支。因此，看到 TFTP 下载不能推断持久化数据一定没有变化。

TFTP 恢复依赖引导程序及网络功能正常；引导程序本身损坏时，不能保证通过网线恢复。

源码依据：[固定版本 U-Boot 环境与启动逻辑](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/patches/445-add-cudy_tr3000-v1.patch)，对应 `boot_default`、`boot_ubi`、`boot_tftp*`、`ubi_write_recovery` 和 `ubi_create_env`。

## 6. 无串口，通过 SSH 安排 U-Boot TFTP 更新 BL2

本节记录 2026-09-30 的 BL2 更新。设备已经使用官方 `cudy,tr3000-v1-ubootmod` 布局，当前系统能通过 SSH 登录，没有连接 TTL 串口。它不适用于原厂布局迁移，也不能用来修复已经无法工作的 U-Boot。

普通 sysupgrade 不更新 BL2。此次编译的 `mt7981-cudy-ddr3` 启用了 `DDR3_FREQ_1866=1`，要使新的内存初始化参数在启动时使用，需要更新 `preloader.bin`。单纯通过 TFTP 启动 initramfs 并不会更新这些参数。本流程由 U-Boot 写入 BL2，Linux 下的分区只读限制不参与这次写入，因此不需要 `kmod-mtd-rw`，也不需要先进入恢复系统。

BL2 属于引导链，擦除或写入失败可能使下一次启动无法进入 U-Boot，届时不能依赖 TFTP 自行恢复。以下实际写入步骤应在镜像、备份和网络检查完成后执行，并保持供电。

### 本次设备与镜像记录

| 项目 | 本次值 |
| --- | --- |
| 更新前正式系统 | OpenWrt 25.12.5，内核 6.12.94，SSH 为 `root@10.0.0.1` |
| U-Boot / 电脑 TFTP 地址 | `192.168.1.1` / `192.168.1.254` |
| 电脑接口 / 直连配置 | `enp2s0` / `tr3000-direct`，额外保留 `10.0.0.2/24` 用于 SSH |
| 自编译 BL2 路径，相对项目根目录 | `output/targets/mediatek/filogic/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-preloader.bin` |
| 本次新旧 preloader 文件长度 | 均为 `230232` 字节；BL2 分区长度为 `1048576` 字节 |
| 更新前 BL2 有效镜像 SHA256 | `e6669e18443c547c2feb44266ea524d7d6e2d32e546a6046e57c3845c941f9b8` |
| 本次新 BL2 SHA256 | `bf40e2b1783012517d94f9fa9cc9905932ad91449b8d1667d5c7b025f824fd42` |

上面的旧哈希与第 2 节官方 25.12.5 preloader 一致。**新哈希和长度只对应本次产物，后续重新编译必须重新计算，不能直接沿用。** 本次最终观察到该 preloader 的 TFTP 发送成功日志，操作者随后确认 BL2 回读哈希匹配；这不等于已经安装自编译的正式系统，也不代替内存稳定性测试。

BL2、FIP 和正式系统不要求来自同一次编译，但需要兼容。本次核对到新旧 BL2 使用同一 TF-A 源码提交 `78a0dfd927bb00ce973a1f8eb4079df0f755887a`，FIP 偏移和长度仍为 `0x3c0000`、`0x200000`；现有 FIP 的哈希与第 2 节官方文件一致。基于这些核对，本次保留现有 FIP 和系统，仅更新 BL2；不能将这个结论推广到不同布局或任意版本组合。

构建定义可对照 [25.12.5 的 TF-A Makefile](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/arm-trusted-firmware-mediatek/Makefile)与本地 `.wrt/openwrt/package/boot/arm-trusted-firmware-mediatek/Makefile` 中的 `Trusted-Firmware-A/mt7981-cudy-ddr3`。

### 先区分环境命令和镜像文件

`boot_tftp_write_bl2` **不是 Linux 下的脚本文件**，而是 U-Boot 环境中保存的一段命令。它的默认定义位于本地 `.wrt/openwrt/package/boot/uboot-mediatek/patches/445-add-cudy_tr3000-v1.patch`，运行时的持久环境保存在 UBI 环境卷中，通过 `fw_printenv` 查看、`fw_setenv` 修改。

在路由器 SSH 中只读核对：

```sh
ubus call system board
cat /proc/mtd
cat /etc/fw_env.config
fw_printenv bootcmd bootfile_bl2 boot_tftp_write_bl2 mtd_write_bl2 ipaddr serverip loadaddr
```

本次相关输出为：

```text
bootcmd=if pstore check ; then run boot_recovery ; else run boot_ubi ; fi
bootfile_bl2=openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-preloader.bin
boot_tftp_write_bl2=tftpboot $loadaddr $bootfile_bl2 && run mtd_write_bl2
mtd_write_bl2=mtd erase bl2 && mtd write bl2 $loadaddr
ipaddr=192.168.1.1
serverip=192.168.1.254
loadaddr=0x46000000
```

`tftpboot` 把电脑提供的文件下载到内存，`run mtd_write_bl2` 才执行擦除和写入。`run`、`tftpboot`、`saveenv` 是 U-Boot 命令，不能直接当作 Linux SSH 命令执行。Linux 的 `fw_setenv` 负责保存它们，等待下一次启动由 U-Boot 执行。

本次复用的内置 `mtd_write_bl2` 会擦除整个 BL2 分区，且 `mtd write` 没有显式指定长度，按该版 U-Boot 的默认分区范围写入。后面的哈希检查只核对 preloader 的有效镜像字节，不是对整个分区、填充区域或 OOB 的验证。

### 保存环境与 BL2 备份

先按第 4 节备份需要保留的系统配置。确认 `/proc/mtd` 中 `mtd0` 确实是 1 MiB 的 `BL2` 后，在**电脑终端**保存更新前的环境和分区内容：

```bash
backup_dir=$(mktemp -d "$HOME/tr3000-bl2-backup.XXXXXX")
ssh root@10.0.0.1 fw_printenv > "$backup_dir/uboot-env.txt"
ssh root@10.0.0.1 'cat /dev/mtd0' > "$backup_dir/BL2.bin"
stat -c '%s %n' "$backup_dir/BL2.bin"
sha256sum "$backup_dir/BL2.bin"
```

检查命令退出状态及报错，确认环境文件有内容，BL2 备份长度与分区长度相符。这里的 `cat` 是本机 MTD 数据视图的读取，不包含 OOB，也不提供坏块处理或通用恢复方案；遇到读取错误应先处理，不能把残缺输出当作有效备份。不要用整个 1 MiB 备份的哈希去比较上表 230232 字节镜像的哈希。

### 准备 preloader、网络与服务

在**电脑的项目根目录**执行：

```bash
preloader=output/targets/mediatek/filogic/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-preloader.bin
stat -c '%s %n' "$preloader"
sha256sum "$preloader"
install -d -m 755 /tmp/tr3000-tftp
install -m 644 "$preloader" /tmp/tr3000-tftp/
sha256sum /tmp/tr3000-tftp/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-preloader.bin
```

源文件和 TFTP 目录内文件的哈希应一致，并与即将写入 `bootcmd` 的预期值一致。文件名必须与实机 `bootfile_bl2` 一致；不要用 `mt7981-ram-ddr3-bl2.bin`、恢复 `.itb` 或 sysupgrade 镜像替换它。

按第 5 节启用直连配置、确认断链后仍能恢复 `192.168.1.254/24`、放行 UDP 69 和 10069，再启动 dnsmasq。已有服务时核对 `192.168.1.254:69` 的监听即可，不必为每次重试重新启动进程。准备文件与启动 TFTP 均不会自行刷写路由器。

### 设置一次性启动命令

以下命令固定使用本次镜像的 SHA256，并在刷写前恢复上面记录的原 `bootcmd`。**只有实机原始启动命令与前面的输出一致时，才能直接使用；存在其他自定义启动逻辑时，应保留并恢复其实际值。** 确认所有前置检查和备份完成后，在**路由器 SSH** 中执行：

```sh
fw_setenv bootcmd 'setenv bootcmd "if pstore check ; then run boot_recovery ; else run boot_ubi ; fi"; if saveenv; then if tftpboot $loadaddr $bootfile_bl2 && hash sha256 $loadaddr $filesize bl2hash && test "$bl2hash" = bf40e2b1783012517d94f9fa9cc9905932ad91449b8d1667d5c7b025f824fd42; then if run mtd_write_bl2; then reset; fi; fi; fi; run boot_ubi'
fw_printenv bootcmd
```

检查 `fw_setenv` 是否成功，读出的 `bootcmd` 是否完整。外层单引号用于保留 `$loadaddr`、`$filesize` 等变量，不能改成让 Linux shell 提前展开它们的写法。该命令展开了原有的下载入口，在下载成功与写入之间增加 SHA256 校验；此时只修改了持久环境，还没有写入 BL2。

**下一条命令会开始实际刷写流程。正常重启，不按 Reset 按钮：**

```sh
reboot
```

### 两次重启与成功验收

正常成功路径按以下顺序进行：

1. 第一次重启仍由旧 BL2 初始化硬件，进入现有 U-Boot。
2. U-Boot 先恢复原 `bootcmd`，并用 `saveenv` 持久保存；保存成功才继续。
3. 从 `192.168.1.254` 下载 `bootfile_bl2`，计算并匹配 SHA256。
4. 执行内置 `mtd_write_bl2`。写入命令返回成功后执行 `reset`，自动第二次重启。
5. 第二次启动由新 BL2 初始化内存，再加载现有 FIP/U-Boot 和原来的正式系统。

电脑可能观察到类似日志：

```text
sent /tmp/tr3000-tftp/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-preloader.bin to 192.168.1.1
```

这只证明 TFTP 文件传输完成，不证明 BL2 写入成功。保持供电，等待路由器自行完成后续动作；不要因为网口暂时断链或还未出现 SSH，就额外手动重启。这里没有启动 initramfs，成功后通常回到 `10.0.0.1` 的原系统；仍显示 OpenWrt 25.12.5 是正常的。

恢复 SSH 后，在**路由器**执行：

```sh
head -c 230232 /dev/mtd0 | sha256sum
fw_printenv bootcmd
```

确认读取无错误，哈希为本次新值：

```text
bf40e2b1783012517d94f9fa9cc9905932ad91449b8d1667d5c7b025f824fd42
```

同时确认启动命令恢复：

```text
bootcmd=if pstore check ; then run boot_recovery ; else run boot_ubi ; fi
```

**正常启动、新 BL2 有效镜像哈希匹配、启动命令恢复，才算通过这一步验收。** 更换镜像时，`head -c` 的长度必须使用该镜像实际字节数。这个检查证明已写入指定镜像；编译参数和回读哈希并不直接测量运行频率，也不能保证所有负载下的内存稳定性。

### 未发送、旧哈希与重试

| 现象或失败阶段 | 含义与处理 |
| --- | --- |
| 只有 dnsmasq 启动日志，没有 `sent` | 先查 `bootcmd` 是否安排了此次下载、网线是否接 1G LAN、重启后直连连接和 `192.168.1.254` 是否仍在、监听与防火墙是否正确；不能仅凭缺少日志认定原因 |
| `saveenv` 失败 | 不进入下载和 BL2 写入；本次内存中的启动命令已恢复，但持久环境可能仍保留一次性命令，需重新读取确认 |
| TFTP 下载、哈希计算或匹配失败 | 不调用 `mtd_write_bl2`，转而尝试 `run boot_ubi` 启动现有系统 |
| 回读仍为上表旧镜像哈希 | BL2 有效镜像未更新；修复原因后，先检查启动环境再决定是否重试 |
| 擦除或写入命令报错 | 不执行成功分支的 `reset`，仍会尝试启动现有系统，但 BL2 可能已经损坏；即使能 SSH 也不要直接再次重启 |
| 回读既不是旧哈希，也不是预期新哈希 | 核对读取错误、设备、分区和镜像长度，保存输出，先排查，不继续升级或反复重启 |
| SSH 没有恢复 | 不能仅凭 TFTP 发送成功判定完成；保持供电并排查网络和启动情况，不盲目重复刷写 |

本次首次尝试没有看到发送成功，操作者反馈哈希不匹配，并发现未开启直连配置自动连接；当时没有捕获启动期间的地址变化，不能据此把自动连接遗漏写成已证实的唯一原因。后续观察到了上述 `sent` 日志，并确认新哈希匹配。

重试时最容易遗漏的是：**保存正常 `bootcmd` 在下载之前发生。** 一旦保存成功，即使 TFTP 下载失败，下次普通重启也不会自动再次刷 BL2。修复网络后先用 `fw_printenv bootcmd` 检查；在旧哈希、镜像和前置条件都重新确认后，才重新设置一次性命令，再正常重启。保留仍在正常监听的 dnsmasq 实例即可。

### 完成后停止 TFTP，再处理正式系统

验收通过后，新 BL2 已在闪存中，正常启动不再依赖这次 TFTP 服务。按第 5 节使用 SIGTERM 停止指定 dnsmasq 实例、检查端口、删除本次添加的临时规则，并恢复电脑原来的网络连接偏好。

这一步没有写入 `squashfs-sysupgrade.itb`。如需安装本次自编译的正式系统，使用 `output/targets/mediatek/filogic/openwrt-mediatek-filogic-cudy_tr3000-v1-ubootmod-squashfs-sysupgrade.itb`，按第 4 节校验并选择保留或不保留配置，再按第 8 节验收；不要因此重复更新 BL2。

源码依据：[TR3000 U-Boot 环境定义](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/patches/445-add-cudy_tr3000-v1.patch)、[U-Boot MTD 命令实现](https://github.com/u-boot/u-boot/blob/v2025.10/cmd/mtd.c)。

## 7. 判断当前是在 RAM 系统，还是正式系统

能 ping 通、能 SSH 登录或显示 OpenWrt 版本，都不足以单独判断正式系统已经安装成功。

路由器端的只读检查：

```sh
ubus call system board
cat /proc/cmdline
cat /proc/self/mountinfo
cat /proc/mtd
df -h
ubinfo -a
dmesg | grep -iE 'ubi|ubifs|nand|ecc|bad block'
```

| 观察项 | 对应含义 |
| --- | --- |
| 根文件系统是内存类型，未挂载正式 SquashFS 和持久化 overlay | 符合临时 RAM 系统特征 |
| `root=/dev/fit0`、正式 SquashFS、UBIFS `/overlay` 正常挂载 | 符合本机正式系统特征 |
| `/tmp` 中文件重启后消失 | RAM 临时目录的正常行为，不代表持久化故障 |
| `/overlay` 无可写空间或挂载失败 | 需要核对卷、文件系统和启动日志，不能只重试升级 |
| 日志出现 ECC、坏块等信息 | 要结合具体错误和计数变化判断，不能把任意一行关键字都判为损坏 |

RAM 根是 `rootfs`、`ramfs` 或 `tmpfs` 等内存类型时，仍应结合挂载信息确认；仅凭存在 `/dev/fit0`、某个内核版本或 UBI 已附着都不够。

SSH 可以为正式系统和恢复系统使用不同的主机密钥别名，例如：

```bash
ssh -o HostKeyAlias=tr3000-initramfs root@192.168.1.1
```

这适用于恢复系统确实使用该地址时。出现密钥变化，先确认网线、路由和设备身份，不通过关闭主机密钥检查来消除提示。

## 8. 升级或恢复后的验收

实际成功应同时包括：预期版本和板名正确、正式根文件系统正常、overlay 可写、无需电脑提供镜像也能重启、重要网络与服务功能正常。

若使用过 TFTP，先结束自己启动的服务，确认相应端口没有该服务监听，再测试独立重启。按实际进程及其启动参数识别服务，不要批量结束电脑上其他 dnsmasq 实例。

持久化可以用一个临时标记文件检查。路由器端示例使用 `mktemp` 避免覆盖已有文件；先在电脑记下输出的路径和哈希：

```sh
check_file=$(mktemp /root/tr3000-persistence.XXXXXX)
date > "$check_file"
sha256sum "$check_file"
sync
```

在业务允许时手动重启。重新连接后，对刚才记下的文件执行 `sha256sum`，确认内容一致，并再次检查系统根、UBI 和 `/overlay`。验证完成后删除这个测试文件。这个测试用于“同一已安装系统的重启”，不是要求不保留配置的升级后仍留下旧文件。

升级交接时 SSH 断开、`ubus` 提示连接失败或包装脚本返回 246，不能单独判定升级失败，也不能据此认定成功。升级命令返回 0 也只是交接信息，仍需检查启动结果；交接不确定时保持供电、等待并观察，不盲目重复刷写。

## 9. 参考资料与源码索引

OpenWrt 源码链接固定到 `v25.12.5`，U-Boot 环境实现固定到 `v2025.10`。滚动文档和分支可能更新；核查其他版本时，以实际使用版本的设备定义和调用链为准。

### 9.1 设备支持、分区和发布文件

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [OpenWrt：Cudy TR3000 设备页](https://openwrt.org/toh/cudy/tr3000)及[布局说明章节](https://openwrt.org/toh/cudy/tr3000#switching_to_openwrt_u-boot_layout) | 设备支持、硬件和布局背景 | Wiki 会更新；具体行为以对应版本源码为准 |
| [官方加入 ubootmod 布局的提交](https://lists.infradead.org/pipermail/lede-commits/2025-May/025599.html) | 官方布局的设计来源、分区扩大及最初的设备支持改动 | 固定历史提交 `6f8c58bfd8f380dfdc1d89aab29fdcdfde0ee65b`；其中首次迁移步骤不用于本机日常升级 |
| [ubootmod DTS](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts) | 板名、`0x7a40000` UBI 长度、`rootdisk` 与 `fit` 卷 | OpenWrt v25.12.5 |
| [TR3000 共用 DTS](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dtsi) | 固定分区、Factory EEPROM、bdinfo MAC、接口与 GPIO | OpenWrt v25.12.5 |
| [Filogic 镜像定义](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/image/filogic.mk) | 搜索 `Device/cudy_tr3000-v1-ubootmod`，查看镜像格式、设备软件包、BL2/FIP 产物 | OpenWrt v25.12.5 |
| [25.12.5 官方下载目录](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/)与[sha256sums](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/sha256sums) | 获取该版本镜像及对应校验值 | 第 2 节列有四个文件的直接下载链接 |
| [version.buildinfo](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/version.buildinfo)、[config.buildinfo](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/config.buildinfo) | 该次官方发布的源码版本标识与构建配置 | 用于对照官方发布，不是本项目的自定义配置 |

### 9.2 U-Boot、环境卷和恢复分支

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [445-add-cudy_tr3000-v1.patch](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/patches/445-add-cudy_tr3000-v1.patch) | `bootcmd`、`bootfile_bl2`、`boot_tftp_write_bl2`，以及 `boot_tftp_recovery`、`ubi_create_env`、`ubi_format` 等分支 | 本板型默认启动、BL2 写入和恢复行为的主要依据 |
| [TF-A 构建定义](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/arm-trusted-firmware-mediatek/Makefile) | `mt7981-cudy-ddr3` 的 DDR 参数、TF-A 源码版本、FIP 位置和长度 | 旧版基线；第 6 节新参数对照本地构建树 |
| [U-Boot cmd/mtd.c](https://github.com/u-boot/u-boot/blob/v2025.10/cmd/mtd.c) | MTD 擦除、写入、未指定长度时的默认范围 | U-Boot v2025.10 |
| [OpenWrt 的 U-Boot 构建定义](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/Makefile) | 所用 U-Boot 版本、设备构建目标和打包关系 | OpenWrt v25.12.5 |
| [U-Boot env/Kconfig](https://github.com/u-boot/u-boot/blob/v2025.10/env/Kconfig) | 环境数据长度、存储后端、冗余环境的配置含义 | U-Boot v2025.10；最终取值还要结合设备配置 |
| [U-Boot env/ubi.c](https://github.com/u-boot/u-boot/blob/v2025.10/env/ubi.c) | 如何从 UBI 读取和写入环境数据、处理冗余副本 | U-Boot v2025.10 |
| [OpenWrt uboot-envtools.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-tools/uboot-envtools/files/uboot-envtools.sh) | 环境访问配置的公共辅助函数 | OpenWrt v25.12.5 |
| [Filogic 的 uboot-envtools 设备配置](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-tools/uboot-envtools/files/mediatek_filogic) | 本平台如何选择环境卷和环境长度 | 配合公共辅助函数及实际 `/etc/fw_env.config` 查看 |

### 9.3 镜像检查、升级和配置备份

| 资料 | 可以核对的内容 |
| --- | --- |
| [platform.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh) | `cudy,tr3000-v1-ubootmod` 对应的 `fit_check_image`、`fit_do_upgrade` 分支 |
| [fit.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/utils/fitblk/files/fit.sh) | FIT 检查、按设备树定位升级目标，以及转入 NAND/UBI 升级的过程 |
| [nand.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/lib/upgrade/nand.sh) | UBI 附着、卷更新、`rootfs_data` 和配置恢复的处理 |
| [common.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/lib/upgrade/common.sh) | 升级公共函数和 RAM 环境处理；辅助理解单一检查的适用范围 |
| [sysupgrade](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/sbin/sysupgrade) | `-T`、`-b`、`-l`、`-n` 等选项、备份清单及升级交接 |

以上五项均固定为 OpenWrt v25.12.5。核查其他版本时应切换到对应 tag 或实际源码提交。

### 9.4 电脑网络和 TFTP 工具

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [dnsmasq 官方手册](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html) | TFTP 选项、`--bind-dynamic`、前台与调试模式、SIGINT 含义 | 在线手册会更新；本次电脑为 dnsmasq 2.93 |
| [nmcli 官方手册](https://networkmanager.dev/docs/api/latest/nmcli.html) | 连接的创建、修改、启用和查询 | 滚动文档 |
| [NetworkManager IPv4 设置](https://networkmanager.dev/docs/api/latest/settings-ipv4.html) | 静态地址、网关和 `never-default` | 滚动文档 |
| [NetworkManager 连接设置](https://networkmanager.dev/docs/api/latest/settings-connection.html) | `autoconnect`、自动连接优先级、绑定网卡 | 滚动文档 |
| [atftp 手册的 Debian 副本](https://manpages.debian.org/testing/atftp/atftp.1.en.html) | `--get`、`--remote-file`、`--local-file` 等客户端选项 | Debian testing 页面会随包版本更新 |
| [NixOS iptables 防火墙模块](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/firewall-iptables.nix) | `nixos-fw`、`nixos-fw-accept` 链及接口、端口放行方式 | `nixos-unstable` 会更新；只适用于对应后端 |

### 9.5 NAND 工具

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [mtd-utils 的 nanddump.c](https://github.com/sigma-star/mtd-utils/blob/master/nand-utils/nanddump.c) | OOB、坏块处理、`skipbad` 和 `padbad` 的实现 | `master` 会变化；选项及默认值应核对所用工具版本 |
| [mtd-rw 软件包定义](https://github.com/openwrt/packages/blob/openwrt-25.12/kernel/mtd-rw/Makefile) | MTD 写保护解锁模块的构建定义与依赖 | 内核模块需匹配运行内核；日常 sysupgrade 不需要此模块 |
