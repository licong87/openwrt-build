#!/usr/bin/env python3
"""Preset only the ZeroTier network checkboxes in ImmortalWrt x86 builds."""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
ui_path = root / 'feeds/luci/applications/luci-app-zerotier/htdocs/luci-static/resources/view/zerotier/config.js'
config_path = root / 'feeds/packages/net/zerotier/files/etc/config/zerotier'
ui = ui_path.read_text(encoding='utf-8')
config = config_path.read_text(encoding='utf-8')

# The network and global forms both contain fw_allow_input; restrict changes
# to the network grid. Explicit writes prevent LuCI from eliding defaults.
marker = "s = m.section(form.GridSection, 'network'"
if ui.count(marker) != 1:
    raise SystemExit('ZeroTier: cannot identify network grid; review upstream UI')
head, body = ui.split(marker, 1)
for name in ('enabled', 'allow_managed', 'fw_allow_input', 'fw_allow_forward', 'fw_allow_masq'):
    pattern = re.compile(r"(?ms)^(\s*o = s\.option\(form\.Flag, '" + re.escape(name) + r"',.*?)(?=^\s*o = s\.option\(|^\s*return m\.render\()")
    matches = list(pattern.finditer(body))
    if len(matches) != 1:
        raise SystemExit(f'ZeroTier: expected one network option {name}, found {len(matches)}')
    match = matches[0]
    block = match.group(0)
    if 'o.default = o.enabled;' not in block:
        block = block.replace("\n\t\to.editable = true;", "\n\t\to.default = o.enabled;\n\t\to.editable = true;", 1)
    if 'o.rmempty = false;' not in block:
        block = block.replace("\n\t\to.editable = true;", "\n\t\to.rmempty = false;\n\t\to.editable = true;", 1)
    if 'o.default = o.enabled;' not in block or 'o.rmempty = false;' not in block:
        raise SystemExit(f'ZeroTier: cannot set defaults for {name}; review upstream UI')
    body = body[:match.start()] + block + body[match.end():]
new_ui = head + marker + body

# Supply an empty example network, never embed the user's ID or activate the
# upstream example ID. Leave global service, interfaces and other options alone.
start = re.search(r"(?m)^config network ['\"]earth['\"]\s*$", config)
if not start:
    raise SystemExit('ZeroTier: cannot find default network earth; review upstream config')
end = re.search(r'^config\s', config[start.end():], re.M)
end_index = start.end() + end.start() if end else len(config)
block = config[start.start():end_index]
for key, value in (('enabled', '1'), ('allow_managed', '1'), ('fw_allow_input', '1'), ('fw_allow_forward', '1'), ('fw_allow_masq', '1')):
    pattern = re.compile(r"(?m)^(\s*option\s+" + re.escape(key) + r"\s+)(['\"])[^'\"]*\2\s*$")
    block, count = pattern.subn(lambda m: m.group(1) + "'" + value + "'", block)
    if count != 1:
        raise SystemExit(f'ZeroTier: cannot set default {key}; review upstream config')
id_pattern = re.compile(r"(?m)^(\s*option\s+id\s+)(['\"])([^'\"]*)\2\s*$")
id_match = id_pattern.search(block)
if not id_match or id_match.group(3) not in ('', '8056c2e21c000001'):
    raise SystemExit('ZeroTier: unrecognized example network ID; not replacing it')
block = id_pattern.sub(lambda m: m.group(1) + "''", block, count=1)
new_config = config[:start.start()] + block + config[end_index:]

# Validate both outputs before touching either source file.
ui_path.write_text(new_ui, encoding='utf-8')
config_path.write_text(new_config, encoding='utf-8')
print('ZeroTier: preset network checkboxes; leave network ID and interfaces empty')
