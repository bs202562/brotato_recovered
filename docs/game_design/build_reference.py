"""Offline, read-only extraction of Godot resources into a Chinese study reference.
Run: python docs/game_design/build_reference.py
No third-party dependencies; does not execute recovered game scripts.
"""
from pathlib import Path
import ast, csv, html, json, re
from urllib.parse import quote, unquote

ROOT = Path(__file__).resolve().parents[2] / 'gdproj'
OUT = Path(__file__).resolve().parent
TR = {}
with (ROOT / '.assets/resources/translations/translations.csv').open(encoding='utf-8-sig', newline='') as f:
    for row in csv.DictReader(f):
        TR[row['key']] = row.get('zh') or row.get('en') or row['key']
FALLBACK_NAMES=json.loads((OUT/'参考译名.json').read_text(encoding='utf-8'))

def tr(s):
    k=str(s).upper()
    return TR.get(k, FALLBACK_NAMES[k]+'〔参考译名〕' if k in FALLBACK_NAMES else str(s))

def clean(s):
    return re.sub(r'\[/?(?:color|font|img|url|b|i|center)[^\]]*\]', '', str(s)).replace('\n', ' / ')

def label(s):
    return clean(re.sub(r'\{\d+\}', '', tr(s))).strip()

def value(s, refs, path):
    s = re.sub(r'ExtResource\(\s*"?([^\s)" ]+)"?\s*\)', lambda m: repr(refs.get(m[1], 'UNRESOLVED:'+m[1])), s)
    s = re.sub(r'SubResource\(\s*"?([^\s)" ]+)"?\s*\)', lambda m: repr(path+'#'+m[1]), s)
    s = re.sub(r'\btrue\b', 'True', s)
    s = re.sub(r'\bfalse\b', 'False', s)
    s = re.sub(r'\bnull\b', 'None', s)
    try:
        return ast.literal_eval(s)
    except (ValueError, SyntaxError):
        return s

DB = {}
for base in ('items', 'weapons', 'effects', 'dlcs', 'zones', 'entities'):
    for p in sorted((ROOT/base).rglob('*.tres')):
        rel = p.relative_to(ROOT).as_posix()
        text = p.read_text(encoding='utf-8-sig')
        refs = {}
        for head in re.findall(r'^\[ext_resource (.*)\]$', text, re.M):
            path = re.search(r'path="res://([^"]+)"', head)
            rid = re.search(r'\bid="?([^\s"\]]+)', head)
            if path and rid:
                refs[rid[1]] = path[1]
        blocks = re.split(r'^\[(resource|sub_resource[^\]]*)\]\s*$', text, flags=re.M)
        for i in range(1, len(blocks), 2):
            head, body = blocks[i:i+2]
            key = rel if head == 'resource' else rel+'#'+re.search(r'\bid="?([^\s"]+)', head)[1]
            d = {'_path': key}
            for m in re.finditer(r'^(\w+)\s*=\s*(.*?)(?=^\w+\s*=|^\[|\Z)', body, re.M|re.S):
                d[m[1]] = value(m[2].strip(), refs, rel)
            DB[key] = d

def res(p):
    return DB.get(p, {}) if isinstance(p, str) else {}

def link(p):
    p = str(p).split('#')[0]
    return '['+p+']('+quote((ROOT/p).as_posix(),safe='/:')+')'

SOURCE_FILES = {}

def absolute_source_links(md):
    def replace(m):
        target=unquote(m[2])
        if target.startswith('../../gdproj/'):
            target=(ROOT/target[len('../../gdproj/'):]).as_posix()
        elif target.startswith('../../'):
            candidate=ROOT/target[len('../../'):]
            if candidate.exists(): target=candidate.as_posix()
        elif '/gdproj/' in target and re.match(r'^[A-Za-z]:/',target):
            target=(ROOT/target.split('/gdproj/',1)[1]).as_posix()
        return '['+m[1]+']('+quote(target,safe='/:#')+')'
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)',replace,md)

