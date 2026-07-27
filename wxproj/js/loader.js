import { GodotSDK } from "./sdk"
import { PACKS_BASE, OVERLAY_PACKS } from "./wx-asset-manifest"
import { BASE_PCK_NAME, BASE_PCK_URL, BASE_PCK_SIZE } from "./wx-base-pck"

const LoaderConfig = {
  logo: "images/logo.png",
  background: "images/background.png",
  iconWidth: 128,
  iconHeight: 128,
  backGroudColor: "#282c34",
  loadingBarHeight: 20,
  loadingBarColor: "#478CBF",
  loadingBarBackgroundColor: "#444",
};

const crypto = {
  getRandomValues: (view) => {
    for (let i = 0; i < view.length; i++) {
      // Math.random() 生成一个 0 到 1 之间的浮动值，将其乘以 256，取整并限制在 0-255 之间
      view[i] = Math.floor(Math.random() * 256);
    }
    return view;
  },
};

class FakeBlob {
  constructor(data, options) {
    this.data = data || [];
    this.type = options?.type || "";
    this.size = this.data.reduce((total, item) => total + (item.length || 0), 0);
  }
}
// GL 调用计数器（排查 wx 的 GL 桥开销；定位完把 GL_PROFILE 改回 false）。
// Godot 3 的 GLES2 不上报绘制调用数，只能从宿主侧数。canvas.getContext("webgl") 重复调用
// 返回同一个上下文对象，所以在 loader 里包一次，引擎后续的调用也全都算得到。
const GL_PROFILE = true;
// 只包热点函数，避免为了统计反而拖慢（每次调用多一层闭包）
const GL_WATCH = [
  "drawElements", "drawArrays", "bindTexture", "useProgram", "bindBuffer",
  "bufferData", "bufferSubData", "vertexAttribPointer", "enableVertexAttribArray",
  "activeTexture", "uniform1i", "uniform1f", "uniform4fv", "uniformMatrix4fv",
  "texImage2D", "texSubImage2D", "scissor", "clear", "blendFunc",
];

function installGlCounter(gl) {
  const counts = Object.create(null);
  for (const name of GL_WATCH) {
    const orig = gl[name];
    if (typeof orig !== "function") continue;
    counts[name] = 0;
    gl[name] = function (...args) {
      counts[name]++;
      return orig.apply(gl, args);
    };
  }
  let last = Date.now();
  setInterval(() => {
    const now = Date.now();
    const secs = (now - last) / 1000;
    last = now;
    const entries = Object.keys(counts)
      .map((k) => [k, counts[k]])
      .filter((e) => e[1] > 0)
      .sort((a, b) => b[1] - a[1]);
    const total = entries.reduce((s, e) => s + e[1], 0);
    const draws = (counts.drawElements || 0) + (counts.drawArrays || 0);
    for (const k of Object.keys(counts)) counts[k] = 0;
    if (!total) return;
    console.log(
      `[gl] ${Math.round(total / secs)} 次调用/秒，其中绘制 ${Math.round(draws / secs)} 次/秒 | ` +
        entries.slice(0, 6).map((e) => `${e[0]}=${Math.round(e[1] / secs)}`).join(" ")
    );
  }, 2000);
}

// ---- canvas 事件桥 ----
// 引擎把 keydown/keyup/mouse*/touch* 都注册在 GodotConfig.canvas 上，而 weapp-adapter 把
// canvas.addEventListener 转发给它【内部那个 document 实例】。开发者工具是 Chromium，
// window.document 是真 DOM 且属性不可配置，weapp-adapter 的覆盖会静默失败
// (它只在 descriptor.configurable === true 时才 defineProperty)，于是
// window.document !== weapp-adapter 的 document —— 往前者派发的键盘事件永远送不到引擎。
// 这里不赌哪个 document 是真的：在引擎注册【之前】接管 canvas.addEventListener，
// 自己留一份回调表，需要注入事件时直接调用，绕开 document 身份问题。
const canvasListeners = Object.create(null);
const inputCounts = Object.create(null);

