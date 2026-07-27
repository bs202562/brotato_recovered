"use strict";
// 诊断：把 base pck 里那些 overlay 覆盖不到的 .res 条目，反查回源 png 路径与导入器类型。
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const PROJ = path.join(ROOT, "gameproj");

// 扫全工程的 *.import，建立 “产物文件名 -> {源路径, importer}” 索引
const index = new Map();
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (e.name === ".import" || e.name === ".git" || e.name === "build") continue;
      walk(path.join(dir, e.name));
    } else if (e.name.endsWith(".import")) {
      const text = fs.readFileSync(path.join(dir, e.name), "utf8");
      const importer = (text.match(/^importer="([^"]+)"/m) || [])[1] || "?";
      const source = (text.match(/^source_file="([^"]+)"/m) || [])[1] || "?";
      for (const m of text.matchAll(/res:\/\/\.import\/([^"\s]+)/g)) {
        index.set(m[1], { source, importer });
      }
    }
  }
}
walk(PROJ);

const targets = process.argv.slice(2);
if (!targets.length) {
  // 无参数：汇总全工程按 importer 分类
  const byImporter = {};
  for (const [file, info] of index) {
    const ext = file.slice(file.lastIndexOf("."));
    const key = `${info.importer} -> ${ext}`;
    (byImporter[key] = byImporter[key] || []).push(info.source);
  }
  for (const k of Object.keys(byImporter).sort()) {
    const list = byImporter[k];
    console.log(`${k}: ${list.length}`);
    for (const s of list.slice(0, 8)) console.log(`    ${s}`);
    if (list.length > 8) console.log(`    ...`);
  }
}