def html_link(m):
    target=unquote(html.unescape(m[2]))
    line=1
    match=re.search(r':(\d+)$',target)
    if match: line=int(match[1]);target=target[:match.start()]
    p=Path(target)
    if not p.is_absolute(): p=OUT/p
    try:
        rel=p.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return '<a href="'+m[2]+'">'+m[1]+'</a>'
    if not p.is_file(): raise ValueError('Broken source link: '+target)
    source=p.read_text(encoding='utf-8-sig')
    if not 1<=line<=len(source.splitlines()): raise ValueError('Invalid source line: '+target)
    SOURCE_FILES[rel]=source
    return '<a href="#source-viewer" data-source="'+html.escape(rel,quote=True)+'" data-line="'+str(line)+'">'+m[1]+'</a>'

def named(p):
    d = res(p)
    return label(d.get('name', d.get('my_id', p)))

def scaling(arr):
    if not isinstance(arr, list): return str(arr)
    return ' + '.join(f'{float(x[1])*100:g}% × {label(x[0])}' for x in arr if isinstance(x, list) and len(x)>1) or '无'

text_script = (ROOT/'singletons/text.gd').read_text(encoding='utf-8')
def text_rules(name):
    body=re.search(r'var '+name+r'.*?\{(.*?)\n\}',text_script,re.S)[1]
    return {k:[int(x) for x in a.split(',') if x.strip()] for k,a in re.findall(r'"([^"]+)":\s*\[([\d, ]*)\]',body)}
operators=text_rules('keys_needing_operator')
percents=text_rules('keys_needing_percent')

