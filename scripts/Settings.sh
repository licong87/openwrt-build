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
sed -i "s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g" target/linux/qualcommax/image/ipq60xx.mk

# 5. 修改系统默认时区 (解决日志时间对不上的问题)
sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s/zonename='UTC'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

# 6. 补齐标准时区数据库 (必选，否则 dae/Nikki 控制面板显示的时间是乱的)
echo "CONFIG_PACKAGE_zoneinfo-core=y" >> .config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> .config

# =========================================================
# 注入全网最全规则库 (适配 dae & Nikki)
# =========================================================

echo "🚀 开始下载满血规则库， dae 与 Nikki 互不干扰，开机即用！"

# ---------------------------------------------------------
# 1. 准备 dae 的规则目录 (使用 Loyalsoldier 满血版)
# ---------------------------------------------------------
mkdir -p files/usr/share/v2ray
echo "-> 下载 dae 专用的 Loyalsoldier 规则 (全小写)..."
# 使用镜像加速，确保编译不超时
curl -L -o files/usr/share/v2ray/geosite.dat https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat
curl -L -o files/usr/share/v2ray/geoip.dat https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat


# ---------------------------------------------------------
# 2. 准备 Nikki (Mihomo) 的规则目录 (使用 MetaCubeX 源)
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

# 7. 强行注入 factory.ubi 生成规则 (注意：这里我用了标准的转义，确保格式正确)
# 强行注入 factory.ubi 生成规则，并补齐闪存物理参数
# 强制修正 UBI 打包参数，解决兆能/亚瑟 PAGESIZE 缺失导致的报错
sed -i 's/append-ubi,$(PAGESIZE),$(BLOCKSIZE)/append-ubi,2048,128k/g' include/image-commands.mk
