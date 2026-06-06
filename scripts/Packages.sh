#!/bin/bash

# =========================================================
# 🚀 OpenWrt CI Packages Manager (Stable + Optional Pool)
# =========================================================

echo "================================================="
echo "🧠 CI PACKAGE PIPELINE START"
echo "================================================="

# =========================================================
# 0. 全局冲突清理（必须第一步）
# =========================================================
echo "🧹 [0] Cleaning conflicts..."

rm -rf package/*mihomo*
rm -rf package/OpenWrt-nikki/mihomo*
rm -rf feeds/*mihomo*

rm -rf package/daed
rm -rf package/luci-app-daed
rm -rf package/temp_daed_repo

echo "✅ Base cleanup done"

# =========================================================
# 1. 安装函数（CI稳定增强版）
# =========================================================
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4

	echo ""
	echo "📦 Installing: $PKG_NAME"

	rm -rf $(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d -iname "*$PKG_NAME*" -prune 2>/dev/null)

	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" \
	"https://github.com/$PKG_REPO.git" "package/tmp_$PKG_NAME"

	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		cp -rf $(find package/tmp_$PKG_NAME/* -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune 2>/dev/null) ./
		rm -rf package/tmp_$PKG_NAME
	else
		mv -f package/tmp_$PKG_NAME "$PKG_NAME"
	fi

	echo "✅ Done: $PKG_NAME"
}

# =========================================================
# 2. UI / 主题（基础必装）
# =========================================================
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

# =========================================================
# 3. 核心代理组件（稳定区）
# =========================================================
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"

# =========================================================
# 4. DAED（唯一源，避免 feeds 冲突）
# =========================================================
echo ""
echo "📌 Installing DAED (clean mode)..."

UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"

rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/packages/net/daed

echo "✅ DAED isolated"

# =========================================================
# 5. MIHOMO（强制禁用区）
# =========================================================
echo ""
echo "🚫 Disabling mihomo family..."

rm -rf package/*mihomo*
rm -rf package/OpenWrt-nikki/mihomo*
rm -rf feeds/*mihomo*

cat >> .config <<EOF

# ===== CI HARD DISABLE MIHOMO =====
# CONFIG_PACKAGE_mihomo is not set
# CONFIG_PACKAGE_mihomo-alpha is not set
# CONFIG_PACKAGE_mihomo-meta is not set
EOF

echo "✅ mihomo locked OFF"

# =========================================================
# 6. ⭐可选插件池（你要的“注释备用区”）
# =========================================================
echo ""
echo "📌 Optional packages pool (comment/uncomment to enable)"

# -----------------------------
# 🎨 主题扩展
# -----------------------------
# UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
# UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"
# UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
# UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

# -----------------------------
# 🌐 代理扩展（可选）
# -----------------------------
# UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
# UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
# UPDATE_PACKAGE "sing-box" "SagerNet/sing-box" "dev"

# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5"
# UPDATE_PACKAGE "smartdns" "pymumu/smartdns" "master"

# -----------------------------
# 📦 下载 / 工具
# -----------------------------
# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master"
# UPDATE_PACKAGE "openlist" "sbwml/luci-app-openlist2" "main"
# UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"

# -----------------------------
# 📡 网络增强
# -----------------------------
# UPDATE_PACKAGE "tailscale" "asvow/luci-app-tailscale" "main"
# UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
# UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"

# -----------------------------
# 🔔 推送 / 自动化
# -----------------------------
# UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
# UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"

# =========================================================
# 7. 版本更新模块（保留你的逻辑）
# =========================================================
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-not}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	echo ""
	echo "📌 Updating version: $PKG_NAME"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Pho 'PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)' $PKG_FILE | head -n 1)
		[ -z "$PKG_REPO" ] && continue

		local PKG_VER=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" \
			| jq -r "map(select(.prerelease|$PKG_MARK)) | first | .tag_name")

		local NEW_VER=$(echo $PKG_VER | sed "s/.*v//g; s/_/./g")

		local NEW_HASH=$(curl -sL "https://codeload.github.com/$PKG_REPO/tar.gz/$PKG_VER" | sha256sum | cut -b -64)
		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")

		if [[ $NEW_VER =~ ^[0-9] ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "⬆️ Updated $PKG_NAME: $OLD_VER → $NEW_VER"
		fi
	done
}

# =========================================================
# 8. 完成
# =========================================================
echo ""
echo "================================================="
echo "🎯 CI PACKAGE PIPELINE READY (STABLE + EXTENDABLE)"
echo "================================================="
