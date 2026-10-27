#!/bin/bash
set -euo pipefail

# 本脚本由工作流在 OpenWrt 源码根目录调用。
[[ -f .config && -d package ]] || { echo "错误：请在已载入 .config 的源码根目录运行" >&2; exit 1; }
asset_tmp=$(mktemp -d)
trap 'rm -rf "$asset_tmp"' EXIT

download() {
    local destination=$1 url=$2
    curl -fL --retry 3 --connect-timeout 30 --max-time 600 \
        -o "$asset_tmp/download" "$url"
    [[ -s "$asset_tmp/download" ]] || { echo "下载为空：$url" >&2; return 1; }
    mv "$asset_tmp/download" "$destination"
}

# =========================================================
# 🚀 OpenWrt 自定义构建脚本（可读增强稳定版）
# =========================================================

# =========================================================
# 1. 基础 LuCI 配置
# =========================================================
echo "📌 [1/9] 配置 LuCI 基础环境..."

echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config


# =========================================================
# 2. 内核网络优化（UDP/转发优化）
# =========================================================
echo "📌 [2/9] 优化内核网络参数..."

mkdir -p files/etc
if [[ -f files/etc/sysctl.conf ]]; then
    sed -i '/^net\.netfilter\.nf_conntrack_udp_timeout=/d; /^net\.netfilter\.nf_conntrack_udp_timeout_stream=/d' files/etc/sysctl.conf
fi

echo "net.netfilter.nf_conntrack_udp_timeout=10" >> files/etc/sysctl.conf
echo "net.netfilter.nf_conntrack_udp_timeout_stream=60" >> files/etc/sysctl.conf


# =========================================================
# 3. Qualcomm NSS 优化
# =========================================================
echo "📌 [3/9] Qualcomm NSS 配置优化..."

if grep -qx "CONFIG_TARGET_qualcommax=y" .config &&
   grep -rq '^[[:space:]]*config NSS_FIRMWARE_VERSION_12_2' target package feeds; then
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> .config
    echo "✅ NSS 配置已锁定 12.2"
fi


# =========================================================
# 4. 时区修复（避免日志错乱）
# =========================================================
echo "📌 [4/9] 修复系统时区..."

mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/98-custom-timezone <<'TIMEZONE'
#!/bin/sh
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
TIMEZONE
chmod +x files/etc/uci-defaults/98-custom-timezone

echo "CONFIG_PACKAGE_zoneinfo-core=y" >> .config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> .config


# =========================================================
# 5. 规则库预置（Nikki / v2ray）
# =========================================================
echo "📌 [5/9] 下载规则库..."

mkdir -p files/usr/share/v2ray

download files/usr/share/v2ray/geosite.dat \
https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat

download files/usr/share/v2ray/geoip.dat \
https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat


mkdir -p files/etc/nikki/run

download files/etc/nikki/run/GeoSite.dat \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat

download files/etc/nikki/run/GeoIP.dat \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat

download files/etc/nikki/run/ASN.mmdb \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/GeoLite2-ASN.mmdb

download files/etc/nikki/run/Country.mmdb \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb

download files/etc/nikki/run/geoip.metadb \
https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb

echo "✅ 规则库下载完成"


# =========================================================
# 6. Nikki Dashboard 预装
# =========================================================
echo "📌 [6/9] 下载 Nikki Dashboard..."

mkdir -p files/etc/nikki/run/ui

download "$asset_tmp/zashboard.zip" \
https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip

unzip -oq "$asset_tmp/zashboard.zip" -d files/etc/nikki/run/ui

echo "✅ Dashboard 安装完成"


# =========================================================
# 7. x86 LAN 自动绑定
# =========================================================
echo "📌 [7/9] x86 网口绑定配置..."

if grep -qx "CONFIG_TARGET_x86=y" .config; then
    mkdir -p files/etc/uci-defaults
    # 资源路径按脚本位置解析，避免依赖当前目录。
    customization_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    cp "$customization_root/files/x86/99-j4125-lan-ports-v2" \
       files/etc/uci-defaults/99-j4125-lan-ports-v2
    chmod +x files/etc/uci-defaults/99-j4125-lan-ports-v2
    echo "✅ J4125 LAN 自动桥接配置已注入"

    if [[ "${REPO_SOURCE:-}" == "immortalwrt" ]]; then
        cp "$customization_root/files/x86/98-immortalwrt-pppoe-ipv6-v2" \
           files/etc/uci-defaults/98-immortalwrt-pppoe-ipv6-v2
        chmod +x files/etc/uci-defaults/98-immortalwrt-pppoe-ipv6-v2
        echo "✅ ImmortalWrt PPPoE IPv6 主路由默认配置已注入"
        python3 "$customization_root/scripts/ZeroTierDefaults.py" "$PWD"
        echo "✅ ZeroTier 网络复选框默认值已设置"
        python3 "$customization_root/scripts/NikkiDefaults.py" "$PWD"
        echo "✅ Nikki 非敏感默认选项已设置"
        python3 "$customization_root/scripts/ServiceDefaults.py" "$PWD"
        echo "✅ Vlmcsd 和 UPnP 默认选项已设置"
    fi
fi

# =========================================================
# 8. ZeroTier 菜单修复
# =========================================================
echo "📌 [8/9] ZeroTier 菜单路径修复..."

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
echo "📌 [9/9] 修复 DAED vmlinux-btf 依赖（使用内核 BTF 模式）..."

# 只保留内核 BTF 模式，不使用外部 vmlinux-btf 包
sed -i '/CONFIG_DAED_USE_VMLINUX_BTF/d' .config
echo '# CONFIG_DAED_USE_VMLINUX_BTF is not set' >> .config

echo "✅ DAED BTF 已锁定为 kernel built-in 模式"


echo "📌 删除 mihomo-alpha（修复循环依赖）..."

rm -rf package/OpenWrt-nikki/mihomo-alpha

echo "✅ mihomo-alpha 已删除"