function hookCanvasListeners() {
  const origAdd = canvas.addEventListener ? canvas.addEventListener.bind(canvas) : null;
  const origRemove = canvas.removeEventListener ? canvas.removeEventListener.bind(canvas) : null;
  canvas.addEventListener = function (type, listener, opts) {
    (canvasListeners[type] = canvasListeners[type] || []).push(listener);
    if (origAdd) origAdd(type, listener, opts);
  };
  canvas.removeEventListener = function (type, listener, opts) {
    const arr = canvasListeners[type];
    if (arr) {
      const i = arr.indexOf(listener);
      if (i >= 0) arr.splice(i, 1);
    }
    if (origRemove) origRemove(type, listener, opts);
  };
}

// 直接投递给引擎注册在 canvas 上的回调。返回 false 表示引擎没注册这类事件。
function emitToCanvas(evt) {
  const arr = canvasListeners[evt.type];
  if (!arr || !arr.length) return false;
  inputCounts[evt.type] = (inputCounts[evt.type] || 0) + 1;
  for (const fn of arr.slice()) {
    try {
      fn(evt);
    } catch (e) {
      console.error("[input] 回调抛错", evt.type, e && e.message);
    }
  }
  return true;
}

// 输入诊断：引擎注册了哪些事件、我们实际送达了多少。定位完连同 GL_PROFILE 一起关掉。
const INPUT_PROFILE = true;
// 直接验证"两个 document 是不是同一个"：往 canvas 注册一个探针，再从 window.document 派发。
// 收不到就证明旧的 doc.dispatchEvent 路径确实是断的。
function probeDocumentIdentity() {
  let hit = false;
  const probe = () => { hit = true; };
  canvas.addEventListener("__probe__", probe);
  try {
    window.document.dispatchEvent({ type: "__probe__" });
  } catch (e) {
    console.log("[input] 探针派发抛错:", e && e.message);
  }
  canvas.removeEventListener("__probe__", probe);
  console.log(
    `[input] window.document 与引擎监听目标一致? ${hit ? "是" : "否 ← 旧的 document.dispatchEvent 路径是断的，键盘收不到"}`
  );
}

function startInputProfile() {
  probeDocumentIdentity();
  console.log("[input] 引擎在 canvas 上注册的事件: " + (Object.keys(canvasListeners).join(",") || "(无！)"));
  setInterval(() => {
    const parts = Object.keys(inputCounts).map((k) => `${k}=${inputCounts[k]}`);
    for (const k of Object.keys(inputCounts)) delete inputCounts[k];
    console.log(`[input] 注册=${Object.keys(canvasListeners).join(",") || "(无)"} | 送达 ${parts.join(" ") || "(本轮无输入)"}`);
  }, 3000);
}

const godotSdk = new GodotSDK()
GameGlobal.WebAssembly = WXWebAssembly;
GameGlobal.crypto = crypto;
// 整个假的Blob，websocket防止出错
GameGlobal.Blob = FakeBlob;
GameGlobal.godotSdk = godotSdk;



class Loader {
  constructor(config) {
    this.config = {
      ...LoaderConfig,
      ...config,
    };
    const info = wx.getWindowInfo();
    const dpr = info.pixelRatio;
    this.progress = 0;
    // Godot 3 + GLES2 用 WebGL1。canvas 只能持有一种上下文，loader 必须和引擎
    // 请求同一种（引擎胶水会 getContext("webgl")），否则引擎拿到 null 起不来
    this.screenContext = canvas.getContext("webgl");
    if (!this.screenContext) {
      const msg = "此环境不支持 WebGL。";
      console.error("[loader]", msg);
      wx.showModal({ title: "无法启动", content: msg, showCancel: false });
      throw new Error(msg);
    }
    if (GL_PROFILE) installGlCounter(this.screenContext);
    // 必须在 require(index.js) / startGame 之前接管，否则引擎已经注册完了
    hookCanvasListeners();
    this.loadingCanvas = document.createElement("canvas");
    this.loadingContext = this.loadingCanvas.getContext("2d");
    this.loadingCanvas.width = window.innerWidth * dpr;
    this.loadingCanvas.height = window.innerHeight * dpr;
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    this.loadingContext.scale(dpr, dpr);

    this.backgroundImage = wx.createImage();
    this.backgroundImage.src = this.config.background;

    this.logoImage = wx.createImage();
    this.logoImage.src = this.config.logo;
    this.logoImage.width = this.config.iconWidth;
    this.logoImage.height = this.config.iconHeight;

    const [screenTexture, cleanWebgl] = this.initWebgl();
    this.screenTexture = screenTexture;
    this.cleanWebgl = cleanWebgl;
  }

