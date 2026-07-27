"use strict";
/**
 * base pck 外置（幂等）
 *
 * 微信小游戏限制：主包和每个分包各自 ≤ 4MB，总计 ≤ 20MB。而 Godot 导出的 index.pck
 * 有 20MB+，放进代码包必然超限（预览会报 "subpackage __FULL__ source size ... exceed max limit 4096KB"）。
 * 这里把它按内容 hash 命名后放到 assetsrv 托管，由宿主(loader.js)在启动时下载到
 * USER_DATA_PATH 再作为 mainPack 传给引擎。
 *
 * 为什么能直接用 .pck 后缀：".pck 不在小游戏文件类型白名单" 这条只约束【代码包内】的文件；
 * 运行时下载到 USER_DATA_PATH 的文件不受限（现有 overlay 分块就是 .pck 存在那里的）。
 *
 * 用法：Godot 导出后运行
 *   node tools_extern/externalize-base-pck.js
 */
const fs = require("fs");
const path = require("path");
const { sha256, ensureDir } = require("./lib");

const ROOT = path.resolve(__dirname, "..");
const SRC = path.join(ROOT, "gameproj/build/web/index.pck");
const OUT_DIR = path.join(ROOT, "assetsrv/packs");
const DST_JS = path.join(ROOT, "wxproj/js/wx-base-pck.js");
// 与 gen-host-manifest.js 的 BASE、wx_assets.gd 的 ASSET_BASE_* 保持一致
const BASE_URL = "http://192.168.1.31:8666/packs/";

if (!fs.existsSync(SRC)) {
  console.error("✗ 找不到", SRC, "—— 先从 Godot 导出");
  process.exit(1);
}

ensureDir(OUT_DIR);
const buf = fs.readFileSync(SRC);
const hash = sha256(buf);
const name = `base_${hash}.pck`;
const dst = path.join(OUT_DIR, name);

// 清掉旧的 base 包（文件名带内容 hash，旧的不会再被引用）
for (const f of fs.readdirSync(OUT_DIR)) {
  if (f.startsWith("base_") && f.endsWith(".pck") && f !== name) {
    fs.unlinkSync(path.join(OUT_DIR, f));
    console.log("  清理旧 base 包:", f);
  }
}

if (!fs.existsSync(dst)) fs.writeFileSync(dst, buf);

fs.writeFileSync(
  DST_JS,
  `// 自动生成（tools_extern/externalize-base-pck.js），勿手改
export const BASE_PCK_NAME = ${JSON.stringify(name)};
export const BASE_PCK_URL = ${JSON.stringify(BASE_URL + name)};
export const BASE_PCK_SIZE = ${buf.length};
`
);

console.log(`✓ base pck 外置: ${name}  ${(buf.length / 1048576).toFixed(2)} MB`);
console.log(`  托管: ${dst}`);
console.log(`  清单: ${DST_JS}`);
