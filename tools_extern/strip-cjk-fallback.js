"use strict";
// 中文小游戏只需简体(SC)字体。把 font_*.tres 和 *.tscn 里的 TC/KR/JP fallback 去掉，只留 SC，
// 消除启动期"Cannot open font file NotoSansTC/KR/JP"报错。幂等。
//
// .tres  : 一个 [resource] 块，fallback 序号全局连续
// .tscn  : 可能有多个 [sub_resource type="DynamicFont"]，fallback 序号必须按块各自从 0 排
const fs = require("fs");
const path = require("path");

const PROJ = path.resolve(__dirname, "..", "gameproj");
const SCAN_DIRS = [PROJ]; // 整个工程扫，字体被内嵌在 ui/*.tscn 里
const DROP = ["NotoSansTC", "NotoSansKR", "NotoSansJP"];
const SKIP_DIRS = new Set([".git", ".import", "build", "node_modules", "tools"]);

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue;
      walk(path.join(dir, e.name), out);
    } else if (e.name.endsWith(".tres") || e.name.endsWith(".tscn")) {
      out.push(path.join(dir, e.name));
    }
  }
  return out;
}

let changed = 0;
let skipped = [];
for (const file of walk(PROJ)) {
  let text = fs.readFileSync(file, "utf8");
  if (!DROP.some((d) => text.includes(d))) continue;
  const eol = text.includes("\r\n") ? "\r\n" : "\n";
  const lines = text.split(/\r?\n/);

  // 1. 找出要删除的 ext_resource id
  const dropIds = new Set();
  for (const ln of lines) {
    const m = ln.match(
      /^\[ext_resource path="[^"]*(?:NotoSansTC|NotoSansKR|NotoSansJP)[^"]*"[^\]]*id=(\d+)/
    );
    if (m) dropIds.add(m[1]);
  }
  if (!dropIds.size) continue;

  // 2. 删除这些 ext_resource 行；删除引用它们的 fallback 行
  let kept = [];
  for (const ln of lines) {
    const extm = ln.match(/^\[ext_resource .*\bid=(\d+)\s*\]/);
    if (extm && dropIds.has(extm[1])) continue;
    const fbm = ln.match(/^fallback\/\d+\s*=\s*ExtResource\(\s*(\d+)\s*\)/);
    if (fbm && dropIds.has(fbm[1])) continue;
    kept.push(ln);
  }

  // 2b. 安全校验：被删的 id 不能还被别处引用（否则会留下悬空 ExtResource）
  const dangling = [...dropIds].filter((id) =>
    kept.some((ln) => new RegExp(`ExtResource\\(\\s*${id}\\s*\\)`).test(ln))
  );
  if (dangling.length) {
    skipped.push(`${path.relative(PROJ, file)} (id ${dangling.join(",")} 仍被非 fallback 处引用)`);
    continue;
  }

  // 3. fallback 序号按块重排为连续 0..n（每遇到一个 [xxx] 段头就归零）
  let fbIndex = 0;
  kept = kept.map((ln) => {
    if (/^\[/.test(ln)) {
      fbIndex = 0;
      return ln;
    }
    const fbm = ln.match(/^fallback\/\d+(\s*=\s*ExtResource\(\s*\d+\s*\).*)$/);
    if (fbm) return `fallback/${fbIndex++}${fbm[1]}`;
    return ln;
  });

  // 4. 修正 load_steps（= ext_resource 数 + sub_resource 数 + 1）
  const stepCount =
    kept.filter((l) => l.startsWith("[ext_resource")).length +
    kept.filter((l) => l.startsWith("[sub_resource")).length;
  kept = kept.map((ln) =>
    /^\[gd_(resource|scene)/.test(ln) ? ln.replace(/load_steps=\d+/, `load_steps=${stepCount + 1}`) : ln
  );

  fs.writeFileSync(file, kept.join(eol));
  changed++;
  console.log(`  - ${path.relative(PROJ, file)}`);
}
console.log(`✓ 处理 ${changed} 个 .tres/.tscn，只保留 SC fallback`);
if (skipped.length) {
  console.log(`⚠ 跳过 ${skipped.length} 个文件：`);
  for (const s of skipped) console.log(`  - ${s}`);
}
