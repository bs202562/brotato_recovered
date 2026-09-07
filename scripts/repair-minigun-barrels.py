"""Offline local mesh repair: preserve the Tripo receiver, replace its single muzzle."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'gdproj/combat3d/models/weapon_minigun_1500_v2.glb'
target = source.with_name('weapon_minigun_1500_multibarrel.glb')
assert not target.exists(), 'Refuse to overwrite an existing derived export'
raw = source.read_bytes()
n = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+n])
binary = bytearray(raw[28+n:])
assert len(doc['meshes']) == len(doc['nodes']) == 1 and not doc.get('skins') and not doc.get('animations')
part = doc['meshes'][0]['primitives'][0]
assert len(doc['meshes'][0]['primitives']) == 1 and part.get('mode', 4) == 4
assert set(part['attributes']) == {'POSITION', 'NORMAL', 'TEXCOORD_0'}
assert not any(key in doc['nodes'][0] for key in ('matrix', 'scale', 'rotation'))

def read(index):
    ac = doc['accessors'][index]
    view = doc['bufferViews'][ac['bufferView']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[ac['type']]
    fmt = {5126: 'f', 5125: 'I', 5123: 'H'}[ac['componentType']]
    offset = view.get('byteOffset', 0) + ac.get('byteOffset', 0)
    stride = view.get('byteStride', struct.calcsize(fmt) * width)
    return [struct.unpack_from('<' + fmt * width, binary, offset + i * stride) for i in range(ac['count'])]

attributes = {key: read(index) for key, index in part['attributes'].items()}
indices = [row[0] for row in read(part['indices'])]
cut_x = 0.10
receiver = {key: [] for key in attributes}

def interpolate(a, b, amount):
    return {key: tuple(x + (y - x) * amount for x, y in zip(a[key], b[key])) for key in a}

for start in range(0, len(indices), 3):
    polygon = [{key: values[index] for key, values in attributes.items()} for index in indices[start:start+3]]
    clipped = []
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        inside_a, inside_b = a['POSITION'][0] <= cut_x, b['POSITION'][0] <= cut_x
        if inside_a:
            clipped.append(a)
        if inside_a != inside_b:
            clipped.append(interpolate(a, b, (cut_x - a['POSITION'][0]) / (b['POSITION'][0] - a['POSITION'][0])))
    for i in range(1, len(clipped)-1):
        for vertex in (clipped[0], clipped[i], clipped[i+1]):
            for key in receiver:
                receiver[key].append(vertex[key])

def accessor(values, kind, component=5126):
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[kind]
    fmt = 'I' if component == 5125 else 'f'
    binary.extend(b'\0' * (-len(binary) % 4))
    offset = len(binary)
    for value in values:
        binary.extend(struct.pack('<' + fmt * width, *value))
    view = len(doc['bufferViews'])
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(binary)-offset})
    result = {'bufferView': view, 'componentType': component, 'count': len(values), 'type': kind}
    if kind == 'VEC3':
        result.update(min=[min(v[i] for v in values) for i in range(3)], max=[max(v[i] for v in values) for i in range(3)])
    index = len(doc['accessors'])
    doc['accessors'].append(result)
    return index

def primitive(values, material):
    return {'attributes': {key: accessor(data, 'VEC2' if key == 'TEXCOORD_0' else 'VEC3') for key, data in values.items()},
            'indices': accessor([(i,) for i in range(len(values['POSITION']))], 'SCALAR', 5125), 'material': material, 'mode': 4}

new = [{key: [] for key in attributes} for _ in range(3)]

def triangle(group, a, b, c, desired):
    u, v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
    cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
    if sum(cross[i]*desired[i] for i in range(3)) < 0:
        b, c = c, b
        cross = [-value for value in cross]
    length = math.sqrt(sum(value*value for value in cross))
    assert length > 1e-10
    for vertex in (a, b, c):
        new[group]['POSITION'].append(vertex)
        new[group]['NORMAL'].append(tuple(value/length for value in cross))
        new[group]['TEXCOORD_0'].append((0, 0))

def point(x, y, z, radius, angle):
    return (x, y+radius*math.cos(angle), z+radius*math.sin(angle))

def sleeve(x0, x1, radius, group=1):
    # A closed collar also seals the cut receiver; the rear disk is inside its body.
    for i in range(12):
        a, b = i*math.tau/12, (i+1)*math.tau/12
        p, q, r, s = point(x0,.30,0,radius,a), point(x1,.30,0,radius,a), point(x1,.30,0,radius,b), point(x0,.30,0,radius,b)
        desired = (0, math.cos((a+b)/2), math.sin((a+b)/2))
        triangle(group,p,q,r,desired); triangle(group,p,r,s,desired)
        triangle(group,(x0,.30,0),p,s,(-1,0,0)); triangle(group,(x1,.30,0),q,r,(1,0,0))

# Six equally long barrels, no central protruding barrel. Visible recessed bores.
for barrel in range(6):
    angle = barrel*math.tau/6
    y, z = .30+.055*math.cos(angle), .055*math.sin(angle)
    for i in range(8):
        a, b = i*math.tau/8, (i+1)*math.tau/8
        p, q, r, s = point(.115,y,z,.021,a), point(.49,y,z,.021,a), point(.49,y,z,.021,b), point(.115,y,z,.021,b)
        desired = (0,math.cos((a+b)/2),math.sin((a+b)/2))
        triangle(0,p,q,r,desired); triangle(0,p,r,s,desired)
        iq, ir = point(.49,y,z,.013,a), point(.49,y,z,.013,b)
        triangle(1,q,iq,ir,(1,0,0)); triangle(1,q,ir,r,(1,0,0))
        bp, br = point(.463,y,z,.013,a), point(.463,y,z,.013,b)
        inward = tuple(-value for value in desired)
        triangle(2,iq,bp,br,inward); triangle(2,iq,br,ir,inward)
        triangle(2,(.463,y,z),bp,br,(1,0,0))
sleeve(.075,.135,.087)
sleeve(.19,.208,.081)
sleeve(.43,.447,.081)

materials = []
for label, color, metallic, roughness in [('Barrel gunmetal',[.105,.15,.17,1],.75,.4),('Teal barrel collars',[.19,.32,.33,1],.65,.45),('Dark recessed bores',[.018,.022,.025,1],.2,.85)]:
    materials.append(len(doc['materials']))
    doc['materials'].append({'name':label,'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':metallic,'roughnessFactor':roughness}})
parts = [primitive(receiver, part['material'])] + [primitive(values, material) for values, material in zip(new, materials)]
triangles = sum(len(values['POSITION'])//3 for values in [receiver]+new)
assert triangles <= 1545, triangles
boundary = [p for p in receiver['POSITION'] if abs(p[0]-cut_x) < 1e-6]
boundary_radius = max(math.hypot(p[1]-.30,p[2]) for p in boundary)
assert boundary_radius < .087*math.cos(math.pi/12), 'Receiver cut extends outside the sealing sleeve'
doc['meshes'][0]['primitives'] = parts
doc['buffers'][0]['byteLength'] = len(binary)
binary.extend(b'\0' * (-len(binary)%4))
encoded = json.dumps(doc,separators=(',',':')).encode()
encoded += b' ' * (-len(encoded)%4)
target.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary)
evidence = {'source':str(source.relative_to(ROOT)),'derived':str(target.relative_to(ROOT)),
            'source_sha256':hashlib.sha256(raw).hexdigest(),'derived_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'triangles':triangles,'barrels':6,'receiver_cut_local_x':cut_x,
            'receiver_triangles':len(receiver['POSITION'])//3,'new_barrel_triangles':sum(len(values['POSITION'])//3 for values in new),
            'receiver_cut_max_radius':boundary_radius,'sealing_sleeve_inscribed_radius':.087*math.cos(math.pi/12),
            'operation':'Clip only forward geometry with interpolated original UVs/normals; preserve receiver material and embedded images; replace front with six equal tubes and recessed bores. Offline candidate, not Godot accepted.'}
target.with_suffix('.derivation.json').write_text(json.dumps(evidence,indent=2)+'\n')
print(json.dumps(evidence))
