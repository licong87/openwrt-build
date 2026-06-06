#!/bin/bash

# 1. 基础配置修改
echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config

# 2. 调整内核参数 /etc/sysctl.conf (优化 UDP 转发，对网游和科学很有帮助)
mkdir -p files/etc
echo "net.netfilter.nf_conntrack_udp_timeout=10" >> files/etc/sysctl.conf
echo "net.netfilter.nf_conntrack_udp_timeout_stream=60" >> files/etc/sysctl.conf

# 3. 高通平台调整 (精准匹配环境)
if [ -d "target/linux/qualcommax" ]; then
    # 取消旧版 NSS，锁定适合大内存机器的 12.2 版本
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> .config
    echo "NSS version has fixed!"    
fi

# 4. 解除亚瑟内核封印：6M 变 12M (只有你要刷大分区版 U-Boot 才需要这个)
# sed -i "s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g" target/linux/qualcommax/image/ipq60xx.mk

# 5. 修改系统默认时区 (解决日志时间对不上的问题)
sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='UTC'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 6. 补齐标准时区数据库 (必选，否则 dae/Nikki 控制面板显示的时间是乱的)
echo "CONFIG_PACKAGE_zoneinfo-core=y" >> .config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> .config

# =========================================================
# 7.注入全网最全规则库 (适配 dae & Nikki)
# =========================================================

echo "🚀 开始下载满血规则库， dae 与 Nikki 互不干扰，开机即用！"

# ---------------------------------------------------------
# 7.1. 准备 dae 的规则目录 (使用 Loyalsoldier 满血版)
# ---------------------------------------------------------
mkdir -p files/usr/share/v2ray
echo "-> 下载 dae 专用的 Loyalsoldier 规则 (全小写)..."
# 使用镜像加速，确保编译不超时
curl -L -o files/usr/share/v2ray/geosite.dat https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat
curl -L -o files/usr/share/v2ray/geoip.dat https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat


# ---------------------------------------------------------
# 7.2. 准备 Nikki (Mihomo) 的规则目录 (使用 MetaCubeX 源)
# ---------------------------------------------------------
mkdir -p files/etc/nikki/run
echo "-> 下载 Nikki 专用的 MetaCubeX 规则 (强制首字母大写 + MMDB 支持)..."

# 下载 dat 格式 (为了适配包含 apple/telegram 标签的需求，必须用 MetaCubeX 的源)
curl -L -o files/etc/nikki/run/GeoSite.dat https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat
curl -L -o files/etc/nikki/run/GeoIP.dat https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat

# 下载 Nikki 核心强依赖的 MMDB 格式
curl -L -o files/etc/nikki/run/ASN.mmdb https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/GeoLite2-ASN.mmdb
curl -L -o files/etc/nikki/run/Country.mmdb https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb
curl -L -o files/etc/nikki/run/geoip.metadb https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb

echo "✅ 固件规则库预装完成！"

# ---------------------------------------------------------
# 8. 预装 Nikki Dashboard (Zashboard)
# ---------------------------------------------------------
echo "-> 下载 Nikki Dashboard..."

mkdir -p files/etc/nikki/run/ui

curl -L \
-o /tmp/zashboard.zip \
https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip

unzip -oq /tmp/zashboard.zip -d files/etc/nikki/run/ui

echo "✅ Nikki Dashboard 预装完成"

# =========================================================
# 9. 自定义注入：x86 固件首次开机默认绑定 eth0、eth2、eth3 到 LAN 网桥（arm直接跳过）
# =========================================================

# 自动探测 OpenWrt 源码目录
if [ -d "openwrt" ]; then
    WRT_DIR="openwrt"
else
    WRT_DIR="."
fi

# 检查 .config 文件中是否包含 x86 架构标志
if grep -q "CONFIG_TARGET_x86=y" ${WRT_DIR}/.config; then
    echo "检测到当前编译目标为 x86，正在注入多网口 LAN 桥接脚本..."
    
    # 创建自定义 files 目录结构
    mkdir -p ${WRT_DIR}/files/etc/uci-defaults

    # 写入绑定 LAN 口的自定义脚本
    cat << "EOF" > ${WRT_DIR}/files/etc/uci-defaults/99-custom-lan-ports
