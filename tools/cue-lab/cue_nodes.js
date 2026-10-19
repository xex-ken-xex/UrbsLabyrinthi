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

    // ---- 先行研究から取り込んだノード(src が出典。RESEARCH.md も見る) ----
    // Lee, Forlizzi, Hudson (UIST 2002) "The Kinetic Typography Engine": 時間フィルタ Delay / Speed / Loop / Reverse / PaceInOut / Pause
    speed: { label: "速さ(時間を k 倍)", ins: ["x", "k"], src: "KTE", f: (v) => v.x * v.k },
    loop: { label: "くり返し(period 秒で 0 に戻る)", ins: ["x", "period"], src: "KTE", f: (v) => ((v.x % v.period) + v.period) % v.period },
    reverse: { label: "逆再生(dur − x)", ins: ["x", "dur"], src: "KTE", f: (v) => v.dur - v.x },
    pace: { label: "緩急(ゆっくり出て、ゆっくり止まる 0→1)", ins: ["x", "dur"], src: "KTE", f: (v) => { const k = clampf(v.x / v.dur, 0, 1); return k * k * (3 - 2 * k); } },
    pause: { label: "一時停止(at 秒から len 秒、時間を止める)", ins: ["x", "at", "len"], src: "KTE", f: (v) => (v.x < v.at ? v.x : v.x < v.at + v.len ? v.at : v.x - v.len) },
    // KTE の波形 Curve(ベジェ1本)と Jitter(乱れ)。Jitter は種から決まる擬似乱数なので、同じ種なら同じ乱れ
    curve: { label: "曲線(ベジェ。p1 p2 で形、0→1)", ins: ["x", "dur", "p1", "p2"], src: "KTE", f: (v) => { const k = clampf(v.x / v.dur, 0, 1), u = 1 - k; return 3 * u * u * k * v.p1 + 3 * u * k * k * v.p2 + k * k * k; } },
    jitter: { label: "乱れ(f 回/秒で跳ぶ、±amp)", ins: ["x", "f", "amp"], src: "KTE", f: (v, nd, c) => { const s = Math.sin((Math.floor(v.x * v.f) + c.i * 7.13 + c.seed) * 12.9898) * 43758.5453; return (s - Math.floor(s) - 0.5) * 2 * v.amp; } },
    // KTE「自動のアニメ技法」: 伸び縮みは主たる動きの一階微分から作る(速いほど進む向きに伸びる)。予備動作と余韻は波形のいじりで作る
    deriv: { label: "微分(ノード of の、1秒あたりの変化)", ins: [], src: "KTE", f: (v, nd, c, evalAt) => { const dt = nd.dt || 0.01; return (evalAt(nd.of, { t: c.t + dt }) - evalAt(nd.of, { t: c.t - dt })) / (2 * dt); } },
    anticip: { label: "予備動作(出る前に amt だけ逆へ引いてから 0→1)", ins: ["x", "dur", "amt"], src: "KTE", f: (v) => { const k = clampf(v.x / v.dur, 0, 1); return k < 0.3 ? -v.amt * Math.sin(k / 0.3 * Math.PI) : easeBack((k - 0.3) / 0.7, 1.7); } },
    // Adobe After Effects の Text Animator「Range Selector」: 文字の位置(0〜1)で重みをつける。形は ramp / triangle / square / round。
    pos: { label: "文字の位置(0〜1。先頭 0、末尾 1)", src: "AE", f: (v, nd, c) => (c.n > 1 ? c.i / (c.n - 1) : 0) },
    rangesel: { label: "範囲選択(位置 p を start〜end で切り、shape で重み 0〜1)", ins: ["p", "start", "end"], src: "AE", f: (v, nd) => {
      const s = nd.start === undefined ? 0 : v.start, e = nd.end === undefined ? 1 : v.end;
      const k = clampf((v.p - s) / Math.max(1e-6, e - s), 0, 1);
      switch (nd.shape) { case "triangle": return 1 - Math.abs(k * 2 - 1); case "square": return k > 0 && k < 1 ? 1 : 0; case "round": return Math.sin(k * Math.PI); default: return k; }
    } },
    // AE の Range Selector「Randomize Order」: 文字の順をばらす(種から決まる並べ替え)。ken の「文字列のシャッフル」も同じ
    perm: { label: "並べ替えた文字番号(seed で決まるシャッフル)", src: "AE", f: (v, nd, c) => { const a = []; for (let k = 0; k < c.n; k++) a.push(k); let s = Math.floor(c.seed * 1000) + (nd.salt || 0); for (let k = c.n - 1; k > 0; k--) { s = (s * 1103515245 + 12345) % 2147483648; const r = s % (k + 1); [a[k], a[r]] = [a[r], a[k]]; } return a[c.i]; } },
    // 加藤ほか (CHI 2015) "TextAlive": フレーズ・単語・文字の階層。ここでは音節(拍)の番号で、音節ごとに同じ動きを割り当てる
    syl: { label: "音節の番号(小書き・ー・濁点は前の字につく)", src: "TextAlive", f: (v, nd, c) => c.syl },
    nsyl: { label: "音節の数", src: "TextAlive", f: (v, nd, c) => c.nsyl },
    alt: { label: "交互(音節が偶数なら a、奇数なら b)", ins: ["a", "b"], src: "TextAlive", f: (v, nd, c) => ((nd.by === "char" ? c.i : c.syl) % 2 === 0 ? v.a : v.b) },
    // Koguchi, Yamada, Taura (ICED 2013): 擬態語の「リズム」は動きの量と角速度の変化。音節ごとに位相をずらした振動で表す
    rhythm: { label: "拍の振動 sin(x·f − syl·ph)", ins: ["x", "f", "ph", "amp"], src: "Koguchi", f: (v, nd, c) => Math.sin(v.x * v.f - c.syl * (nd.ph === undefined ? 0 : v.ph)) * (nd.amp === undefined ? 1 : v.amp) },
  };

  // 音節(拍)の番号(cue_lab.js の syllableIndex と同じ決まり)
  function syllables(chars) {
    if (window.CueLab && window.CueLab.syllableIndex) return window.CueLab.syllableIndex(chars);
    return chars.map((c, i) => i);
  }

  // グラフの評価。nodes は {id: ノード}、props は {性質: 入力}。文字ごとに memo を作り直す
  function makeEval(graph) {
    const nodes = graph.nodes || {};
    return function evalProps(c) {
      const memo = {};
      // 別の時刻でノードを評価する(deriv 用)。memo は使わない
      function evalAt(ref, over) { return makeEval({ nodes, props: { v: ref } })(Object.assign({}, c, over)).v; }
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
        return def.f(v, nd, c, evalAt);
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
    const sylIdx = syllables(chars);
    const base = { t, n, px, seed, dx: d.x, dy: d.y, big: !!big, life: lifeS, i: 0, g: 0, syl: 0, nsyl: sylIdx[n - 1] + 1 };
    ctx.font = px + "px " + font;
    const widths = chars.map((ch) => ctx.measureText(ch).width);
    const wordP = evalProps(Object.assign({}, base, { i: 0 }));
    const spread = wordP.spread || 0;
    let total = widths.reduce((a, b) => a + b, 0) + spread * (n - 1);
    let x = -total / 2;
    // 整列(layout): 無ければ一列。"arc" は放射状(半径 radius、span ラジアンに等間隔。ken の「放射状に整列」)
    const lay = graph.layout || null;
    const outline = Math.max(3, Math.floor(px * 0.22));
    const copies = graph.copies;
    const evalCopy = copies ? makeEval({ nodes: graph.nodes, props: { x: copies.x, y: copies.y, alpha: copies.alpha } }) : null;
    ctx.textBaseline = "alphabetic";
    ctx.lineJoin = "round";
    for (let i = 0; i < n; i++) {
      const w = widths[i];
      const p = evalProps(Object.assign({}, base, { i, syl: sylIdx[i] }));
      const a = (p.alpha === undefined ? 1 : p.alpha) * color.a;
      let bx = x + w / 2, by = 0, brot = 0;
      if (lay && lay.type === "arc" && n > 1) {
        const span = lay.span === undefined ? Math.PI : lay.span, r = lay.radius === undefined ? px * 2 : lay.radius;
        const ang = -Math.PI / 2 - span / 2 + span * i / (n - 1);
        bx = Math.cos(ang) * r; by = Math.sin(ang) * r + r; brot = ang + Math.PI / 2;
      }
      const cx = bx + (p.x || 0);
      const cy = by + (p.y || 0);
      const sx = p.sx === undefined ? 1 : p.sx, sy = p.sy === undefined ? 1 : p.sy, rot = brot + (p.rot || 0);
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

  // ---- 先行研究の部品を使った例(ゲームには無い。実験室の「研究の例」) ----
  const EXAMPLES = {
    // TextAlive の階層 + Koguchi のリズム: 音節ごとに左右へ交互に振れる(ひらひらひら、ゴロゴロゴロ)。ken の「音節ごとに向きを変える」
    ex_hira: {
      src: "TextAlive / Koguchi",
      nodes: { ts: { type: "delay", x: T, per: 0.12, idx: "syl" }, sw: { type: "hill", x: "ts", dur: 0.5 } },
      props: {
        x: { type: "alt", a: { type: "mul", a: "sw", b: { type: "mul", a: "px", b: -0.5 } }, b: { type: "mul", a: "sw", b: { type: "mul", a: "px", b: 0.5 } } },
        y: { type: "add", a: { type: "mul", a: T, b: -10 }, b: { type: "rhythm", x: T, f: 8, ph: 1.2, amp: { type: "mul", a: "px", b: 0.15 } } },
        rot: { type: "alt", a: { type: "mul", a: "sw", b: -0.3 }, b: { type: "mul", a: "sw", b: 0.3 } },
        alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "step", x: "ts", at: 0, before: 0, after: 1 } },
      },
    },
    // KTE の自動技法: 予備動作(少し沈んでから跳ぶ)+ 速さの微分から伸び縮み(速いほど縦に伸びる)
    ex_anticip: {
      src: "KTE",
      nodes: {
        yy: { type: "mul", a: { type: "anticip", x: T, dur: 0.35, amt: 0.25 }, b: { type: "mul", a: "px", b: -2.0 } },
        vel: { type: "deriv", of: "yy", dt: 0.01 },
        st: { type: "add", a: 1, b: { type: "clamp", x: { type: "mul", a: { type: "abs", x: "vel" }, b: { type: "div", a: 0.004, b: { type: "div", a: "px", b: 14 } } }, lo: 0, hi: 0.6 } },
      },
      props: { y: "yy", sy: "st", sx: { type: "div", a: 1, b: "st" }, alpha: { type: "fadeend", x: T } },
    },
    // After Effects の Range Selector: 先頭から末尾へ「窓」が走り、通った字が浮いて現れる
    ex_range: {
      src: "AE",
      nodes: { k: { type: "mul", a: { type: "ramp", x: T, dur: 0.6 }, b: 1.3 }, w: { type: "rangesel", p: "pos", start: { type: "sub", a: "k", b: 0.3 }, end: "k", shape: "ramp" } },
      props: { alpha: { type: "mul", a: "w", b: { type: "fadeend", x: T } }, y: { type: "mul", a: { type: "sub", a: 1, b: "w" }, b: { type: "mul", a: "px", b: 0.8 } }, sx: { type: "mix", k: "w", from: 0.6, to: 1 }, sy: { type: "mix", k: "w", from: 0.6, to: 1 } },
    },
    // AE の Randomize Order / ken の「文字列のシャッフル → シャッフルキャンセル」: ばらばらの位置から、正しい並びへ戻る
    ex_shuffle: {
      src: "AE",
      nodes: { k: { type: "back", x: T, dur: 0.45, over: 1.2 }, off: { type: "mul", a: { type: "sub", a: "perm", b: "i" }, b: "px" } },
      props: { x: { type: "mix", k: "k", from: "off", to: 0 }, y: { type: "mul", a: { type: "hill", x: T, dur: 0.45 }, b: { type: "mul", a: "px", b: -0.6 } }, alpha: { type: "fadeend", x: T } },
    },
    // ken の「放射状に整列」+ 波: 弧に並べて揺れる
    ex_arc: {
      src: "ken",
      layout: { type: "arc", span: 1.6, radius: 40 },
      props: { y: { type: "add", a: { type: "mul", a: T, b: -8 }, b: { type: "osc", x: T, f: 9, ph: -0.9, amp: { type: "mul", a: "px", b: 0.15 } } }, alpha: { type: "fadeend", x: T } },
    },
    // ken の「裏返り(y 軸回転)」: 一文字ずつ、くるっと裏返って出る(sx を 1→−1→1。KTE の Loop で回し続ける)
    ex_flip: {
      src: "ken / KTE",
      nodes: { ti: { type: "delay", x: T, per: 0.05 }, ph: { type: "mul", a: { type: "loop", x: "ti", period: 0.5 }, b: { type: "div", a: Math.PI, b: 0.25 } } },
      props: { sx: { type: "sin", x: { type: "add", a: "ph", b: { type: "div", a: Math.PI, b: 2 } } }, y: { type: "mul", a: T, b: -10 }, alpha: { type: "mul", a: { type: "fadeend", x: T }, b: { type: "step", x: "ti", at: 0, before: 0, after: 1 } } },
    },
    // KTE の Pause + Curve: 出てすぐ 0.2 秒止まり(タメ)、ベジェの曲線でふわっと上がる
    ex_pause: {
      src: "KTE",
      nodes: { tp: { type: "pause", x: T, at: 0.08, len: 0.2 }, c: { type: "curve", x: "tp", dur: 0.6, p1: 0.1, p2: 1.0 } },
      props: { y: { type: "mul", a: "c", b: { type: "mul", a: "px", b: -1.5 } }, sx: { type: "mix", k: "c", from: 1.3, to: 1 }, sy: { type: "mix", k: "c", from: 0.7, to: 1 }, alpha: { type: "fadeend", x: T } },
    },
  };
  for (const k of Object.keys(EXAMPLES)) GRAPHS[k] = EXAMPLES[k];

  window.CueNodes = { NODES, GRAPHS, EXAMPLES, makeEval, drawWordGraph };
})();
