#!/usr/bin/env node
/**
 * Godot 3.6.2 微信小游戏导出后处理脚本（wxproj3 版）
 *
 * 用法：从 Godot 3.6.2 导出 HTML5 版到 gdexport/ 后运行
 *   node tools/patch-export.js
 *
 * 做三件事（全部幂等，重复运行安全）：
 *   1. index.wasm  → brotli 压缩为 index.wasm.br（WXWebAssembly 原生解压）
 *   2. index.pck   → 改名 index.zip（.pck 不在小游戏代码包文件类型白名单，
 *                    Godot 按文件头魔数 GDPC 识别 pack 格式，不看扩展名）
 *   3. index.js    → 打全部微信适配补丁
 *
 * 与 Godot 4 版（wxproj/tools/patch-export.js）的差异：
 *   - Godot 3 胶水无"位置上报 worklet"，D1 两条补丁不存在
 *   - Godot 3 的 GodotFS.init 走 IDBFS 挂载，新增 D-FS/D3a 两条补丁整体绕开
 *   - 包装层未压缩且缩进规整，C 类补丁改用宽松空白正则，抗缩进漂移
 */
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const crypto = require("crypto");

const GDEXPORT = path.join(__dirname, "..", "gdexport");
// index.js 放【主包】而不是 gdexport 分包：分包上限 4MB，index.wasm.br 已占 3.6MB，
// 再塞 335KB 的胶水只剩 79KB 余量，太险。主包才 100KB，放这里绰绰有余。
// 分包里只留 index.wasm.br —— WXWebAssembly.instantiate 只接受【代码包内】路径，
// 它没法像 pck 那样运行时下载，必须留在包里。
const GLUE_DIR = path.join(__dirname, "..", "glue");
const INDEX_JS = path.join(GLUE_DIR, "index.js");

function log(ok, msg) {
  console.log(`${ok ? "✓" : "✗"} ${msg}`);
}

// ---------- 1. brotli 压缩 wasm ----------
function compressWasm() {
  const src = path.join(GDEXPORT, "index.wasm");
  const dst = src + ".br";
  if (!fs.existsSync(src)) {
    log(fs.existsSync(dst), "index.wasm 不存在，跳过压缩" + (fs.existsSync(dst) ? "（已有 index.wasm.br）" : "——缺产物！"));
    return;
  }
  // Godot 每次导出都会重写 index.wasm（内容通常不变），按内容哈希判断是否需要重压
  const hashFile = path.join(__dirname, "index.wasm.br.srchash"); // 放 tools/ 内，避免进代码包
  const buf = fs.readFileSync(src);
  const hash = crypto.createHash("sha256").update(buf).digest("hex");
  if (fs.existsSync(dst) && fs.existsSync(hashFile) && fs.readFileSync(hashFile, "utf8").trim() === hash) {
    fs.unlinkSync(src); // 压缩产物已是最新，删除源 wasm 节约磁盘（可随时重导出）
    log(true, "index.wasm 内容未变（sha256 一致），跳过压缩并删除源文件");
    return;
  }
  console.log(`  压缩 index.wasm (${(buf.length / 1048576).toFixed(1)}MB)，quality 11 需一两分钟...`);
  const out = zlib.brotliCompressSync(buf, {
    params: {
      [zlib.constants.BROTLI_PARAM_QUALITY]: 11,
      [zlib.constants.BROTLI_PARAM_SIZE_HINT]: buf.length,
    },
  });
  fs.writeFileSync(dst, out);
  fs.writeFileSync(hashFile, hash);
  fs.unlinkSync(src); // 删除源 wasm 节约磁盘（内容哈希已记录，可随时重导出）
  log(true, `index.wasm.br 生成：${(out.length / 1048576).toFixed(2)}MB（${((out.length / buf.length) * 100).toFixed(1)}%），已删除源 wasm`);
}