#!/bin/sh
# 仅供 x86 软路由使用：将 eth0 eth2 eth3 绑定到 br-lan 网桥
uci set network.@device[0].ports='eth0 eth2 eth3'
uci commit network
exit 0
EOF

    # 赋予脚本可执行权限
    chmod +x ${WRT_DIR}/files/etc/uci-defaults/99-custom-lan-ports

else
    echo "当前编译目标非 x86 (可能是 ARM 等)，跳过网口绑定脚本注入，保留官方默认网络配置。"
fi

# =========================================================
# 10. 调整 ZeroTier 菜单层级 (在编译源码阶段修改)
# =========================================================
echo "🚀 正在修改 ZeroTier 源码菜单路径..."

# 动态寻找 luaci-app-zerotier 的源码目录并进行无差别替换
if [ -d "feeds/luci/applications/luci-app-zerotier" ]; then
    # 1. 替换新版 JSON 菜单文件中的路径
    find feeds/luci/applications/luci-app-zerotier/ -type f -name "*.json" -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +
    
    # 2. 替换可能存在的旧版 Lua 路由文件中的路径（做兼容兜底）
    find feeds/luci/applications/luci-app-zerotier/ -type f -name "*.lua" -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +
    
    echo "✅ ZeroTier 菜单源码修改完成"
else
    echo "⚠️ 未找到 ZeroTier 源码目录，跳过修改。"
fi

# =========================================================
# 11. 修复 daed 依赖 (Kconfig 优雅版)
# =========================================================
echo "🚀 正在通过系统配置关闭外部 BTF 依赖..."

# 删除配置单中可能存在的旧版开启选项
sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config
# 明确写入：不使用外部 vmlinux-btf 软件包 (依赖内核原生 BTF)
echo '# CONFIG_DAED_USE_VMLINUX_BTF is not set' >> .config

echo "✅ 外部 BTF 依赖关闭完成"

# =========================================================
# 12. 修复 Mihomo 核心依赖死循环
# =========================================================
echo "🚀 正在清理配置单中的官方 Mihomo 冲突残留..."

# 1. 删掉原来的开启指令（如果有的话）
sed -i '/CONFIG_PACKAGE_mihomo-alpha/d' .config
sed -i '/CONFIG_PACKAGE_mihomo/d' .config

# 2. 明确写入：不要编译官方版核心！
echo '# CONFIG_PACKAGE_mihomo-alpha is not set' >> .config
echo '# CONFIG_PACKAGE_mihomo is not set' >> .config

echo "✅ Mihomo 核心冲突清理完成"

# =========================================================
# 彻底替换 QiuSimons 版 DAED (暴力破解云端缓存与软链接)
# =========================================================

echo "🛡️ 开始清理官方 DAED 残留与软链接..."
# 删除 Feeds 里的官方源码
rm -rf feeds/packages/net/dae
rm -rf feeds/packages/net/daed
rm -rf feeds/luci/applications/luci-app-dae
rm -rf feeds/luci/applications/luci-app-daed

# 删除 package/feeds 里的软链接（这是死灰复燃的根源）
rm -rf package/feeds/packages/dae
rm -rf package/feeds/packages/daed
rm -rf package/feeds/luci/luci-app-dae
rm -rf package/feeds/luci/luci-app-daed

echo "📦 正在拉取 QiuSimons 大神版源码..."
# 将大神的仓库 clone 到 package 的一个临时目录
git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed.git package/temp_daed_repo

# 将仓库里面的核心包和面板包提出来，平铺到 package 目录下
mv package/temp_daed_repo/luci-app-daed package/luci-app-daed
mv package/temp_daed_repo/daed package/daed
rm -rf package/temp_daed_repo

echo "🔥 正在篡改版本号，强杀 APK 云端缓存拦截..."
# 把版本号强行改成 999！让系统认为本地的代码版本遥遥领先，强制触发本地源码编译！
sed -i 's/PKG_RELEASE:=.*/PKG_RELEASE:=999/g' package/luci-app-daed/Makefile
sed -i 's/PKG_RELEASE:=.*/PKG_RELEASE:=999/g' package/daed/Makefile

echo "✅ DAED 定制版注入完成！"
