import { GodotSDK } from "./sdk"

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
  // 引擎胶水把 keydown/keyup/mouse*/wheel 注册在 canvas 上，weapp-adapter 已把
  // canvas.addEventListener 转到 document，所以往 document.dispatchEvent 派发即可送达。
  setupPcInput() {
    const doc = window.document;
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
        doc.dispatchEvent({
          type: "keydown", key: e.key, code: e.code, repeat: false,
          ...mods, preventDefault: noop, stopPropagation: noop,
        });
      });
      wx.onKeyUp((e) => {
        updateMods(e.code, false);
        doc.dispatchEvent({
          type: "keyup", key: e.key, code: e.code, repeat: false,
          ...mods, preventDefault: noop, stopPropagation: noop,
        });
      });
    }
    // PC 端鼠标（手机/模拟器的点击走 wx.onTouchStart，weapp-adapter 已桥接）
    const mouseEvent = (type) => (e) => {
      doc.dispatchEvent({
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
        doc.dispatchEvent({
          type: "wheel", deltaX: e.deltaX, deltaY: e.deltaY, deltaZ: 0, deltaMode: 0,
          clientX: e.x, clientY: e.y,
          ...mods, cancelable: false, preventDefault: noop, stopPropagation: noop,
        });
      });
    }
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
        // 引擎胶水在 gdexport 分包内，必须等 loadSubpackage 完成后才能 require；
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
        require("../gdexport/index.js");
        console.log("[build] engine glue loaded, patched =", typeof window.Engine === "function" && String(window.Engine.load).includes("wasm.br"));
        const Engine = window.Engine;
        const engine = new Engine();
        GameGlobal.engine = engine;
        godotSdk.set_engine(engine);
        // 存档回灌必须在引擎启动前完成：preloadFile 会在 callMain 之前把文件写进引擎 FS，
        // 保证游戏脚本 _ready 里读 user:// 时数据已就位（启动后再灌就晚了）
        return this.preloadUserFiles(engine).then(() => engine.startGame({
          canvas: canvas,
          executable: "gdexport/index",
          // .pck 不在小游戏代码包文件类型白名单内(readFile 会 permission denied)，
          // 改名为 .zip 绕过；Godot 按文件头魔数(GDPC)识别 pack 格式，不看扩展名
          mainPack: "gdexport/index.zip",
          // Godot 3 无 --audio-driver 参数：JS 音频驱动按 has_worklet/has_script_processor
          // 自动选择，wx 音频上下文无 audioWorklet，会自动落到 ScriptProcessor
        }));
      })
      .then(() => {
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