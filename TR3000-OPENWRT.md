# Cudy TR3000：官方 OpenWrt 使用与恢复参考

适用设备：Cudy TR3000 v1，官方 `cudy,tr3000-v1-ubootmod` 布局。

源码版本：OpenWrt `v25.12.5`。容量示例取自 2026-09-16 的设备实测；当前容量以设备输出为准，其他版本的行为需核对对应源码。

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
| `preloader.bin` | BL2，早期启动和硬件初始化组件 | 引导链维护资料，日常系统升级不使用 |
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

## 5. TFTP 恢复所需的固定信息

TFTP 的作用是让仍能工作的 U-Boot 从电脑取得恢复镜像。电脑必须提前准备好文件、有线地址和服务；仅在电脑启动 TFTP 服务，不会让一台正常启动的路由器自动进入恢复模式。

以下是已安装引导版本对应源码中的默认值；后续若修改过 U-Boot 环境，应以实际环境为准。

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

插好 LAN 网线后，显式启用该连接，再检查地址和路由。启用操作会将这张网卡切换到直连配置：

```bash
sudo nmcli connection up tr3000-direct
ip -4 addr show enp2s0
ip -4 route get 192.168.1.1 from 192.168.1.254
ip rule show
```

路由结果应走直连网卡。VPN、代理 TUN、其他网卡的同网段地址可能改变实际路径，不能只看网卡有没有 IP。路由器重启造成断链后，电脑还需要恢复该地址，TFTP 服务才能继续响应；正式操作前可用拔插 LAN 网线验证这一点。

如果恢复结束后希望保留配置、以后只手动启用，可以执行 `sudo nmcli connection modify tr3000-direct connection.autoconnect no connection.autoconnect-priority 0`；这只修改后续自动连接行为，不会立即断开当前连接。

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

两份文件的哈希应一致。TFTP 目录只提供准备使用的恢复镜像。

下面使用 dnsmasq 提供 TFTP 服务。电脑需要已有 dnsmasq；NixOS 可通过 `nix shell nixpkgs#dnsmasq --command bash` 临时进入带有该工具的环境，首次获取工具可能需要电脑联网。

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

### NixOS iptables 防火墙的临时放行

以下示例仅适用于采用 NixOS iptables 防火墙、且实际存在 `nixos-fw` 和 `nixos-fw-accept` 两条链的电脑。先查看：

```bash
sudo iptables -w -S nixos-fw
sudo iptables -w -S nixos-fw-accept
```

确认后，只对直连网卡放行 TFTP 所需端口。将 `enp2s0` 换成实际接口；若已有下面这条规则，不要重复添加：

```bash
sudo iptables -w -I nixos-fw 1 -i enp2s0 -p udp \
  -m multiport --dports 69,10069 \
  -m comment --comment tr3000-tftp -j nixos-fw-accept
```

这是一条临时规则，防火墙重载可能清除它。若电脑使用 nftables 或其他链结构，应按实际后端配置相同的接口和端口范围，不创建同名空链来套用命令。

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

结束自己启动的 TFTP 服务前，先在电脑查看 PID 和启动参数：

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

连接配置是否继续自动启用，按“电脑网络”一节中的 `connection.autoconnect` 设置处理。

### 恢复分支的实际边界

该版 U-Boot 的默认启动顺序包含正式 `fit`、已有 `recovery` 和 TFTP 回退。启动阶段检测到 Reset 按键也有恢复分支；按键是否触发取决于引导阶段的检测，不能从该分支直接推导固定的按住时长。

TFTP 不等于始终只读：`boot_tftp` 是下载后启动；`boot_tftp_recovery` 在 `replacevol` 条件满足时还会写入 `recovery` 卷，而相应写入流程会移除 `rootfs_data`。环境卷初始化失败也有擦除 UBI 的回退分支。因此，看到 TFTP 下载不能推断持久化数据一定没有变化。

TFTP 恢复依赖引导程序及网络功能正常；引导程序本身损坏时，不能保证通过网线恢复。

源码依据：[固定版本 U-Boot 环境与启动逻辑](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/patches/445-add-cudy_tr3000-v1.patch)，对应 `boot_default`、`boot_ubi`、`boot_tftp*`、`ubi_write_recovery` 和 `ubi_create_env`。

## 6. 判断当前是在 RAM 系统，还是正式系统

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

## 7. 升级或恢复后的验收

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

## 8. 参考资料与源码索引

OpenWrt 源码链接固定到 `v25.12.5`，U-Boot 环境实现固定到 `v2025.10`。滚动文档和分支可能更新；核查其他版本时，以实际使用版本的设备定义和调用链为准。

