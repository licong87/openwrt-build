#!/bin/bash

# =========================================================
# 1. 基础配置修改
# =========================================================
echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config

# =========================================================
# 2. 调整内核参数
# =========================================================
mkdir -p files/etc
echo "net.netfilter.nf_conntrack_udp_timeout=10" >> files/etc/sysctl.conf
echo "net.netfilter.nf_conntrack_udp_timeout_stream=60" >> files/etc/sysctl.conf

# =========================================================
# 3. 高通 NSS 优化
# =========================================================
if [ -d "target/linux/qualcommax" ]; then
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> .config
fi

# =========================================================
# 5. 时区修复
# =========================================================
sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='UTC'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

echo "CONFIG_PACKAGE_zoneinfo-core=y" >> .config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> .config

# =========================================================
# 6. 规则库
# =========================================================
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


# =========================================================
# 7. Dashboard
# =========================================================
mkdir -p files/etc/nikki/run/ui

curl -L -o /tmp/zashboard.zip \
https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip

unzip -oq /tmp/zashboard.zip -d files/etc/nikki/run/ui


# =========================================================
# 8. x86 LAN 绑定
# =========================================================
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
fi


# =========================================================
# 9. ZeroTier 修复
# =========================================================
if [ -d "feeds/luci/applications/luci-app-zerotier" ]; then
    find feeds/luci/applications/luci-app-zerotier/ -type f -name "*.json" \
    -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +

    find feeds/luci/applications/luci-app-zerotier/ -type f -name "*.lua" \
    -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +
fi


# =========================================================
# 10. DAED 修复（重点修复版）
# =========================================================
echo "🚀 修复 DAED vmlinux-btf..."

# 强制关闭 Kconfig
sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config
echo "CONFIG_DAED_USE_VMLINUX_BTF=n" >> .config

# 直接删除 Makefile 条件依赖（关键）
sed -i 's/+DAED_USE_VMLINUX_BTF:vmlinux-btf//g' package/daed/Makefile

echo "DAED BTF fix done"


# =========================================================
# 11. Mihomo 彻底修复（重点）
# =========================================================
echo "🚀 修复 Mihomo 冲突..."

# 一次性清干净所有冲突源
sed -i '/CONFIG_PACKAGE_mihomo/d' .config
sed -i '/CONFIG_PACKAGE_mihomo-alpha/d' .config
sed -i '/CONFIG_PACKAGE_mihomo-meta/d' .config

# 强制关闭
echo "# CONFIG_PACKAGE_mihomo is not set" >> .config
echo "# CONFIG_PACKAGE_mihomo-alpha is not set" >> .config
echo "# CONFIG_PACKAGE_mihomo-meta is not set" >> .config

echo "Mihomo conflict resolved"


# =========================================================
# 12. DAED 替换（QiuSimons）
# =========================================================
./scripts/feeds uninstall dae
./scripts/feeds uninstall daed
./scripts/feeds uninstall luci-app-dae
./scripts/feeds uninstall luci-app-daed

git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed.git package/temp_daed_repo

mv package/temp_daed_repo/luci-app-daed package/luci-app-daed
mv package/temp_daed_repo/daed package/daed
rm -rf package/temp_daed_repo
