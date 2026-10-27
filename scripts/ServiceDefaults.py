#!/usr/bin/env python3
"""Preset requested UPnP and Vlmcsd options for ImmortalWrt and LibWrt x86 builds."""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
# 新版直接使用 ext_allow_private_ipv4；25.12 用 force_forwarding
# 传递给 miniupnpd 的同一个 ext_allow_private_ipv4 参数。
init_path = root / 'feeds/packages/net/miniupnpd/files/miniupnpd.init'
init = init_path.read_text(encoding='utf-8')
if re.search(r'(?m)^\s*config_get\s+ext_allow_private_ipv4\s+config\s+ext_allow_private_ipv4(?:\s|$)', init):
    private_ipv4_option = 'ext_allow_private_ipv4'
elif re.search(r'(?m)^\s*config_get\s+force_forwarding\s+config\s+force_forwarding(?:\s|$)', init) and re.search(r'(?m)^\s*upnpd_write_bool\s+ext_allow_private_ipv4\s+\$force_forwarding(?:\s|$)', init):
    private_ipv4_option = 'force_forwarding'
else:
    raise SystemExit(f'{init_path}: unknown private IPv4 option; review upstream service')
configurations = [
    (root / 'feeds/packages/net/vlmcsd/files/vlmcsd.conf', 'vlmcsd', {
        'enabled': '1', 'auto_activate': '1', 'internet_access': '0',
    }),
    (root / 'feeds/packages/net/miniupnpd/files/upnpd.config', 'upnpd', {
        'enabled': '1', 'enable_upnp': '1', 'enable_natpmp': '1',
        private_ipv4_option: '1', 'igdv1': '1',
    }),
]


def token(value):
    return r"(?:'" + re.escape(value) + r"'|\"" + re.escape(value) + r"\"|" + re.escape(value) + r")"


# Prepare and validate both changes first; do not leave a partially applied
# configuration if an upstream package changes its structure.
outputs = []
for path, section_type, options in configurations:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r'(?m)^config[ \t]+' + token(section_type) + r'[ \t]+' + token('config') + r'[ \t]*$')
    sections = list(pattern.finditer(text))
    if len(sections) != 1:
        raise SystemExit(f'{path}: expected one {section_type} config section')
    start, after = sections[0].start(), sections[0].end()
    next_section = re.search(r'^config[ \t]', text[after:], re.M)
    end = after + next_section.start() if next_section else len(text)
    block = text[start:end]
    for key, value in options.items():
        option = re.compile(r'(?m)^([ \t]*option[ \t]+' + token(key) + r'[ \t]+)(?:\'[^\']*\'|"[^"]*"|[^\s#]+)([ \t]*(?:#.*)?)$')
        matches = list(option.finditer(block))
        if len(matches) > 1:
            raise SystemExit(f'{path}: duplicate option {key}')
        if matches:
            block = option.sub(lambda m: m.group(1) + "'" + value + "'" + m.group(2), block, count=1)
        else:
            block = block.rstrip() + "\n\toption " + key + " '" + value + "'\n\n"
    outputs.append((path, text[:start] + block + text[end:]))

for path, content in outputs:
    path.write_text(content, encoding='utf-8')
print('预置 Vlmcsd 和 UPnP 服务选项；保留带宽、访问规则及其他配置')