### 8.1 设备支持、分区和发布文件

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [OpenWrt：Cudy TR3000 设备页](https://openwrt.org/toh/cudy/tr3000)及[布局说明章节](https://openwrt.org/toh/cudy/tr3000#switching_to_openwrt_u-boot_layout) | 设备支持、硬件和布局背景 | Wiki 会更新；具体行为以对应版本源码为准 |
| [官方加入 ubootmod 布局的提交](https://lists.infradead.org/pipermail/lede-commits/2025-May/025599.html) | 官方布局的设计来源、分区扩大及最初的设备支持改动 | 固定历史提交 `6f8c58bfd8f380dfdc1d89aab29fdcdfde0ee65b`；其中首次迁移步骤不用于本机日常升级 |
| [ubootmod DTS](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts) | 板名、`0x7a40000` UBI 长度、`rootdisk` 与 `fit` 卷 | OpenWrt v25.12.5 |
| [TR3000 共用 DTS](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dtsi) | 固定分区、Factory EEPROM、bdinfo MAC、接口与 GPIO | OpenWrt v25.12.5 |
| [Filogic 镜像定义](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/image/filogic.mk) | 搜索 `Device/cudy_tr3000-v1-ubootmod`，查看镜像格式、设备软件包、BL2/FIP 产物 | OpenWrt v25.12.5 |
| [25.12.5 官方下载目录](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/)与[sha256sums](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/sha256sums) | 获取该版本镜像及对应校验值 | 第 2 节列有四个文件的直接下载链接 |
| [version.buildinfo](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/version.buildinfo)、[config.buildinfo](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/config.buildinfo) | 该次官方发布的源码版本标识与构建配置 | 用于对照官方发布，不是本项目的自定义配置 |

### 8.2 U-Boot、环境卷和恢复分支

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [445-add-cudy_tr3000-v1.patch](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/patches/445-add-cudy_tr3000-v1.patch) | `ipaddr`、`serverip`、`bootfile`，以及 `boot_tftp_recovery`、`ubi_create_env`、`ubi_format` 等分支 | 本板型默认启动与恢复行为的主要依据 |
| [OpenWrt 的 U-Boot 构建定义](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-mediatek/Makefile) | 所用 U-Boot 版本、设备构建目标和打包关系 | OpenWrt v25.12.5 |
| [U-Boot env/Kconfig](https://github.com/u-boot/u-boot/blob/v2025.10/env/Kconfig) | 环境数据长度、存储后端、冗余环境的配置含义 | U-Boot v2025.10；最终取值还要结合设备配置 |
| [U-Boot env/ubi.c](https://github.com/u-boot/u-boot/blob/v2025.10/env/ubi.c) | 如何从 UBI 读取和写入环境数据、处理冗余副本 | U-Boot v2025.10 |
| [OpenWrt uboot-envtools.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-tools/uboot-envtools/files/uboot-envtools.sh) | 环境访问配置的公共辅助函数 | OpenWrt v25.12.5 |
| [Filogic 的 uboot-envtools 设备配置](https://github.com/openwrt/openwrt/blob/v25.12.5/package/boot/uboot-tools/uboot-envtools/files/mediatek_filogic) | 本平台如何选择环境卷和环境长度 | 配合公共辅助函数及实际 `/etc/fw_env.config` 查看 |

### 8.3 镜像检查、升级和配置备份

| 资料 | 可以核对的内容 |
| --- | --- |
| [platform.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh) | `cudy,tr3000-v1-ubootmod` 对应的 `fit_check_image`、`fit_do_upgrade` 分支 |
| [fit.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/utils/fitblk/files/fit.sh) | FIT 检查、按设备树定位升级目标，以及转入 NAND/UBI 升级的过程 |
| [nand.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/lib/upgrade/nand.sh) | UBI 附着、卷更新、`rootfs_data` 和配置恢复的处理 |
| [common.sh](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/lib/upgrade/common.sh) | 升级公共函数和 RAM 环境处理；辅助理解单一检查的适用范围 |
| [sysupgrade](https://github.com/openwrt/openwrt/blob/v25.12.5/package/base-files/files/sbin/sysupgrade) | `-T`、`-b`、`-l`、`-n` 等选项、备份清单及升级交接 |

以上五项均固定为 OpenWrt v25.12.5。核查其他版本时应切换到对应 tag 或实际源码提交。

### 8.4 电脑网络和 TFTP 工具

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [dnsmasq 官方手册](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html) | `--port=0`、`--enable-tftp`、`--interface`、`--bind-dynamic`、`--tftp-port-range` | 在线手册会更新；命令是否支持还要对照电脑安装版本 |
| [nmcli 官方手册](https://networkmanager.dev/docs/api/latest/nmcli.html) | 连接的创建、修改、启用和查询 | 滚动文档 |
| [NetworkManager IPv4 设置](https://networkmanager.dev/docs/api/latest/settings-ipv4.html) | 静态地址、网关和 `never-default` | 滚动文档 |
| [NetworkManager 连接设置](https://networkmanager.dev/docs/api/latest/settings-connection.html) | `autoconnect`、自动连接优先级、绑定网卡 | 滚动文档 |
| [atftp 手册的 Debian 副本](https://manpages.debian.org/testing/atftp/atftp.1.en.html) | `--get`、`--remote-file`、`--local-file` 等客户端选项 | Debian testing 页面会随包版本更新 |
| [NixOS iptables 防火墙模块](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/firewall-iptables.nix) | `nixos-fw`、`nixos-fw-accept` 链及接口、端口放行方式 | `nixos-unstable` 会更新；只适用于对应后端 |

### 8.5 NAND 工具

| 资料 | 可以核对的内容 | 版本或边界 |
| --- | --- | --- |
| [mtd-utils 的 nanddump.c](https://github.com/sigma-star/mtd-utils/blob/master/nand-utils/nanddump.c) | OOB、坏块处理、`skipbad` 和 `padbad` 的实现 | `master` 会变化；选项及默认值应核对所用工具版本 |
| [mtd-rw 软件包定义](https://github.com/openwrt/packages/blob/openwrt-25.12/kernel/mtd-rw/Makefile) | MTD 写保护解锁模块的构建定义与依赖 | 内核模块需匹配运行内核；日常 sysupgrade 不需要此模块 |
