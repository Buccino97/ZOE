/* Understands Italian commands typed (or, later, spoken) to ZOE.
   parse(text, now) -> intent object. Pure: no side effects, easy to test. */
(function (root) {
  'use strict';

  const WORD_NUMS = {
    un: 1, uno: 1, una: 1, due: 2, tre: 3, quattro: 4, cinque: 5, sei: 6, sette: 7, otto: 8, nove: 9,
    dieci: 10, undici: 11, dodici: 12, quindici: 15, venti: 20, trenta: 30, quaranta: 40, cinquanta: 50
  };
  const UNIT_MS = {
    secondi: 1e3, secondo: 1e3, sec: 1e3, s: 1e3,
    minuti: 6e4, minuto: 6e4, min: 6e4, m: 6e4,
    ore: 36e5, ora: 36e5, h: 36e5
  };
  const NUM = '(\\d+(?:[.,]\\d+)?|' + Object.keys(WORD_NUMS).join('|') + ')';
  const UNIT = '(secondi|secondo|sec|s|minuti|minuto|min|m|ore|ora|h)';

  function normalize(text) {
    return String(text).toLowerCase()
      .normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/[’`]/g, "'")
      .replace(/\b(un|mezz|quest|dell|all|d)'/g, '$1 ')
      .replace(/\s+/g, ' ')
      .replace(/[!?.]+$/, '')
      .trim();
  }

  function toNumber(tok) {
    if (tok in WORD_NUMS) return WORD_NUMS[tok];
    return parseFloat(tok.replace(',', '.'));
  }

  /** Total duration in ms found in the text ("1 ora e 30 minuti", "mezz'ora", "90 sec"), or 0. */
  function parseDuration(text) {
    const t = normalize(text);
    let ms = 0;
    const re = new RegExp('\\b' + NUM + '\\s*' + UNIT + '\\b', 'g');
    let m;
    while ((m = re.exec(t))) ms += toNumber(m[1]) * UNIT_MS[m[2]];
    if (/\bmezz ?ora\b/.test(t)) ms += 30 * 6e4;
    if (/\b(un )?quarto d ?ora\b/.test(t)) ms += 15 * 6e4;
    if (/\b(ora|ore) e mezz[ao]\b/.test(t)) ms += 30 * 6e4;
    return Math.round(ms);
  }

  /** "alle 18", "alle 18:30", "alle 7.15", "domani alle 9" -> timestamp of the next such moment, or null. */
  function parseClock(text, now) {
    const t = normalize(text);
    const m = t.match(/\b(?:alle|all|per le)\s+(\d{1,2})(?:[:.](\d{2}))?(?:\s+e\s+(mezza|un quarto|quarto))?/);
    if (!m) return null;
    const h = +m[1], min = m[2] ? +m[2] : (m[3] === 'mezza' ? 30 : m[3] ? 15 : 0);
    if (h > 23 || min > 59) return null;
    const d = new Date(now);
    d.setHours(h, min, 0, 0);
    if (/\bdomani\b/.test(t)) d.setDate(d.getDate() + 1);
    else if (d.getTime() <= now) {
      // "alle 6" said at 15:00 most likely means 18:00, otherwise tomorrow.
      if (h < 12 && h + 12 > new Date(now).getHours()) d.setHours(h + 12);
      else d.setDate(d.getDate() + 1);
    }
    return d.getTime();
  }

  /** Safe arithmetic: numbers, + - * / x : ^ % and parentheses. Returns a number or null. */
  function calculate(expr) {
    const src = String(expr).toLowerCase()
      .replace(/\bper\b|x|×/g, '*').replace(/\bdiviso\b|:|÷/g, '/')
      .replace(/\bpiu\b|\bpiù\b/g, '+').replace(/\bmeno\b/g, '-')
      .replace(/(\d),(\d)/g, '$1.$2').replace(/\s+/g, '');
    if (!src || /[^0-9.+\-*/^%()]/.test(src)) return null;
    let i = 0;
    const peek = () => src[i];
    function number() {
      const m = src.slice(i).match(/^\d+(\.\d+)?|^\.\d+/);
      if (!m) throw new Error('num');
      i += m[0].length;
      let v = parseFloat(m[0]);
      if (peek() === '%') { i++; v /= 100; }
      return v;
    }
    function factor() {
      if (peek() === '-') { i++; return -factor(); }
      if (peek() === '+') { i++; return factor(); }
      let v;
      if (peek() === '(') { i++; v = sum(); if (peek() !== ')') throw new Error(')'); i++; }
      else v = number();
      if (peek() === '^') { i++; v = Math.pow(v, factor()); }
      return v;
    }
    function product() {
      let v = factor();
      while (peek() === '*' || peek() === '/') { const op = src[i++]; const r = factor(); v = op === '*' ? v * r : v / r; }
      return v;
    }
    function sum() {
      let v = product();
      while (peek() === '+' || peek() === '-') { const op = src[i++]; const r = product(); v = op === '+' ? v + r : v - r; }
      return v;
    }
    try {
      const v = sum();
      if (i !== src.length || !isFinite(v)) return null;
      return Math.round(v * 1e10) / 1e10;
    } catch { return null; }
  }

  function parse(text, now) {
    now = now == null ? Date.now() : now;
    const raw = String(text || '').trim();
    const t = normalize(raw);
    if (!t) return { type: 'empty' };

    if (/^(annulla|ferma|stop|basta)\b/.test(t) && !/promemoria/.test(t)) return { type: 'timer-cancel' };
    if (/^(annulla|cancella|elimina) (i |il |tutti i )?promemoria/.test(t)) return { type: 'reminder-clear' };

    // Reminders: "ricordami di X alle 18", "tra 10 minuti ricordami di X", "ricordami alle 9 di X"
    if (/\bricordami\b|\bricorda(mi)? di\b|\bpromemoria\b/.test(t)) {
      let at = parseClock(t, now);
      if (at == null) { const d = parseDuration(t); if (d && /\b(tra|fra|in|dopo)\b/.test(t)) at = now + d; }
      // Strip the "when" words from the original text so the reminder keeps its capitals ("chiamare Luca").
      const keep = raw.replace(/[’`]/g, "'").replace(/\s+/g, ' ').replace(/[!?.]+$/, '');
      let what = keep
        .replace(/\b(domani )?(alle|all|per le)\s+\d{1,2}([:.]\d{2})?(\s+e\s+(mezza|un quarto|quarto))?/i, ' ')
        .replace(new RegExp("\\b(tra|fra|in|dopo)\\s+(" + NUM + "['\\s]*" + UNIT + "(\\s+e\\s+(mezz[ao]\\b)?)?)+", 'gi'), ' ')
        .replace(/\b(tra|fra) (mezz['\s]?ora|un quarto d['\s]?ora)/i, ' ')
        .replace(/\b(metti un |crea un |imposta un )?promemoria( per)?\b|\bricordami\b|\bricorda di\b/gi, ' ')
        .replace(/\bdomani\b/i, ' ')
        .replace(/\s+/g, ' ').trim()
        .replace(/^(di|che|per)\s+/i, '').trim();
      if (at == null) return { type: 'reminder-incomplete', text: what };
      return { type: 'reminder', text: what || 'il tuo promemoria', at };
    }

    if (/\b(pomodoro|focus|concentrar(mi|si)|studiare|studio)\b/.test(t)) {
      return { type: 'timer', ms: parseDuration(t) || 25 * 6e4, label: 'Focus' };
    }

    const dur = parseDuration(t);
    if (/\b(timer|conto alla rovescia|sveglia|avvisami|countdown)\b/.test(t) || (dur && /^(\d|un|uno|una|due|tre|cinque|dieci|mezz)/.test(t))) {
      if (!dur) return { type: 'timer-incomplete' };
      const label = (t.match(/\bper (la |il |lo |le |i |l )?([a-z ]{3,30})$/) || [])[2];
      return { type: 'timer', ms: dur, label: label ? label.trim() : 'Timer' };
    }

    const calc = t.match(/^(?:quanto fa|quanto e|calcola|calcolami)\s+(.+)$/);
    if (calc) { const v = calculate(calc[1]); return v == null ? { type: 'unknown' } : { type: 'calc', expr: calc[1], value: v }; }
    if (/^[\d\s.,+\-*/x:^%()]+$/.test(t) && /\d\s*[+\-*/x:^]\s*\d/.test(t)) {
      const v = calculate(t); if (v != null) return { type: 'calc', expr: t, value: v };
    }

    if (/\b(ho bevuto|bevuto|bicchier[ei]|acqua)\b/.test(t)) {
      const n = (t.match(/\b(\d+|un|uno|due|tre|quattro|cinque)\s+bicchier/) || [])[1];
      return { type: 'water', delta: n ? toNumber(n) : 1 };
    }
    if (/\bpassword\b/.test(t)) {
      const n = +((t.match(/\b(\d{1,2})\b/) || [])[1] || 16);
      return { type: 'password', length: Math.min(64, Math.max(8, n)) };
    }
    if (/\bche (ore|ora) (sono|e)\b|\bche ora\b|\bche ore\b/.test(t)) return { type: 'time' };
    if (/\bche giorno\b|\bche data\b|\bdata di oggi\b/.test(t)) return { type: 'date' };
    if (/\b(lancia|tira)\b.*\bmoneta\b|\btesta o croce\b/.test(t)) return { type: 'coin' };
    if (/\b(lancia|tira)\b.*\bdad[oi]\b/.test(t)) return { type: 'dice' };
    if (/\b(barzellett[ae]|battuta|fammi ridere)\b/.test(t)) return { type: 'joke' };
    if (/\b(personalizza|impostazioni|cambia colore|cambia look)\b/.test(t)) return { type: 'settings' };
    if (/\b(buonanotte|vai a dormire|dormi|riposati)\b/.test(t)) return { type: 'sleep' };
    if (/\b(come ti chiami|chi sei|cosa sei)\b/.test(t)) return { type: 'whoami' };
    if (/\b(cosa sai fare|aiuto|help|comandi)\b/.test(t)) return { type: 'help' };
    if (/\b(grazie|grazie mille|ti adoro|sei brava|brava)\b/.test(t)) return { type: 'thanks' };
    if (/\b(stanc[oa]|triste|stress|ansia|giu di morale)\b/.test(t)) return { type: 'comfort' };
    if (/^(ciao|ehi|hey|buongiorno|buonasera|salve|we)\b/.test(t)) return { type: 'greet' };
    return { type: 'unknown', text: raw };
  }

  function formatDuration(ms) {
    const s = Math.max(0, Math.round(ms / 1000));
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
    const parts = [];
    if (h) parts.push(h + (h === 1 ? ' ora' : ' ore'));
    if (m) parts.push(m + (m === 1 ? ' minuto' : ' minuti'));
    if (sec && !h) parts.push(sec + (sec === 1 ? ' secondo' : ' secondi'));
    return parts.join(' e ') || '0 secondi';
  }

  function formatClock(ms) {
    const s = Math.max(0, Math.ceil(ms / 1000));
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60, p = n => String(n).padStart(2, '0');
    return (h ? h + ':' + p(m) : m) + ':' + p(sec);
  }

  const api = { parse, parseDuration, parseClock, calculate, normalize, formatDuration, formatClock };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ZoeCommands = api;
})(typeof window !== 'undefined' ? window : globalThis);
