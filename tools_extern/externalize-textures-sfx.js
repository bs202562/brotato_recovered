"use strict";
/**
 * 贴图 + 音效外置（幂等）
 *
 * 顺序很重要——必须先从当前真实 .import 抓产物打 overlay，再替占位重导入：
 *  1. 收集真实 .import/*.stex（贴图）、.import/*.sample（音效）、resources/fonts/raw/*.otf（字体）
 *  2. 打成分块 overlay pck（每块 ~7MB，避开微信模拟器 readFile base64 桥限）→ assetsrv/packs/
 *     overlay 内资源用其原 res:// 路径；运行时 load_resource_pack(replace=true) 按路径覆盖占位
 *  3. 备份源图/源 wav 到 _srcbackup/（便于 --restore），再替换为 1px png / 静音 wav 占位
 *  4. 字体不动源（已由 export_presets 的 exclude_filter 从 base pck 排除），只进 overlay
 *  5. 把 overlay 分块清单写进 gameproj/asset_manifest.json 的 packs 字段
 *
 * 之后重导出：Godot 重导入占位 → base pck 里 stex/sample 变小；字体被排除。
 *
 * 用法：
 *   node tools_extern/externalize-textures-sfx.js           # 外置
 *   node tools_extern/externalize-textures-sfx.js --restore # 从 _srcbackup 还原源文件
 */
const fs = require("fs");
const path = require("path");
const {
  sha256, walk, toResPath, ensureDir, PNG_1PX, makeSilentWav, writeGdpc,
} = require("./lib");

const ROOT = path.resolve(__dirname, "..");
const PROJ = path.join(ROOT, "gameproj");
const IMPORT = path.join(PROJ, ".import");
const FONTS = path.join(PROJ, "resources", "fonts", "raw");
const PACKS_OUT = path.join(ROOT, "assetsrv", "packs");
const SRCBAK = path.join(__dirname, "_srcbackup");
const MANIFEST = path.join(PROJ, "asset_manifest.json");

const CHUNK_BYTES = 7 * 1024 * 1024; // 单 overlay 分块上限
const IMG_EXTS = [".png", ".jpg", ".jpeg", ".webp"];
// 被 GDScript preload() 的图必须保留在 base pck（preload 是编译期，overlay 运行时挂载补不了）
const KEEP_REAL = [
  "ui/custom_cursor.png",
  "ui/manual_cursor.png",
  "items/stats/empty.png",
  "dlcs/dlc_1/enemies/iron_lung/iron_lung_full.png",
  "dlcs/dlc_1/enemies/spiky_lung/spiky_lung_full.png",
].map((p) => path.join(PROJ, p.split("/").join(path.sep)));
const IMG_PLACEHOLDER_MAX = 200; // 源图 <=此字节视为已占位
const WAV_PLACEHOLDER_MAX = 128;

function loadManifest() {
  if (fs.existsSync(MANIFEST)) {
    try { return JSON.parse(fs.readFileSync(MANIFEST, "utf8")); } catch (e) {}
  }
  return { version: 1, audio: {} };
}

