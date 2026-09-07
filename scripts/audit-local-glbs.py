"""Read-only audit of every local combat3d GLB."""
from __future__ import annotations

import hashlib
import io
import json
import struct
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "gdproj" / "combat3d" / "models"
OUT = ROOT / "docs" / "local-art-audit-latest.json"


def audit(path: Path) -> dict:
    raw = path.read_bytes()
    item = {
        "file": path.relative_to(ROOT).as_posix(),
        "bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "header_valid": False,
        "triangles": 0,
        "textures": [],
        "errors": [],
    }
    try:
        magic, version, declared = struct.unpack_from("<4sII", raw, 0)
        if magic != b"glTF":
            raise ValueError(f"invalid magic {magic!r}")
        if version != 2:
            raise ValueError(f"unsupported GLB version {version}")
        if declared != len(raw):
            raise ValueError(f"declared length {declared} != actual {len(raw)}")
        chunks = []
        offset = 12
        while offset < len(raw):
            size, kind = struct.unpack_from("<II", raw, offset)
            start = offset + 8
            end = start + size
            if end > len(raw):
                raise ValueError("chunk extends past file")
            chunks.append((kind, raw[start:end]))
            offset = end
        if offset != len(raw):
            raise ValueError("invalid chunk alignment")
        json_chunks = [data for kind, data in chunks if kind == 0x4E4F534A]
        if len(json_chunks) != 1:
            raise ValueError(f"expected one JSON chunk, found {len(json_chunks)}")
        doc = json.loads(json_chunks[0].rstrip(b" \t\r\n\0"))
        bin_chunks = [data for kind, data in chunks if kind == 0x004E4942]
        binary = bin_chunks[0] if bin_chunks else b""
        item["header_valid"] = True
        item["meshes"] = len(doc.get("meshes", []))
        item["skins"] = len(doc.get("skins", []))
        item["animations"] = len(doc.get("animations", []))
        primitive_count = 0
        for mesh in doc.get("meshes", []):
            for prim in mesh.get("primitives", []):
                primitive_count += 1
                if prim.get("mode", 4) != 4:
                    item["errors"].append(f"non-triangle primitive mode {prim.get('mode')}")
                    continue
                if "indices" in prim:
                    item["triangles"] += doc["accessors"][prim["indices"]]["count"] // 3
                elif "POSITION" in prim.get("attributes", {}):
                    item["triangles"] += doc["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
        item["primitives"] = primitive_count
        for index, image in enumerate(doc.get("images", [])):
            tex = {"image": index, "name": image.get("name"), "mime_type": image.get("mimeType")}
            try:
                if "bufferView" in image:
                    view = doc["bufferViews"][image["bufferView"]]
                    start = view.get("byteOffset", 0)
                    payload = binary[start:start + view["byteLength"]]
                    with Image.open(io.BytesIO(payload)) as im:
                        tex.update({"width": im.width, "height": im.height, "format": im.format})
                else:
                    tex["unresolved_uri"] = image.get("uri")
            except Exception as exc:
                tex["error"] = str(exc)
                item["errors"].append(f"image {index}: {exc}")
            item["textures"].append(tex)
    except Exception as exc:
        item["errors"].append(str(exc))
    return item


files = sorted(MODEL_DIR.glob("*.glb"), key=lambda p: p.name.lower())
items = [audit(path) for path in files]
hashes = defaultdict(list)
for item in items:
    hashes[item["sha256"]].append(item["file"])
duplicates = [
    {"sha256": digest, "files": names}
    for digest, names in sorted(hashes.items()) if len(names) > 1
]
focus_tokens = ("repaired", "derived", "nobase", "aligned")
focus = [item for item in items if any(token in Path(item["file"]).name.lower() for token in focus_tokens)]
lute = next((item for item in items if item["file"].endswith("weapon_lute_1500_repaired.glb")), None)
raw_lute = next((item for item in items if item["file"].endswith("weapon_lute_tertiary_1500_raw.glb")), None)
derivations = []
for sidecar in sorted(MODEL_DIR.glob("*.derivation.json"), key=lambda p: p.name.lower()):
    entry = {"file": sidecar.relative_to(ROOT).as_posix(), "valid": False, "errors": []}
    try:
        metadata = json.loads(sidecar.read_text(encoding="utf-8"))
        entry["source"] = metadata.get("source")
        entry["derived"] = metadata.get("derived")
        for label in ("source", "derived"):
            declared_path = metadata.get(label)
            declared_hash = metadata.get(label + "_sha256")
            if not declared_path:
                entry["errors"].append(f"missing {label} path")
                continue
            target = ROOT / Path(declared_path.replace("\\", "/"))
            if not target.is_file():
                entry["errors"].append(f"missing {label} file: {declared_path}")
                continue
            actual_hash = hashlib.sha256(target.read_bytes()).hexdigest()
            entry[label + "_actual_sha256"] = actual_hash
            if declared_hash and declared_hash != actual_hash:
                entry["errors"].append(f"{label} SHA-256 mismatch")
        entry["valid"] = not entry["errors"]
    except Exception as exc:
        entry["errors"].append(str(exc))
    derivations.append(entry)
max_texture = max(
    (max(tex.get("width", 0), tex.get("height", 0)) for item in items for tex in item["textures"]),
    default=0,
)
report = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "scope": MODEL_DIR.relative_to(ROOT).as_posix() + "/*.glb",
    "checks": ["GLB v2 header and declared length", "triangle count", "embedded texture dimensions", "exact SHA-256 duplicates"],
    "summary": {
        "files": len(items),
        "valid_headers": sum(item["header_valid"] for item in items),
        "files_with_errors": sum(bool(item["errors"]) for item in items),
        "total_triangles": sum(item["triangles"] for item in items),
        "files_with_embedded_textures": sum(bool(item["textures"]) for item in items),
        "maximum_texture_dimension": max_texture,
        "duplicate_hash_groups": len(duplicates),
        "focus_variant_files": len(focus),
        "derivation_sidecars": len(derivations),
        "valid_derivation_sidecars": sum(entry["valid"] for entry in derivations),
    },
    "lute_repair": {
        "repaired": lute,
        "raw_source": raw_lute,
        "triangle_delta": (lute["triangles"] - raw_lute["triangles"]) if lute and raw_lute else None,
        "distinct_from_raw": (lute["sha256"] != raw_lute["sha256"]) if lute and raw_lute else None,
    },
    "duplicate_hashes": duplicates,
    "derivation_sidecars": derivations,
    "focus_variants": focus,
    "files": items,
}
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report["summary"], ensure_ascii=False))
