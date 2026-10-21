// 擬音の実験室: 書き出し(リール向け)。APNG・PNG 連番の zip・WebM の符号化。依存なし。
// APNG: https://www.w3.org/TR/png-3/#apng (acTL / fcTL / fdAT)。zip は圧縮なし(store)の最小形。
(function () {
  "use strict";
  const CRC = (function () { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  function crc32(u8, from, to, seed) {
    let c = (seed === undefined ? 0xffffffff : seed) >>> 0;
    for (let i = from; i < to; i++) c = CRC[(c ^ u8[i]) & 0xff] ^ (c >>> 8);
    return c >>> 0;
  }
  const be32 = (v) => [(v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255];
  const be16 = (v) => [(v >>> 8) & 255, v & 255];
  const le32 = (v) => [v & 255, (v >>> 8) & 255, (v >>> 16) & 255, (v >>> 24) & 255];
  const le16 = (v) => [v & 255, (v >>> 8) & 255];
  const ascii = (s) => Array.from(s, (ch) => ch.charCodeAt(0));

  // PNG のチャンクを読む: [{type, data(Uint8Array)}]
  function pngChunks(u8) {
    const out = []; let p = 8;
    while (p + 8 <= u8.length) {
      const len = (u8[p] << 24 | u8[p + 1] << 16 | u8[p + 2] << 8 | u8[p + 3]) >>> 0;
      const type = String.fromCharCode(u8[p + 4], u8[p + 5], u8[p + 6], u8[p + 7]);
      out.push({ type, data: u8.subarray(p + 8, p + 8 + len) });
      p += 12 + len;
    }
    return out;
  }
  function chunk(type, data) {
    const td = new Uint8Array(4 + data.length); td.set(ascii(type), 0); td.set(data, 4);
    const crc = crc32(td, 0, td.length) ^ 0xffffffff;
    return [new Uint8Array(be32(data.length)), td, new Uint8Array(be32(crc >>> 0))];
  }
  // frames: 1 枚ごとの PNG(Uint8Array)。全部同じ大きさ。fps で表示。
  function apng(frames, fps) {
    const parts = [new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10])];
    const first = pngChunks(frames[0]);
    const ihdr = first.find((c) => c.type === "IHDR");
    const w = (ihdr.data[0] << 24 | ihdr.data[1] << 16 | ihdr.data[2] << 8 | ihdr.data[3]) >>> 0;
    const h = (ihdr.data[4] << 24 | ihdr.data[5] << 16 | ihdr.data[6] << 8 | ihdr.data[7]) >>> 0;
    parts.push(...chunk("IHDR", ihdr.data));
    parts.push(...chunk("acTL", new Uint8Array([...be32(frames.length), ...be32(0)])));
    let seq = 0;
    frames.forEach((png, fi) => {
      const chunks = fi === 0 ? first : pngChunks(png);
      const fctl = new Uint8Array([...be32(seq++), ...be32(w), ...be32(h), ...be32(0), ...be32(0), ...be16(1), ...be16(fps), 0, 0]);
      parts.push(...chunk("fcTL", fctl));
      for (const c of chunks) {
        if (c.type !== "IDAT") continue;
        if (fi === 0) parts.push(...chunk("IDAT", c.data));
        else { const d = new Uint8Array(4 + c.data.length); d.set(be32(seq++), 0); d.set(c.data, 4); parts.push(...chunk("fdAT", d)); }
      }
    });
    parts.push(...chunk("IEND", new Uint8Array(0)));
    return new Blob(parts, { type: "image/png" });
  }
  // entries: [{name, data(Uint8Array)}] → zip(無圧縮)
  function zip(entries) {
    const local = [], central = []; let off = 0;
    for (const e of entries) {
      const name = new TextEncoder().encode(e.name);
      const crc = (crc32(e.data, 0, e.data.length) ^ 0xffffffff) >>> 0;
      const head = new Uint8Array([...le32(0x04034b50), ...le16(20), ...le16(0x800), ...le16(0), ...le16(0), ...le16(0), ...le32(crc), ...le32(e.data.length), ...le32(e.data.length), ...le16(name.length), ...le16(0)]);
      local.push(head, name, e.data);
      central.push(new Uint8Array([...le32(0x02014b50), ...le16(20), ...le16(20), ...le16(0x800), ...le16(0), ...le16(0), ...le16(0), ...le32(crc), ...le32(e.data.length), ...le32(e.data.length), ...le16(name.length), ...le16(0), ...le16(0), ...le16(0), ...le16(0), ...le32(0), ...le32(off)]), name);
      off += head.length + name.length + e.data.length;
    }
    const cdLen = central.reduce((s, u) => s + u.length, 0);
    const end = new Uint8Array([...le32(0x06054b50), ...le16(0), ...le16(0), ...le16(entries.length), ...le16(entries.length), ...le32(cdLen), ...le32(off), ...le16(0)]);
    return new Blob([...local, ...central, end], { type: "application/zip" });
  }
  function toPNG(canvas) {
    return new Promise((res) => canvas.toBlob((b) => b.arrayBuffer().then((ab) => res(new Uint8Array(ab))), "image/png"));
  }
  // WebM: canvas を実時間で描きながら MediaRecorder で録る(透過は残らない。背景色を付けて使う)
  function webm(canvas, drawAt, dur, fps, onProgress) {
    return new Promise((res, rej) => {
      if (!window.MediaRecorder || !canvas.captureStream) return rej(new Error("この端末では WebM を録れない"));
      const stream = canvas.captureStream(fps);
      const mime = ["video/webm;codecs=vp9", "video/webm;codecs=vp8", "video/webm"].find((m) => MediaRecorder.isTypeSupported(m)) || "";
      const rec = new MediaRecorder(stream, mime ? { mimeType: mime, videoBitsPerSecond: 12e6 } : undefined);
      const chunks = [];
      rec.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      rec.onstop = () => res(new Blob(chunks, { type: "video/webm" }));
      rec.onerror = (e) => rej(e.error || new Error("録画に失敗"));
      const t0 = performance.now();
      drawAt(0); rec.start(100);
      (function tick() {
        const t = (performance.now() - t0) / 1000;
        drawAt(Math.min(t, dur)); if (onProgress) onProgress(Math.min(t / dur, 1));
        if (t < dur) requestAnimationFrame(tick); else setTimeout(() => rec.stop(), 150);
      })();
    });
  }
  function download(blob, name) {
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = name; document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 2000);
  }
  window.CueExport = { apng, zip, toPNG, webm, download, crc32 };
})();
