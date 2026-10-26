# OpenWrt 云编译

支持 J4125 等 x86 设备、兆能 M2 和京东云亚瑟。

| 工作流 | 源码 | 分支 | 配置 |
| --- | --- | --- | --- |
| x86-imm | immortalwrt/immortalwrt | master | config/x86.config |
| x86-libWrt | LiBwrt/openwrt-6.x | 25.12-nss | config/x86.config |
| ipq60xx-libWrt | LiBwrt/openwrt-6.x | 25.12-nss | config/arm 下的三个设备配置 |

在 Actions 选择对应工作流，点击 Run workflow，并选择 main。修改配置后请创建新运行；重跑旧任务仍使用旧提交。

## 文件职责

- `.github/workflows/core.yml`：共享的下载、编译与发布流程。
- `scripts/Packages.sh`：先拉取软件包，再按确切目录替换已有版本；记录自定义包提交。
- `scripts/Handles.sh`：已有的软件包兼容处理。
- `scripts/Fixes.sh`：sing-box 版本设置，以及 Nikki、libffi 兼容修复。
- `scripts/Settings.sh`：时区、规则库、面板、NSS 和网口等自定义设置。
- `config/`：设备编译配置。

## 当前保留的个人设置

x86 首次启动将第一个网络 device 的端口列表设为 `eth0 eth2 eth3`。这是现有四网口 J4125 的专用配置，WAN 沿用源码设置；换设备时应核对网口。

sing-box 仍固定为 1.12.25，并沿用原来的 `PKG_HASH:=skip` 设置。本次没有完成该版本整套软件包定义与哈希的固定。Nikki、mihomo-alpha 和 DAED/BTF 的现有处理保留。软件包分支和数据文件仍随上游变化，并非完全可复现构建。

NSS 12.2 设置仅在当前目标为 qualcommax、且源码存在对应选项时注入。首次启动设置上海时区；保留系统配置升级时，应检查已有时区设置。

## 发布与排查

镜像保留上游文件名，使清单引用保持一致。Release 标签包含设备、日期、运行编号和尝试次数，避免同日重编混用产物。附件包含 `build.config`、`build.diffconfig`、`build-revisions.txt` 和重新生成的 `sha256sums`。

下载使用 HTTP 错误检查和重试，空文件、失败下载和解压错误会中止构建。HTTP 成功和非空检查并不验证规则库的内部格式。

自动清理保留至少 14 天内的运行记录，默认保留编译缓存；手动运行 Auto-Clean 时可选择清空缓存。Release 仍按原策略保留最近指定数量。

`patch/0001-fix-upnp.patch` 是历史补丁，目前未被工作流应用。本次保留文件，不自动启用。
