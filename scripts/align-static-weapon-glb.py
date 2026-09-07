"""Bake a static Tripo weapon's principal axes into its vertices; preserve its source GLB."""
import argparse
import json
import math
import struct
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('source', type=Path)
p.add_argument('output', type=Path)
args = p.parse_args()
assert args.source.resolve() != args.output.resolve()
raw = args.source.read_bytes()
magic, version, size = struct.unpack_from('<4sII', raw)
assert magic == b'glTF' and version == 2 and size == len(raw)
json_size, json_type = struct.unpack_from('<II', raw, 12)
assert json_type == 0x4E4F534A
doc = json.loads(raw[20:20 + json_size])
bin_size, bin_type = struct.unpack_from('<II', raw, 20 + json_size)
assert bin_type == 0x004E4942
binary = bytearray(raw[28 + json_size:28 + json_size + bin_size])
assert not doc.get('skins') and not doc.get('animations')
assert len(doc['nodes']) == 1 and len(doc['meshes']) == 1
node = doc['nodes'][0]
assert node.get('mesh') == 0 and not any(k in node for k in ('rotation', 'scale', 'matrix', 'children'))
translation = node.get('translation', [0, 0, 0])

def values(index):
    accessor = doc['accessors'][index]
    assert accessor['componentType'] == 5126 and accessor['type'] in ('VEC3', 'VEC4') and 'sparse' not in accessor
    view = doc['bufferViews'][accessor['bufferView']]
    assert view.get('buffer', 0) == 0
    width = 3 if accessor['type'] == 'VEC3' else 4
    offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', width * 4)
    return accessor, offset, stride, width, [struct.unpack_from('<' + 'f' * width, binary, offset + i * stride) for i in range(accessor['count'])]

attributes = doc['meshes'][0]['primitives']
position_ids = {part['attributes']['POSITION'] for part in attributes}
points = [v for idx in position_ids for v in values(idx)[4]]
mean = [sum(v[i] for v in points) / len(points) for i in range(3)]
cov = [[sum((v[i] - mean[i]) * (v[j] - mean[j]) for v in points) / len(points) for j in range(3)] for i in range(3)]
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def normalize(v):
    length = math.sqrt(dot(v, v))
    assert length > 1e-12
    return [x / length for x in v]
def multiply(v): return [dot(row, v) for row in cov]
axis = normalize([1, 1, 1])
for _ in range(80): axis = normalize(multiply(axis))
if axis[0] < 0: axis = [-x for x in axis]
side = normalize([-axis[1], axis[0], 0])
for _ in range(80):
    v = multiply(side)
    side = normalize([v[i] - dot(v, axis) * axis[i] for i in range(3)])
if side[1] < 0: side = [-x for x in side]
normal = [axis[1]*side[2]-axis[2]*side[1], axis[2]*side[0]-axis[0]*side[2], axis[0]*side[1]-axis[1]*side[0]]
rotation = [axis, normal, [-x for x in side]]
processed = set()
for part in attributes:
    for semantic in ('POSITION', 'NORMAL', 'TANGENT'):
        if semantic not in part['attributes']: continue
        idx = part['attributes'][semantic]
        if idx in processed: continue
        processed.add(idx)
        accessor, offset, stride, width, vectors = values(idx)
        output = []
        for i, vector in enumerate(vectors):
            xyz = [vector[j] + (translation[j] if semantic == 'POSITION' else 0) for j in range(3)]
            transformed = [dot(row, xyz) for row in rotation]
            if width == 4: transformed.append(vector[3])
            struct.pack_into('<' + 'f' * width, binary, offset + i * stride, *transformed)
            output.append(transformed)
        if semantic == 'POSITION':
            accessor['min'] = [min(v[i] for v in output) for i in range(3)]
            accessor['max'] = [max(v[i] for v in output) for i in range(3)]
node.pop('translation', None)
encoded = json.dumps(doc, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
args.output.write_bytes(struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(binary)) + struct.pack('<II', len(encoded), json_type) + encoded + struct.pack('<II', len(binary), bin_type) + binary)
print('Aligned static weapon:', args.output)
print('Source long axis:', axis)
