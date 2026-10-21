// 擬音の実験室: godot/scripts/cue_text.gd の draw_word と sfx.gd の life() を JS に写したもの。
// ゲームの描き方を変えたら、ここも同じに直す(ロジックの確認用なので、1対1で写す)。
// 「実験」の印がある所は、ゲームにはまだ無い試し(音節ごとに向きを変える alt)。濁点をくっつける split と
// flutter / stagger / tremble / loom、語末の仕上げ(ッ・ン)は 2026-10-19 にゲームへ入れた。
(function () {
  "use strict";

  const LIFE = 0.9;
  const FONT = '"Dela Gothic One", "M PLUS 1p", sans-serif';

  // ---- cue_text.gd の写し ----
  function clampf(v, a, b) { return Math.min(Math.max(v, a), b); }
  function lerpf(a, b, k) { return a + (b - a) * k; }
  function easeBack(k, over) {
    if (over === undefined) over = 1.7;
    k = clampf(k, 0, 1) - 1;
    return 1 + k * k * ((over + 1) * k + over);
  }
  function easeOut(k) {
    k = 1 - clampf(k, 0, 1);
    return 1 - k * k * k;
  }

  // sfx.gd の life(): 消えるまでの秒
  function life(style, size, nchars) {
    let l = LIFE * (1 + (size - 1) * 0.3);
    switch (style) {
      case "bounce": case "stretch": l += 0.06 * nchars; break;
      case "slam": case "shake": case "wave": case "drop": case "fly": l += 0.2; break;
      case "roll": l += 0.3 + 0.07 * nchars; break;
      case "flutter": l += 0.08 * nchars; break;
      case "stagger": l += 0.3 + 0.04 * nchars; break;
      case "tremble": l += 0.4; break;
      case "loom": l += 0.6; break;
    }
    // テロップの目安(1 文字 0.1〜0.15 秒)を下限に
    return Math.max(l, 0.1 * nchars + 0.35);
  }

  // 2026-10-19 までの split(コードポイント単位。濁点が別の字になる)。比べるために残す
  function splitPlain(s) { return Array.from(s); }

  // cue_text.gd の split: 濁点・半濁点(U+3099 / U+309A、半角 ﾞ ﾟ)を前の字にくっつける(ゲームもこれになった)
  function splitGrapheme(s) {
    const out = [];
    for (const c of s) {
      const cp = c.codePointAt(0);
      if ((cp === 0x3099 || cp === 0x309a || cp === 0xff9e || cp === 0xff9f) && out.length) out[out.length - 1] += c;
      else out.push(c);
    }
    return out;
  }

  // cue_text.gd の syllables: 音節(拍)の番号。小書き・ー・濁点・読点・ッ は前の字につく(flutter が使う)
  const SMALL_CP = [0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30E3, 0x30E5, 0x30E7, 0x30EE, 0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3083, 0x3085, 0x3087, 0x308E, 0x30FC, 0x301C, 0xFF5E, 0x2026, 0x3001, 0x3099, 0x309A, 0x30C3, 0x3063];
  function syllableIndex(chars) {
    const idx = [];
    let j = -1;
    chars.forEach((c, i) => {
      const small = SMALL_CP.includes(c.codePointAt(0));
      if (i === 0 || !small) j += 1;
      idx.push(Math.max(j, 0));
    });
    return idx;
  }

  // cue_text.gd の ending: 語末の標識 ["ッ"|"ン"|"", その字の番号]。! ? は読み飛ばす
  function ending(chars) {
    let i = chars.length - 1;
    while (i >= 0 && (chars[i] === "!" || chars[i] === "?" || chars[i] === "！" || chars[i] === "？")) i -= 1;
    if (i < 0) return ["", -1];
    const c = chars[i].codePointAt(0);
    if (c === 0x30C3 || c === 0x3063) return ["ッ", i];
    if (c === 0x30F3 || c === 0x3093) return ["ン", i];
    return ["", i];
  }
  // cue_text.gd の char_delay
  function charDelay(style) {
    switch (style) { case "bounce": return 0.06; case "stretch": case "roll": return 0.07; case "drop": return 0.05; case "stagger": return 0.04; }
    return 0;
  }
  // cue_text.gd の hash01
  function hash01(i, seed, salt) {
    const v = Math.sin(i * 12.9898 + seed * 7.13 + (salt || 0)) * 43758.5453;
    return v - Math.floor(v);
  }

  function measure(ctx, c, px) {
    ctx.font = px + "px " + FONT;
    return ctx.measureText(c).width;
  }

  // draw_word(ci, chars, style, t, life, px, color, seed, big, origin, dir)
  // opts(実験): {alt: 0..1 音節ごとに向きを変える強さ, altBy: "char"|"syllable"}
  function drawWord(ctx, chars, style, t, lifeS, px, color, seed, big, origin, dir, opts) {
    opts = opts || {};
    const n = chars.length;
    if (n === 0) return;
    let fade = (1 - clampf((t - (lifeS - 0.35)) / 0.35, 0, 1)) * color.a;
    let rise = -t * 14;
    let scale = 1;
    let tilt = 0;
    let shake = { x: 0, y: 0 };
    let spread = 0;
    const dl = Math.hypot(dir.x, dir.y);
    const d = dl > 0 ? { x: dir.x / dl, y: dir.y / dl } : { x: 1, y: 0 };
    let slide = { x: 0, y: 0 };
    switch (style) {
      case "pop":
        scale = lerpf(0.55, 1, easeBack(t / 0.16, 2.6));
        break;
      case "slam": {
        const k = clampf(t / 0.14, 0, 1);
        scale = lerpf(big ? 2.3 : 1.9, 1, k) + 0.12 * Math.sin(k * Math.PI) * (1 - k);
        if (t >= 0.14 && t < 0.24) scale = 1 - 0.1 * Math.sin((t - 0.14) / 0.1 * Math.PI);
        const sk = Math.max(0, 1 - t / 0.35) * (big ? 6 : 3.5);
        shake = { x: Math.sin(t * 90 + seed) * sk, y: Math.cos(t * 77 + seed) * sk };
        tilt = -0.08;
        rise = -Math.max(0, t - 0.3) * 8;
        break;
      }
      case "shake": rise = -t * 6; break;
      case "stretch": spread = Math.min(t, 0.6) * px * 0.35; rise = -t * 10; break;
      case "soft":
        fade *= clampf(t / 0.18, 0, 1);
        scale = lerpf(0.8, 1, clampf(t / 0.25, 0, 1));
        rise = -t * 22;
        break;
      case "snap": {
        const k2 = easeBack(t / 0.11, 2.2);
        shake.x = -(1 - k2) * px * 2;
        tilt = -0.18 * (1 - clampf(t / 0.11, 0, 1)) - 0.05;
        rise = -t * 8;
        break;
      }
      case "drop": rise = -Math.max(0, t - 0.4) * 10; break;
      case "roll": rise = -Math.max(0, t - 0.5) * 8; break;
      case "fly": {
        const kf = easeOut(t / 0.16);
        const m = -(1 - kf) * px * 4 + t * px * 0.8;
        slide = { x: d.x * m, y: d.y * m };
        tilt = clampf(d.x, -1, 1) * 0.12 * (1 - kf) + d.y * 0.1;
        rise = -t * 4;
        break;
      }
      case "wave": case "bounce": case "flutter": rise = -t * 10; break;
      case "stagger": {
        const sk2 = Math.max(0, 1 - t / 0.4) * (big ? 4 : 2.5);
        shake = { x: Math.sin(t * 80 + seed) * sk2, y: Math.cos(t * 70 + seed) * sk2 };
        rise = -Math.max(0, t - 0.4) * 8;
        break;
      }
      case "tremble":
        scale = lerpf(1, 1.08, clampf(t / 1, 0, 1));
        rise = -t * 5;
        break;
      case "loom": {
        const kl = clampf(t / 0.6, 0, 1);
        scale = lerpf(0.8, 1.05, kl);
        fade *= kl;
        spread = px * 0.1;
        rise = -t * px * 0.25;
        break;
      }
    }
    const endm = ending(chars);
    const dly = charDelay(style);
    const widths = chars.map((c) => measure(ctx, c, px));
    let total = widths.reduce((a, b) => a + b, 0) + spread * (n - 1);
    let x = -total / 2;
    const outline = Math.max(3, Math.floor(px * 0.22));
    const syl = syllableIndex(chars);
    const alt = opts.alt || 0;
    for (let i = 0; i < n; i++) {
      const w = widths[i];
      let off = { x: 0, y: 0 };
      let a = fade;
      let cs = scale;
      let sq = { x: 1, y: 1 };
      let rot = tilt;
      let ti = t;            // 実験用: この字の時間
      let skip = false;
      switch (style) {
        case "bounce": {
          ti = t - i * 0.06;
          if (ti < 0) { skip = true; break; }
          const hop = clampf(ti / 0.22, 0, 1);
          off.y = -Math.sin(hop * Math.PI) * px * 0.55;
          cs = 1 + 0.25 * (1 - clampf(ti / 0.1, 0, 1));
          break;
        }
        case "stretch": {
          ti = t - i * 0.07;
          if (ti < 0) { skip = true; break; }
          cs = lerpf(0.4, 1, easeBack(ti / 0.16, 2));
          a *= clampf(ti / 0.08, 0, 1);
          break;
        }
        case "drop": {
          ti = t - i * 0.05;
          if (ti < 0) { skip = true; break; }
          const FALL = 0.15;
          if (ti < FALL) {
            const kd = ti / FALL;
            off.y = -(1 - kd * kd) * px * 3.2;
            sq = { x: 0.85, y: 1.25 };
            a *= clampf(ti / 0.05, 0, 1);
          } else {
            const tl = ti - FALL;
            const squash = Math.max(0, 1 - tl / 0.16);
            sq = { x: 1 + 0.4 * squash, y: 1 - 0.35 * squash };
            off.y = -Math.sin(clampf((tl - 0.06) / 0.18, 0, 1) * Math.PI) * px * 0.25;
            off.y += px * 0.12 * squash;
          }
          break;
        }
        case "roll": {
          ti = t - i * 0.07;
          if (ti < 0) { skip = true; break; }
          const kr = easeOut(ti / 0.5);
          const dist = (1 - kr) * px * 3.5;
          off = { x: -d.x * dist, y: -d.y * dist };
          off.y -= Math.abs(Math.sin(dist / px * 1.6)) * px * 0.18;
          rot = (d.x >= 0 ? 1 : -1) * dist / (px * 0.5);
          a *= clampf(ti / 0.08, 0, 1);
          break;
        }
        case "fly": {
          const j = d.x >= 0 ? (n - 1 - i) : i;
          const kc = easeOut((t - j * 0.025) / 0.16);
          off = { x: -d.x * (1 - kc) * px * 0.9 * j, y: -d.y * (1 - kc) * px * 0.9 * j };
          break;
        }
        case "shake": {
          const amp = px * 0.08;
          off = { x: Math.sin(t * 61 + i * 2.3 + seed) * amp, y: Math.cos(t * 53 + i * 1.7 + seed) * amp };
          break;
        }
        case "wave":
          off.y = Math.sin(t * 9 - i * 0.9 + seed) * px * 0.18;
          rot = Math.sin(t * 7 - i * 0.9) * 0.12;
          break;
        case "flutter": {
          const sy = syl[i];
          ti = t - sy * 0.12;
          if (ti < 0) { skip = true; break; }
          const sg = sy % 2 === 0 ? -1 : 1;
          const kf2 = Math.sin(clampf(ti / 0.5, 0, 1) * Math.PI);
          off.x = sg * kf2 * px * 0.5;
          off.y = -Math.sin(ti * 8 - sy * 1.2) * px * 0.15;
          rot = sg * kf2 * 0.3;
          a *= clampf(ti / 0.08, 0, 1);
          break;
        }
        case "stagger": {
          ti = t - i * dly;
          if (ti < 0) { skip = true; break; }
          const kg = easeBack(ti / 0.2, 2.2);
          cs = lerpf(3, 1, kg);
          rot = (i % 2 === 0 ? -1 : 1) * lerpf(0.4, 0.12, kg);
          off.y = -(1 - kg) * px * 0.5;
          break;
        }
        case "tremble": {
          const amp2 = px * lerpf(0.04, 0.16, clampf(t / 1, 0, 1));
          off = { x: Math.sin(t * 61 + i * 2.3 + seed) * amp2, y: Math.cos(t * 53 + i * 1.7 + seed) * amp2 };
          break;
        }
        case "loom":
          off.x = (hash01(i, seed, 1) - 0.5) * px * 0.5;
          off.y = (hash01(i, seed, 2) - 0.5) * px * 1.8;
          rot = (hash01(i, seed, 3) - 0.5) * 0.5;
          break;
      }
      if (skip) { x += w + spread; continue; }
      // 語末の仕上げ: ッ で終わる語は最後の字が叩き込まれて止まる、ン で終わる語は出きったあとに揺れ戻す
      if (endm[0] === "ッ" && i === endm[1] && style !== "slam" && style !== "stagger") {
        const te = t - i * dly;
        if (te >= 0) cs *= lerpf(1.7, 1, easeOut(te / 0.09));
      } else if (endm[0] === "ン" && style !== "shake" && style !== "wave" && style !== "tremble") {
        const tn = t - ((n - 1) * dly + 0.15);
        if (tn > 0) rot += Math.sin(tn * 14) * 0.08 * Math.exp(-tn * 4);
      }
      // ---- 実験: 音節(または字)ごとに左右の向きを変える ----
      if (alt > 0) {
        const g = opts.altBy === "char" ? i : syl[i];
        const sign = g % 2 === 0 ? -1 : 1;
        if (sign > 0) { off.x = -off.x; rot = -rot; }      // 既にある横の動きと傾きは、奇数の組で反転
        const env = Math.sin(clampf(ti / 0.35, 0, 1) * Math.PI);   // 出てすぐ振れて、戻る
        off.x += sign * alt * px * 0.45 * env;
        rot += sign * alt * 0.22 * env;
      }
      const cx = x + w / 2 + off.x + shake.x + slide.x;
      const cy = rise + off.y + shake.y + slide.y;
      const fill = "rgba(" + color.r + "," + color.g + "," + color.b + "," + a + ")";
      ctx.font = px + "px " + FONT;
      ctx.textBaseline = "alphabetic";
      ctx.lineJoin = "round";
      if (style === "fly" && t < 0.2) {
        for (const g of [2, 1]) {
          const ga = a * 0.22 * (1 - t / 0.2) * (3 - g) / 2;
          ctx.save();
          ctx.translate(origin.x + cx - d.x * px * 0.7 * g, origin.y + cy - d.y * px * 0.7 * g);
          ctx.rotate(rot);
          ctx.scale(cs, cs);
          ctx.fillStyle = "rgba(" + color.r + "," + color.g + "," + color.b + "," + ga + ")";
          ctx.fillText(chars[i], -w / 2, px * 0.35);
          ctx.restore();
        }
      }
      ctx.save();
      ctx.translate(origin.x + cx, origin.y + cy);
      ctx.rotate(rot);
      ctx.scale(cs * sq.x, cs * sq.y);
      ctx.lineWidth = outline * 2;
      ctx.strokeStyle = "rgba(13,8,15," + 0.9 * a + ")";
      ctx.strokeText(chars[i], -w / 2, px * 0.35);
      ctx.fillStyle = fill;
      ctx.fillText(chars[i], -w / 2, px * 0.35);
      ctx.restore();
      x += w + spread;
    }
  }

  window.CueLab = { LIFE, FONT, life, splitPlain, splitGrapheme, syllableIndex, ending, charDelay, hash01, drawWord };
})();
