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

# 7. 强行注入 factory.ubi 生成规则 (注意：这里我用了标准的转义，确保格式正确)
# 强行注入 factory.ubi 生成规则，并补齐闪存物理参数
sed -i '/define Device\/zn_m2/a\  BLOCKSIZE := 128k\n  PAGESIZE := 2048\n  IMAGES += factory.ubi\n  IMAGE/factory.ubi := append-ubi' target/linux/qualcommax/image/ipq60xx.mk
sed -i '/define Device\/jdcloud_re-ss-01/a\  BLOCKSIZE := 128k\n  PAGESIZE := 2048\n  IMAGES += factory.ubi\n  IMAGE/factory.ubi := append-ubi' target/linux/qualcommax/image/ipq60xx.mk
