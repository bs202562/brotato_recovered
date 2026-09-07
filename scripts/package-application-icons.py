"""Encode the reviewed Godot render in native icon containers; no new artwork."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
folder = root / 'gdproj/combat3d/art/application'
source = Image.open(folder / 'dead_shift_icon.png').convert('RGBA')
assert source.size == (512, 512)
assert len(source.getcolors(512 * 512)) > 100, 'Blank application render'
source.save(folder / 'dead_shift_icon.ico', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
source.save(folder / 'dead_shift_icon.icns')
ico = Image.open(folder / 'dead_shift_icon.ico')
assert (256,256) in ico.info['sizes'] and (16,16) in ico.info['sizes']
icns = Image.open(folder / 'dead_shift_icon.icns')
icns.size = (512,512)
icns.load(scale=1)
assert icns.convert('RGBA').tobytes() == source.tobytes(), 'ICNS 512 image changed'
print('Native application icons encoded and decoded successfully')