def describe(d):
    key = d.get('key', '')
    tk = d.get('text_key') or key
    script = Path(d.get('script', '')).stem
    v = d.get('value', 0)
    dk = key[:-2] if d.get('custom_key') == 'starting_weapon' else key
    args = [str(v), label(dk)]
    supported = script in ('effect', 'null_effect')
    if script == 'stat_gains_modification_effect':
        return f"{label(d.get('stat_displayed',''))}的读取倍率修正 {'+' if v>=0 else '-'}{abs(v)}%（gain_*，含已累计值）；作用属性："+'、'.join(label(x) for x in d.get('stats_modified',[]))
    if d.get('custom_key') == 'starting_weapon':
        weapon=next((x for x in DB.values() if x.get('my_id')==key),{})
        return f"起始获得 {v} 把{label(weapon.get('name',dk))}（按该武器资源品质）"
    if script == 'gain_stat_for_every_stat_effect':
        return f"每 {d.get('nb_stat_scaled',0)} 点／个{label(d.get('stat_scaled',''))}，获得 {v:+g} {label(key)}；永久属性限制 perm_stats_only={d.get('perm_stats_only',True)}。当前总收益随局内状态计算。"
    if script == 'convert_stat_effect':
        return f"转换比例 {d.get('pct_converted',0)}%；来源 {label(key)} → {label(d.get('to_stat',''))}；源值 value={v}，目标值 to_value={d.get('to_value',0)}（结算规则见脚本）。"
    if script == 'weapon_stack_effect':
        return f"每额外持有一把{label(d.get('weapon_stacked_name',''))}，{label(d.get('stat_displayed_name',''))} {v:+g}；不计自身。"
    if script == 'chance_stat_damage_effect':
        trigger={'dmg_when_pickup_gold':'拾取材料时','dmg_on_dodge':'闪避时','dmg_on_heal':'治疗时','dmg_on_death':'击杀时'}.get(d.get('custom_key'),d.get('custom_key','事件触发'))
        return f"{trigger}，{d.get('chance',3)}% 概率造成基于 {v}% × {label(key)} 的伤害；经整数转换和伤害加成结算。目标选择见 {tk} 对应处理逻辑。"
    if script in ('item_exploding_effect','item_exploding_when_below_hp_effect','item_exploding_and_burn_effect'):
        s=res(d.get('stats'))
        template=clean(re.sub(r'\{\d+\}','〈见基础参数〉',tr(tk)))
        return f"{template}；爆炸基础参数：概率 {d.get('chance',1)*100:g}%，基础伤害 {s.get('damage','未给出')}，缩放 {scaling(s.get('scaling_stats',[]))}，缺失生命缩放开关 {d.get('scale_with_missing_health',False)}。"
    if script=='effect' and key=='group_structures':
        return '结构物集中生成规则开启（group_structures）；生成位置逻辑见工程代码。'
    if script in ('double_value_effect', 'double_key_value_effect', 'null_double_value_effect'):
        args += [str(d.get('value2', 0))]
        if script == 'double_key_value_effect': args += [label(d.get('key2', ''))]
        supported = True
    elif script == 'stat_gains_modification_effect':
        args = [label(d.get('stat_displayed', '')), str(abs(v))]; supported = True
    elif script == 'class_bonus_effect':
        sid = d.get('set_id')
        sd = next((x for x in DB.values() if x.get('my_id') == sid), {})
        args = [str(v), label(d.get('stat_displayed_name', '')), label(sd.get('name', sid))]; supported = True
    elif script == 'weapon_type_bonus_effect':
        args = [str(v), label(d.get('stat_displayed_name', ''))]; supported = True
    elif script == 'temp_stats_per_interval_effect':
        args += [str(d.get('interval', 0))]; supported = True
    elif script == 'gain_stat_for_every_stat_effect':
        args = [str(v), label(key), str(d.get('nb_stat_scaled', 0)), label(d.get('stat_scaled', '')), '随局内状态计算']; supported = True
    elif script == 'exploding_effect':
        args = [f"{100*d.get('chance', 0):g}"]; supported = True
    elif script == 'burning_effect':
        b = res(d.get('burning_data'))
        return f"燃烧基础配置：概率 {b.get('chance', 0)*100:g}%；每跳基础伤害 {b.get('damage', 0)}；持续计数 {b.get('duration', 0)}；缩放 {scaling(b.get('scaling_stats', []))}。实际间隔及覆盖规则见学习指南。"
    template = tr(tk)
    if not supported or d.get('custom_args'):
        template = re.sub(r'\{(\d+)\}', lambda m: '〈参数'+m[1]+'〉', template)
        return '描述模板（需结合下方参数）：'+clean(template)
    if 0 in operators.get(str(tk).lower(),[]) and '{0}' not in template:
        template='{0} '+template
    for i in operators.get(str(tk).lower(), []):
        if i < len(args):
            try:
                if float(args[i]) >= 0: args[i] = '+'+args[i]
            except ValueError: pass
    for i in percents.get(str(tk).lower(), []):
        if i<len(args): args[i]+='%'
    out = re.sub(r'\{(\d+)\}', lambda m: args[int(m[1])] if int(m[1]) < len(args) else '〈动态参数'+m[1]+'〉', template)
    if template == tk:
        out = f'{label(key)}：{v:+g}' if isinstance(v, (int,float)) else f'{label(key)}：{v}'
    return clean(out)

HIDE = {'script','custom_args','effect_sign','text_key','key','value','custom_key','storage_method'}
def fields(d):
    return {k:v for k,v in d.items() if not k.startswith('_') and k not in HIDE}

def effect_lines(paths):
    lines = []
    for p in paths or []:
        d = res(p)
        if not d:
            lines.append('- 未解析资源：'+str(p)); continue
        lines.append('- '+describe(d))
        # Keep the full parameter contract visible for auditing special descriptions.
        raw = {k:v for k,v in d.items() if not k.startswith('_') and k != 'script' and v not in ('', [], None)}
        lines.append('  - 原始参数：`'+json.dumps(raw, ensure_ascii=False)+'`')
        lines.append('  - 来源：'+link(p)+'；行为脚本：'+link(d.get('script','')))
        for k,v in fields(d).items():
            for sub in (v if isinstance(v,list) else [v]):
                if isinstance(sub,str) and sub in DB:
                    lines.append('  - 关联 '+k+'：`'+json.dumps({a:b for a,b in res(sub).items() if not a.startswith('_') and a!='script'}, ensure_ascii=False)+'`；'+link(sub))
    return lines

