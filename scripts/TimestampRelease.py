#!/usr/bin/env python3
"""Add the build timestamp to release files and keep profiles.json references in sync."""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
stamp = sys.argv[2]
if not stamp or any(c not in '0123456789_-' for c in stamp):
    raise SystemExit('Invalid build timestamp')

protected = {'profiles.json', 'sha256sums'}
mapping = {}
for path in root.iterdir():
    if not path.is_file() or path.name in protected:
        continue
    name = path.name
    # Preserve compound extensions so tools still recognize compressed images.
    ext = next((e for e in ('.img.gz', '.tar.gz', '.bin.gz', '.squashfs.gz') if name.endswith(e)), path.suffix)
    base = name[:-len(ext)] if ext else name
    target = f'{base}_{stamp}{ext}'
    if (root / target).exists() or target in mapping.values():
        raise SystemExit(f'Duplicate release filename: {target}')
    mapping[name] = target

profiles = root / 'profiles.json'
if profiles.exists():
    data = json.loads(profiles.read_text(encoding='utf-8'))
    def update(obj):
        if isinstance(obj, str):
            return mapping.get(obj, obj)
        if isinstance(obj, list):
            return [update(item) for item in obj]
        if isinstance(obj, dict):
            return {key: update(value) for key, value in obj.items()}
        return obj
    profiles.write_text(json.dumps(update(data), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

for old, new in mapping.items():
    (root / old).rename(root / new)
print(f'Added timestamp to {len(mapping)} release files')
