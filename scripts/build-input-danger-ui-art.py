"""Replace display keycaps and difficulty badges; preserve every source mapping."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]; P=ROOT/'gdproj'
files=[p for p in P.rglob('*') if p.suffix in ('.gd','.tscn','.tres') and 'combat3d' not in p.parts and '.import' not in p.parts]
texts={p:p.read_text(encoding='utf-8-sig') for p in files}
glyphs={'0':'M2 0H12V20H2Z','1':'M3 4L8 0V20M3 20H13','2':'M2 0H12V10H2V20H12','3':'M2 0H12V20H2M3 10H12','4':'M2 0V10H12M12 0V20','5':'M12 0H2V10H12V20H2','6':'M12 0H2V20H12V10H2','7':'M2 0H12L4 20','8':'M2 0H12V20H2ZM2 10H12','9':'M12 10H2V0H12V20H2','A':'M1 20L7 0L13 20M4 12H10','B':'M2 0V20H9Q16 20 12 11Q16 0 9 0ZM2 10H10','E':'M13 0H2V20H13M2 10H11','F':'M13 0H2V20M2 10H11','L':'M2 0V20H13','R':'M2 20V0H10Q17 8 10 10H2M8 10L14 20','S':'M13 0H2V10H13V20H2','X':'M1 0L13 20M13 0L1 20','Y':'M1 0L7 10L13 0M7 10V20'}
def line(d,c='#edbe72',width=2.5,fill='none'):
 return f'<path d="{d}" fill="{fill}" stroke="{c}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'
def letters(s,c='#f0e9d8',scale=1):
 width=len(s)*18-4
 return f'<g transform="translate({32-width*scale/2}, {32-10*scale}) scale({scale})">'+''.join(f'<g transform="translate({i*18},0)">{line(glyphs[ch],c)}</g>' for i,ch in enumerate(s))+'</g>'
rows=[]
for source in sorted((P/'ui/menus/global').glob('key_*.png')):
 old='res://'+source.relative_to(P).as_posix()
 if not any(old in text for text in texts.values()): continue
 name=source.stem; token=name.split('_')[-1]
 body='<rect x="5" y="9" width="54" height="46" rx="10" fill="#18313b" stroke="#759b9b" stroke-width="3"/>'
 if 'positional_' in name:
  chosen={'up':(32,18),'down':(32,46),'left':(18,32),'right':(46,32)}[token]
  body=''.join(f'<circle cx="{x}" cy="{y}" r="8" fill="'+('#edbe72' if (x,y)==chosen else '#294850')+'" stroke="#91adaa" stroke-width="2"/>' for x,y in [(32,18),(32,46),(18,32),(46,32)])
 elif token=='space': body+=line('M15 29V37H49V29','#f0e9d8',3)
 elif token in ['cross','triangle','circle','square']:
  body+=line({'cross':'M22 22L42 42M42 22L22 42','triangle':'M32 19L47 44H17Z','circle':'M19 32A13 13 0 1 0 45 32A13 13 0 1 0 19 32','square':'M20 20H44V44H20Z'}[token],{'cross':'#92c5ee','triangle':'#75d5c4','circle':'#e88f85','square':'#d8a4d8'}[token],3)
 else:
  col={'a':'#85cf9f','b':'#e88f85','x':'#92c5ee','y':'#edcf79'}.get(token,'#f0e9d8') if 'xbox' in name else '#f0e9d8'
  body+=letters(token.upper(),col,0.9 if len(token)>1 else 1.2)
 rows.append((name,source,body))
for token in [str(i) for i in range(11)]+['nightmare']:
 source=P/f'ui/menus/run/difficulty_selection/difficulty_icons/{token}.png'
 color='#ba91dc' if token=='nightmare' else ['#90b5b0','#8bd3aa','#9acd80','#e0cb7b','#e3ab70','#e28c79'][min(int(token),5)]
 body=line('M32 3L57 13V40L32 61L7 40V13Z',color,3,'#18313b')
 if token=='nightmare':
  body+=line('M17 18L13 8L26 15M47 18L51 8L38 15M21 23L27 27M43 23L37 27',color,3)+f'<g transform="translate(0,9)">{letters("6",color,.95)}</g>'
 else: body+=letters(token,color,1.25 if len(token)==1 else 1)
 rows.append(('difficulty_'+token,source,body))
source=P/'ui/icons/misc/elite_icon_small.png'
rows.append(('coop_elite',source,line('M15 21L9 8L26 17L32 8L38 17L55 8L49 21 M15 25Q15 15 32 15Q49 15 49 25V42L40 49V56H24V49L15 42Z','#edbe72',3,'#213e46')+line('M21 30L28 33M43 30L36 33M27 44H37M29 50V55M35 50V55','#e9a08b',3)))
out=[]
for name,source,body in rows:
 w,h=Image.open(source).size
 target='res://combat3d/art/ui/ui_input_'+name+'.svg'
 (P/target[6:]).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 64 64">{body}</svg>\n',encoding='utf-8')
 out.append({'id':name,'source':'res://'+source.relative_to(P).as_posix(),'target':target,'size':[w,h]})
resources=[]
for p,before in texts.items():
 after=before
 for row in out: after=after.replace(row['source'],row['target'])
 if before!=after:
  p.write_text(after,encoding='utf-8',newline='\n'); resources.append(p.relative_to(ROOT).as_posix())
(ROOT/'docs/input-danger-ui-art-map.json').write_text(json.dumps({'assets':out,'resources':resources},indent=2)+'\n')
print('Assets',len(out),'resources',len(resources))
