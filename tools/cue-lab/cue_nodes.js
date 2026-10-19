// 擬音の動きを「ノードを繋いだグラフ」で表すエンジン(実験)。
// 考え方は Lee, Forlizzi, Hudson「The Kinetic Typography Engine」(UIST 2002)と同じ:
// 文字ごとに、時間からいくつかの波形を作り、性質(位置・拡縮・回転・透明度・字間)に足したり掛けたりする。
// グラフは JSON。ノードは {"type": 名前, 入力...}。入力は 数 / ノード id の文字列 / 入れ子のノード。
// 文脈の値: t(語の時間) i(文字番号) n(文字数) px(文字の大きさ) seed dx dy(向き) big life g(残像の番号)
(function () {
  "use strict";
  const clampf = (v, a, b) => Math.min(Math.max(v, a), b);
  const easeBack = (k, over) => { k = clampf(k, 0, 1) - 1; return 1 + k * k * ((over + 1) * k + over); };
  const easeOut = (k) => { k = 1 - clampf(k, 0, 1); return 1 - k * k * k; };

  // ノードの種類。f(入力の値, ノード, 文脈) → 数
  const NODES = {
    // 元になる値
    t: { label: "時間", f: (v, nd, c) => c.t },
    i: { label: "文字番号", f: (v, nd, c) => c.i },
    n: { label: "文字数", f: (v, nd, c) => c.n },
    px: { label: "文字の大きさ", f: (v, nd, c) => c.px },
    seed: { label: "乱数の種", f: (v, nd, c) => c.seed },
    dx: { label: "向き x", f: (v, nd, c) => c.dx },
    dy: { label: "向き y", f: (v, nd, c) => c.dy },
    g: { label: "残像の番号", f: (v, nd, c) => c.g || 0 },
    jrev: { label: "文字番号(右向きなら逆順)", f: (v, nd, c) => (c.dx >= 0 ? c.n - 1 - c.i : c.i) },
    big: { label: "大きいとき / ふつう", ins: ["yes", "no"], f: (v, nd, c) => (c.big ? v.yes : v.no) },
    // 時間
    delay: { label: "字ごとの遅れ", ins: ["x", "per", "idx"], f: (v, nd, c) => v.x - (nd.idx === undefined ? c.i : v.idx) * v.per },
    ramp: { label: "0→1(dur 秒で)", ins: ["x", "dur"], f: (v) => clampf(v.x / v.dur, 0, 1) },
    back: { label: "行き過ぎて戻る", ins: ["x", "dur", "over"], f: (v, nd) => easeBack(v.x / v.dur, nd.over === undefined ? 1.7 : v.over) },
    out: { label: "速く出て遅く止まる", ins: ["x", "dur"], f: (v) => easeOut(v.x / v.dur) },
    hill: { label: "山(sin 半周)", ins: ["x", "dur"], f: (v) => Math.sin(clampf(v.x / v.dur, 0, 1) * Math.PI) },
    decay: { label: "1→0(dur 秒で。0 より下がらない)", ins: ["x", "dur"], f: (v) => Math.max(0, 1 - v.x / v.dur) },
    fadeend: { label: "終わりのフェードアウト", ins: ["x"], f: (v, nd, c) => 1 - clampf((v.x - (c.life - 0.35)) / 0.35, 0, 1) },
    after: { label: "at 秒から数える(それまで 0)", ins: ["x", "at"], f: (v) => Math.max(0, v.x - v.at) },
    // 波
    osc: { label: "振動 sin(x·f + i·ph + seed)", ins: ["x", "f", "ph", "amp"], f: (v, nd, c) => Math.sin(v.x * v.f + c.i * (nd.ph === undefined ? 0 : v.ph) + (nd.seeded === false ? 0 : c.seed)) * (nd.amp === undefined ? 1 : v.amp) },
    cosc: { label: "振動 cos(x·f + i·ph + seed)", ins: ["x", "f", "ph", "amp"], f: (v, nd, c) => Math.cos(v.x * v.f + c.i * (nd.ph === undefined ? 0 : v.ph) + (nd.seeded === false ? 0 : c.seed)) * (nd.amp === undefined ? 1 : v.amp) },
    // 計算
    add: { label: "足す", ins: ["a", "b", "c", "d"], f: (v, nd) => (v.a || 0) + (v.b || 0) + (nd.c === undefined ? 0 : v.c) + (nd.d === undefined ? 0 : v.d) },
    mul: { label: "掛ける", ins: ["a", "b", "c"], f: (v, nd) => v.a * v.b * (nd.c === undefined ? 1 : v.c) },
    sub: { label: "引く", ins: ["a", "b"], f: (v) => v.a - v.b },
    div: { label: "割る", ins: ["a", "b"], f: (v) => v.a / v.b },
    mix: { label: "from→to を k で混ぜる", ins: ["k", "from", "to"], f: (v) => v.from + (v.to - v.from) * v.k },
    sin: { label: "sin", ins: ["x"], f: (v) => Math.sin(v.x) },
    abs: { label: "絶対値", ins: ["x"], f: (v) => Math.abs(v.x) },
    sq: { label: "二乗", ins: ["x"], f: (v) => v.x * v.x },
    max: { label: "大きい方", ins: ["a", "b"], f: (v) => Math.max(v.a, v.b) },
    min: { label: "小さい方", ins: ["a", "b"], f: (v) => Math.min(v.a, v.b) },
    clamp: { label: "はさむ", ins: ["x", "lo", "hi"], f: (v) => clampf(v.x, v.lo, v.hi) },
    step: { label: "段: x < at なら before、でなければ after", ins: ["x", "at", "before", "after"], f: (v) => (v.x < v.at ? v.before : v.after) },
    sign: { label: "x ≥ 0 なら pos、でなければ neg", ins: ["x", "pos", "neg"], f: (v) => (v.x >= 0 ? v.pos : v.neg) },
  };

  // グラフの評価。nodes は {id: ノード}、props は {性質: 入力}。文字ごとに memo を作り直す
  function makeEval(graph) {
    const nodes = graph.nodes || {};
    return function evalProps(c) {
      const memo = {};
      function ev(x) {
        if (typeof x === "number") return x;
        if (typeof x === "string") {
          if (x in memo) return memo[x];
          if (x in nodes) return (memo[x] = evNode(nodes[x]));
          if (x in NODES && !(NODES[x].ins)) return (memo[x] = evNode({ type: x }));   // "t" "px" "dx" など、文脈の値は id だけで引ける
          throw new Error("ノードが無い: " + x);
        }
        if (x && typeof x === "object") return evNode(x);
        return 0;
      }
      function evNode(nd) {
        const def = NODES[nd.type];
        if (!def) throw new Error("知らないノード: " + nd.type);
        const v = {};
        for (const k of def.ins || []) if (nd[k] !== undefined) v[k] = ev(nd[k]);
        return def.f(v, nd, c);
      }
      const p = graph.props || {};
      const out = {};
      for (const k of Object.keys(p)) out[k] = ev(p[k]);
      return out;
    };
  }

  // draw_word と同じ描き方で、グラフの性質から一文字ずつ描く
  // props: x y sx sy rot alpha spread、残像は graph.copies = {count, x, y, alpha}(g=count..1、alpha は本体に掛ける)
  function drawWordGraph(ctx, chars, graph, t, lifeS, px, color, seed, big, origin, dir, font) {
    const n = chars.length;
    if (n === 0) return;
    const dl = Math.hypot(dir.x, dir.y);
    const d = dl > 0 ? { x: dir.x / dl, y: dir.y / dl } : { x: 1, y: 0 };
    const evalProps = makeEval(graph);
    const base = { t, n, px, seed, dx: d.x, dy: d.y, big: !!big, life: lifeS, i: 0, g: 0 };
    ctx.font = px + "px " + font;
    const widths = chars.map((ch) => ctx.measureText(ch).width);
    const wordP = evalProps(Object.assign({}, base, { i: 0 }));
    const spread = wordP.spread || 0;
    let total = widths.reduce((a, b) => a + b, 0) + spread * (n - 1);
    let x = -total / 2;
    const outline = Math.max(3, Math.floor(px * 0.22));
    const copies = graph.copies;
    const evalCopy = copies ? makeEval({ nodes: graph.nodes, props: { x: copies.x, y: copies.y, alpha: copies.alpha } }) : null;
    ctx.textBaseline = "alphabetic";
    ctx.lineJoin = "round";
    for (let i = 0; i < n; i++) {
      const w = widths[i];
      const p = evalProps(Object.assign({}, base, { i }));
      const a = (p.alpha === undefined ? 1 : p.alpha) * color.a;
      const cx = x + w / 2 + (p.x || 0);
      const cy = p.y || 0;
      const sx = p.sx === undefined ? 1 : p.sx, sy = p.sy === undefined ? 1 : p.sy, rot = p.rot || 0;
      x += w + spread;
      if (a <= 0) continue;
      if (copies) {
        for (let g = copies.count; g >= 1; g--) {
          const cp = evalCopy(Object.assign({}, base, { i, g }));
          const ga = a * cp.alpha;
          if (ga <= 0) continue;
          ctx.save();
          ctx.translate(origin.x + cx + cp.x, origin.y + cy + cp.y);
          ctx.rotate(rot); ctx.scale(sx, sy);
          ctx.fillStyle = "rgba(" + color.r + "," + color.g + "," + color.b + "," + ga + ")";
          ctx.fillText(chars[i], -w / 2, px * 0.35);
          ctx.restore();
        }
      }
      ctx.save();
      ctx.translate(origin.x + cx, origin.y + cy);
      ctx.rotate(rot); ctx.scale(sx, sy);
      ctx.lineWidth = outline * 2;
      ctx.strokeStyle = "rgba(13,8,15," + 0.9 * a + ")";
      ctx.strokeText(chars[i], -w / 2, px * 0.35);
      ctx.fillStyle = "rgba(" + color.r + "," + color.g + "," + color.b + "," + a + ")";
      ctx.fillText(chars[i], -w / 2, px * 0.35);
      ctx.restore();
    }
  }

  // ---- いまの11種を、グラフに書き直したもの(cue_text.gd の draw_word と同じ式) ----
  const T = "t";
  const GRAPHS = {
    pop: {
      nodes: { k: { type: "back", x: T, dur: 0.16, over: 2.6 }, s: { type: "mix", k: "k", from: 0.55, to: 1 } },
      props: { sx: "s", sy: "s", y: { type: "mul", a: T, b: -14 }, alpha: { type: "fadeend", x: T } },
    },
    slam: {
      nodes: {
        k: { type: "ramp", x: T, dur: 0.14 },
        s0: { type: "add", a: { type: "mix", k: "k", from: { type: "big", yes: 2.3, no: 1.9 }, to: 1 },
          b: { type: "mul", a: 0.12, b: { type: "sin", x: { type: "mul", a: "k", b: Math.PI } }, c: { type: "sub", a: 1, b: "k" } } },
        s1: { type: "sub", a: 1, b: { type: "mul", a: 0.1, b: { type: "sin", x: { type: "mul", a: { type: "div", a: { type: "sub", a: T, b: 0.14 }, b: 0.1 }, b: Math.PI } } } },
        s: { type: "step", x: T, at: 0.14, before: "s0", after: { type: "step", x: T, at: 0.24, before: "s1", after: "s0" } },
        sk: { type: "mul", a: { type: "decay", x: T, dur: 0.35 }, b: { type: "big", yes: 6, no: 3.5 } },
      },
      props: {
        sx: "s", sy: "s",
        x: { type: "osc", x: T, f: 90, amp: "sk" },
        y: { type: "add", a: { type: "cosc", x: T, f: 77, amp: "sk" }, b: { type: "mul", a: { type: "after", x: T, at: 0.3 }, b: -8 } },
        rot: -0.08, alpha: { type: "fadeend", x: T },
      },
    },
    shake: {
      nodes: { amp: { type: "mul", a: "px", b: 0.08 } },
      props: {
        x: { type: "osc", x: T, f: 61, ph: 2.3, amp: "amp" },
        y: { type: "add", a: { type: "mul", a: T, b: -6 }, b: { type: "cosc", x: T, f: 53, ph: 1.7, amp: "amp" } },
        alpha: { type: "fadeend", x: T },
      },
    },
    stretch: {
      nodes: { ts: { type: "delay", x: T, per: 0.07 }, s: { type: "mix", k: { type: "back", x: "ts", dur: 0.16, over: 2.0 }, from: 0.4, to: 1 } },
      props: {
        spread: { type: "mul", a: { type: "min", a: T, b: 0.6 }, b: { type: "mul", a: "px", b: 0.35 } },
        sx: "s", sy: "s", y: { type: "mul", a: T, b: -10 },
        alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "ramp", x: "ts", dur: 0.08 }, c: { type: "step", x: "ts", at: 0, before: 0, after: 1 } },
      },
    },
    soft: {
      nodes: { s: { type: "mix", k: { type: "ramp", x: T, dur: 0.25 }, from: 0.8, to: 1 } },
      props: { sx: "s", sy: "s", y: { type: "mul", a: T, b: -22 }, alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "ramp", x: T, dur: 0.18 } } },
    },
    snap: {
      nodes: { k2: { type: "back", x: T, dur: 0.11, over: 2.2 } },
      props: {
        x: { type: "mul", a: { type: "sub", a: "k2", b: 1 }, b: { type: "mul", a: "px", b: 2 } },
        rot: { type: "add", a: { type: "mul", a: -0.18, b: { type: "sub", a: 1, b: { type: "ramp", x: T, dur: 0.11 } } }, b: -0.05 },
        y: { type: "mul", a: T, b: -8 }, alpha: { type: "fadeend", x: T },
      },
    },
    bounce: {
      nodes: { ti: { type: "delay", x: T, per: 0.06 }, s: { type: "add", a: 1, b: { type: "mul", a: 0.25, b: { type: "sub", a: 1, b: { type: "ramp", x: "ti", dur: 0.1 } } } } },
      props: {
        y: { type: "add", a: { type: "mul", a: T, b: -10 }, b: { type: "mul", a: { type: "hill", x: "ti", dur: 0.22 }, b: { type: "mul", a: "px", b: -0.55 } } },
        sx: "s", sy: "s",
        alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "step", x: "ti", at: 0, before: 0, after: 1 } },
      },
    },
    drop: {
      nodes: {
        td: { type: "delay", x: T, per: 0.05 },
        kd: { type: "div", a: "td", b: 0.15 },
        fallY: { type: "mul", a: { type: "sub", a: { type: "sq", x: "kd" }, b: 1 }, b: { type: "mul", a: "px", b: 3.2 } },
        tl: { type: "sub", a: "td", b: 0.15 },
        squash: { type: "decay", x: "tl", dur: 0.16 },
        landY: { type: "add", a: { type: "mul", a: { type: "hill", x: { type: "sub", a: "tl", b: 0.06 }, dur: 0.18 }, b: { type: "mul", a: "px", b: -0.25 } },
          b: { type: "mul", a: "px", b: { type: "mul", a: 0.12, b: "squash" } } },
        rise: { type: "mul", a: { type: "after", x: T, at: 0.4 }, b: -10 },
        falling: { type: "step", x: "td", at: 0.15, before: 1, after: 0 },
      },
      props: {
        y: { type: "add", a: "rise", b: { type: "step", x: "td", at: 0.15, before: "fallY", after: "landY" } },
        sx: { type: "step", x: "td", at: 0.15, before: 0.85, after: { type: "add", a: 1, b: { type: "mul", a: 0.4, b: "squash" } } },
        sy: { type: "step", x: "td", at: 0.15, before: 1.25, after: { type: "sub", a: 1, b: { type: "mul", a: 0.35, b: "squash" } } },
        alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "step", x: "td", at: 0.15, before: { type: "ramp", x: "td", dur: 0.05 }, after: 1 },
          c: { type: "step", x: "td", at: 0, before: 0, after: 1 } },
      },
    },
    roll: {
      nodes: {
        tr: { type: "delay", x: T, per: 0.07 },
        dist: { type: "mul", a: { type: "sub", a: 1, b: { type: "out", x: "tr", dur: 0.5 } }, b: { type: "mul", a: "px", b: 3.5 } },
        bob: { type: "mul", a: { type: "abs", x: { type: "sin", x: { type: "mul", a: { type: "div", a: "dist", b: "px" }, b: 1.6 } } }, b: { type: "mul", a: "px", b: -0.18 } },
      },
      props: {
        x: { type: "mul", a: "dx", b: { type: "mul", a: "dist", b: -1 } },
        y: { type: "add", a: { type: "mul", a: "dy", b: { type: "mul", a: "dist", b: -1 } }, b: "bob", c: { type: "mul", a: { type: "after", x: T, at: 0.5 }, b: -8 } },
        rot: { type: "mul", a: { type: "sign", x: "dx", pos: 1, neg: -1 }, b: { type: "div", a: "dist", b: { type: "mul", a: "px", b: 0.5 } } },
        alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "ramp", x: "tr", dur: 0.08 }, c: { type: "step", x: "tr", at: 0, before: 0, after: 1 } },
      },
    },
    fly: {
      nodes: {
        kf: { type: "out", x: T, dur: 0.16 },
        m: { type: "add", a: { type: "mul", a: { type: "sub", a: "kf", b: 1 }, b: { type: "mul", a: "px", b: 4 } }, b: { type: "mul", a: T, b: { type: "mul", a: "px", b: 0.8 } } },
        j: { type: "jrev" },
        kc: { type: "out", x: { type: "delay", x: T, per: 0.025, idx: "j" }, dur: 0.16 },
        lag: { type: "mul", a: { type: "sub", a: "kc", b: 1 }, b: { type: "mul", a: "px", b: { type: "mul", a: 0.9, b: "j" } } },
      },
      props: {
        x: { type: "add", a: { type: "mul", a: "dx", b: "m" }, b: { type: "mul", a: "dx", b: "lag" } },
        y: { type: "add", a: { type: "mul", a: "dy", b: "m" }, b: { type: "mul", a: "dy", b: "lag" }, c: { type: "mul", a: T, b: -4 } },
        rot: { type: "add", a: { type: "mul", a: { type: "clamp", x: "dx", lo: -1, hi: 1 }, b: { type: "mul", a: 0.12, b: { type: "sub", a: 1, b: "kf" } } }, b: { type: "mul", a: "dy", b: 0.1 } },
        alpha: { type: "fadeend", x: T },
      },
      copies: {
        count: 2,
        x: { type: "mul", a: "dx", b: { type: "mul", a: "px", b: { type: "mul", a: -0.7, b: "g" } } },
        y: { type: "mul", a: "dy", b: { type: "mul", a: "px", b: { type: "mul", a: -0.7, b: "g" } } },
        alpha: { type: "mul", a: 0.22, b: { type: "decay", x: T, dur: 0.2 }, c: { type: "div", a: { type: "sub", a: 3, b: "g" }, b: 2 } },
      },
    },
    wave: {
      props: {
        y: { type: "add", a: { type: "mul", a: T, b: -10 }, b: { type: "osc", x: T, f: 9, ph: -0.9, amp: { type: "mul", a: "px", b: 0.18 } } },
        rot: { type: "osc", x: T, f: 7, ph: -0.9, amp: 0.12, seeded: false },
        alpha: { type: "fadeend", x: T },
      },
    },
  };

  window.CueNodes = { NODES, GRAPHS, makeEval, drawWordGraph };
})();
