# OpenWrt 云编译

支持 J4125 等 x86 设备。兆能 M2 和京东云亚瑟等 ARM 构建已迁移至 [openwrt-build-arm](https://github.com/licong87/openwrt-build-arm)。

| 工作流 | 源码 | 分支 | 配置 |
| --- | --- | --- | --- |
| x86-imm | immortalwrt/immortalwrt | master | config/x86.config |
| x86-libWrt | LiBwrt/openwrt-6.x | 25.12-nss | config/x86.config |

在 Actions 选择对应工作流，点击 Run workflow，并选择 main。修改配置后请创建新运行；重跑旧任务仍使用旧提交。

## 文件职责

- `.github/workflows/core.yml`：共享的下载、编译与发布流程。
- `scripts/Packages.sh`：先拉取软件包，再按确切目录替换已有版本；记录自定义包提交。
- `scripts/Handles.sh`：已有的软件包兼容处理。
- `scripts/Fixes.sh`：Nikki、libffi 兼容修复；sing-box 保留 feeds 配套版本、补丁和源码哈希。
- `scripts/Settings.sh`：时区、规则库、面板、NSS 和网口等自定义设置。
- `config/`：设备编译配置。

## 当前保留的个人设置

x86 固件内置 `files/x86/99-j4125-lan-ports-v2`，首次启动或升级后按名称找到（必要时创建）`br-lan`，将存在且未被 WAN 占用的 `eth0 eth2 eth3` 加入 LAN。`eth1` 从 LAN 网桥中排除，WAN/WAN6、LAN 地址和 DHCP 设置保持不变。新版首次启动脚本使用新文件名，以便保留配置升级后执行；不是每次启动强制重置网口。该布局用于现有四网口 J4125，其他 x86 设备需自行核对。

sing-box 不再固定 1.12.25，也不再覆盖 PKG_HASH；跟随各源码 feeds 的版本、补丁和依赖一起更新，避免新补丁与旧源码混用。HomeProxy 随 LuCI feeds 更新。Nikki、mihomo-alpha 和 DAED/BTF 的现有处理保留。软件包分支和数据文件仍随上游变化，并非完全可复现构建。

NSS 12.2 设置仅在当前目标为 qualcommax、且源码存在对应选项时注入。首次启动设置上海时区；保留系统配置升级时，应检查已有时区设置。

## x86 的 PPPoE IPv6 默认值

ImmortalWrt 和 LibWrt x86 均注入 `files/x86/98-immortalwrt-pppoe-ipv6-v2`，适用于桥接光猫、OpenWrt 主路由 PPPoE 拨号且运营商提供 IPv6-PD 的环境。首次启动或保留配置升级后执行一次，会设置 WAN IPv6 自动获取及前缀委托、LAN /64、关闭 LAN 前缀委派与 EUI-64 后缀、RA/SLAAC、存在可用前缀时通告默认路由器、过滤 AAAA 查询；停用 LAN DHCPv6、NDP 代理及 RA IPv6 DNS 通告。经 dnsmasq 查询时 IPv6 域名解析会被过滤，可能影响仅支持 IPv6 的域名；OpenClash、加密 DNS 和使用其他 DNS 的客户端可能绕过此过滤。

脚本不会设置 WAN 协议、账号密码、LAN IPv4 或防火墙。仅当独立 `wan6` 是 DHCPv6 且直接绑定和 WAN 相同的物理设备时，设为不自动启动，避免与 PPPoE 的动态 `wan_6` 并存；自定义接口不改。已有个性化 IPv6 配置会被本脚本的上述设置覆盖，请备份。光猫桥接及公网 IPv6-PD 由运营商提供，编译固件本身无法保证。

## ZeroTier 网络默认选项

ImmortalWrt 和 LibWrt x86 的全新固件预设 ZeroTier 网络复选框：启用、允许管理 IP/路由、允许入站、允许转发、IP 动态伪装。示例网络的 ID 留空；新增网络也默认勾选上述选项。全局服务开关仍需用户自行启用，现有 ZeroTier 配置不会在保留配置升级时强行更改。

预置网络的转发接口和伪装接口均设置为 `br-lan`；新建网络请检查并按需选择。插件中留空表示所有接口。允许入站、转发和伪装会改变 ZeroTier 网络可访问的范围，请确认加入可信网络并在控制端授权设备。

## x86 的 Nikki 默认值

固件编译时基于 Nikki 上游配置设置 20 秒启动延迟、TCP/UDP TUN、IPv4/IPv6 绕过中国大陆地址、统一延迟和 TCP 并发，并保留 IPv6 DNS、IPv6 流量接管和 IPv6 DNS 劫持。具体是否生效还受 Nikki 订阅配置及其覆写开关影响。

不打包用户的订阅地址、节点或配置文件名；Nikki 主开关保留上游默认关闭，需用户选择自己的配置并启用。新固件 API 密码默认为 `123456`，默认代理认证密码同样为 `123456`；保留配置升级不强制改已有 Nikki 设置。请勿将弱密码保护的 API 端口开放到公网。

Nikki 开启 IPv6 DNS 与 IPv6 DNS 劫持后，查询可能不经过 dnsmasq；固件中设置的 dnsmasq AAAA 过滤不保证控制 Nikki 或其他独立 DNS 的解析结果。

## x86 的 Vlmcsd 与 UPnP 默认值

全新固件默认启用 Vlmcsd 和客户端自动发现；互联网访问保持关闭。UPnP 默认启用服务、UPnP IGD、PCP/NAT-PMP、允许私有 IPv4 和 IGDv1 兼容模式。LibWrt 25.12 使用“强制转发”实现同一私有 IPv4 功能，选项位于 UPnP 高级设置；带宽数字、访问控制规则、安全模式及其他选项保持源码默认值。UPnP 允许局域网设备按规则请求端口映射；实际公网连通性取决于上游网络。

这些设置作用于软件包初始配置；保留配置升级时，已有 Vlmcsd/UPnP 配置不会被强制覆盖。

## 发布与排查

发布文件名包含北京时间戳，profiles.json 的文件引用和校验清单同步更新。Release 标签包含设备、日期、运行编号和尝试次数，避免同日重编混用产物。附件包含 `build.config`、`build.diffconfig`、`build-revisions.txt` 和重新生成的 `sha256sums`。

下载使用 HTTP 错误检查和重试，空文件、失败下载和解压错误会中止构建。HTTP 成功和非空检查并不验证规则库的内部格式。

自动清理保留至少 14 天内的运行记录，默认保留编译缓存；手动运行 Auto-Clean 时可选择清空缓存。Release 仍按原策略保留最近指定数量。

`patch/0001-fix-upnp.patch` 是历史补丁，目前未被工作流应用。本次保留文件，不自动启用。



Release 标题及发布文件名包含北京时间戳（年月日_时分秒）；profiles.json 与 sha256sums 保持引用和校验一致。

ZeroTier 全局默认保持关闭；监听端口为 9993，本地配置文件路径为 `/etc/zerotier.conf`，持久配置目录为 `/etc/zerotier`，允许入站，不启用复制配置目录。首次启用时由设备生成密钥。