  // 小游戏适配: 键盘/鼠标事件桥接（PC 端微信与开发者工具支持 wx.onKeyDown 等 API）。
  // 投递优先走 emitToCanvas（直接调用引擎注册在 canvas 上的回调），送不到再退回
  // document.dispatchEvent —— 见 hookCanvasListeners 处关于两个 document 不是同一个对象的说明。
  setupPcInput() {
    const doc = window.document;
    const deliver = (evt) => {
      if (!emitToCanvas(evt)) doc.dispatchEvent(evt);
    };
    const mods = { shiftKey: false, ctrlKey: false, altKey: false, metaKey: false };
    const noop = () => {};
    const updateMods = (code, pressed) => {
      if (code === "ShiftLeft" || code === "ShiftRight") mods.shiftKey = pressed;
      if (code === "ControlLeft" || code === "ControlRight") mods.ctrlKey = pressed;
      if (code === "AltLeft" || code === "AltRight") mods.altKey = pressed;
      if (code === "MetaLeft" || code === "MetaRight") mods.metaKey = pressed;
    };
    if (wx.onKeyDown) {
      wx.onKeyDown((e) => {
        updateMods(e.code, true);
        deliver({
          type: "keydown", key: e.key, code: e.code, repeat: false,
          ...mods, preventDefault: noop, stopPropagation: noop,
        });
      });
      wx.onKeyUp((e) => {
        updateMods(e.code, false);
        deliver({
          type: "keyup", key: e.key, code: e.code, repeat: false,
          ...mods, preventDefault: noop, stopPropagation: noop,
        });
      });
    } else {
      console.warn("[input] 此环境没有 wx.onKeyDown，键盘不可用（手机端正常，PC/开发者工具应有）");
    }
    // PC 端鼠标（手机/模拟器的点击走 wx.onTouchStart，weapp-adapter 已桥接）
    const mouseEvent = (type) => (e) => {
      deliver({
        type, clientX: e.x, clientY: e.y, button: e.button || 0,
        ...mods, cancelable: false, preventDefault: noop, stopPropagation: noop,
      });
    };
    if (wx.onMouseDown) {
      wx.onMouseDown(mouseEvent("mousedown"));
      wx.onMouseUp(mouseEvent("mouseup"));
      wx.onMouseMove(mouseEvent("mousemove"));
    }
    if (wx.onWheel) {
      wx.onWheel((e) => {
        deliver({
          type: "wheel", deltaX: e.deltaX, deltaY: e.deltaY, deltaZ: 0, deltaMode: 0,
          clientX: e.x, clientY: e.y,
          ...mods, cancelable: false, preventDefault: noop, stopPropagation: noop,
        });
      });
    }
  }

  // 微信禁用 eval → Godot 的 JavaScript.eval 不可用，无法从 GDScript 调宿主下载。
  // 改由宿主在【游戏启动前】直接下载 overlay 分块到 wx 存储的 /userfs/packs/，
  // 随后 preloadUserFiles 会把它们恢复进引擎 FS，WxAssets._ready 即可同步挂载
  // （早于加载贴图的自动加载单例）→ 贴图首帧即真实，且已持久化（下次免下载）。
  downloadOverlayPacks() {
    const fsm = wx.getFileSystemManager();
    const dir = `${wx.env.USER_DATA_PATH}/userfs/packs`;
    try { fsm.mkdirSync(dir, true); } catch (e) {}
    let done = 0;
    const total = OVERLAY_PACKS.length;
    const tasks = OVERLAY_PACKS.map((file) => new Promise((resolve) => {
      const dest = `${dir}/${file}`;
      try { fsm.accessSync(dest); done++; resolve(); return; } catch (e) {} // 已在 wx 存储 → 免下载
      wx.downloadFile({
        url: PACKS_BASE + file,
        success: (res) => {
          if (res.statusCode === 200) {
            try { fsm.copyFileSync(res.tempFilePath, dest); }
            catch (e) { console.error("[overlay] 存储失败", file, e.message); }
          } else { console.error("[overlay] HTTP", res.statusCode, file); }
          done++;
          resolve();
        },
        fail: (err) => { console.error("[overlay] 下载失败", file, err && err.errMsg); resolve(); },
      });
    }));
    console.log(`[overlay] 启动前下载 ${total} 个分块...`);
    return Promise.all(tasks).then(() => console.log(`[overlay] 就绪 ${done}/${total}（已存 wx 存储，下次免下载）`));
  }

