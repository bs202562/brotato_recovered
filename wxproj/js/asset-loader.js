// 小游戏资源下载桥：GDScript 通过 JavaScript.eval 调这里，把远程资源下载后写进引擎 FS 的 user:// 目录。
// GDScript 侧用 OS.get_user_data_dir() 提供绝对路径(absPath)，随后用 File.file_exists 轮询就绪。
// 依赖 GameGlobal.godotWriteUserFile —— 由 patch-export 的 D-userfile-bridge 补丁注入(FS 在胶水闭包内)。

const inflight = {}; // absPath -> true，去重
const state = {}; // absPath -> "downloading" | "done" | "error"
GameGlobal.__assetState = state;

function readTempFile(tempFilePath) {
  const fs = wx.getFileSystemManager();
  const data = fs.readFileSync(tempFilePath); // ArrayBuffer
  return new Uint8Array(data);
}

// 下载 url 到引擎 FS 的 absPath（幂等：同一 absPath 只下一次）
GameGlobal.wxDownloadAsset = function (url, absPath) {
  if (inflight[absPath] || state[absPath] === "done") return;
  inflight[absPath] = true;
  state[absPath] = "downloading";
  wx.downloadFile({
    url: url,
    success: function (res) {
      if (res.statusCode !== 200) {
        console.error("[asset] HTTP", res.statusCode, url);
        state[absPath] = "error";
        inflight[absPath] = false;
        return;
      }
      try {
        const bytes = readTempFile(res.tempFilePath);
        const ok = GameGlobal.godotWriteUserFile(absPath, bytes);
        state[absPath] = ok ? "done" : "error";
        if (ok) console.log(`[asset] 就绪 ${(bytes.length / 1048576).toFixed(2)}MB -> ${absPath}`);
      } catch (e) {
        console.error("[asset] 写入失败", absPath, e && e.message);
        state[absPath] = "error";
      }
      inflight[absPath] = false;
    },
    fail: function (err) {
      console.error("[asset] 下载失败", url, err && err.errMsg);
      state[absPath] = "error";
      inflight[absPath] = false;
    },
  });
};

// 供 GDScript 查询状态（JavaScript.eval 返回字符串）："downloading"/"done"/"error"/"idle"
GameGlobal.wxAssetState = function (absPath) {
  return state[absPath] || "idle";
};
