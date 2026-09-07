"""Refresh the current progress paragraph from accepted queue entries only."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
queue = json.loads((root / 'docs/model-production-queue.json').read_text(encoding='utf-8'))
rows = queue['models']
accepted = [row for row in rows if all(row['acceptance'].values())]
dynamic = sum(row['category'] in ('survivor', 'enemy') for row in accepted)
environment = sum(row['category'] == 'environment' for row in accepted)
weapons = sum(row['category'] == 'weapon' for row in accepted)
utility = len(accepted) - dynamic - environment - weapons
paragraph = (
    f'当前完整验收 **{len(accepted)} / {len(rows)}**：{dynamic} 套动态角色/敌人模型、'
    f'{environment} 件环境设施、{weapons} 件武器、{utility} 件物件。'
    '当前优先连续生成并下载全部美术，离线检查同步进行，剩余引擎加载与实战验证集中到生成后。生成落地数量另见 model-generation-snapshot.json，不等于完整验收。'
    f'当前仍有 {len(rows)-len(accepted)} 项未完成独立模型验收。'
    '以下为追加历史，早期阻断状态已被后续记录解除。'
)
path = root / 'docs/model-production-progress.md'
content = path.read_text(encoding='utf-8')
content, replacements = re.subn(r'^当前完整验收[^\n]+', paragraph, content, count=1, flags=re.M)
assert replacements == 1, 'Progress paragraph not found'
path.write_text(content, encoding='utf-8')
print(f'Progress updated: {len(accepted)} / {len(rows)} accepted')
