#!/bin/bash
set -e

log() {
    echo -e "\n=============================="
    echo "📌 [$1] $2"
    echo "=============================="
}

done_ok() {
    echo "✅ DONE: $1"
    echo "------------------------------"
}

fail() {
    echo "❌ FAIL: $1"
    exit 1
}

echo "================ CI SETTINGS START ================"

# =========================================================
# 1. LuCI 基础
# =========================================================
log "1/12" "LuCI 基础配置"

echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config

done_ok "LuCI 基础配置"

# =========================================================
# 2. 网络优化
# =========================================================
log "2/12" "网络优化"

mkdir -p files/etc

cat >> files/etc/sysctl.conf <<EOF
net.netfilter.nf_conntrack_udp_timeout=10
net.netfilter.nf_conntrack_udp_timeout_stream=60
EOF

done_ok "网络优化"

# =========================================================
# 3. NSS
# =========================================================
log "3/12" "NSS 配置"

if [ -d "target/linux/qualcommax" ]; then
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> .config
fi

done_ok "NSS 配置"

# =========================================================
# 4. 时区
# =========================================================
log "4/12" "时区修复"

sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='UTC'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

echo "CONFIG_PACKAGE_zoneinfo-core=y" >> .config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> .config

done_ok "时区修复"

# =========================================================
# 5. mihomo 隔离
# =========================================================
log "5/12" "mihomo 清理"

sed -i '/mihomo/d' .config || true

cat >> .config <<EOF
# CONFIG_PACKAGE_mihomo is not set
# CONFIG_PACKAGE_mihomo-alpha is not set
# CONFIG_PACKAGE_mihomo-meta is not set
EOF

rm -rf package/OpenWrt-nikki/mihomo* feeds/packages/net/mihomo* feeds/luci/applications/luci-app-mihomo* 2>/dev/null || true

done_ok "mihomo 清理完成"

# =========================================================
# 6. DAED BTF
# =========================================================
log "6/12" "DAED BTF"

sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config || true
echo "CONFIG_DAED_USE_VMLINUX_BTF=n" >> .config

done_ok "DAED BTF"

# =========================================================
# 7. x86 LAN
# =========================================================
log "7/12" "LAN 绑定"

if grep -q "CONFIG_TARGET_x86=y" .config; then
    mkdir -p files/etc/uci-defaults

    cat > files/etc/uci-defaults/99-custom-lan-ports <<EOF
#!/bin/sh
uci set network.@device[0].ports='eth0 eth2 eth3'
uci commit network
exit 0
EOF

    chmod +x files/etc/uci-defaults/99-custom-lan-ports
fi

done_ok "LAN 配置"

# =========================================================
# 8. 规则库
# =========================================================
log "8/12" "规则库下载"

mkdir -p files/usr/share/v2ray files/etc/nikki/run

curl -sL -o files/usr/share/v2ray/geosite.dat \
https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat

curl -sL -o files/usr/share/v2ray/geoip.dat \
https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat

curl -sL -o files/etc/nikki/run/GeoSite.dat \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat

curl -sL -o files/etc/nikki/run/GeoIP.dat \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat

done_ok "规则库"

# =========================================================
# 9. Dashboard
# =========================================================
log "9/12" "Dashboard"

mkdir -p files/etc/nikki/run/ui

curl -sL -o /tmp/zashboard.zip \
https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip

unzip -oq /tmp/zashboard.zip -d files/etc/nikki/run/ui

done_ok "Dashboard"

# =========================================================
# 10. ZeroTier
# =========================================================
log "10/12" "ZeroTier 修复"

if [ -d "feeds/luci/applications/luci-app-zerotier" ]; then
    find feeds/luci/applications/luci-app-zerotier -name "*.json" \
        -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +

    find feeds/luci/applications/luci-app-zerotier -name "*.lua" \
        -exec sed -i 's/admin\/vpn\/zerotier/admin\/services\/zerotier/g' {} +
fi

done_ok "ZeroTier"

# =========================================================
# 11. DAED 替换
# =========================================================
log "11/12" "DAED 替换"

rm -rf package/daed package/luci-app-daed package/temp_daed_repo 2>/dev/null || true

git clone --depth=1 -b kix https://github.com/QiuSimons/luci-app-daed.git package/temp_daed_repo

mv package/temp_daed_repo/luci-app-daed package/luci-app-daed
mv package/temp_daed_repo/daed package/daed
rm -rf package/temp_daed_repo

sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config || true
echo "CONFIG_DAED_USE_VMLINUX_BTF=n" >> .config

sed -i 's/+DAED_USE_VMLINUX_BTF:vmlinux-btf//g' package/daed/Makefile || true

done_ok "DAED 替换"

# =========================================================
# 12. END
# =========================================================
log "12/12" "完成"

echo "🎉 CI SETTINGS COMPLETE - STABLE READY"
echo "================ CI SETTINGS END ================"
