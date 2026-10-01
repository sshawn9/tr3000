# 配置备份与恢复

在电脑上执行，默认连接 `root@10.0.0.1`；假定电脑和路由器都已安装 rsync，并能通过 SSH 连接：

```bash
./restore/backup.sh
```

也可以指定 SSH 目标：

```bash
./restore/backup.sh tr3000
```

`TARGET`、`SCRIPT_DIR`、`SNAPSHOT` 在全局定义处初始化，同时创建本次备份的时间目录 `restore/snapshots/YYYY-MM-DD_HHMMSS/`。`main` 依次调用三个备份函数；统一通过 `rsync -aR` 经 SSH 复制，保留原始路径：

- `backup_preset`：将 `/etc/preset.d/` 整个目录保存到本次目录中的 `etc/preset.d/`，包含以下划线开头的停用预设；目录不存在时提示跳过。
- `backup_mihomo`：将 `/etc/mihomo/` 保存到本次目录中的 `etc/mihomo/`，保留文件权限、时间和符号链接；目录不存在时提示跳过。
- `backup_root_password`：将完整的 `/etc/shadow` 保存到本次目录中的 `etc/shadow`；文件不存在时提示跳过。

每次运行创建独立时间目录，各项备份放在同一个目录中，不覆盖之前的备份，也不压缩打包。源文件或目录不存在时提示跳过并继续；SSH、权限、路径类型或 rsync 传输错误仍会中止，且不显示“备份完成”。失败时本次目录可能只包含部分文件。`snapshots/` 已加入 Git 忽略规则。

`shadow` 包含各账户的密码哈希、锁定标记和密码有效期等信息，属于敏感数据。恢复 root 密码时只更新 root 的密码字段，不覆盖整个 `/etc/shadow`，避免影响新固件的其他账户。

在线复制运行中的 `cache.db` 不保证数据库事务一致性。

## 恢复

不指定目录时，自动选择 `restore/snapshots/` 下目录名时间最新的备份；没有备份时提示并退出：

```bash
./restore/restore.sh
```

也可以指定备份目录，第二个参数可指定 SSH 目标，默认 `root@10.0.0.1`：

```bash
./restore/restore.sh restore/snapshots/2026-09-30_153000
./restore/restore.sh restore/snapshots/2026-09-30_153000 tr3000
```

脚本先安装本机 SSH 公钥，再覆盖目标设备的对应配置文件并恢复 root 密码。假定电脑已有 `ssh-copy-id` 和 SSH 公钥，两端已有 rsync，路由器已有支持 `-e` 的 `chpasswd`。

- `setup_ssh_key`：首先执行 `ssh-copy-id` 安装本机公钥，首次可能需要输入路由器当前的 root 密码。
- `restore_preset`：将 `etc/preset.d/` 复制回 `/etc/preset.d/`，覆盖同名文件，保留目标目录的其他文件；备份没有该目录时提示跳过。
- `restore_mihomo`：将 `etc/mihomo/` 复制回 `/etc/mihomo/`，覆盖同名文件，保留目标目录的其他文件；备份没有该目录时提示跳过。
- `restore_root_password`：从备份的 `etc/shadow` 提取 root 密码字段，通过 `chpasswd -e` 恢复；不上传整个 shadow，也不修改其他账户；备份没有 `etc/shadow` 时提示跳过。

本机的 `ssh-copy-id` 会识别 OpenWrt，将 root 公钥追加到 `/etc/dropbear/authorized_keys`。之后可使用对应私钥免输路由器密码登录；若私钥本身有口令，仍需输入私钥口令或交由 `ssh-agent` 管理。

配置文件恢复为 `root:root` 所有，避免带入电脑上的用户和组。密码放在最后恢复，完成后新建密码认证的 SSH 连接需要使用备份时的密码。密码哈希通过 SSH 标准输入传输，不作为命令行参数输出。`chpasswd -e` 的含义见 [BusyBox 手册](https://busybox.net/downloads/BusyBox.html#chpasswd)。

脚本恢复文件和密码。需要让当前系统立即应用配置时，再在路由器上执行：

```sh
/etc/init.d/mihomo restart
preset-apply
```

`preset-apply` 会应用预设并重载相关服务，可能改变网络连接，因此放在全部文件恢复完成后执行。

预设从 `/etc/preset.d/` 读取，按文件名顺序应用当前目录中的 `.jsonc` 文件，跳过以下划线开头的文件，不递归子目录。同一配置项以后面的文件为准，空字符串仍表示跳过。可用 `preset-apply --check` 检查全部预设，或用 `preset-apply [--check] 目录` 指定其他目录。全部启用的预设处理成功后才提交配置并重载服务。

## 设置 root 密码

在电脑终端运行，按路由器的提示输入两次新密码：

```bash
./restore/set-root-password.sh
```

默认连接 `root@10.0.0.1`，也可以指定 SSH 目标：

```bash
./restore/set-root-password.sh tr3000
```

脚本通过 SSH 交互终端执行 `passwd root`，不依赖备份文件；密码输入不回显，不写入脚本或命令行参数。
