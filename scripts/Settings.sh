#!/bin/bash

# =========================================================
# 🚀 OpenWrt 自定义构建脚本（可读增强稳定版）
# =========================================================

# =========================================================
# 1. 基础 LuCI 配置
# =========================================================
echo "📌 [1/12] 配置 LuCI 基础环境..."

echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config


# =========================================================
# 2. 内核网络优化（UDP/转发优化）
# =========================================================
echo "📌 [2/12] 优化内核网络参数..."

mkdir -p files/etc

echo "net.netfilter.nf_conntrack_udp_timeout=10" >> files/etc/sysctl.conf
echo "net.netfilter.nf_conntrack_udp_timeout_stream=60" >> files/etc/sysctl.conf


# =========================================================
# 3. Qualcomm NSS 优化
# =========================================================
echo "📌 [3/12] Qualcomm NSS 配置优化..."

if [ -d "target/linux/qualcommax" ]; then
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> .config
    echo "✅ NSS 配置已锁定 12.2"
fi


# =========================================================
# 4. 时区修复（避免日志错乱）
# =========================================================
echo "📌 [4/12] 修复系统时区..."

sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='UTC'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

echo "CONFIG_PACKAGE_zoneinfo-core=y" >> .config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> .config


# =========================================================
# 5. 规则库预置（Nikki / v2ray）
# =========================================================
echo "📌 [5/12] 下载规则库..."

mkdir -p files/usr/share/v2ray

curl -L -o files/usr/share/v2ray/geosite.dat \
https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat

curl -L -o files/usr/share/v2ray/geoip.dat \
https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat


mkdir -p files/etc/nikki/run

curl -L -o files/etc/nikki/run/GeoSite.dat \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat

curl -L -o files/etc/nikki/run/GeoIP.dat \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat

curl -L -o files/etc/nikki/run/ASN.mmdb \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/GeoLite2-ASN.mmdb

curl -L -o files/etc/nikki/run/Country.mmdb \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb

curl -L -o files/etc/nikki/run/geoip.metadb \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb

echo "✅ 规则库下载完成"


# =========================================================
# 6. Nikki Dashboard 预装
# =========================================================
echo "📌 [6/12] 下载 Nikki Dashboard..."

mkdir -p files/etc/nikki/run/ui

curl -L -o /tmp/zashboard.zip \
https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip

unzip -oq /tmp/zashboard.zip -d files/etc/nikki/run/ui

echo "✅ Dashboard 安装完成"


# =========================================================
# 7. x86 LAN 自动绑定
# =========================================================
echo "📌 [7/12] x86 网口绑定配置..."

if [ -d "openwrt" ]; then
    WRT_DIR="openwrt"
else
    WRT_DIR="."
fi

if grep -q "CONFIG_TARGET_x86=y" ${WRT_DIR}/.config; then
    mkdir -p ${WRT_DIR}/files/etc/uci-defaults

    cat << "EOF" > ${WRT_DIR}/files/etc/uci-defaults/99-custom-lan-ports
#!/bin/sh
uci set network.@device[0].ports='eth0 eth2 eth3'
uci commit network
exit 0
EOF

    chmod +x ${WRT_DIR}/files/etc/uci-defaults/99-custom-lan-ports

    echo "✅ x86 LAN 绑定已注入"
fi


# =========================================================
# 8. ZeroTier 菜单修复
# =========================================================
echo "📌 [8/12] ZeroTier 菜单路径修复..."

if [ -d "feeds/luci/applications/luci-app-zerotier" ]; then
    find feeds/luci/applications/luci-app-zerotier/ -type f -name "*.json" \
        -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +

    find feeds/luci/applications/luci-app-zerotier/ -type f -name "*.lua" \
        -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +

    echo "✅ ZeroTier 菜单修复完成"
fi


# =========================================================
# 9. DAED BTF 修复（推荐稳定版）
# =========================================================
echo "📌 [9/12] 修复 DAED vmlinux-btf 依赖（使用内核 BTF 模式）..."

# 只保留内核 BTF 模式，不使用外部 vmlinux-btf 包
sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config
echo '# CONFIG_DAED_USE_VMLINUX_BTF is not set' >> .config

echo "✅ DAED BTF 已锁定为 kernel built-in 模式"


echo "📌 删除 mihomo-alpha（修复循环依赖）..."

rm -rf package/OpenWrt-nikki/mihomo-alpha

echo "✅ mihomo-alpha 已删除"


# =========================================================
# 11. DAED 替换（QiuSimons 稳定版）
# =========================================================
# echo "📌 [11/12] 替换 DAED 为 QiuSimons 版本..."

# ./scripts/feeds uninstall dae
# ./scripts/feeds uninstall daed
# ./scripts/feeds uninstall luci-app-dae
# ./scripts/feeds uninstall luci-app-daed

# rm -rf package/temp_daed_repo
# rm -rf package/daed
# rm -rf package/luci-app-daed

# git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed.git package/temp_daed_repo

# mv package/temp_daed_repo/luci-app-daed package/luci-app-daed
# mv package/temp_daed_repo/daed package/daed
# rm -rf package/temp_daed_repo

# 关键：关闭外部 BTF
sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config
echo "CONFIG_DAED_USE_VMLINUX_BTF=n" >> .config

# 关键：删除 Makefile 外部依赖
sed -i 's/+DAED_USE_VMLINUX_BTF:vmlinux-btf//g' package/daed/Makefile

# echo "✅ DAED 替换完成"
