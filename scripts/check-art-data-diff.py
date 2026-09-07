"""Ensure bulk icon replacement did not rewrite numeric gameplay data."""
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
result=subprocess.run(['git','diff','--unified=0','--','gdproj/items','gdproj/weapons','gdproj/entities','gdproj/dlcs'],cwd=root,capture_output=True,text=True,encoding='utf-8')
unexpected=[]
file=''
for line in result.stdout.splitlines():
    if line.startswith('+++ b/'): file=line[6:]
    elif line.startswith(('+++','---')): continue
    elif line.startswith(('+','-')):
        if 'res://' not in line and line[1:].strip(): unexpected.append((file,line))
if unexpected:
    for file,line in unexpected[:30]: print(file,line)
    raise SystemExit('Review non-resource-path changes in gameplay asset data')
print('PASS: bulk art changes in items/weapons/entities/DLC contain resource paths only; numeric gameplay data preserved.')
