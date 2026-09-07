"""Report a static imported weapon's upper surface for tier-plaque placement.
Reads the manifest and GLB only. Supports the single-mesh static Tripo exports;
rejects hierarchy/skinning rather than silently returning inaccurate geometry.
"""
import argparse
import json
import math
import struct
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("identity")
parser.add_argument("x", type=float)
parser.add_argument("z", type=float)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
entry = json.loads((root / "gdproj/combat3d/models.json").read_text(encoding="utf-8"))[args.identity]
blob = (root / "gdproj" / entry["path"].removeprefix("res://")).read_bytes()
size, kind = struct.unpack_from("<II", blob, 12)
assert kind == 0x4E4F534A
model = json.loads(blob[20:20 + size])
assert not model.get("skins") and not model.get("animations"), "Static exports only"
assert len(model["nodes"]) == 1 and len(model["meshes"]) == 1, "Single-node mesh only"
node = model["nodes"][0]
assert not any(key in node for key in ("matrix", "rotation", "children")), "Unsupported node transform"
data = blob[28 + size:]

def accessor(index):
    acc = model["accessors"][index]
    assert "sparse" not in acc
    view = model["bufferViews"][acc["bufferView"]]
    fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[acc["componentType"]]
    count = {"VEC3": 3, "VEC2": 2, "SCALAR": 1}[acc["type"]]
    stride = view.get("byteStride", struct.calcsize(fmt) * count)
    offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * count, data, offset + i * stride) for i in range(acc["count"])]

rotation = [math.radians(v) for v in entry.get("rotation", [0, entry.get("yaw", 0), 0])]
node_scale = node.get("scale", [1, 1, 1])
node_translation = node.get("translation", [0, 0, 0])

def transform(point):
    x, y, z = [(point[i] * node_scale[i] + node_translation[i]) * entry.get("scale", 1) for i in range(3)]
    ax, ay, az = rotation
    # Godot's default Euler order is YXZ: apply Z, X, then Y.
    x, y = x * math.cos(az) - y * math.sin(az), x * math.sin(az) + y * math.cos(az)
    y, z = y * math.cos(ax) - z * math.sin(ax), y * math.sin(ax) + z * math.cos(ax)
    x, z = x * math.cos(ay) + z * math.sin(ay), -x * math.sin(ay) + z * math.cos(ay)
    return x, y, z

vertices, triangles = [], []
for primitive in model["meshes"][0]["primitives"]:
    assert primitive.get("mode", 4) == 4
    start = len(vertices)
    vertices.extend(map(transform, accessor(primitive["attributes"]["POSITION"])))
    indices = [item[0] for item in accessor(primitive["indices"])]
    triangles.extend([[start + v for v in indices[i:i + 3]] for i in range(0, len(indices), 3)])
center = [(min(v[i] for v in vertices) + max(v[i] for v in vertices)) * 0.5 for i in range(3)]
offset = entry.get("weapon_offset", [0, 0, 0])
vertices = [[v[i] - center[i] + offset[i] for i in range(3)] for v in vertices]
heights = []
for triangle in triangles:
    a, b, c = [vertices[i] for i in triangle]
    det = (b[0] - a[0]) * (c[2] - a[2]) - (c[0] - a[0]) * (b[2] - a[2])
    if abs(det) < 1e-12:
        continue
    u = ((args.x - a[0]) * (c[2] - a[2]) - (c[0] - a[0]) * (args.z - a[2])) / det
    v = ((b[0] - a[0]) * (args.z - a[2]) - (args.x - a[0]) * (b[2] - a[2])) / det
    if u >= 0 and v >= 0 and u + v <= 1:
        heights.append(a[1] + u * (b[1] - a[1]) + v * (c[1] - a[1]))
print(json.dumps({"identity": args.identity, "x": args.x, "z": args.z, "upper_surface_y": max(heights) if heights else None,
                  "suggested_plaque_center_y": max(heights) + 0.006 if heights else None, "triangles": len(triangles)}))