CATS = {'角色':'character_data.gd','武器':'weapon_data.gd','道具':'item_data.gd','套装':'set_data.gd','升级':'upgrade_data.gd','难度':'difficulty_data.gd','敌人基础数值':'stats.gd','波次':'wave_data.gd'}
GROUPS = {k: sorted([d for d in DB.values() if Path(d.get('script','')).name==v], key=lambda d:(d['_path'].startswith('dlcs/'),d.get('name',''),d.get('tier',0),d['_path'])) for k,v in CATS.items()}
TIERS = ['I 普通','II 罕见','III 稀有','IV 传奇','危险4','危险5','噩梦']

def origin(d): return 'DLC' if d['_path'].startswith('dlcs/') else '本体目录'
def tier(d):
    t=d.get('tier',0)
    return TIERS[t] if isinstance(t,int) and 0<=t<len(TIERS) else str(t)
def table(headers, rows):
    esc=lambda x:str(x).replace('|','／').replace('\n',' ')
    return ['| '+' | '.join(headers)+' |','| '+' | '.join(['---']*len(headers))+' |']+['| '+' | '.join(esc(x) for x in row)+' |' for row in rows]

def chapter(cat):
    ds=GROUPS[cat]
    lines=['# '+cat+'数值图鉴','',f'本章扫描到 {len(ds)} 条资源记录。目录归属不等于当前运行时已解锁或已加入资源池。来源链接指向本地工程。','']
    if cat=='升级':
        lines+=table(['升级','品质','效果','目录'],[(named(d['_path']),tier(d),'；'.join(describe(res(p)) for p in d.get('effects',[])),origin(d)) for d in ds])+['']
    if cat == '武器':
        lines += ['攻击间隔是零角色／零套装修正的基础显示值，含动作时间；不能直接把 cooldown/60 当作攻击周期。升级是独立资源。缩放系数、基础价格、额外装填与特效应一起看。','']
        rows=[]
        for d in ds:
            s=res(d.get('stats')); c=s.get('cooldown',60); recoil=s.get('recoil_duration',0.1); rng=s.get('max_range',150)
            melee=d.get('type',0)==0
            interval=c/60+((0.2+rng/70*0.15)/2+0.2+recoil if melee else recoil*2)
            rows.append([named(d['_path']),tier(d),origin(d),'近战' if melee else '远程',s.get('damage',1),scaling(s.get('scaling_stats',[])),f'{interval:.3f}',f"{s.get('crit_chance',.03)*100:g}% ×{s.get('crit_damage',1.5)}",rng,s.get('nb_projectiles',1),d.get('value',1)])
        lines+=table(['名称','品质','目录','类型','基础伤害','缩放','基础间隔秒','暴击','射程','弹数','基础价格'],rows)+['']
    for d in ds:
        p=d['_path']; name=named(p)
        if cat in ('波次','敌人基础数值'): name=p
        lines+=['## '+name+(' · '+tier(d) if cat in ('武器','道具','升级') else ''),'',f"目录：{origin(d)}；ID：`{d.get('my_id',d.get('upgrade_id','—'))}`；来源：{link(p)}",'']
        if cat in ('道具','武器'):
            lines += [f"基础价格：{d.get('value',1)}；可掉落 can_be_looted：{d.get('can_be_looted',True)}；持有上限 max_nb：{d.get('max_nb','不适用')}（-1 表示无限制）。",'']
        if cat=='角色':
            lines+=['初始武器候选：'+('、'.join(named(x) for x in d.get('starting_weapons',[])) or '无列表')+'。这是选择池，不代表同时赠送。','']
            for k, cn in [('starting_items','初始物品'),('wanted_tags','偏好标签'),('banned_item_groups','禁用道具组'),('banned_items','禁用物品'),('banned_upgrades','禁用升级')]:
                if d.get(k): lines += [cn+'：'+json.dumps(d[k],ensure_ascii=False),'']
        if cat=='武器':
            lines+=['武器套装：'+('、'.join(named(x) for x in d.get('sets',[])) or '无')+'；升级目标：'+(named(d['upgrades_into']) if d.get('upgrades_into') else '无'),'']
            s=res(d.get('stats'))
            lines += table(['参数','配置值'],[(k,scaling(v) if k=='scaling_stats' else json.dumps(v,ensure_ascii=False)) for k,v in s.items() if not k.startswith('_') and k not in ('script','shooting_sounds','custom_on_cooldown_sprite')])+['']
        if cat=='套装':
            for i, effects in enumerate(d.get('set_bonuses',[]),2):
                lines+=['### 持有 '+str(i)+' 件时','']+effect_lines(effects)+['']
        elif cat in ('波次','敌人基础数值'):
            lines+=table(['字段','原始值'],[(k,json.dumps(v,ensure_ascii=False)) for k,v in d.items() if not k.startswith('_') and k!='script'])+['']
        else:
            lines+=effect_lines(d.get('effects',[]))+['']
    return '\n'.join(lines)

