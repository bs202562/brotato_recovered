"use strict";
// 从 asset_manifest.json 生成宿主(loader.js)用的 JS 清单：overlay 分块列表 + 基址。
// 宿主在游戏启动前直接下载 overlay 包（微信禁 eval，不能用 JavaScript.eval 从 GDScript 调）。
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, "gameproj/asset_manifest.json"), "utf8"));
const packs = (manifest.packs || []).map((p) => p.file);

// 局域网 IP，真机调试时手机要能访问到这台机器。上架换正式 HTTPS 域名。
// 注意：改这里的同时要同步改 gameproj/singletons/wx_assets.gd 里的 ASSET_BASE_*
// 和 tools_extern/externalize-base-pck.js 里的 BASE_URL（GDScript 侧读不到这个 JS 常量）。
const BASE = "http://192.168.1.31:8666";

const out = `// 自动生成（tools_extern/gen-host-manifest.js），勿手改
export const PACKS_BASE = ${JSON.stringify(BASE + "/packs/")};
export const AUDIO_BASE = ${JSON.stringify(BASE + "/audio/")};
export const OVERLAY_PACKS = ${JSON.stringify(packs, null, 2)};
`;
const dst = path.join(ROOT, "wxproj/js/wx-asset-manifest.js");
fs.writeFileSync(dst, out);
console.log("✓ 生成", dst, "—", packs.length, "个 overlay 分块");
