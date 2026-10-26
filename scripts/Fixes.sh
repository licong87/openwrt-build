#!/bin/bash
set -euo pipefail

# 从工作区根目录调用，保留 Nikki / libffi 兼容修复。
# sing-box 使用各源码 feeds 的配套版本、补丁与真实源码哈希。
# 禁止只改 PKG_VERSION：旧版源码无法应用新版包的 libcronet 补丁。
echo 'sing-box: 保留 feeds 配套版本与源码哈希'

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
