"use strict";
// 诊断：比对 overlay pck 内的资源路径 与 当前 gameproj/.import 磁盘产物名。
// 名字对不上 = 挂载成功也覆盖不到任何东西（贴图仍是占位）。
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const PACKS = path.join(ROOT, "assetsrv", "packs");
const IMPORT = path.join(ROOT, "gameproj", ".import");

function readPckEntries(pckPath) {
  const buf = fs.readFileSync(pckPath);
  let p = 0;
  if (buf.readUInt32LE(p) !== 0x43504447) throw new Error("非 GDPC: " + pckPath);
  p += 4;
  p += 4; // fmt
  p += 12; // version
  p += 64; // reserved
  const count = buf.readInt32LE(p);
  p += 4;
  const out = [];
  for (let i = 0; i < count; i++) {
    const plen = buf.readInt32LE(p);
    p += 4;
    const raw = buf.toString("utf8", p, p + plen).replace(/\0+$/, "");
    p += plen;
    const offset = Number(buf.readBigUInt64LE(p)); p += 8;
    const size = Number(buf.readBigUInt64LE(p)); p += 8;
    p += 16; // md5
    out.push({ resPath: raw, offset, size });
  }
  return out;
}

const inPack = new Map(); // resPath -> size
for (const f of fs.readdirSync(PACKS)) {
  if (!f.startsWith("overlay_") || !f.endsWith(".pck")) continue;
  for (const e of readPckEntries(path.join(PACKS, f))) inPack.set(e.resPath, e.size);
}

const onDisk = new Set();
for (const f of fs.readdirSync(IMPORT)) {
  if (f.endsWith(".stex") || f.endsWith(".sample")) onDisk.add("res://.import/" + f);
}

const packImport = [...inPack.keys()].filter((k) => k.startsWith("res://.import/"));
const packOther = [...inPack.keys()].filter((k) => !k.startsWith("res://.import/"));

const missingInPack = [...onDisk].filter((k) => !inPack.has(k)); // base pck 要、overlay 没有 → 保持占位
const staleInPack = packImport.filter((k) => !onDisk.has(k)); // overlay 有、当前用不上 → 死重量

// 真正决定成败的比对：base pck(实际下发给引擎的) 里的 .import 条目，是否都能被 overlay 覆盖
const BASE_PCK = path.join(ROOT, "gameproj", "build", "web", "index.pck");
if (fs.existsSync(BASE_PCK)) {
  const baseEntries = readPckEntries(BASE_PCK);
  const baseImport = baseEntries.filter((e) => e.resPath.startsWith("res://.import/"));
  const uncovered = baseImport.filter((e) => !inPack.has(e.resPath));
  const placeholderBytes = baseImport.reduce((s, e) => s + e.size, 0);
  console.log("=== base pck vs overlay ===");
  console.log(`base pck 内 .import 条目 : ${baseImport.length}（占位合计 ${(placeholderBytes / 1048576).toFixed(2)} MB）`);
  console.log(`✗ overlay 覆盖不到       : ${uncovered.length}`);
  const byExt = {};
  for (const e of uncovered) {
    const ext = e.resPath.slice(e.resPath.indexOf(".", e.resPath.lastIndexOf("/")));
    byExt[ext] = (byExt[ext] || 0) + 1;
  }
  for (const k of Object.keys(byExt)) console.log(`     ${k}: ${byExt[k]}`);
  for (const e of uncovered.slice(0, 20)) console.log(`     缺: ${e.resPath} (${e.size}B)`);
  console.log("");
}

console.log(`overlay 内资源总数 : ${inPack.size}（.import ${packImport.length}，其它 ${packOther.length}）`);
console.log(`当前磁盘 .import   : ${onDisk.size}`);
console.log(`交集(能真正覆盖)   : ${packImport.length - staleInPack.length}`);
console.log(`✗ 覆盖不到(仍占位) : ${missingInPack.length}`);
console.log(`✗ overlay 里的废条目: ${staleInPack.length}`);
if (packOther.length) console.log(`  非 .import 条目样例: ${packOther.slice(0, 5).join(", ")}`);
for (const s of missingInPack.slice(0, 15)) console.log(`   缺: ${s}`);
for (const s of staleInPack.slice(0, 15)) console.log(`   废: ${s}`);
