#!/usr/bin/env node
/**
 * 临时诊断脚本：给 gdexport/index.js 的 GL 上下文创建链路埋日志。
 * 幂等；定位完问题后重新导出+patch 即可清除。
 *   node tools/debug-gl.js
 */
const fs = require("fs");
const path = require("path");
const INDEX_JS = path.join(__dirname, "..", "gdexport", "index.js");

const SPOTS = [
  {
    name: "has_webgl 探测",
    find: 'function _godot_js_display_has_webgl(p_version){if(p_version!==1&&p_version!==2){return false}try{return!!document.createElement("canvas").getContext(p_version===2?"webgl2":"webgl")}catch(e){}return false}',
    replace:
      'function _godot_js_display_has_webgl(p_version){if(p_version!==1&&p_version!==2){return false}try{const r=!!document.createElement("canvas").getContext(p_version===2?"webgl2":"webgl");console.log("[dbg-gl] has_webgl v"+p_version+" =",r);return r}catch(e){console.log("[dbg-gl] has_webgl v"+p_version+" throw:",e&&e.message)}return false}',
  },
  {
    name: "do_create_context 入口/结果",
    find: "var canvas=findCanvasEventTarget(target);if(!canvas){return 0}",
    replace:
      'var canvas=findCanvasEventTarget(target);console.log("[dbg-gl] create_context target=",target,"canvas found=",!!canvas);if(!canvas){return 0}',
  },
  {
    name: "GL.createContext 结果",
    find: "var ctx=webGLContextAttributes.majorVersion>1?canvas.getContext(\"webgl2\",webGLContextAttributes):canvas.getContext(\"webgl\",webGLContextAttributes);if(!ctx)return 0;",
    replace:
      'var ctx=webGLContextAttributes.majorVersion>1?canvas.getContext("webgl2",webGLContextAttributes):canvas.getContext("webgl",webGLContextAttributes);console.log("[dbg-gl] GL.createContext major=",webGLContextAttributes.majorVersion,"ctx=",!!ctx);if(!ctx)return 0;',
  },
  {
    name: "makeContextCurrent",
    find: "makeContextCurrent:function(contextHandle){GL.currentContext=GL.contexts[contextHandle];Module.ctx=GLctx=GL.currentContext&&GL.currentContext.GLctx;return!(contextHandle&&!GLctx)}",
    replace:
      'makeContextCurrent:function(contextHandle){GL.currentContext=GL.contexts[contextHandle];Module.ctx=GLctx=GL.currentContext&&GL.currentContext.GLctx;console.log("[dbg-gl] makeContextCurrent handle=",contextHandle,"GLctx=",!!GLctx);return!(contextHandle&&!GLctx)}',
  },
];

let src = fs.readFileSync(INDEX_JS, "utf8");
let failed = 0;
for (const p of SPOTS) {
  if (src.includes(p.replace)) {
    console.log(`✓ ${p.name} —— 已埋过`);
    continue;
  }
  const before = src;
  src = src.replace(p.find, p.replace);
  console.log(`${src === before ? "✗" : "✓"} ${p.name}${src === before ? " —— 锚点没命中!" : ""}`);
  if (src === before) failed++;
}
fs.writeFileSync(INDEX_JS, src);
if (failed) process.exitCode = 1;
