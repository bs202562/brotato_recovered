"use strict";
/**
 * 音乐外置工具（幂等）
 *
 * 做的事：
 *  1. 扫 gameproj 下所有音乐源文件（.mp3；音乐目录白名单，避免误伤音效 wav）
 *  2. 每个文件按内容 sha256 命名，原始文件复制到 assetsrv/audio/<hash>.mp3（dev 服务器托管）
 *  3. 把 gameproj 里的源文件替换为静音占位 mp3（体积从几 MB 降到 ~1KB）
 *  4. 生成 manifest：res 路径 -> {hash, size}，写到 gameproj/asset_manifest.json（打进 pck，运行时读）
 *
 * 幂等：占位文件很小（<2KB）即视为已外置，跳过；靠 manifest 记录原始 hash。
 * 还原：node externalize-music.js --restore  （从 assetsrv 拷回原文件）
 *
 * 用法：
 *   node tools_extern/externalize-music.js            # 外置
 *   node tools_extern/externalize-music.js --restore  # 还原
 */
const fs = require("fs");
const path = require("path");
const { makeSilentMp3, sha256, walk, toResPath, ensureDir } = require("./lib");

const ROOT = path.resolve(__dirname, "..");
const PROJ = path.join(ROOT, "gameproj");
const ASSETSRV = path.join(ROOT, "assetsrv", "audio");
const MANIFEST = path.join(PROJ, "asset_manifest.json");
const PLACEHOLDER_MAX = 2048; // 小于此视为占位，跳过

// 只处理“音乐”——按目录白名单（含 dlc）。音效 wav 走另一条 asset-pack 链，不在此处。
const MUSIC_DIRS = [
  path.join(PROJ, "resources", "music"),
  path.join(PROJ, "dlcs"),
];
const MUSIC_EXTS = [".mp3"];

function loadManifest() {
  if (fs.existsSync(MANIFEST)) {
    try {
      return JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
    } catch (e) {}
  }
  return { version: 1, audio: {} };
}

function collectMusic() {
  const files = [];
  for (const d of MUSIC_DIRS) {
    // dlcs 下只取 music 子目录里的 mp3
    if (path.basename(d) === "dlcs") {
      for (const f of walk(d, MUSIC_EXTS)) {
        if (f.split(path.sep).includes("music")) files.push(f);
      }
    } else {
      files.push(...walk(d, MUSIC_EXTS));
    }
  }
  return files;
}

function externalize() {
  const manifest = loadManifest();
  ensureDir(ASSETSRV);
  const silence = makeSilentMp3();
  const files = collectMusic();
  let done = 0,
    skipped = 0,
    totalSaved = 0;

  for (const abs of files) {
    const resPath = toResPath(PROJ, abs);
    const stat = fs.statSync(abs);

    if (stat.size <= PLACEHOLDER_MAX) {
      // 已是占位。必须已有 manifest 记录，否则原文件已丢失，警告。
      if (!manifest.audio[resPath]) {
        console.warn(`  ! ${resPath} 已是占位但 manifest 无记录（原文件可能已丢）`);
      }
      skipped++;
      continue;
    }

    const buf = fs.readFileSync(abs);
    const hash = sha256(buf);
    const hosted = path.join(ASSETSRV, hash + ".mp3");
    if (!fs.existsSync(hosted)) fs.writeFileSync(hosted, buf);

    manifest.audio[resPath] = { hash, size: buf.length };
    fs.writeFileSync(abs, silence); // 源替占位
    totalSaved += buf.length - silence.length;
    done++;
  }

  fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2));
  console.log(
    `✓ 音乐外置：处理 ${done}，跳过(已占位) ${skipped}，节省 ${(totalSaved / 1048576).toFixed(1)} MB`
  );
  console.log(`  托管目录：${ASSETSRV}（${Object.keys(manifest.audio).length} 首）`);
  console.log(`  manifest：${MANIFEST}`);
  console.log(`  ⚠️ 请在 Godot 重新导出前不要动这些占位文件；重导出会把占位打进 pck`);
}

function restore() {
  const manifest = loadManifest();
  let n = 0,
    miss = 0;
  for (const [resPath, info] of Object.entries(manifest.audio)) {
    const abs = path.join(PROJ, resPath.replace(/^res:\/\//, "").split("/").join(path.sep));
    const hosted = path.join(ASSETSRV, info.hash + ".mp3");
    if (fs.existsSync(hosted)) {
      fs.copyFileSync(hosted, abs);
      n++;
    } else {
      console.warn(`  ! 缺托管源，无法还原：${resPath}`);
      miss++;
    }
  }
  console.log(`✓ 还原 ${n} 首${miss ? `，缺失 ${miss}` : ""}`);
}

if (process.argv.includes("--restore")) restore();
else externalize();