  // base pck（20MB+）不能进代码包——微信主包/分包各限 4MB。改为托管在资源服务器上，
  // 启动时下载到 USER_DATA_PATH 再作为 mainPack 传给引擎（C1 补丁读文件走 wx 文件系统，
  // 对 USER_DATA_PATH 的绝对路径同样有效）。文件名带内容 hash，存在即免下载。
  // 返回引擎可用的绝对路径。
  downloadBasePck() {
    const fsm = wx.getFileSystemManager();
    const dir = `${wx.env.USER_DATA_PATH}/gamedata`;
    try { fsm.mkdirSync(dir, true); } catch (e) {}
    const dest = `${dir}/${BASE_PCK_NAME}`;

    // 清掉旧版本的 base 包，避免占满本地存储配额
    try {
      for (const f of fsm.readdirSync(dir)) {
        if (f.startsWith("base_") && f.endsWith(".pck") && f !== BASE_PCK_NAME) {
          try { fsm.unlinkSync(`${dir}/${f}`); console.log("[base] 清理旧包", f); } catch (e) {}
        }
      }
    } catch (e) {}

    try {
      const st = fsm.statSync(dest);
      if (st.size === BASE_PCK_SIZE) {
        console.log(`[base] 已缓存 ${BASE_PCK_NAME}（${(st.size / 1048576).toFixed(1)}MB），免下载`);
        return Promise.resolve(dest);
      }
      console.warn("[base] 缓存大小不符，重新下载");
    } catch (e) {} // 不存在 → 下载

    console.log(`[base] 下载主资源包 ${(BASE_PCK_SIZE / 1048576).toFixed(1)}MB ...`);
    return new Promise((resolve, reject) => {
      const task = wx.downloadFile({
        url: BASE_PCK_URL,
        timeout: 180000,
        success: (res) => {
          if (res.statusCode !== 200) {
            reject(new Error(`主资源包下载失败 HTTP ${res.statusCode}`));
            return;
          }
          try {
            fsm.copyFileSync(res.tempFilePath, dest);
            console.log("[base] 就绪", BASE_PCK_NAME);
            resolve(dest);
          } catch (e) {
            reject(new Error("主资源包落盘失败: " + (e && e.message)));
          }
        },
        fail: (err) => reject(new Error("主资源包下载失败: " + (err && err.errMsg))),
      });
      if (task && task.onProgressUpdate) {
        let last = -1;
        task.onProgressUpdate((p) => {
          // 每 10% 打一次，避免刷屏
          const step = Math.floor(p.progress / 10);
          if (step !== last) {
            last = step;
            console.log(`[base] 下载 ${p.progress}%`);
          }
        });
      }
    });
  }

  // 小游戏适配(D3): 启动前把 USER_DATA_PATH 里的存档递归收集并注册为引擎预载文件，
  // Engine.start 会在 callMain 前逐个 copyToFS，保证游戏首帧就能读到 user:// 数据
  preloadUserFiles(engine) {
    const fs = wx.getFileSystemManager();
    const base = wx.env.USER_DATA_PATH;
    const collect = (dir) =>
      new Promise((resolve) => {
        fs.readdir({
          dirPath: `${base}${dir}`,
          success: (res) => {
            const entries = res.files.filter((v) => v !== "." && v !== "..");
            Promise.all(
              entries.map(
                (name) =>
                  new Promise((resolveEntry) => {
                    const rel = `${dir}/${name}`;
                    fs.stat({
                      path: `${base}${rel}`,
                      success: (st) => {
                        if (st.stats.isDirectory()) {
                          collect(rel).then(resolveEntry);
                        } else {
                          resolveEntry([rel]);
                        }
                      },
                      fail: () => resolveEntry([]),
                    });
                  })
              )
            ).then((lists) => resolve([].concat(...lists)));
          },
          fail: () => resolve([]), // 目录不存在 = 首次运行无存档
        });
      });
    const paths = (engine.config && engine.config.persistentPaths) || ["/userfs"];
    return Promise.all(paths.map((p) => collect(p))).then((lists) => {
      const files = [].concat(...lists);
      if (files.length) {
        console.log(`[loader] 回灌存档 ${files.length} 个文件`);
      }
      return Promise.all(files.map((rel) => engine.preloadFile(`${base}${rel}`, rel)));
    });
  }

