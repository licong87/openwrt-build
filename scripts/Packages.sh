#!/bin/bash

set -euo pipefail

# 工作目录必须是源码的 package；先在同一文件系统下载，再替换旧包。
[[ -d ../feeds/packages && -d ../feeds/luci ]] || { echo "错误：请在源码 package 目录运行" >&2; exit 1; }
package_tmp=$(mktemp -d .package-update.XXXXXX)
trap 'rm -rf "$package_tmp"' EXIT

UPDATE_PACKAGE() {
    local name=$1 repository=$2 branch=$3 mode=${4:-}
    local repo_name=${repository##*/}
    local staging="$package_tmp/$repo_name"
    local extracted_name=$name
    [[ "$name" != openclash ]] || extracted_name=luci-app-openclash
    local package_name candidate target
    local -a candidates=()

    git clone --depth=1 --single-branch --branch "$branch" \
        "https://github.com/$repository.git" "$staging"
    if [[ "$mode" == pkg ]]; then
        while IFS= read -r -d '' candidate; do
            candidates+=("$candidate")
        done < <(find "$staging" -mindepth 1 -maxdepth 4 -type d -name "$extracted_name" -print0)
        [[ ${#candidates[@]} == 1 && -f "${candidates[0]}/Makefile" ]] || {
            echo "错误：$repository 中未找到唯一有效的 $name" >&2; return 1;
        }
        # OpenClash 对应的真实目录名为 luci-app-openclash。
    else
        candidates=("$staging")
    fi

    [[ -n "$(find "${candidates[0]}" -maxdepth 2 -type f -name Makefile -print -quit)" ]] || {
        echo "错误：$repository 中没有可用的软件包 Makefile" >&2; return 1;
    }
    # 根据下载内容中真实的包目录名替换，避免 *argon* 等模糊匹配。
    while IFS= read -r -d '' candidate; do
        package_name=$(basename "$(dirname "$candidate")")
        for target in "./$package_name" "../feeds/luci/themes/$package_name" \
            "../feeds/luci/applications/$package_name" "../feeds/packages/net/$package_name"; do
            [[ ! -e "$target" && ! -L "$target" ]] || rm -rf -- "$target"
        done
    done < <(find "${candidates[0]}" -maxdepth 2 -type f -name Makefile -print0)

    printf '%s %s\n' "$repository" "$(git -C "$staging" rev-parse HEAD)" >> ../custom-package-revisions.txt
    target=$repo_name
    [[ "$mode" != pkg && "$mode" != name ]] || target=$name
    rm -rf -- "./$target"
    mv -- "${candidates[0]}" "./$target"
}

UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"
# UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
# UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"

# UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
# UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
# UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
# UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
# UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
# UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
# UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
# UPDATE_PACKAGE "gecoosac" "openwrt-fork/openwrt-gecoosac" "main"
# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
# UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
# UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
# UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
# UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
# UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
# UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"