function buildOverlay() {
  ensureDir(PACKS_OUT);
  // 收集真实产物（当前 .import 尚未被占位覆盖）
  const entries = [];
  for (const abs of walk(IMPORT, [".stex", ".sample"])) {
    entries.push({ resPath: "res://.import/" + path.basename(abs), buf: fs.readFileSync(abs) });
  }
  for (const abs of walk(FONTS, [".otf"])) {
    entries.push({ resPath: toResPath(PROJ, abs), buf: fs.readFileSync(abs) });
  }
  // 按 ~7MB 贪心分块
  const chunks = [];
  let cur = [], curSize = 0;
  for (const e of entries) {
    if (curSize + e.buf.length > CHUNK_BYTES && cur.length) {
      chunks.push(cur); cur = []; curSize = 0;
    }
    cur.push(e); curSize += e.buf.length;
  }
  if (cur.length) chunks.push(cur);

  // 清掉旧分块
  for (const f of fs.readdirSync(PACKS_OUT)) {
    if (f.startsWith("overlay_") && f.endsWith(".pck")) fs.unlinkSync(path.join(PACKS_OUT, f));
  }
  const packList = [];
  chunks.forEach((chunk, i) => {
    const tmp = path.join(PACKS_OUT, `_tmp_${i}.pck`);
    writeGdpc(chunk, tmp);
    const buf = fs.readFileSync(tmp);
    const hash = sha256(buf);
    const name = `overlay_${hash}.pck`;
    fs.renameSync(tmp, path.join(PACKS_OUT, name));
    packList.push({ file: name, hash, size: buf.length, files: chunk.length });
    console.log(`  overlay 分块 ${i}: ${name}  ${(buf.length / 1048576).toFixed(2)}MB  ${chunk.length} 文件`);
  });
  console.log(`✓ overlay 共 ${chunks.length} 块，${entries.length} 个资源`);
  return packList;
}

function backupAndPlaceholder() {
  ensureDir(SRCBAK);
  const silentWav = makeSilentWav();
  let imgN = 0, wavN = 0, imgSkip = 0, wavSkip = 0;

  const doFile = (abs, placeholder, maxSize, kind) => {
    const stat = fs.statSync(abs);
    if (stat.size <= maxSize) return kind === "img" ? imgSkip++ : wavSkip++;
    // 备份源（保留相对路径）
    const rel = path.relative(PROJ, abs);
    const bak = path.join(SRCBAK, rel);
    ensureDir(path.dirname(bak));
    if (!fs.existsSync(bak)) fs.copyFileSync(abs, bak);
    fs.writeFileSync(abs, placeholder);
    kind === "img" ? imgN++ : wavN++;
  };

  // 源图（排除 .import 与字体目录；KEEP_REAL 里被 preload 的图保留真身）
  for (const abs of walk(PROJ, IMG_EXTS)) {
    if (abs.includes(path.sep + ".import" + path.sep)) continue;
    if (KEEP_REAL.indexOf(abs) !== -1) continue;
    doFile(abs, PNG_1PX, IMG_PLACEHOLDER_MAX, "img");
  }
  // 源 wav
  for (const abs of walk(PROJ, [".wav"])) {
    if (abs.includes(path.sep + ".import" + path.sep)) continue;
    doFile(abs, silentWav, WAV_PLACEHOLDER_MAX, "wav");
  }
  console.log(`✓ 占位：图 ${imgN}(跳过${imgSkip})，wav ${wavN}(跳过${wavSkip})`);
}

function externalize() {
  console.log("=== 贴图/音效外置 ===");
  console.log("[1/3] 打 overlay pck（从真实 .import 抓产物）...");
  const packList = buildOverlay();
  console.log("[2/3] 备份源文件并替换为占位...");
  backupAndPlaceholder();
  console.log("[3/3] 写 manifest...");
  const manifest = loadManifest();
  manifest.packs = packList;
  fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2));
  console.log(`✓ 完成。overlay ${packList.length} 块托管于 assetsrv/packs/`);
  console.log(`  ⚠️ 现在重新导出 Godot，base pck 里 stex/sample 会随重导入缩小`);
}

function restore() {
  let n = 0;
  const restoreDir = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const full = path.join(d, e.name);
      if (e.isDirectory()) restoreDir(full);
      else {
        const rel = path.relative(SRCBAK, full);
        fs.copyFileSync(full, path.join(PROJ, rel));
        n++;
      }
    }
  };
  if (fs.existsSync(SRCBAK)) restoreDir(SRCBAK);
  console.log(`✓ 还原源文件 ${n} 个（重导出即恢复满贴图/音效）`);
}

if (process.argv.includes("--restore")) restore();
else externalize();