  loadSubpackages() {
    return new Promise((resolve, reject) => {
      wx.loadSubpackage({
        fail: (reason) => {
          reject(reason);
        },
        name: "gdexport",
        success: () => {
          this.updateLoading();
          resolve();
        },
      });
    });
  }

  drawLoadingBar() {
    const barWidth = window.innerWidth - 48;
    const barX = (window.innerWidth - barWidth) / 2;
    const barY = window.innerHeight - this.config.loadingBarHeight / 2 - 100;
    const ctx = this.loadingContext;

    // Draw background of loading bar
    ctx.fillStyle = this.config.loadingBarBackgroundColor;
    ctx.fillRect(barX, barY, barWidth, this.config.loadingBarHeight);

    // Draw the progress
    ctx.fillStyle = this.config.loadingBarColor;
    ctx.fillRect(
      barX,
      barY,
      (this.progress / 3) * barWidth,
      this.config.loadingBarHeight
    );

    // Add text percentage
    ctx.font = "16px";
    ctx.fillStyle = "#fff";
    ctx.textAlign = "center";
    ctx.fillText(
      `${((this.progress / 3) * 100).toFixed(1)}%`,
      window.innerWidth / 2,
      barY + this.config.loadingBarHeight - 6
    );
  }

  drawBackground() {
    const ctx = this.loadingContext;
    const canvasWidth = this.loadingCanvas.width;
    const canvasHeight = this.loadingCanvas.height;
    const imageAspectRatio =
      this.backgroundImage.naturalWidth / this.backgroundImage.naturalWidth;
    const canvasAspectRatio = canvasWidth / canvasHeight;
    let drawWidth, drawHeight, offsetX, offsetY;
    if (canvasAspectRatio > imageAspectRatio) {
      // Canvas is wider than the image, fit by height.
      drawHeight = canvasHeight;
      drawWidth = drawHeight * imageAspectRatio;
      offsetX = (canvasWidth - drawWidth) / 2;
      offsetY = 0;
    } else {
      // Canvas is taller than the image, fit by width.
      drawWidth = canvasWidth;
      drawHeight = drawWidth / imageAspectRatio;
      offsetX = 0;
      offsetY = (canvasHeight - drawHeight) / 2;
    }
    ctx.drawImage(
      this.backgroundImage,
      offsetX,
      offsetY,
      drawWidth,
      drawHeight
    );
  }

  drawIcon() {
    const ctx = this.loadingContext;
    const centerX = window.innerWidth / 2 - this.config.iconWidth / 2;
    const centerY = window.innerHeight / 3 - this.config.iconHeight / 3;
    ctx.drawImage(
      this.logoImage,
      centerX,
      centerY,
      this.config.iconWidth,
      this.config.iconHeight
    );
  }

  updateLoading() {
    this.progress += 1;
    if (this.progress > 3) this.progress = 3;
    this.drawBackground();
    this.drawIcon();
    this.drawLoadingBar();
    this.drawScreen();
  }

