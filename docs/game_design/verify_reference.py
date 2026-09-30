"""Check documentation links, embedded source snapshots and attribute coverage offline."""
from pathlib import Path
from urllib.parse import unquote
from html.parser import HTMLParser
import json, re, shutil, subprocess

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[1]/'gdproj'

class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids=set();self.links=[];self.source_links=[];self.scripts=[]
        self.sections=0;self.nav=0;self.active_script=None
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        if tag=='section':self.sections+=1
        if tag=='button' and 'data-id' in a:self.nav+=1
        if tag=='a':
            self.links.append(a.get('href',''))
            if 'data-source' in a:self.source_links.append((a['data-source'],int(a['data-line'])))
        if tag=='script':
            self.active_script={'type':a.get('type','javascript'),'id':a.get('id'),'text':''}
    def handle_data(self,data):
        if self.active_script is not None:self.active_script['text']+=data
    def handle_endtag(self,tag):
        if tag=='script':
            self.scripts.append(self.active_script);self.active_script=None

def main():
    checked=0
    for p in OUT.glob('*.md'):
        for url in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8')):
            if url.startswith(('http:','https:','#')):continue
            target=unquote(url)
            match=re.search(r':(\d+)$',target)
            line=int(match[1]) if match else None
            if match:target=target[:match.start()]
            f=Path(target)
            if not f.is_absolute():f=p.parent/f
            assert f.is_file(),(p.name,target)
            if line:assert 1<=line<=len(f.read_text(encoding='utf-8-sig').splitlines())
            checked+=1
    page=Page();page.feed((OUT/'Brotato_技能与数值设计手册.html').read_text(encoding='utf-8'))
    assert page.sections==page.nav==10
    sources=json.loads(next(s['text'] for s in page.scripts if s['id']=='source-data'))
    for rel,text in sources.items():
        assert (ROOT/rel).read_text(encoding='utf-8-sig')==text,rel
    for rel,line in page.source_links:
        assert rel in sources and 1<=line<=len(sources[rel].splitlines()),(rel,line)
    for url in page.links:
        assert url.startswith('#') and url[1:] in page.ids,url
    data=json.loads((OUT/'数据索引.json').read_text(encoding='utf-8'))
    stats={d['stat_name'] for d in data['resources'].values() if d.get('script','').endswith('/stat_data.gd')}
    formulas=(OUT/'10_全属性计算公式.md').read_text(encoding='utf-8')
    assert len(stats)==25
    assert all(s in formulas for s in stats),stats
    node=shutil.which('node')
    if node:
        scripts=[s['text'] for s in page.scripts if s['type']=='javascript']
        result=subprocess.run([node,'-e',"let d='';process.stdin.setEncoding('utf8');process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>JSON.parse(d).forEach(s=>new Function(s)));"],input=json.dumps(scripts),text=True,capture_output=True)
        assert result.returncode==0,result.stderr
    report={'markdown_links_checked':checked,'html_source_links_checked':len(page.source_links),'embedded_source_files_verified':len(sources),'attribute_keys_covered':len(stats),'chapters':page.sections,'javascript_syntax':'passed' if node else 'not checked: node unavailable','broken_links':0,'browser_interaction':'not tested','scope':'Static source and document checks; no game runtime test'}
    (OUT/'核对记录.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
