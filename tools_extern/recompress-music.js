"use strict";
/**
 * BGM 重压缩工具（幂等）
 *
 * 背景：assetsrv/audio 下的托管音乐是 320kbps CBR 立体声（母带级），每首 6~9MB，共 122MB。
 * 对小游戏来说远超必要——BGM 在手机上 128k joint stereo 基本无感，体积降 ~60%。
 *
 * 做的事：
 *  1. 扫 assetsrv/audio/*.mp3，跳过已 <= TARGET_KBPS 的（幂等）
 *  2. ffmpeg 转码到 TARGET_KBPS joint stereo，按新内容 sha256 重命名
 *  3. 同步更新 gameproj/asset_manifest.json 里 audio 条目的 hash 与 size
 *  4. 原 320k 文件删除（git HEAD 里有,回滚用 git checkout HEAD -- assetsrv/audio）
 *
 * hash 变了 → 玩家端 user://audiocache 自动重下，不会用到旧缓存。
 * manifest 在 gameproj 内（会打进 pck），改完必须重新导出 pck。
 *
 * 用法：
 *   node tools_extern/recompress-music.js --dry-run    # 只报告，不改文件
 *   node tools_extern/recompress-music.js              # 执行
 *   node tools_extern/recompress-music.js --kbps 96    # 换目标码率
 */
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const { sha256 } = require("./lib");

const ROOT = path.resolve(__dirname, "..");
const ASSETSRV = path.join(ROOT, "assetsrv", "audio");
const MANIFEST = path.join(ROOT, "gameproj", "asset_manifest.json");
const TMP = path.join(ROOT, "assetsrv", ".recompress_tmp");

const argv = process.argv.slice(2);
const DRY = argv.includes("--dry-run");
const kbpsArg = argv.indexOf("--kbps");
const TARGET_KBPS = kbpsArg >= 0 ? parseInt(argv[kbpsArg + 1], 10) : 128;
const FFMPEG = process.env.FFMPEG || "ffmpeg";

if (!Number.isFinite(TARGET_KBPS) || TARGET_KBPS < 32 || TARGET_KBPS > 320) {
  console.error("--kbps 需在 32~320 之间");
  process.exit(1);
}

// --- mp3 首帧头解析：拿当前码率，用于幂等判断 -------------------------------
const BITRATES_V1L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];

function readBitrate(buf) {
  let i = 0;
  if (buf.slice(0, 3).toString("latin1") === "ID3") {
    i = 10 + ((buf[6] << 21) | (buf[7] << 14) | (buf[8] << 7) | buf[9]);
  }
  for (; i < buf.length - 4; i++) {
    if (buf[i] !== 0xff || (buf[i + 1] & 0xe0) !== 0xe0) continue;
    const ver = (buf[i + 1] >> 3) & 3;
    const layer = (buf[i + 1] >> 1) & 3;
    if (ver !== 3 || layer !== 1) continue; // 只认 MPEG1 Layer3
    return BITRATES_V1L3[(buf[i + 2] >> 4) & 15];
  }
  return 0; // 未识别
}

function checkFfmpeg() {
  try {
    execFileSync(FFMPEG, ["-version"], { stdio: "pipe" });
  } catch (e) {
    console.error(
      `找不到 ffmpeg（尝试的命令：${FFMPEG}）。\n` +
        `装好后重跑，或用 FFMPEG=C:\\path\\to\\ffmpeg.exe node tools_extern/recompress-music.js`
    );
    process.exit(1);
  }
}

function loadManifest() {
  const m = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
  if (!m.audio) m.audio = {};
  return m;
}

