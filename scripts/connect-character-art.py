"""Connect the complete roster to portraits rendered from the combat outfits."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "gdproj"
inventory = json.loads((ROOT / "docs/art-inventory.json").read_text())
models = json.loads((PROJECT / "combat3d/models.json").read_text())
connected = []
for item in inventory["identities"]["characters"]:
    path = PROJECT / item["resource"].removeprefix("res://")
    replacement = f"res://combat3d/art/characters/{item['id']}.png"
    assert (PROJECT / replacement.removeprefix("res://")).exists(), replacement
    text = path.read_text(encoding="utf-8-sig")
    icon = re.search(r'^icon = ExtResource\( (\d+) \)', text, re.M)
    assert icon, path
    pattern = rf'(\[ext_resource path=")[^"]+(" type="Texture" id={icon[1]}\])'
    text, count = re.subn(pattern, lambda match: match[1] + replacement + match[2], text)
    assert count == 1, path
    path.write_text(text, encoding="utf-8", newline="\n")
    bespoke = models.get(item['id'], {}).get('authored_outfit', False)
    connected.append({"id": item["id"], "resource": item["resource"], "icon": replacement, "status": "independent_tripo_body" if bespoke else "shared_rig_authored_outfit", "bespoke_body": bespoke})
(ROOT / "docs/character-art-coverage.json").write_text(json.dumps(connected, indent=2) + "\n")
print(f"Connected {len(connected)} character portraits")
