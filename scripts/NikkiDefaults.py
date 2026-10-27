#!/usr/bin/env python3
"""Set Nikki defaults for ImmortalWrt and LibWrt x86 firmware builds."""
import re
import sys
from pathlib import Path

path = Path(sys.argv[1]) / 'package/OpenWrt-nikki/nikki/files/nikki.conf'
text = path.read_text(encoding='utf-8')

# Preserve profile; preset the proxy authentication password as requested.
values = {
    ('config', 'config'): {'start_delay': '20'},
    ('mixin', 'mixin'): {
        'api_secret': '123456',
        'ipv6': '1',
        'dns_ipv6': '1',
        'unify_delay': '1',
        'tcp_concurrent': '1',
        'dns_proxy_server_nameserver_policy': '0',
    },
    ('proxy', 'proxy'): {
        'tcp_mode': 'tun',
        'udp_mode': 'tun',
        'ipv6_dns_hijack': '1',
        'ipv6_proxy': '1',
        'bypass_china_mainland_ip': '1',
        'bypass_china_mainland_ip6': '1',
    },
}

def token(value):
    return r"(?:'" + re.escape(value) + r"'|\"" + re.escape(value) + r"\"|" + re.escape(value) + r")"

for (section_type, section_name), options in values.items():
    pattern = re.compile(r'(?m)^config[ \t]+' + token(section_type) + r'[ \t]+' + token(section_name) + r'[ \t]*$')
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f'Nikki: expected one {section_type}/{section_name} section; review upstream configuration')
    start = matches[0].start()
    after_header = matches[0].end()
    next_section = re.search(r'^config[ \t]', text[after_header:], re.M)
    end = after_header + next_section.start() if next_section else len(text)
    block = text[start:end]
    for key, value in options.items():
        opt = re.compile(r'(?m)^([ \t]*option[ \t]+' + token(key) + r'[ \t]+)(?:\'[^\']*\'|"[^"]*"|[^\s#]+)([ \t]*(?:#.*)?)$')
        matches = list(opt.finditer(block))
        if len(matches) > 1:
            raise SystemExit(f'Nikki: duplicate option {section_type}.{key}; review upstream configuration')
        if matches:
            block = opt.sub(lambda m: m.group(1) + "'" + value + "'" + m.group(2), block, count=1)
        else:
            block = block.rstrip() + "\n\toption '" + key + "' '" + value + "'\n\n"
    text = text[:start] + block + text[end:]

# Set the default anonymous proxy authentication section's password.
auth_sections = list(re.finditer(r"(?m)^config[ \t]+['\"]?authentication['\"]?[ \t]*$", text))
if len(auth_sections) != 1:
    raise SystemExit('Nikki: expected one default authentication section')
start = auth_sections[0].start()
after = auth_sections[0].end()
next_section = re.search(r'^config[ \t]', text[after:], re.M)
end = after + next_section.start() if next_section else len(text)
block = text[start:end]
password = re.compile(r"""(?m)^([ \t]*option[ \t]+(?:'password'|"password"|password)[ \t]+)(?:'[^']*'|"[^"]*"|[^\s#]+)([ \t]*(?:#.*)?)$""")
if len(list(password.finditer(block))) != 1:
    raise SystemExit('Nikki: expected one authentication password')
block = password.sub(lambda m: m.group(1) + "'123456'" + m.group(2), block, count=1)
text = text[:start] + block + text[end:]

init_path = Path(sys.argv[1]) / 'package/OpenWrt-nikki/nikki/files/uci-defaults/init.sh'
init_text = init_path.read_text(encoding='utf-8')
old = 'uci set nikki.mixin.api_secret="$random"'
new = 'uci -q get nikki.mixin.api_secret >/dev/null || uci set nikki.mixin.api_secret="$random"'
old_auth = 'uci set nikki.@authentication[0].password="$random"'
new_auth = 'uci -q get nikki.@authentication[0].password >/dev/null || uci set nikki.@authentication[0].password="$random"'
if init_text.count(old_auth) != 1:
    raise SystemExit('Nikki: upstream authentication initialization changed')
if init_text.count(old) != 1:
    raise SystemExit('Nikki: upstream init script changed; review API secret initialization')
init_path.write_text(init_text.replace(old, new).replace(old_auth, new_auth), encoding='utf-8')
path.write_text(text, encoding='utf-8')
print('Nikki: preset TUN, IPv6 proxy, delay and mainland bypass; preset API secret; preset API and proxy authentication passwords')
