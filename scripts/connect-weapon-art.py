"""Connect engine-rendered weapon portraits to existing item resources."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "gdproj"
changes = []
for path in sorted(PROJECT.rglob("*.tres")):
    text = path.read_text(encoding="utf-8-sig")
    weapon = re.search(r'^weapon_id = "([^"]+)"', text, re.M)
    if not weapon:
        continue
    tier = re.search(r'^tier = (\d+)', text, re.M)
    icon = re.search(r'^icon = ExtResource\( (\d+) \)', text, re.M)
    if not tier or not icon:
        raise RuntimeError(f"Missing tier/icon: {path}")
    replacement = f"res://combat3d/art/weapons/{weapon[1]}_{min(3, int(tier[1]))}.png"
    assert (PROJECT / replacement.removeprefix("res://")).is_file(), replacement
    pattern = rf'(\[ext_resource path=")[^"]+(" type="Texture" id={icon[1]}\])'
    updated, count = re.subn(pattern, lambda match: match[1] + replacement + match[2], text)
    assert count == 1, path
    if updated != text:
        path.write_text(updated, encoding="utf-8", newline="\n")
    changes.append({"resource": "res://" + path.relative_to(PROJECT).as_posix(), "weapon": weapon[1], "tier": int(tier[1]), "icon": replacement})
(ROOT / "docs" / "weapon-art-coverage.json").write_text(json.dumps({"resources": changes, "unique_weapons": len({entry["weapon"] for entry in changes}), "status": "authored_3d_and_engine_rendered_icons"}, indent=2) + "\n", encoding="utf-8")
print(f"Connected {len(changes)} weapon resources, {len({entry['weapon'] for entry in changes})} identities")
