"""Assign explicit zombie art roles to every base and DLC enemy identity."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--dry-run', action='store_true', help='Report assignments without writing the project')
args = parser.parse_args()
PROJECT = ROOT / "gdproj"
inventory = json.loads((ROOT / "docs/art-inventory.json").read_text())
manifest_path = PROJECT / "combat3d/models.json"
manifest = json.loads(manifest_path.read_text())
roles = {
    "armored": "bruiser horned_bruiser helmet_alien colossus rhino giant giant_isopod turtle prisoner dead_whale megalodon stonefish walrus cool_walrus hermit iron_lung shielded_diplocaulus crab spider_crab lobster".split(),
    "bloated": "mom butcher bloated_spawner bloated_pufferfish pufferfish blobfish infected_blobfish sea_pig looting_pig spawner clam spiky_lung".split(),
    "toxic": "spitter horned_spitter invoker anemone firemane_anemone anglerfish brainy_squid colossal_squid dragonfish mad_dragonfish eel jellyfish viperfish vampire_squid".split(),
    "medic": "healer buffer corrupted_buffer monk".split(),
    "runner": "charger horned_charger fly horned_fly junkie dire_junkie pursuer chaser fin_alien predator croc gargoyle mantis goblin_shark scaled_goblin_shark stargazer scaled_stargazer diplocaulus narwhal shrimp bat".split(),
    "slasher": "slasher mad_slasher looter".split(),
    "small": "baby_alien plankton evil_mob".split(),
    "spore_nest": "slasher_egg infected_slasher_egg".split(),
    "tentacle": "tentacle lamprey impaled_worm".split(),
}
models = {
    "armored": "zombie_riot_captain_6000_walk",
    "bloated": "zombie_foodcourt_chef_6000_walk",
    "toxic": "zombie_toxic_janitor_3000_walk",
}
outfits = {
    "medic": ["medical", "medbag", "dde6ce", "a9bc83"],
    "runner": ["bandana", "pouches", "b56c48", "a3b985"],
    "slasher": ["hood", "toolbox", "7f678d", "adbc8b"],
    "small": ["beanie", "none", "9a6876", "aabd84"],
}
shared_paths = {"res://combat3d/models/" + name + ".glb" for name in [*models.values(), "zombie_shopper_3000_walk"]}
preserved = set()
bosses = {path.stem for path in PROJECT.rglob("*.gd") if "extends Boss" in path.read_text(encoding="utf-8-sig")}
coverage = []
for item in inventory["identities"]["enemies"]:
    identity = item["id"]
    matched = [role for role, names in roles.items() if identity in names]
    assert len(matched) == 1, (identity, matched)
    role = matched[0]
    size = 2.35 if identity in bosses else {"armored": 1.65, "bloated": 1.55, "small": 0.95, "runner": 1.25}.get(role, 1.35)
    entry = {"role": role, "scale": size, "yaw": 0, "offset_y": 0.002, "art_identity": identity}
    if role in {"spore_nest", "tentacle"}:
        entry["recipe"] = role
        entry["scale"] = 1.65 if identity in bosses else 1.0
    else:
        entry["path"] = "res://combat3d/models/" + models.get(role, "zombie_shopper_3000_walk") + ".glb"
        entry["animation"] = "presetbipedwalk"
        if role in outfits:
            entry["outfit"] = outfits[role].copy()
            if identity.startswith("horned_"):
                entry["outfit"][0] = "horns"
            if identity in {"gargoyle", "predator", "croc", "mantis"}:
                entry["outfit"][0] = "helmet"
            if identity == "corrupted_buffer":
                entry["outfit"][2:] = ["af76ae", "b0a27a"]
    key = "enemy:" + identity
    existing = manifest.get(key, {})
    bespoke = bool(existing.get("authored_model") or (existing.get("path") and existing["path"] not in shared_paths))
    if bespoke:
        entry = existing
        preserved.add(identity)
    manifest[key] = entry
    coverage.append({**item, "role": role, "model": entry.get("path", entry.get("recipe")), "status": "independent_tripo_body" if bespoke else "explicit_3d_role_variant", "bespoke_identity_mesh": bespoke})
if not args.dry_run:
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    (ROOT / "docs/enemy-art-coverage.json").write_text(json.dumps(coverage, indent=2) + "\n")
print("Preserved independent enemy models:", ", ".join(sorted(preserved)))
print(f"Assigned {len(coverage)} enemy resources / {len({e['id'] for e in coverage})} identities")
