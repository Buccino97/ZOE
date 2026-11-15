/* ZOE mascot: draws the character as SVG from a small state object. */
(function (root) {
  'use strict';
  const DARK = '#1b1630';
  const EXPR = {
    felice:     { eyes: 'open',   mouth: 'M50 72 Q60 82 70 72', cheeks: 1 },
    contenta:   { eyes: 'open',   mouth: 'M53 73 Q60 77 67 73' },
    ride:       { eyes: 'laugh',  mouth: 'fill', cheeks: 1 },
    sorpresa:   { eyes: 'big',    mouth: 'o' },
    assonnata:  { eyes: 'half',   mouth: 'M55 76 Q60 74 65 76' },
    dorme:      { eyes: 'closed', mouth: 'M56 76 Q60 78 64 76', zzz: 1 },
    arrabbiata: { eyes: 'open',   mouth: 'M50 79 Q60 70 70 79', brows: 'angry' },
    triste:     { eyes: 'open',   mouth: 'M51 79 Q60 71 69 79', brows: 'sad' },
    innamorata: { eyes: 'heart',  mouth: 'M52 72 Q60 80 68 72', cheeks: 1 },
    pensierosa: { eyes: 'open',   mouth: 'M53 76 L67 74', brows: 'think', look: [-3, -3] },
    occhiolino: { eyes: 'wink',   mouth: 'M50 72 Q60 81 70 72', cheeks: 1 },
    emozionata: { eyes: 'star',   mouth: 'fill', cheeks: 1 },
    confusa:    { eyes: 'open',   mouth: 'M52 76 Q56 73 60 76 Q64 79 68 76', brows: 'think' }
  };
  const EYE_SIZES = { tondi: [9, 11], grandi: [11, 13.5], piccoli: [6.5, 7.5], anime: [10, 13], stelle: [9, 11] };
  const COLORS = ['#7c5cff', '#3ee0b0', '#ff7a59', '#ff5d9e', '#4cc3ff', '#ffc93c', '#9aa0c3', '#2f2f3a'];
  const ACCESSORIES = ['nessuno', 'cappellino', 'cilindro', 'corona', 'fiocco', 'occhiali', 'occhiali da sole',
    'cuffie', 'sciarpa', 'fiore', 'antenna', 'papillon'];
  const BEHIND = new Set(['cuffie']);

  function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16), c = v => Math.max(0, Math.min(255, v));
    const r = c((n >> 16) + amt), g = c(((n >> 8) & 255) + amt), b = c((n & 255) + amt);
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
  }
  const heart = (cx, cy, s) => `<path d="M${cx} ${cy + s * .9} C${cx - s * 1.6} ${cy - s * .1} ${cx - s * .9} ${cy - s * 1.3} ${cx} ${cy - s * .4} C${cx + s * .9} ${cy - s * 1.3} ${cx + s * 1.6} ${cy - s * .1} ${cx} ${cy + s * .9}Z" fill="#ff4d8d"/>`;
  function star(cx, cy, r) {
    const p = [];
    for (let i = 0; i < 10; i++) {
      const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * .45 : r;
      p.push((cx + Math.cos(a) * rr).toFixed(1) + ',' + (cy + Math.sin(a) * rr).toFixed(1));
    }
    return `<polygon points="${p.join(' ')}" fill="#ffc93c"/>`;
  }

  function eye(cx, cy, mode, style, color, idx) {
    let [rx, ry] = EYE_SIZES[style] || EYE_SIZES.tondi;
    if (mode === 'big') { rx *= 1.15; ry *= 1.2; }
    const stroke = `stroke="${DARK}" stroke-width="3" stroke-linecap="round" fill="none"`;
    if (mode === 'closed') return `<path d="M${cx - rx} ${cy} Q${cx} ${cy + 6} ${cx + rx} ${cy}" ${stroke}/>`;
    if (mode === 'laugh' || (mode === 'wink' && idx === 1)) return `<path d="M${cx - rx} ${cy + 3} Q${cx} ${cy - 7} ${cx + rx} ${cy + 3}" ${stroke}/>`;
    if (mode === 'heart') return heart(cx, cy, rx * .85);
    const pr = style === 'piccoli' ? rx * .7 : rx * .55;
    const pupil = (mode === 'star' || style === 'stelle')
      ? star(cx, cy, pr * 1.3)
      : `<circle cx="${cx}" cy="${cy}" r="${pr}" fill="${DARK}"/><circle cx="${cx - pr * .4}" cy="${cy - pr * .5}" r="${pr * .35}" fill="#fff"/>` +
        (style === 'anime' ? `<circle cx="${cx + pr * .4}" cy="${cy + pr * .4}" r="${pr * .18}" fill="#fff"/>` : '');
    let s = `<g class="blink${idx ? ' b2' : ''}"><ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="#fff"/><g class="zp">${pupil}</g></g>`;
    if (mode === 'half') s += `<rect x="${cx - rx - 2}" y="${cy - ry - 2}" width="${rx * 2 + 4}" height="${ry + 2}" fill="${color}"/><path d="M${cx - rx} ${cy} H${cx + rx}" ${stroke}/>`;
    return s;
  }

  function accessory(name, color) {
    switch (name) {
      case 'cappellino': return `<path d="M30 30 Q34 4 60 4 Q86 4 90 30 Z" fill="#ffb547"/><path d="M60 26 H100 Q104 30 98 32 H60 Z" fill="#e8962a"/><circle cx="60" cy="5" r="4" fill="#e8962a"/>`;
      case 'cilindro': return `<rect x="44" y="-10" width="32" height="30" rx="3" fill="#22223a"/><rect x="44" y="12" width="32" height="5" fill="#ff5d9e"/><rect x="34" y="18" width="52" height="6" rx="3" fill="#22223a"/>`;
      case 'corona': return `<polygon points="42,26 42,8 51,17 60,3 69,17 78,8 78,26" fill="#ffc93c" stroke="#e0a400" stroke-width="2" stroke-linejoin="round"/><circle cx="60" cy="18" r="3" fill="#ff5d9e"/>`;
      case 'fiocco': return `<g transform="translate(84 24) rotate(15)"><path d="M0 0 L-14 -9 L-14 9 Z M0 0 L14 -9 L14 9 Z" fill="#ff5d9e" stroke="#e03c80" stroke-width="2" stroke-linejoin="round"/><circle r="4" fill="#e03c80"/></g>`;
      case 'occhiali': return `<g fill="none" stroke="${DARK}" stroke-width="3"><circle cx="45" cy="52" r="14"/><circle cx="75" cy="52" r="14"/><path d="M59 50 Q60 47 61 50"/><path d="M31 50 L18 46 M89 50 L102 46"/></g>`;
      case 'occhiali da sole': return `<g><rect x="29" y="42" width="30" height="20" rx="8" fill="#111"/><rect x="61" y="42" width="30" height="20" rx="8" fill="#111"/><path d="M59 48 H61" stroke="#111" stroke-width="4"/><path d="M34 47 l8 0 M66 47 l8 0" stroke="#fff" stroke-opacity=".5" stroke-width="3" stroke-linecap="round"/></g>`;
      case 'cuffie': return `<path d="M20 54 Q18 6 60 6 Q102 6 100 54" fill="none" stroke="#2f2f3a" stroke-width="7" stroke-linecap="round"/><rect x="9" y="44" width="15" height="26" rx="7" fill="#2f2f3a"/><rect x="96" y="44" width="15" height="26" rx="7" fill="#2f2f3a"/><rect x="12" y="49" width="9" height="16" rx="4" fill="#3ee0b0"/><rect x="99" y="49" width="9" height="16" rx="4" fill="#3ee0b0"/>`;
      case 'sciarpa': return `<rect x="22" y="80" width="76" height="12" rx="6" fill="#ff5a5a"/><path d="M78 86 L86 102 L96 100 L90 86 Z" fill="#e04444"/><path d="M30 83 v6 M40 83 v6 M50 83 v6" stroke="#fff" stroke-opacity=".35" stroke-width="3"/>`;
      case 'fiore': {
        let p = '';
        for (let i = 0; i < 5; i++) { const a = i * 72 * Math.PI / 180; p += `<circle cx="${(84 + Math.cos(a) * 6).toFixed(1)}" cy="${(22 + Math.sin(a) * 6).toFixed(1)}" r="5" fill="#fff"/>`; }
        return p + `<circle cx="84" cy="22" r="4" fill="#ffc93c"/>`;
      }
      case 'antenna': return `<path d="M60 20 Q58 10 62 2" stroke="${shade(color, -40)}" stroke-width="3" fill="none"/><circle cx="62" cy="0" r="5" fill="#3ee0b0"><animate attributeName="opacity" values="1;.4;1" dur="1.6s" repeatCount="indefinite"/></circle>`;
      case 'papillon': return `<g transform="translate(60 88)"><path d="M0 0 L-13 -8 L-13 8 Z M0 0 L13 -8 L13 8 Z" fill="#ff5d9e" stroke="#c93578" stroke-width="2" stroke-linejoin="round"/><circle r="3.5" fill="#c93578"/></g>`;
    }
    return '';
  }

  function render(svg, st) {
    const e = EXPR[st.expr] || EXPR.felice, c = st.color || COLORS[0], acc = st.acc || 'nessuno';
    const bs = `stroke="${DARK}" stroke-width="3" stroke-linecap="round" fill="none"`;
    let o = `<ellipse cx="60" cy="96" rx="34" ry="4" fill="#000" opacity=".25"/>`;
    o += `<ellipse cx="42" cy="91" rx="11" ry="6" fill="${shade(c, -40)}"/><ellipse cx="78" cy="91" rx="11" ry="6" fill="${shade(c, -40)}"/>`;
    if (BEHIND.has(acc)) o += accessory(acc, c);
    o += `<rect x="15" y="20" width="90" height="72" rx="36" fill="${c}"/><ellipse cx="44" cy="32" rx="20" ry="9" fill="#fff" opacity=".16"/>`;
    if (e.cheeks) o += `<ellipse cx="31" cy="66" rx="7" ry="4" fill="#ff7aa8" opacity=".55"/><ellipse cx="89" cy="66" rx="7" ry="4" fill="#ff7aa8" opacity=".55"/>`;
    o += eye(45, 52, e.eyes, st.eyes, c, 0) + eye(75, 52, e.eyes, st.eyes, c, 1);
    if (e.brows === 'angry') o += `<path d="M34 36 L52 42 M86 36 L68 42" ${bs}/>`;
    if (e.brows === 'sad') o += `<path d="M35 42 L52 36 M85 42 L68 36" ${bs}/>`;
    if (e.brows === 'think') o += `<path d="M36 38 L52 38 M68 36 Q76 30 85 35" ${bs}/>`;
    if (e.mouth === 'fill') o += `<path d="M48 70 Q60 88 72 70 Z" fill="${DARK}"/><path d="M54 79 Q60 84 66 79 Q60 76 54 79Z" fill="#ff6b8b"/>`;
    else if (e.mouth === 'o') o += `<ellipse cx="60" cy="76" rx="5" ry="6.5" fill="${DARK}"/>`;
    else o += `<path d="${e.mouth}" ${bs}/>`;
    if (!BEHIND.has(acc)) o += accessory(acc, c);
    if (e.zzz) o += `<text class="zzz" x="94" y="22">z<animate attributeName="y" values="24;8" dur="2s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="2s" repeatCount="indefinite"/></text><text class="zzz" x="102" y="10" font-size="10">z<animate attributeName="y" values="14;-4" dur="2s" begin="1s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="2s" begin="1s" repeatCount="indefinite"/></text>`;
    svg.innerHTML = o;
    svg.dataset.look = e.look ? e.look.join(',') : '';
    if (e.look) setPupils(svg, e.look[0], e.look[1]);
  }

  function setPupils(svg, dx, dy) {
    svg.querySelectorAll('.zp').forEach(g => g.setAttribute('transform', `translate(${dx.toFixed(2)} ${dy.toFixed(2)})`));
  }

  /** Point the pupils toward (x, y) in page coordinates. */
  function lookToward(svg, x, y) {
    if (svg.dataset.look) return;
    const r = svg.getBoundingClientRect();
    if (!r.width) return;
    const cx = r.left + r.width / 2, cy = r.top + r.height * .45;
    const dx = x - cx, dy = y - cy, d = Math.hypot(dx, dy) || 1, m = Math.min(1, d / 120) * 3.6;
    setPupils(svg, dx / d * m, dy / d * m);
  }

  root.ZoeMascot = { render, lookToward, EXPR, COLORS, ACCESSORIES, EYE_STYLES: Object.keys(EYE_SIZES) };
})(window);