// ---------- 2. 把 pck 踢出代码包 ----------
// base pck 有 20MB+，放代码包必然超微信 4MB 分包上限。它由
// tools_extern/externalize-base-pck.js 托管到 assetsrv，宿主启动时下载到 USER_DATA_PATH。
// 这里只负责清掉 gdexport 里的残留，避免它们被打进包。
function evictPck() {
  let removed = 0;
  for (const name of ["index.pck", "index.zip", "game.js"]) {
    const p = path.join(GDEXPORT, name);
    if (fs.existsSync(p)) {
      fs.unlinkSync(p);
      removed++;
      log(true, `已从代码包移除 gdexport/${name}`);
    }
  }
  if (!removed) log(true, "gdexport 内无 pck 残留");
}

// index.js 从 gdexport 挪到 glue/（主包）。Godot 每次导出都写到 gdexport，这里搬一次。
function relocateGlue() {
  fs.mkdirSync(GLUE_DIR, { recursive: true });
  const from = path.join(GDEXPORT, "index.js");
  if (fs.existsSync(from)) {
    fs.renameSync(from, INDEX_JS);
    log(true, "gdexport/index.js → glue/index.js（主包）");
  } else if (!fs.existsSync(INDEX_JS)) {
    log(false, "index.js 既不在 gdexport 也不在 glue——缺产物！");
    process.exitCode = 1;
  }
}

