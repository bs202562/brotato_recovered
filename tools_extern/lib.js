"use strict";
// 通用工具：静音 mp3 合成、hash、目录遍历
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

// 合成一个合法的 MPEG-1 Layer III 静音 mp3（44100Hz 单声道 32kbps），供占位用。
// minimp3 / Godot AudioStreamMP3 能解码为静音。帧长 = 144*32000/44100 ≈ 104 字节。
// 帧头 FF FB 50 C0：FF FB=MPEG1 L3 无CRC；0x50=bitrate idx5(32k)+samplerate idx0(44100)；0xC0=单声道。
function makeSilentMp3(frames = 12) {
  const FRAME = 104;
  const buf = Buffer.alloc(FRAME * frames, 0);
  for (let i = 0; i < frames; i++) {
    const o = i * FRAME;
    buf[o] = 0xff;
    buf[o + 1] = 0xfb;
    buf[o + 2] = 0x50;
    buf[o + 3] = 0xc0;
  }
  return buf;
}

function sha256(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

// 递归收集匹配扩展名的文件（返回绝对路径）
function walk(dir, exts, out = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (e) {
    return out;
  }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      walk(full, exts, out);
    } else {
      const ext = path.extname(e.name).toLowerCase();
      if (exts.includes(ext)) out.push(full);
    }
  }
  return out;
}

// gameproj 绝对路径 -> res:// 路径
function toResPath(projRoot, abs) {
  const rel = path.relative(projRoot, abs).split(path.sep).join("/");
  return "res://" + rel;
}

function ensureDir(d) {
  fs.mkdirSync(d, { recursive: true });
}

// 生成一个合法的 1x1 全透明 RGBA PNG（CRC 正确，Godot 严格校验 PNG CRC）
function makePng1px() {
  const zlib = require("zlib");
  function chunk(type, data) {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length, 0);
    const typeBuf = Buffer.from(type, "ascii");
    const body = Buffer.concat([typeBuf, data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(body) >>> 0, 0); // Node 22.7+ 有 zlib.crc32
    return Buffer.concat([len, body, crc]);
  }
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(1, 0); // width
  ihdr.writeUInt32BE(1, 4); // height
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type RGBA
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0; // compression/filter/interlace
  const raw = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00]); // filter=0 + RGBA(0,0,0,0)
  const idat = zlib.deflateSync(raw);
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0))]);
}
const PNG_1PX = makePng1px();

// 极短静音 WAV（PCM 16bit 单声道 8000Hz，几个样本），作音效占位源
function makeSilentWav(samples = 8) {
  const dataLen = samples * 2;
  const buf = Buffer.alloc(44 + dataLen, 0);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + dataLen, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16); // fmt chunk size
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(1, 22); // mono
  buf.writeUInt32LE(8000, 24); // sample rate
  buf.writeUInt32LE(8000 * 2, 28); // byte rate
  buf.writeUInt16LE(2, 32); // block align
  buf.writeUInt16LE(16, 34); // bits
  buf.write("data", 36);
  buf.writeUInt32LE(dataLen, 40);
  return buf;
}

// 用 Node 直接写 Godot 3.x GDPC pack（format 1）。entries: [{resPath, buf}]
// 路径按 4 字节对齐补零；offset 为文件绝对偏移；md5 逐文件计算（Godot 校验）。
function writeGdpc(entries, outPath, ver = [3, 6, 2]) {
  const crypto = require("crypto");
  const fs = require("fs");
  // 头部固定：magic(4)+fmt(4)+3*ver(12)+64 保留 = 84；然后 count(4)
  const HEADER = 4 + 4 + 12 + 64 + 4;
  // 预算表大小
  let tableSize = 0;
  const recs = entries.map((e) => {
    const pathBuf = Buffer.from(e.resPath, "utf8");
    const pad = (4 - (pathBuf.length % 4)) % 4;
    const plen = pathBuf.length + pad;
    tableSize += 4 + plen + 8 + 8 + 16; // plen + path + offset + size + md5
    return { pathBuf, pad, plen, buf: e.buf };
  });
  let dataOffset = HEADER + tableSize;
  const head = Buffer.alloc(HEADER);
  let p = 0;
  head.writeUInt32LE(0x43504447, p); p += 4; // GDPC
  head.writeInt32LE(1, p); p += 4; // format 1
  head.writeInt32LE(ver[0], p); p += 4;
  head.writeInt32LE(ver[1], p); p += 4;
  head.writeInt32LE(ver[2], p); p += 4;
  p += 64; // reserved zeros
  head.writeInt32LE(recs.length, p); p += 4;

  const table = Buffer.alloc(tableSize);
  let tp = 0;
  let cur = dataOffset;
  for (const r of recs) {
    table.writeInt32LE(r.plen, tp); tp += 4;
    r.pathBuf.copy(table, tp); tp += r.pathBuf.length;
    tp += r.pad; // zeros
    table.writeBigUInt64LE(BigInt(cur), tp); tp += 8;
    table.writeBigUInt64LE(BigInt(r.buf.length), tp); tp += 8;
    crypto.createHash("md5").update(r.buf).digest().copy(table, tp); tp += 16;
    cur += r.buf.length;
  }
  const fd = fs.openSync(outPath, "w");
  fs.writeSync(fd, head);
  fs.writeSync(fd, table);
  for (const r of recs) fs.writeSync(fd, r.buf);
  fs.closeSync(fd);
  return cur; // 总字节数
}

module.exports = {
  makeSilentMp3, sha256, walk, toResPath, ensureDir,
  PNG_1PX, makeSilentWav, writeGdpc,
};
