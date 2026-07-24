"use strict";
/**
 * 本地静态资源服务器——托管外置资源，供微信小游戏 wx.downloadFile 下载。
 * 开发者工具需勾选：详情 → 本地设置 → 不校验合法域名、web-view、TLS 版本以及 HTTPS 证书。
 *
 * 用法：node tools_extern/dev-server.js [port]
 * 根目录：assetsrv/（audio/<hash>.mp3、packs/*.pck ...）
 */
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = parseInt(process.argv[2] || "8666", 10);
const ROOT = path.resolve(__dirname, "..", "assetsrv");

const MIME = {
  ".mp3": "audio/mpeg",
  ".ogg": "audio/ogg",
  ".wav": "audio/wav",
  ".pck": "application/octet-stream",
  ".json": "application/json",
  ".png": "image/png",
};

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent(req.url.split("?")[0]);
  console.log(`[req] ${req.method} ${urlPath} range=${req.headers.range || "-"}`);
  // 防目录穿越
  const safe = path.normalize(urlPath).replace(/^(\.\.[\/\\])+/, "");
  const file = path.join(ROOT, safe);
  if (!file.startsWith(ROOT)) {
    res.writeHead(403);
    return res.end("forbidden");
  }
  fs.stat(file, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404);
      return res.end("not found");
    }
    const ext = path.extname(file).toLowerCase();
    const total = stat.size;
    const range = req.headers.range;
    const headers = {
      "Content-Type": MIME[ext] || "application/octet-stream",
      "Access-Control-Allow-Origin": "*",
      "Accept-Ranges": "bytes",
    };
    if (range) {
      const m = /bytes=(\d*)-(\d*)/.exec(range);
      let start = m && m[1] ? parseInt(m[1], 10) : 0;
      let end = m && m[2] ? parseInt(m[2], 10) : total - 1;
      if (start > end || end >= total) end = total - 1;
      headers["Content-Range"] = `bytes ${start}-${end}/${total}`;
      headers["Content-Length"] = end - start + 1;
      res.writeHead(206, headers);
      fs.createReadStream(file, { start, end }).pipe(res);
    } else {
      headers["Content-Length"] = total;
      res.writeHead(200, headers);
      fs.createReadStream(file).pipe(res);
    }
  });
});

server.listen(PORT, () => {
  console.log(`[dev-server] 托管 ${ROOT}`);
  console.log(`[dev-server] http://localhost:${PORT}/  (Ctrl+C 停止)`);
  console.log(`[dev-server] 例：http://localhost:${PORT}/audio/<hash>.mp3`);
});
