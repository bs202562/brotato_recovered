"""Validate local downloaded GLBs and summarize game import budgets."""
import json
import struct
import sys
from pathlib import Path

for name in sys.argv[1:]:
    path = Path(name)
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    assert magic == b"glTF" and version == 2 and length == len(data), path
    json_length, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    gltf = json.loads(data[20:20 + json_length])
    counts, bounds = [], []
    for mesh in gltf.get("meshes", []):
        for primitive in mesh["primitives"]:
            accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
            bounds.append({"min": accessor.get("min"), "max": accessor.get("max")})
            if "indices" in primitive:
                counts.append(gltf["accessors"][primitive["indices"]]["count"] // 3)
    print(json.dumps({"file": str(path), "bytes": len(data), "triangles": sum(counts), "skins": len(gltf.get("skins", [])), "animations": [a.get("name") for a in gltf.get("animations", [])], "bounds": bounds}))