  initWebgl() {
    const gl = this.screenContext;
    gl.bindTexture(gl.TEXTURE_2D, texture);
    // 创建着色器
    const vertexShaderSource = `
      attribute vec4 a_position;
      attribute vec2 a_texCoord;
      varying vec2 v_texCoord;
      void main() {
        gl_Position = a_position;
        v_texCoord = a_texCoord;
      }
    `;

    const fragmentShaderSource = `
      precision mediump float;
      varying vec2 v_texCoord;
      uniform sampler2D u_texture;
      void main() {
        gl_FragColor = texture2D(u_texture, v_texCoord);
      }
    `;

    function createShader(type, source) {
      const shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error("Error compiling shader:", gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
      }
      return shader;
    }
    const vertexShader = createShader(gl.VERTEX_SHADER, vertexShaderSource);
    const fragmentShader = createShader(
      gl.FRAGMENT_SHADER,
      fragmentShaderSource
    );
    const shaderProgram = gl.createProgram();
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);
    if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
      console.error(
        "Program linking error:",
        gl.getProgramInfoLog(shaderProgram)
      );
    }
    gl.useProgram(shaderProgram);
    // Step 4: 创建顶点缓冲区并绑定
    const vertices = new Float32Array([
      -1.0, 1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0,
      0.0, 0.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0,
    ]);
    const vertexBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
    const positionLocation = gl.getAttribLocation(shaderProgram, "a_position");
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 16, 0);
    gl.enableVertexAttribArray(positionLocation);

    const texCoordLocation = gl.getAttribLocation(shaderProgram, "a_texCoord");
    gl.vertexAttribPointer(texCoordLocation, 2, gl.FLOAT, false, 16, 8);
    gl.enableVertexAttribArray(texCoordLocation);

    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.viewport(0, 0, this.loadingCanvas.width, this.loadingCanvas.height);
    const clean = () => {
      const maxAttributes = gl.getParameter(gl.MAX_VERTEX_ATTRIBS);
      for (let i = 0; i < maxAttributes; i++) {
        gl.disableVertexAttribArray(i);
      }
      if (texture) gl.deleteTexture(texture);
      gl.bindTexture(gl.TEXTURE_2D, null);
      if (vertexShader) gl.deleteShader(vertexShader);
      if (fragmentShader) gl.deleteShader(fragmentShader);
      if (shaderProgram) gl.deleteProgram(shaderProgram);
      gl.bindBuffer(gl.ARRAY_BUFFER, null);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
      gl.bindTexture(gl.TEXTURE_2D, null);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.bindRenderbuffer(gl.RENDERBUFFER, null);
      gl.clear(
        gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT
      );
      gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
      gl.disable(gl.DEPTH_TEST);
      gl.disable(gl.BLEND);
      gl.disable(gl.CULL_FACE);
    };
    return [texture, clean];
  }

  drawScreen() {
    const gl = this.screenContext;
    gl.bindTexture(gl.TEXTURE_2D, this.screenTexture);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      this.loadingCanvas
    );
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  clean() {
    this.logoImage = null;
    this.loadingContext.clearRect(
      0,
      0,
      this.loadingCanvas.width,
      this.loadingCanvas.height
    );
    const gl = this.screenContext;
  }

  load() {
    const loadLogo = () => {
      return new Promise((resolve, reject) => {
        this.logoImage.onload = () => {
          resolve();
        };
        this.logoImage.onerror = (error) => {
          reject(error);
        };
      });
    };
    const loadBackground = () => {
      return new Promise((resolve, reject) => {
        this.backgroundImage.onload = () => {
          resolve();
        };
        this.backgroundImage.error = (error) => {
          reject(error);
        };
      });
    };
    Promise.all([loadBackground(), loadLogo()])
      .then(() => {
        this.progress += 1;
        return this.loadSubpackages();
      })
      .then(() => {
        this.updateLoading();
        // 引擎胶水 index.js 现在放在【主包】的 glue/ 下（分包 4MB 上限装不下它和 wasm），
        // gdexport 分包里只剩 index.wasm.br —— WXWebAssembly.instantiate 只接受代码包内路径，
        // 它没法像 pck 那样运行时下载，所以仍需 loadSubpackage 后才能被引擎读到。
        // index.js 执行时会把 Engine 挂到 window（weapp-adapter 提供）上
        // 小游戏适配: wx 主 canvas 没有 focus()，引擎在 init_config 和鼠标/触摸按下时都会调用
        if (typeof canvas.focus !== "function") {
          canvas.focus = function () {};
        }
        // 小游戏适配(D1): 真机没有 window.AudioContext（模拟器是 Chrome 泄漏的真全局），
        // 引擎的 _godot_audio_is_available 探测不到会只注册 Dummy 驱动并因 --audio-driver 不匹配而 abort。
        // 用 wx.createWebAudioContext 垫上；它自带 createScriptProcessor，audioWorklet 为空，
        // 引擎会自动选中 ScriptProcessor 后端
        if (typeof window.AudioContext === "undefined" && wx.createWebAudioContext) {
          // wx 音频节点的 connect() 不返回目标节点，标准 WebAudio 返回目标以支持
          // .connect(a).connect(b) 链式调用（引擎总线搭建大量使用），包一层修复
          const fixNode = (node) => {
            if (node && typeof node.connect === "function" && !node.__connectFixed) {
              const origConnect = node.connect.bind(node);
              node.connect = function (dest, ...rest) {
                origConnect(dest, ...rest);
                return fixNode(dest);
              };
              node.__connectFixed = true;
            }
            // wx 节点没有 EventTarget 接口，只有 on<type> 属性（如 onended），
            // 引擎用 addEventListener("ended") 监听采样播放结束，映射过去
            if (node && typeof node.addEventListener !== "function") {
              const listeners = {};
              node.addEventListener = function (type, cb) {
                (listeners[type] = listeners[type] || []).push(cb);
                node["on" + type] = function (ev) {
                  (listeners[type] || []).slice().forEach(function (f) { f(ev); });
                };
              };
              node.removeEventListener = function (type, cb) {
                const arr = listeners[type] || [];
                const i = arr.indexOf(cb);
                if (i >= 0) arr.splice(i, 1);
              };
            }
            return node;
          };
          window.AudioContext = function AudioContext() {
            const ctx = wx.createWebAudioContext();
            const names = new Set(Object.keys(ctx));
            let proto = Object.getPrototypeOf(ctx);
            while (proto && proto !== Object.prototype) {
              Object.getOwnPropertyNames(proto).forEach((n) => names.add(n));
              proto = Object.getPrototypeOf(proto);
            }
            names.forEach((name) => {
              if (name.startsWith("create") && typeof ctx[name] === "function") {
                const orig = ctx[name].bind(ctx);
                ctx[name] = (...args) => fixNode(orig(...args));
              }
            });
            return ctx;
          };
        }
        this.setupPcInput();
        require("../glue/index.js");
        console.log("[build] engine glue loaded, patched =", typeof window.Engine === "function" && String(window.Engine.load).includes("wasm.br"));
        const Engine = window.Engine;
        const engine = new Engine();
        GameGlobal.engine = engine;
        godotSdk.set_engine(engine);
        // 先下载 overlay 分块到 wx 存储，再由 preloadUserFiles 一并恢复进引擎 FS，
        // 保证 WxAssets 能在贴图单例之前同步挂载。存档回灌必须在引擎启动前完成：
        // preloadFile 会在 callMain 之前把文件写进引擎 FS（启动后再灌就晚了）。
        // 先把 base pck 和 overlay 分块下到 wx 存储，再由 preloadUserFiles 把 overlay 与存档
        // 恢复进引擎 FS，保证 WxAssets 能在贴图单例之前同步挂载。存档回灌必须在引擎启动前完成：
        // preloadFile 会在 callMain 之前把文件写进引擎 FS（启动后再灌就晚了）。
        // base pck 不走 preloadFile —— 它由引擎自己按 mainPack 路径读，无需进 MEMFS（省 20MB 内存）。
        let mainPackPath = "";
        return this.downloadBasePck()
          .then((p) => { mainPackPath = p; })
          .then(() => this.downloadOverlayPacks())
          .then(() => this.preloadUserFiles(engine))
          .then(() => engine.startGame({
          canvas: canvas,
          executable: "gdexport/index",
          // 运行时下载到 USER_DATA_PATH 的绝对路径。".pck 不在文件类型白名单" 只约束
          // 代码包内的文件，本地存储里的不受限，所以不用再改名 .zip
          mainPack: mainPackPath,
          // Godot 3 无 --audio-driver 参数：JS 音频驱动按 has_worklet/has_script_processor
          // 自动选择，wx 音频上下文无 audioWorklet，会自动落到 ScriptProcessor
        }));
      })
      .then(() => {
        if (INPUT_PROFILE) startInputProfile();
        // 存档持久化(C5/D2/D3)：主通道是事件驱动——引擎每次写完 user:// 会经
        // _godot_js_os_fs_sync 钩子立即落盘；这里的 30 秒轮询只是兜底
        setInterval(() => {
          godotSdk.syncfs(() => {
          }, (error) => {
            console.error("[loader] 存档同步失败:", error)
          });
        }, 30000)
        this.clean();
        this.cleanWebgl();
      })
      .catch((error) => {
        console.error("[loader] 启动失败:", error);
      });
  }
}

export default Loader;