def inline(s):
    # Protect code spans before interpreting markdown links.
    chunks=re.split(r'(`[^`]*`)',s)
    out=[]
    for c in chunks:
        if c.startswith('`') and c.endswith('`'): out.append('<code>'+html.escape(c[1:-1])+'</code>'); continue
        c=html.escape(c)
        c=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',html_link,c)
        c=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',c)
        out.append(c)
    return ''.join(out)

def render(md):
    out=[]; intable=False; inpre=False
    for line in md.splitlines():
        if line.startswith('```'):
            if intable: out.append('</tbody></table></div>'); intable=False
            out.append('</pre>' if inpre else '<pre>'); inpre=not inpre; continue
        if inpre: out.append(html.escape(line)+'\n'); continue
        if line.startswith('|'):
            cells=line.strip().strip('|').split('|')
            if all(re.fullmatch(r'\s*:?-+:?\s*',c) for c in cells): continue
            if not intable:
                out.append('<div class="table"><table><thead><tr>'+''.join('<th>'+inline(c.strip())+'</th>' for c in cells)+'</tr></thead><tbody>'); intable=True
            else: out.append('<tr>'+''.join('<td>'+inline(c.strip())+'</td>' for c in cells)+'</tr>')
            continue
        if intable: out.append('</tbody></table></div>'); intable=False
        if not line.strip(): continue
        m=re.match(r'^(#{1,6}) (.*)',line)
        if m: out.append(f'<h{len(m[1])}>'+inline(m[2])+f'</h{len(m[1])}>')
        elif line.lstrip().startswith('- 原始参数：'):
            out.append('<details><summary>展开原始参数</summary><p>'+inline(line.lstrip()[2:])+'</p></details>')
        elif line.lstrip().startswith('- 来源：'):
            out.append('<details><summary>查看配置与行为脚本来源</summary><p>'+inline(line.lstrip()[2:])+'</p></details>')
        elif line.lstrip().startswith('- 关联 '):
            out.append('<details><summary>展开关联资源</summary><p>'+inline(line.lstrip()[2:])+'</p></details>')
        elif line.lstrip().startswith('- '): out.append('<p class="bullet">• '+inline(line.lstrip()[2:])+'</p>')
        else: out.append('<p>'+inline(line)+'</p>')
    if intable: out.append('</tbody></table></div>')
    return '\n'.join(out)

