// 音乐按需下载——文件桥（微信禁 eval，不能从 GDScript 直接调宿主）。
// GDScript(WxAssets) 把待下载请求写进 user://.wxreq.json；本模块轮询该文件，
// 下载后分片读入引擎 FS（godotWriteUserFile），并持久化到 wx 存储。GDScript 轮询文件就绪。
//
// 依赖补丁 D-userfile-bridge 暴露的：godotReadUserFileText / godotWriteUserFile。

const REQ_FILE = "/userfs/.wxreq.json"; // 与 GDScript OS.get_user_data_dir()=/userfs 对应
const doneSet = {}; // path -> true
const inflight = {}; // path -> true

// 分片读取本地文件为 Uint8Array，避开开发者工具模拟器 coverRes 对大文件 base64 的限制。
function readFileChunked(fsm, filePath) {
  const size = fsm.statSync(filePath).size;
  const out = new Uint8Array(size);
  const CHUNK = 512 * 1024;
  let pos = 0;
  while (pos < size) {
    const len = Math.min(CHUNK, size - pos);
    const buf = fsm.readFileSync(filePath, undefined, pos, len); // (path, encoding, position, length)
    out.set(new Uint8Array(buf), pos);
    pos += len;
  }
  return out;
}

function handle(r) {
  if (!r || !r.path || !r.url) return;
  if (doneSet[r.path] || inflight[r.path]) return;
  inflight[r.path] = true;
  wx.downloadFile({
    url: r.url,
    success: (res) => {
      if (res.statusCode === 200) {
        try {
          const fsm = wx.getFileSystemManager();
          const bytes = readFileChunked(fsm, res.tempFilePath);
          GameGlobal.godotWriteUserFile(r.path, bytes); // 写入引擎 FS（MEMFS），GDScript 立即可读
          // 持久化到 wx 存储，下次启动 preloadUserFiles 恢复
          try {
            const wxPath = wx.env.USER_DATA_PATH + r.path;
            const dir = wxPath.slice(0, wxPath.lastIndexOf("/"));
            try { fsm.mkdirSync(dir, true); } catch (e) {}
            fsm.copyFileSync(res.tempFilePath, wxPath);
          } catch (e) {}
          doneSet[r.path] = true;
          console.log(`[asset] 音乐就绪 ${(bytes.length / 1048576).toFixed(2)}MB -> ${r.path}`);
        } catch (e) {
          console.error("[asset] 写入失败", r.path, e && e.message);
        }
      } else {
        console.error("[asset] HTTP", res.statusCode, r.url);
      }
      inflight[r.path] = false;
    },
    fail: (err) => {
      console.error("[asset] 下载失败", r.url, err && err.errMsg);
      inflight[r.path] = false;
    },
  });
}

// 轮询请求文件
function pump() {
  if (!GameGlobal.godotReadUserFileText || !GameGlobal.godotWriteUserFile) return;
  let text = "";
  try { text = GameGlobal.godotReadUserFileText(REQ_FILE); } catch (e) { return; }
  if (!text) return;
  let reqs;
  try { reqs = JSON.parse(text); } catch (e) { return; }
  if (Array.isArray(reqs)) reqs.forEach(handle);
}

setInterval(pump, 400);
