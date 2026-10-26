#!/bin/bash
set -euo pipefail

# 从工作区根目录调用，保留现有 sing-box / Nikki / libffi 修复。
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.12.25/g' openwrt/feeds/packages/net/sing-box/Makefile
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' openwrt/feeds/packages/net/sing-box/Makefile

# 修复 nikki 编译时尝试拷贝不存在的 Go 源码而报错的问题
nikki_makefile=openwrt/package/OpenWrt-nikki/nikki/Makefile
if ! grep -q '^define Build/InstallDev' "$nikki_makefile"; then
  sed -i '/eval.*BuildPackage/i define Build/InstallDev\nendef\n' "$nikki_makefile"
fi

# 兼容不同源码的 libffi 路径
for libffi_makefile in \
  openwrt/package/libs/libffi/Makefile \
  openwrt/feeds/packages/libs/libffi/Makefile
do
  if [ -f "$libffi_makefile" ]; then
    sed -i 's#$(PKG_BUILD_DIR)/$(GNU_TARGET_NAME)\*/fficonfig.h#$(PKG_BUILD_DIR)/*/fficonfig.h#g' \
      "$libffi_makefile"
  fi
done