function main() {
  checkFfmpeg();
  const manifest = loadManifest();

  // hash -> [res 路径]，一个音频可能被多个 res 路径引用
  const byHash = {};
  for (const [resPath, info] of Object.entries(manifest.audio)) {
    (byHash[info.hash] = byHash[info.hash] || []).push(resPath);
  }

  const files = fs.readdirSync(ASSETSRV).filter((f) => f.toLowerCase().endsWith(".mp3"));
  if (!DRY) fs.mkdirSync(TMP, { recursive: true });

  let done = 0, skipped = 0, orphan = 0, before = 0, after = 0;

  for (const f of files) {
    const src = path.join(ASSETSRV, f);
    const buf = fs.readFileSync(src);
    const oldHash = path.basename(f, ".mp3");
    const kbps = readBitrate(buf);

    if (kbps && kbps <= TARGET_KBPS) {
      console.log(`  - 跳过 ${oldHash.slice(0, 8)} 已是 ${kbps}kbps`);
      skipped++;
      continue;
    }

    const refs = byHash[oldHash];
    if (!refs) {
      // manifest 里没人引用：可能是历史遗留。不动它，只报告。
      console.warn(`  ! ${oldHash.slice(0, 8)} manifest 无引用，跳过（可手动清理）`);
      orphan++;
      continue;
    }

    before += buf.length;

    if (DRY) {
      const est = Math.round((buf.length * TARGET_KBPS) / (kbps || 320));
      after += est;
      console.log(
        `  ~ ${oldHash.slice(0, 8)} ${kbps}k ${(buf.length / 1048576).toFixed(1)}MB ` +
          `→ ~${(est / 1048576).toFixed(1)}MB  [${refs[0]}]`
      );
      done++;
      continue;
    }

    const tmpOut = path.join(TMP, oldHash + ".mp3");
    execFileSync(
      FFMPEG,
      [
        "-hide_banner", "-loglevel", "error", "-y",
        "-i", src,
        "-vn",                                  // 丢掉内嵌封面，省几十 KB
        "-map_metadata", "-1",                  // 丢掉 ID3
        "-c:a", "libmp3lame",
        "-b:a", `${TARGET_KBPS}k`,
        "-joint_stereo", "1",
        "-ar", "44100",
        tmpOut,
      ],
      { stdio: "pipe" }
    );

    const outBuf = fs.readFileSync(tmpOut);
    const newHash = sha256(outBuf);
    fs.writeFileSync(path.join(ASSETSRV, newHash + ".mp3"), outBuf);
    fs.unlinkSync(tmpOut);
    if (newHash !== oldHash) fs.unlinkSync(src);

    for (const resPath of refs) {
      manifest.audio[resPath] = { hash: newHash, size: outBuf.length };
    }
    byHash[newHash] = refs;

    after += outBuf.length;
    done++;
    console.log(
      `  ✓ ${oldHash.slice(0, 8)} ${kbps}k ${(buf.length / 1048576).toFixed(1)}MB → ` +
        `${newHash.slice(0, 8)} ${TARGET_KBPS}k ${(outBuf.length / 1048576).toFixed(1)}MB`
    );
  }

  if (!DRY) {
    fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2));
    try { fs.rmdirSync(TMP); } catch (e) {}
  }

  const saved = before - after;
  console.log(
    `\n${DRY ? "[dry-run] " : "✓ "}重压缩 ${done} 首 @ ${TARGET_KBPS}kbps，` +
      `跳过 ${skipped}${orphan ? `，无引用 ${orphan}` : ""}`
  );
  console.log(
    `  ${(before / 1048576).toFixed(1)}MB → ${(after / 1048576).toFixed(1)}MB，` +
      `节省 ${(saved / 1048576).toFixed(1)}MB (${before ? Math.round((saved / before) * 100) : 0}%)`
  );
  if (!DRY && done) {
    console.log(`  已更新 ${MANIFEST}`);
    console.log(`  ⚠️ manifest 在 gameproj 内会打进 pck —— 需重新导出 pck 后再测`);
    console.log(`  ⚠️ 回滚：git checkout HEAD -- assetsrv/audio gameproj/asset_manifest.json`);
  }
}

main();
