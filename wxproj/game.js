console.log("[build] brotato-wxproj (godot 3.6.2) #13 (overlay diag)");
import "./weapp-adapter";
import "./fetch";
import "./js/asset-loader";
import Loader from "./js/loader";

function checkUpdate() {
  const updateManager = wx.getUpdateManager();
  updateManager.onCheckForUpdate(() => {
    // 请求完新版本信息的回调
  });
  updateManager.onUpdateReady(() => {
    wx.showModal({
      title: "更新提示",
      content: "新版本已经准备好，是否重启应用？",
      success(res) {
        if (res.confirm) {
          updateManager.applyUpdate();
        }
      },
    });
  });
  updateManager.onUpdateFailed(() => {
    // 新版本下载失败
  });
}
// 开发者工具里没有线上版本，UpdateManager 的检查请求会被中止并触发 AbortError 上报，只在真机跑
if (wx.getSystemInfoSync().platform !== "devtools") {
  checkUpdate();
}
const loader = new Loader();
loader.load();