// ---------- 3. index.js 适配补丁 ----------
// 每项: name / applied(已打标志) / find(原文,字符串或正则) / replace
const PATCHES = [
  {
    name: "C1 loadFetch: fetch → wx 文件系统【分片读取】",
    applied: "小游戏适配(C1)",
    find: /return fetch\(file\)\.then\(function \(response\) \{[\s\S]*?return tr\.arrayBuffer\(\);\n\s*\}\);/,
    replace: `// 小游戏适配(C1): fetch(wx.request) 读不了代码包内文件，改用 wx 文件系统读取。
\t\t// 【分片】开发者工具模拟器的 coverRes 会把整个文件 base64 转交游戏侧 atob，
\t\t// 大文件(>~4MB)的 base64 字符串超限被截断 → "atob not correctly encoded"。
\t\t// 按 512KB 分片读取(readFile 支持 position/length)，每片 base64 都很小，拼回完整 buffer。
\t\t// 真机原生读盘无此桥，分片只是多几次调用，无害。
\t\treturn new Promise(function (resolve, reject) {
\t\t\tconst fsm = wx.getFileSystemManager();
\t\t\tlet total = 0;
\t\t\ttry { total = fsm.statSync(file).size; } catch (e) { total = 0; }
\t\t\tif (!total) {
\t\t\t\tfsm.readFile({ filePath: file,
\t\t\t\t\tsuccess: function (res) { tracker[file].loaded = tracker[file].total; tracker[file].done = true; resolve(res.data); },
\t\t\t\t\tfail: function (reason) { tracker[file].done = true; reject(new Error(\`Failed loading file '\${file}': \${reason.errMsg}\`)); } });
\t\t\t\treturn;
\t\t\t}
\t\t\tconst CHUNK = 512 * 1024;
\t\t\tconst out = new Uint8Array(total);
\t\t\tlet pos = 0;
\t\t\tfunction readNext() {
\t\t\t\tif (pos >= total) { tracker[file].loaded = tracker[file].total; tracker[file].done = true; resolve(out.buffer); return; }
\t\t\t\tconst len = Math.min(CHUNK, total - pos);
\t\t\t\tfsm.readFile({ filePath: file, position: pos, length: len,
\t\t\t\t\tsuccess: function (res) { out.set(new Uint8Array(res.data), pos); pos += len; tracker[file].loaded = pos; readNext(); },
\t\t\t\t\tfail: function (reason) { tracker[file].done = true; reject(new Error(\`Failed loading chunk '\${file}'@\${pos}: \${reason.errMsg}\`)); } });
\t\t\t}
\t\t\treadNext();
\t\t});`,
  },
  {
    name: "C2 Engine.load: .wasm → .wasm.br",
    applied: "小游戏适配(C2)",
    find: "loadPromise = preloader.loadPromise(`${loadPath}.wasm`, size, true);",
    replace: "// 小游戏适配(C2): 加载 brotli 压缩产物（原始 .wasm 不进包）\n\t\t\tloadPromise = preloader.loadPromise(`${loadPath}.wasm.br`, size, true);",
  },
  {
    name: "C3 instantiateWasm: WXWebAssembly 按路径实例化",
    applied: "小游戏适配(C3)",
    find: /if \(typeof \(WebAssembly\.instantiateStreaming\) !== 'undefined'\) \{[\s\S]*?WebAssembly\.instantiate\(buffer, imports\)\.then\(done\);\n\s*\}\);\n\s*\}/,
    replace: `// 小游戏适配(C3): WXWebAssembly 无 instantiateStreaming，只接受包内路径字符串（原生解压 .wasm.br）
\t\t\t\tWebAssembly.instantiate(\`\${loadPath}.wasm.br\`, imports).then(done);`,
  },
  {
    name: "C4 doInit: 去掉 Response.clone 包装，补 catch 防静默卡死",
    applied: "小游戏适配(C4)",
    find: /promise\.then\(function \(response\) \{\n\s*const cloned = new Response\(response\.clone\(\)\.body[\s\S]*?resolve\(\);\n\s*\}\);\n\s*\}\);\n\s*\}\);/,
    replace: `promise.then(function (response) {
\t\t\t\t\t\t\t// 小游戏适配(C4): fetch polyfill 无 Response/clone，wasm 由 C3 按路径实例化；
\t\t\t\t\t\t\t// initFS 保留（GodotFS.init 已由 D-FS 补丁绕开 IDBFS，只建目录）
\t\t\t\t\t\t\tGodot(me.config.getModuleConfig(loadPath, null)).then(function (module) {
\t\t\t\t\t\t\t\tconst paths = me.config.persistentPaths;
\t\t\t\t\t\t\t\tmodule['initFS'](paths).then(function (err) {
\t\t\t\t\t\t\t\t\tme.rtenv = module;
\t\t\t\t\t\t\t\t\tif (me.config.unloadAfterInit) {
\t\t\t\t\t\t\t\t\t\tEngine.unload();
\t\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t\t\tresolve();
\t\t\t\t\t\t\t\t});
\t\t\t\t\t\t\t}).catch(reject); // 小游戏适配: 显式上抛加载失败，避免静默卡死
\t\t\t\t\t\t}).catch(reject);`,
  },
  {
    name: "C5-engine: Engine 包装层加 copyFSToAdapter",
    applied: "小游戏适配(C5)",
    find: /copyToFS: function \(path, buffer\) \{\n\s*if \(this\.rtenv == null\) \{\n\s*throw new Error\('Engine must be inited before copying files'\);\n\s*\}\n\s*this\.rtenv\['copyToFS'\]\(path, buffer\);\n\s*\},/,
    replace: `copyToFS: function (path, buffer) {
\t\t\t\tif (this.rtenv == null) {
\t\t\t\t\tthrow new Error('Engine must be inited before copying files');
\t\t\t\t}
\t\t\t\tthis.rtenv['copyToFS'](path, buffer);
\t\t\t},

\t\t\t// 小游戏适配(C5): 把 persistentPaths 下的引擎 FS 文件全部导出给 adapter(GodotSDK)落盘
\t\t\tcopyFSToAdapter: function (adapter) {
\t\t\t\tif (this.rtenv == null) {
\t\t\t\t\tthrow new Error('Engine must be inited before copying files');
\t\t\t\t}
\t\t\t\tconst me = this;
\t\t\t\treturn Promise.all(me.config.persistentPaths.map(function (path) {
\t\t\t\t\treturn me.rtenv['copyToAdapter'](path, adapter);
\t\t\t\t}));
\t\t\t},`,
  },
  {
    name: "D-FS-init: GodotFS.init 绕开 IDBFS（只建目录）",
    applied: "小游戏适配(D-FS)",
    find: 'GodotFS._mount_points.forEach(function(path){createRecursive(path);FS.mount(IDBFS,{},path)});return new Promise(function(resolve,reject){FS.syncfs(true,function(err){if(err){GodotFS._mount_points=[];GodotFS._idbfs=false;GodotRuntime.print(`IndexedDB not available: ${err.message}`)}else{GodotFS._idbfs=true}resolve(err)})})',
    replace: 'GodotFS._mount_points.forEach(function(path){createRecursive(path)});GodotFS._idbfs=true;return Promise.resolve(null)/* 小游戏适配(D-FS): 无 indexedDB，目录建在 MEMFS，持久化改走 wx 文件系统(见 D3) */',
  },
  {
    name: "D3a-fs-sync-neuter: GodotFS.sync 去掉 IDBFS 同步",
    applied: "小游戏适配(D3a)",
    find: 'sync:function(){if(GodotFS._syncing){GodotRuntime.error("Already syncing!");return Promise.resolve()}GodotFS._syncing=true;return new Promise(function(resolve,reject){FS.syncfs(false,function(error){if(error){GodotRuntime.error(`Failed to save IDB file system: ${error.message}`)}GodotFS._syncing=false;resolve(error)})})}',
    replace: 'sync:function(){return Promise.resolve(null)/* 小游戏适配(D3a): IDBFS 不可用，真正落盘在 fs_sync 钩子经 godotSdk 完成 */}',
  },
  {
    name: "D-GL-target: findEventTarget 无 querySelector 时回退 GodotConfig.canvas",
    applied: "小游戏适配(D-GL)",
    find: 'function findEventTarget(target){target=maybeCStringToJsString(target);var domElement=specialHTMLTargets[target]||(typeof document!="undefined"?document.querySelector(target):undefined);return domElement}',
    replace:
      'function findEventTarget(target){target=maybeCStringToJsString(target);/* 小游戏适配(D-GL): weapp-adapter 的 document 无 querySelector，选择器查 canvas 必失败 → WebGL 上下文创建返回 0 → GLctx 空引用崩溃。这里直接回退引擎配置传入的真 canvas */var domElement=specialHTMLTargets[target]||(typeof document!="undefined"&&typeof document.querySelector=="function"?document.querySelector(target):undefined);if(!domElement&&typeof GodotConfig!="undefined"&&GodotConfig.canvas){domElement=GodotConfig.canvas;console.log("[D-GL] findEventTarget fallback → GodotConfig.canvas, target=",target)}if(!domElement&&typeof canvas!="undefined"){domElement=canvas}return domElement}',
  },
  {
    name: "D-GL2: 去掉 Safari WebGL2 兼容包装的 instanceof 误杀",
    applied: "小游戏适配(D-GL2)",
    find: 'function fixedGetContext(ver,attrs){var gl=canvas.getContextSafariWebGL2Fixed(ver,attrs);return ver=="webgl"==gl instanceof WebGLRenderingContext?gl:null}',
    replace: 'function fixedGetContext(ver,attrs){var gl=canvas.getContextSafariWebGL2Fixed(ver,attrs);return gl/* 小游戏适配(D-GL2): wx 的 WebGL 上下文不是 WebGLRenderingContext 实例，Safari 兼容判断会把有效上下文误判为 null */}',
  },
  {
    name: "D-GL3: emscriptenWebGLGet 数组判断改鸭子类型（跨 realm instanceof 失效）",
    applied: "小游戏适配(D-GL3)",
    find: "else if(result instanceof Float32Array||result instanceof Uint32Array||result instanceof Int32Array||result instanceof Array){",
    replace: 'else if(typeof result.length=="number"){/* 小游戏适配(D-GL3): wx 的 WebGL 代理跨 realm，TypedArray instanceof 恒 false，导致 MAX_VIEWPORT_DIMS 等数组参数读成 0，按 length 鸭子判断 */',
  },
  {
    name: "D-IME: 禁用 IME DOM 元素（文字输入后续走 wx.showKeyboard）",
    applied: "小游戏适配(D): 无 DOM，禁用 IME",
    find: "init:function(ime_cb,key_cb,code,key){function key_event_cb(pressed,evt){",
    replace: "init:function(ime_cb,key_cb,code,key){return;/* 小游戏适配(D): 无 DOM，禁用 IME 元素，文字输入后续走 wx.showKeyboard */function key_event_cb(pressed,evt){",
  },
  {
    name: "D-title: 禁用 document.title 设置",
    applied: "小游戏适配(D): 无 document.title",
    find: "function _godot_js_display_window_title_set(p_data){document.title=GodotRuntime.parseString(p_data)}",
    replace: "function _godot_js_display_window_title_set(p_data){/* 小游戏适配(D): 无 document.title，窗口标题无意义 */}",
  },
  {
    name: "D-icon: 禁用窗口图标设置",
    applied: "小游戏适配(D): 无 DOM head/link",
    find: "function _godot_js_display_window_icon_set(p_ptr,p_len){let link=",
    replace: "function _godot_js_display_window_icon_set(p_ptr,p_len){return;/* 小游戏适配(D): 无 DOM head/link，窗口图标无意义 */let link=",
  },
  {
    name: "D-fullscreen: 全屏请求直接返回 OK（wx 无 DOM 全屏，避免 set_window_fullscreen 报错）",
    applied: "小游戏适配(D-fullscreen)",
    find: "function _godot_js_display_fullscreen_request(){return GodotDisplayScreen.requestFullscreen()}",
    replace: "function _godot_js_display_fullscreen_request(){return 0/* 小游戏适配(D-fullscreen): wx 无 DOM 全屏请求，直接返回 OK 避免引擎报错 */}",
  },
  {
    name: "D-cursor: 禁用自定义鼠标光标（wx 无 URL.createObjectURL/Blob）",
    applied: "小游戏适配(D-cursor)",
    find: "_godot_js_display_cursor_set_custom_shape(p_shape,p_ptr,p_len,p_hotspot_x,p_hotspot_y){const shape=GodotRuntime.parseString(p_shape);",
    replace: "_godot_js_display_cursor_set_custom_shape(p_shape,p_ptr,p_len,p_hotspot_x,p_hotspot_y){return;/* 小游戏适配(D-cursor): wx 无 URL.createObjectURL/真 Blob，移动端也无 CSS 光标，直接禁用 */const shape=GodotRuntime.parseString(p_shape);",
  },
  {
    name: "D-alert: window.alert → console.warn",
    applied: "小游戏适配(D): 无 window.alert",
    find: "function _godot_js_display_alert(p_text){window.alert(GodotRuntime.parseString(p_text))}",
    replace: 'function _godot_js_display_alert(p_text){console.warn("[godot alert]",GodotRuntime.parseString(p_text))/* 小游戏适配(D): 无 window.alert */}',
  },
  {
    name: "D2-fs-adapter: GodotFS 注入 copy_to_adapter（存档导出）",
    applied: "小游戏适配(D2)",
    find: 'copy_to_fs:function(path,buffer){const idx=path.lastIndexOf("/");',
    replace:
      'copy_to_adapter:function(path,adapter){/* 小游戏适配(D2): 递归导出引擎 FS 目录到 adapter(GodotSDK)，用于存档落盘。\n\t\t\t\tSKIP: 外置资源缓存目录绝不参与同步——audiocache(~66MB 音乐) 与 packs(~41MB overlay) 是宿主\n\t\t\t\t下载时就已 copyFileSync 落过盘的只读缓存，磁盘上本来就有。它们只是被 preloadUserFiles 灌进\n\t\t\t\t引擎 MEMFS 供 File/load_resource_pack 读取，不该再写回去。不跳过的话，每次存档(战斗中极频繁)\n\t\t\t\t都会 readFile+write 整整 107MB，直接把帧冻住——实测表现为存档日志后紧跟 fps=3。 */\n\t\t\t\tconst SKIP_SYNC=["audiocache","packs"];let dirs;try{dirs=FS.readdir(path).filter(function(v){return v!=="."&&v!==".."})}catch(e){return Promise.resolve()}const promises=[];dirs.forEach(function(d){if(SKIP_SYNC.indexOf(d)>=0){return}const _p=path+"/"+d;const st=FS.stat(_p);if(FS.isFile(st.mode)){promises.push(adapter.writeFile(_p,FS.readFile(_p)))}else if(FS.isDir(st.mode)){promises.push(GodotFS.copy_to_adapter(_p,adapter))}});return Promise.all(promises)},copy_to_fs:function(path,buffer){const idx=path.lastIndexOf("/");',
  },
  {
    name: "D2-fs-export: Module 导出 copyToAdapter",
    applied: 'Module["copyToAdapter"]',
    find: 'Module["copyToFS"]=GodotFS.copy_to_fs;',
    replace: 'Module["copyToFS"]=GodotFS.copy_to_fs;Module["copyToAdapter"]=GodotFS.copy_to_adapter;',
  },
  {
    name: "D-userfile-bridge: 暴露 GameGlobal.godotWriteUserFile（宿主把下载字节写进引擎 FS）",
    applied: "GameGlobal.godotWriteUserFile",
    find: 'Module["copyToAdapter"]=GodotFS.copy_to_adapter;',
    replace:
      'Module["copyToAdapter"]=GodotFS.copy_to_adapter;/* 小游戏适配(D-userfile-bridge): FS 在胶水闭包内，暴露全局写入桥，供 asset-loader 把 wx.downloadFile 下来的字节写进引擎 FS 的 user:// 目录，GDScript 随后用 File 读取。absPath 由 GDScript 的 OS.get_user_data_dir() 提供，避免 user:// 映射猜测 */GameGlobal.godotWriteUserFile=function(absPath,bytes){try{const idx=absPath.lastIndexOf("/");const dir=absPath.slice(0,idx);if(dir){try{FS.mkdirTree(dir)}catch(e){}}FS.writeFile(absPath,bytes);return true}catch(e){console.error("[godotWriteUserFile]",absPath,e&&e.message);return false}};GameGlobal.godotUserFileExists=function(absPath){try{FS.stat(absPath);return true}catch(e){return false}};GameGlobal.godotReadUserFileText=function(absPath){try{return FS.readFile(absPath,{encoding:"utf8"})}catch(e){return ""}};',
  },
  {
    name: "D3-fs-persistent: is_persistent 返回真（触发引擎 fs_sync）",
    applied: "小游戏适配(D3): 存档经 wx 文件系统持久化",
    find: "function _godot_js_os_fs_is_persistent(){return GodotFS.is_persistent()}",
    replace: "function _godot_js_os_fs_is_persistent(){return 1/* 小游戏适配(D3): 存档经 wx 文件系统持久化，且需为真引擎才会触发 fs_sync */}",
  },
  {
    name: "D3-fs-sync: fs_sync 钩子挂 wx 落盘（事件驱动存档）",
    applied: "小游戏适配(D3): 引擎写完 user://",
    find: "function _godot_js_os_fs_sync(callback){const func=GodotRuntime.get_func(callback);GodotOS._fs_sync_promise=GodotFS.sync();GodotOS._fs_sync_promise.then(function(err){func()})}",
    replace:
      'function _godot_js_os_fs_sync(callback){const func=GodotRuntime.get_func(callback);/* 小游戏适配(D3): 引擎写完 user:// 会主动调这里，挂上 wx 落盘实现事件驱动存档 */GodotOS._fs_sync_promise=GodotFS.sync().then(function(){return new Promise(function(res){if(GameGlobal.godotSdk){GameGlobal.godotSdk.syncfs(res,function(e){console.error("[fs_sync]",e);res()})}else{res()}})});GodotOS._fs_sync_promise.then(function(err){func()})}',
  },
];

function patchIndexJs() {
  if (!fs.existsSync(INDEX_JS)) {
    log(false, "glue/index.js 不存在！");
    process.exitCode = 1;
    return;
  }
  let src = fs.readFileSync(INDEX_JS, "utf8");
  let changed = false;
  let failed = 0;
  for (const p of PATCHES) {
    if (src.includes(p.applied)) {
      log(true, `${p.name} —— 已打过，跳过`);
      continue;
    }
    const before = src;
    src = src.replace(p.find, p.replace);
    if (src === before) {
      log(false, `${p.name} —— 锚点没匹配到！引擎版本可能变了，需人工核对`);
      failed++;
    } else {
      log(true, p.name);
      changed = true;
    }
  }
  if (changed) fs.writeFileSync(INDEX_JS, src);
  if (failed) process.exitCode = 1;
}

console.log("=== Godot 3.6.2 微信小游戏导出后处理 ===");
compressWasm();
evictPck();
relocateGlue();
patchIndexJs();
console.log("=== 完成 ===");
