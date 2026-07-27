"use strict";
// 诊断：给定 .import 产物名片段，报告它在 base pck / 各 overlay 分块 / 磁盘 上的实际字节数。
const fs = require("fs");
const path = require("path");
const ROOT = path.resolve(__dirname, "..");

function readPckEntries(pckPath) {
  const buf = fs.readFileSync(pckPath);
  let p = 4 + 4 + 12 + 64;
  const count = buf.readInt32LE(p);
  p += 4;
  const out = [];
  for (let i = 0; i < count; i++) {
    const plen = buf.readInt32LE(p); p += 4;
    const raw = buf.toString("utf8", p, p + plen).replace(/\0+$/, ""); p += plen;
    p += 8;
    const size = Number(buf.readBigUInt64LE(p)); p += 8;
    p += 16;
    out.push({ resPath: raw, size });
  }
  return out;
}

const needles = process.argv.slice(2);
const sources = [];
const base = path.join(ROOT, "gameproj", "build", "web", "index.pck");
if (fs.existsSync(base)) sources.push(["base pck", base]);
const packsDir = path.join(ROOT, "assetsrv", "packs");
for (const f of fs.readdirSync(packsDir)) {
  if (f.startsWith("overlay_") && f.endsWith(".pck")) sources.push(["overlay " + f.slice(8, 16), path.join(packsDir, f)]);
}

for (const needle of needles) {
  console.log(`\n### ${needle}`);
  let found = false;
  for (const [label, p] of sources) {
    for (const e of readPckEntries(p)) {
      if (e.resPath.includes(needle)) {
        console.log(`  ${label.padEnd(18)} ${String(e.size).padStart(8)} B   ${e.resPath}`);
        found = true;
      }
    }
  }
  // 磁盘
  const impDir = path.join(ROOT, "gameproj", ".import");
  for (const f of fs.readdirSync(impDir)) {
    if (f.includes(needle)) {
      console.log(`  ${"磁盘 .import".padEnd(18)} ${String(fs.statSync(path.join(impDir, f)).size).padStart(8)} B   ${f}`);
      found = true;
    }
  }
  if (!found) console.log("  (哪里都没找到)");
}
