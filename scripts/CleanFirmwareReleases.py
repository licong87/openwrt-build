#!/usr/bin/env python3
"""Keep the newest published release for each recognized firmware type."""
import json
import os
import re
import subprocess
import sys

GROUPS = {
    'x86': ('x86-imm', 'x86-LibWrt'),
    'arm': ('ipq60xx-libWrt-nowifi-ress01', 'ipq60xx-libWrt-nowifi-znm2',
            'ipq60xx-libWrt-wifi-ress01'),
}
kind = sys.argv[1]
repo = os.environ['GITHUB_REPOSITORY']
pages = json.loads(subprocess.check_output([
    'gh', 'api', '--paginate', '--slurp', f'/repos/{repo}/releases?per_page=100'
], text=True))
groups = {name: [] for name in GROUPS[kind]}
for page in pages:
    for release in page:
        if release.get('draft') or release.get('prerelease') or not release.get('published_at'):
            continue
        tag = release['tag_name']
        for name in groups:
            pattern = re.escape(name) + r'_(?:\d{4}\.\d{2}\.\d{2}|\d{8}_\d{6})_\d+_\d+'
            if re.fullmatch(pattern, tag):
                groups[name].append(release)
                break
for name, items in groups.items():
    items.sort(key=lambda item: (item['published_at'], item['id']), reverse=True)
    if not items:
        print(f'{name}: no recognized published release; nothing to delete', flush=True)
        continue
    print(f"{name}: keep {items[0]['tag_name']}", flush=True)
    for item in items[1:]:
        tag = item['tag_name']
        print(f'{name}: delete old release and tag {tag}', flush=True)
        subprocess.run(['gh', 'release', 'delete', tag, '--repo', repo, '--yes', '--cleanup-tag'], check=True)
