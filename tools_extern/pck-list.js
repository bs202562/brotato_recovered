"use strict";
// 解析 Godot 3.x GDPC pck，按目录/扩展名汇总大小，找外置目标
const fs = require("fs");
const path = require("path");

const pckPath = process.argv[2] || path.resolve(__dirname, "..", "gameproj/build/web/index.pck");
const buf = fs.readFileSync(pckPath);
let p = 0;
const magic = buf.readUInt32LE(p); p += 4;
if (magic !== 0x43504447) { console.error("非 GDPC magic:", magic.toString(16)); process.exit(1); }
const fmt = buf.readInt32LE(p); p += 4;
const vMaj = buf.readInt32LE(p); p += 4;
const vMin = buf.readInt32LE(p); p += 4;
const vRev = buf.readInt32LE(p); p += 4;
p += 16 * 4; // reserved
const count = buf.readInt32LE(p); p += 4;
console.log(`GDPC fmt=${fmt} engine=${vMaj}.${vMin}.${vRev} files=${count} pckSize=${(buf.length/1048576).toFixed(1)}MB\n`);

const byDir = {};
const byExt = {};
let entries = [];
for (let i = 0; i < count; i++) {
  const plen = buf.readInt32LE(p); p += 4;
  const rawPath = buf.slice(p, p + plen).toString("utf8").replace(/\0+$/, ""); p += plen;
  const offset = Number(buf.readBigUInt64LE(p)); p += 8;
  const size = Number(buf.readBigUInt64LE(p)); p += 8;
  p += 16; // md5
  entries.push({ path: rawPath, size });
  // 顶层目录（res://a/b/c -> a/b）
  const rel = rawPath.replace(/^res:\/\//, "");
  const parts = rel.split("/");
  const dir = parts.length > 2 ? parts.slice(0, 2).join("/") : parts[0];
  byDir[dir] = (byDir[dir] || 0) + size;
  const ext = path.extname(rel).toLowerCase() || "(noext)";
  byExt[ext] = (byExt[ext] || 0) + size;
}

function dump(title, obj) {
  console.log(`=== ${title} ===`);
  Object.entries(obj).sort((a, b) => b[1] - a[1]).slice(0, 20)
    .forEach(([k, v]) => console.log(`${(v/1048576).toFixed(2).padStart(7)} MB  ${k}`));
  console.log("");
}
dump("按扩展名 top20", byExt);
dump("按目录(前2级) top20", byDir);
console.log("=== 单文件 top15 ===");
entries.sort((a, b) => b.size - a.size).slice(0, 15)
  .forEach((e) => console.log(`${(e.size/1048576).toFixed(2).padStart(7)} MB  ${e.path}`));