def main():
    OUT.mkdir(exist_ok=True)
    docs=[]
    for name,file in [('学习指南','01_技能与数值设计学习指南.md'),('属性计算公式','10_全属性计算公式.md')]:
        path=OUT/file
        md=absolute_source_links(path.read_text(encoding='utf-8'))
        path.write_text(md,encoding='utf-8')
        docs.append((name,md))
    for i,cat in enumerate(CATS,2):
        md=chapter(cat); (OUT/f'{i:02d}_{cat}数值图鉴.md').write_text(md,encoding='utf-8'); docs.append((cat,md))
    counts={k:len(v) for k,v in GROUPS.items()}
    manifest={'scope':'local recovered repository; static configuration, not runtime balance verification','counts':counts,'translation_source':'.assets/resources/translations/translations.csv','resources':DB}
    (OUT/'数据索引.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    nav=''.join(f'<button data-id="s{i}" onclick="show(\'s{i}\')">{html.escape(n)}'+(f' <small>{counts[n]}</small>' if n in counts else '')+'</button>' for i,(n,_) in enumerate(docs))
    sections=''.join(f'<section id="s{i}" '+('hidden' if i else '')+'>'+render(md)+'</section>' for i,(_,md) in enumerate(docs))
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Brotato 技能与数值设计手册</title>
<style>:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#f5f3ed;color:#27312d;font:16px/1.8 "Microsoft YaHei",sans-serif}aside{position:fixed;width:245px;inset:0 auto 0 0;background:#203c35;color:#f9f5e9;padding:28px 22px;overflow:auto}aside h2{font-size:22px;line-height:1.5}button,input{font:inherit}aside button{display:block;text-align:left;width:100%;padding:9px 10px;border:0;background:transparent;color:inherit;cursor:pointer;border-radius:6px}aside button:hover,aside button.active{background:#38594d}small{opacity:.6}main{max-width:1450px;margin-left:245px;padding:35px 45px}h1{font-size:32px;border-bottom:3px solid #bda96b;padding-bottom:15px}h2{margin-top:48px;color:#245245}h3{color:#766132}p{max-width:1000px}.bullet{margin:5px 0 5px 16px}a{color:#226756;overflow-wrap:anywhere}code{font:13px/1.65 Consolas,monospace;background:#e8e7df;padding:2px 5px;overflow-wrap:anywhere}pre{padding:18px;background:#e8e7df;white-space:pre-wrap}input{padding:9px 12px;width:100%;border:1px solid #ccc8bb;border-radius:6px}.search{position:sticky;top:0;background:#f5f3ed;padding:12px 0;z-index:2}.table{overflow:auto;margin:20px 0}table{border-collapse:collapse;font-size:14px;min-width:650px;width:100%;background:#fffdf7}th{background:#e4e9df;text-align:left}td,th{padding:10px 12px;border:1px solid #dcded4;vertical-align:top}td{overflow-wrap:anywhere}tr:nth-child(even){background:#f4f5ef}.hint{font-size:13px;color:#6d776e}#results a{display:block;padding:8px 0}mark{background:#f4dd8c}@media(max-width:800px){aside{position:static;width:auto}aside button{display:inline-block;width:auto}main{margin:0;padding:20px}h1{font-size:26px}}@media print{aside,.search{display:none}main{margin:0;padding:0}section[hidden]{display:none}table{font-size:10px}a{color:inherit}h2{break-after:avoid}tr{break-inside:avoid}}</style>
<aside><h2>BROTATO<br>技能与数值设计手册</h2><p class="hint" style="color:#d4d9c9">基于当前工程 · 离线阅读</p>'''+nav+'''<p class="hint" style="color:#d4d9c9">先读学习指南，再按角色与武器追踪构筑。支持浏览器打印当前章节。</p></aside><main><div class="search"><input id="q" placeholder="搜索全部章节：例如 工程学、燃烧、冲锋枪" aria-label="搜索全部章节"><div class="hint" id="status">输入至少 2 个字符检索；也可使用 Ctrl+F 查找当前章节。</div></div><div id="results" hidden></div>'''+sections+'''</main><script>
const sections=[...document.querySelectorAll('section')];let current='s0';function show(id){document.getElementById('q').value='';document.getElementById('results').hidden=true;sections.forEach(s=>s.hidden=s.id!==id);current=id;document.querySelectorAll('aside button').forEach(b=>b.classList.toggle('active',b.dataset.id===id));window.scrollTo(0,0)}
const index=[];sections.forEach(s=>{let heading=null;for(const el of s.children){if(/^H[123]$/.test(el.tagName)){heading=el;el.id='h'+index.length;index.push({section:s.id,id:el.id,title:el.textContent,text:el.textContent})}else if(heading){index[index.length-1].text+=' '+el.textContent}}});let timer;document.getElementById('q').addEventListener('input',e=>{clearTimeout(timer);timer=setTimeout(()=>{const q=e.target.value.trim().toLowerCase();if(q.length<2){document.getElementById('results').hidden=true;sections.forEach(s=>s.hidden=s.id!==current);return}sections.forEach(s=>s.hidden=true);const r=document.getElementById('results');r.hidden=false;r.replaceChildren();const found=index.filter(x=>x.text.toLowerCase().includes(q));document.getElementById('status').textContent='找到 '+found.length+' 个章节／条目（最多显示 150 个）';found.slice(0,150).forEach(x=>{const a=document.createElement('a');a.href='#'+x.id;a.textContent=x.title;a.onclick=()=>{show(x.section);document.getElementById(x.id).scrollIntoView();};r.append(a)})},150)});show('s0');</script></html>'''
    source_ui='''<style>#source-viewer{width:min(1100px,95vw);height:85vh;border:1px solid #b8c6ba;border-radius:10px;padding:18px}#source-viewer::backdrop{background:#14241dcc}#source-viewer header{display:flex;justify-content:space-between;gap:12px}#source-code{height:calc(100% - 65px);overflow:auto;white-space:pre;font:14px/22px Consolas,monospace;margin:12px 0}#source-title{overflow-wrap:anywhere}</style>
<dialog id="source-viewer"><header><strong id="source-title"></strong><button id="close-source">关闭源码</button></header><pre id="source-code"></pre></dialog>
<script id="source-data" type="application/json">'''+json.dumps(SOURCE_FILES,ensure_ascii=False).replace('<','\\u003c')+'''</script>
<script>const sources=JSON.parse(document.getElementById('source-data').textContent);const sourceDialog=document.getElementById('source-viewer');document.getElementById('close-source').onclick=()=>sourceDialog.close();document.addEventListener('click',e=>{const a=e.target.closest('a[data-source]');if(!a)return;e.preventDefault();const key=a.dataset.source;const line=Number(a.dataset.line||1);document.getElementById('source-title').textContent='gdproj/'+key+' · 第 '+line+' 行（生成时源码快照）';const code=document.getElementById('source-code');code.textContent=sources[key].split('\\n').map((text,i)=>String(i+1).padStart(5)+'  '+text).join('\\n');sourceDialog.showModal();code.scrollTop=Math.max(0,(line-4)*22)});</script>'''
    page=page.replace('</body>','') if '</body>' in page else page
    page=page.replace('</html>',source_ui+'</html>')
    (OUT/'Brotato_技能与数值设计手册.html').write_text(page,encoding='utf-8')
    readme='# Brotato 技能与数值设计文档\n\n优先打开 [离线阅读手册](Brotato_技能与数值设计手册.html)，有目录、跨章节搜索和打印样式。\n\n'+ '\n'.join(f'- {k}：{v} 条配置记录' for k,v in counts.items())+'\n\n每个章节也提供独立 Markdown。`数据索引.json` 保留扫描资源和参数；`build_reference.py` 可重复生成图鉴与网页。学习指南人工编写，重新生成不会覆盖它。\n\n边界：仅对本地恢复工程做静态分析；目录中的测试、未注册、未解锁资源可能一起纳入，不宣称等同于某个商店发布版本。特殊效果中标为“描述模板”的条目需结合原始参数阅读，未伪造运行时数值。\n'
    readme+='\n## 属性公式与源码阅读\n\n[全属性计算公式](10_全属性计算公式.md)逐项列出属性聚合、战斗结算、上限、取整及算例。\n\nMarkdown 的源码引用使用当前工程的绝对路径，适配 Codex 文件跳转；HTML 的源码链接直接打开内嵌源码快照，无需跳出页面或请求本地文件。工程路径或代码变化后重新运行生成脚本；人工章节中带 gdproj 标识的 Windows 旧路径也会自动重定位。HTML 内容是生成时快照，不是实时源码编辑器。\n'
    (OUT/'README.md').write_text(readme,encoding='utf-8')
    print(json.dumps(counts,ensure_ascii=False))
    print('Resources:',len(DB),'HTML bytes:',len(page.encode('utf-8')))

if __name__=='__main__': main()
