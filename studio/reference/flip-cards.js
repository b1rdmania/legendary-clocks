/* Reference for the site engine (not loaded by any page). Cifra 3 flip cards: the render holds blank cards;
   this draws numerals and the falling flap over them. Add as a ClockView method; call it instead of the hands when cl.flip is set.
   Clock config: cifra: { flip: { z: .1205, w: .0705, h: .0585, gap: .0012, units: [-.036, .036] }, looks: { wall: { day: { ink: '#efede6', card: '#2a2b2d' } } } }
   Font: FontFace('LCFlip', 'url(fonts/InterDisplay-Medium.woff2)', { weight: '500' }), Inter Display Medium, SIL OFL. */
  flaps(g, L) {
    const F = this.cl.flip, { cx, cy, pxm } = this.geo(L), k = pxm * 1.15 / (1.15 - F.z), now = performance.now(), d = new Date();
    const vals = [String(d.getHours()), String(d.getMinutes()).padStart(2, '0')];
    const st = this.fl || (this.fl = vals.map(v => ({ cur: v, prev: v, t0: 0 })));
    const W = F.w * k, H = F.h * k, gp = Math.max(1, F.gap * k), fs = H * .92, ink = L.look.ink || '#eee', card = L.look.card || '#222';
    g.font = `500 ${fs}px LCFlip, "Inter Display", system-ui, sans-serif`; g.textAlign = 'center'; g.textBaseline = 'alphabetic';
    const half = (txt, x, ys, top, sc, shade, bg) => {          // ys: split line; sc: vertical scale of this half
      const hh = (H - gp) / 2;
      g.save(); g.translate(0, ys); g.scale(1, Math.max(sc, .001));
      g.beginPath(); g.rect(x - W / 2, top ? -gp / 2 - hh : gp / 2, W, hh); g.clip();
      if (bg) { g.fillStyle = card; g.fillRect(x - W / 2, top ? -gp / 2 - hh : gp / 2, W, hh); }
      g.fillStyle = ink; g.fillText(txt, x, fs * .364);
      if (shade) { g.fillStyle = `rgba(0,0,0,${shade})`; g.fillRect(x - W / 2, top ? -gp / 2 - hh : gp / 2, W, hh); }
      g.restore();
    };
    F.units.forEach((ux, i) => {
      const s = st[i]; if (vals[i] !== s.cur) { s.prev = s.cur; s.cur = vals[i]; s.t0 = REDUCE ? 0 : now; }
      const p = Math.min(1, (now - s.t0) / 340), x = cx + ux * k, ys = cy;
      half(s.cur, x, ys, true, 1, 0, false);                                      // new top, revealed behind the flap
      half(p < 1 ? s.prev : s.cur, x, ys, false, 1, 0, false);                    // old bottom until the flap lands
      if (p < .5) half(s.prev, x, ys, true, Math.cos(p * Math.PI), p * .9, true);
      else if (p < 1) half(s.cur, x, ys, false, -Math.cos(p * Math.PI), (1 - p) * .7, true);
    });
  }
