"""Map reviewed, regular icon atlases via Godot AtlasTexture (no image editing)."""
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "gdproj"
items = json.loads((ROOT / "docs/item-art-inventory.json").read_text())
connected, pending = [], []
for index, item in enumerate(items):
    page, slot = divmod(index, 36)
    atlas = PROJECT / f"combat3d/art/items/items_atlas_{page}.png"
    if not atlas.exists():
        pending.append(item["id"])
        continue
    width, height = struct.unpack(">II", atlas.read_bytes()[16:24])
    assert width == height and width % 6 == 0, (atlas, width, height)
    cell = width // 6
    x, y = slot % 6 * cell, slot // 6 * cell
    texture_path = f"res://combat3d/art/items/{item['id']}.tres"
    texture = f'''[gd_resource type="AtlasTexture" load_steps=2 format=2]

[ext_resource path="res://combat3d/art/items/items_atlas_{page}.png" type="Texture" id=1]

[resource]
atlas = ExtResource( 1 )
region = Rect2( {x}, {y}, {cell}, {cell} )
filter_clip = true
'''
    (PROJECT / texture_path.removeprefix("res://")).write_text(texture, encoding="utf-8")
    resource = ROOT / item["resource"]
    text = resource.read_text(encoding="utf-8-sig")
    icon = re.search(r'^icon = ExtResource\( (\d+) \)', text, re.M)
    assert icon, resource
    pattern = rf'(\[ext_resource path=")[^"]+(" type="Texture" id={icon[1]}\])'
    text, count = re.subn(pattern, lambda match: match[1] + texture_path + match[2], text)
    assert count == 1, resource
    resource.write_text(text, encoding="utf-8", newline="\n")
    connected.append({**item, "page": page, "slot": slot, "texture": texture_path})
(ROOT / "docs/item-art-coverage.json").write_text(json.dumps({"connected": connected, "pending": pending}, indent=2) + "\n")
print(f"Connected {len(connected)} item icons; pending {len(pending)}")
