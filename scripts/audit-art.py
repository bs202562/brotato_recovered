"""Inventory actual resource identities and texture references; never infer completion."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "gdproj"


def inventory():
    textures = {}
    identities = {"characters": [], "weapons": [], "enemies": []}
    weapon_groups = {}
    for path in sorted(PROJECT.rglob("*")):
        if not path.is_file() or ".import" in path.parts or "combat3d" in path.parts:
            continue
        relative = "res://" + path.relative_to(PROJECT).as_posix()
        if path.suffix.lower() in {".png", ".svg", ".jpg", ".jpeg", ".webp"}:
            textures.setdefault(relative, {"path": relative, "references": [], "status": "pending"})
        if path.suffix not in {".tres", ".tscn", ".gd", ".godot"}:
            continue
        content = path.read_text(encoding="utf-8-sig")
        for texture in set(re.findall(r'res://[^"\n]+\.(?:png|svg|jpe?g|webp)', content)):
            textures.setdefault(texture, {"path": texture, "references": [], "status": "pending"})["references"].append(relative)
        character = re.search(r'^my_id = "(character_[^"]+)"', content, re.M)
        weapon = re.search(r'^weapon_id = "([^"]+)"', content, re.M)
        enemy = re.search(r'^enemy_id = "([^"]+)"', content, re.M)
        if character:
            identities["characters"].append({"id": character[1], "resource": relative, "status": "shared_base_pending_identity"})
        if weapon:
            weapon_groups.setdefault(weapon[1], []).append(relative)
        if enemy and path.suffix == ".tscn":
            identities["enemies"].append({"id": enemy[1], "resource": relative, "status": "shared_base_pending_identity"})
    identities["weapons"] = [{"id": key, "resources": value, "status": "primitive_pending_final_art"} for key, value in sorted(weapon_groups.items())]
    result = {"schema": 1, "note": "Inventory is not an acceptance report. Pending includes archived 2D resources; references establish usage, not runtime visibility.", "identities": identities, "textures": list(textures.values())}
    output = ROOT / "docs" / "art-inventory.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({**{key: len(value) for key, value in identities.items()}, "textures": len(textures), "referenced_textures": sum(bool(t["references"]) for t in textures.values())}))


if __name__ == "__main__":
    inventory()
