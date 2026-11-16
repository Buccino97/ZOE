/* ZOE – app logic for the strip: hover, commands, timers, reminders, water, mood. */
(function () {
  'use strict';
  const api = window.zoe;
  const M = window.ZoeMascot;
  const C = window.ZoeCommands;
  const $ = id => document.getElementById(id);

  const strip = $('strip'), panel = $('panel'), cmd = $('cmd'), msg = $('msg'), toast = $('toast');
  const mini = $('miniZoe'), big = $('bigZoe'), fly = $('fly'), settingsEl = $('settings');

  const HOUR = 36e5, MIN = 6e4;
  const SLEEP_AFTER = 3 * MIN;

  let settings = { name: 'ZOE', color: M.COLORS[0], eyes: 'tondi', acc: 'nessuno', wellness: true };
  let water = { date: today(), count: 0 };
  let reminders = [];
  let timer = null;               // { end, total, label }
  let mood = 'felice', moodTimer = null, sleeping = false;
  let lastActivity = Date.now(), lastWater = Date.now(), lastNudge = Date.now();
  let cursor = { x: -999, y: -999 }, inside = false, closeTimer = null, toastTimer = null;
  let flyState = null, nextFly = Date.now() + rand(4, 8) * MIN;

  function today() { const d = new Date(); return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate(); }
  function rand(a, b) { return a + Math.random() * (b - a); }
  function pick(list) { return list[Math.floor(Math.random() * list.length)]; }
  function hhmm(ts) { return new Date(ts).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }); }
  function when(ts) {
    const d = new Date(ts), now = new Date();
    if (ts - now.getTime() < HOUR && ts > now.getTime()) return 'tra ' + C.formatDuration(Math.round((ts - now.getTime()) / MIN) * MIN || MIN);
    const sameDay = d.toDateString() === now.toDateString();
    const tomorrow = new Date(now); tomorrow.setDate(now.getDate() + 1);
    return (sameDay ? 'oggi' : d.toDateString() === tomorrow.toDateString() ? 'domani' : d.toLocaleDateString('it-IT')) + ' alle ' + hhmm(ts);
  }

  /* ---------- Mascot ---------- */
  function draw() {
    const shown = sleeping ? 'dorme' : mood;
    M.render(mini, { ...settings, acc: 'nessuno', expr: shown });
    M.render(big, { ...settings, expr: shown });
  }
  function setMood(expr, ms) {
    mood = expr; clearTimeout(moodTimer);
    if (ms) moodTimer = setTimeout(() => { mood = 'felice'; draw(); }, ms);
    draw();
  }
  function bounce() { mini.classList.remove('bounce'); void mini.getBBox(); mini.classList.add('bounce'); }

  /* ---------- Talking ---------- */
  function say(text, expr, ms) {
    ms = ms || 6000;
    msg.textContent = text;
    if (expr) setMood(expr, ms);
    if (!strip.classList.contains('open')) {
      toast.textContent = text; toast.hidden = false;
      clearTimeout(toastTimer); toastTimer = setTimeout(() => { toast.hidden = true; }, ms);
      bounce();
    }
  }

  /* ---------- Open / close ---------- */
  const isOpen = () => strip.classList.contains('open');
  const pinned = () => document.activeElement === cmd || document.activeElement === $('nameInput') || !settingsEl.hidden;
  function open() {
    clearTimeout(closeTimer);
    if (!isOpen()) { strip.classList.add('open'); toast.hidden = true; }
    wake();
  }
  function close(force) {
    if (!force && pinned()) return;
    strip.classList.remove('open', 'with-settings');
    settingsEl.hidden = true;
  }
  function openSettings() { open(); settingsEl.hidden = false; strip.classList.add('with-settings'); strip.scrollTop = 0; }
  function closeSettings() { settingsEl.hidden = true; strip.classList.remove('with-settings'); strip.scrollTop = 0; }

  function hitTest(p) {
    const r = strip.getBoundingClientRect(), pad = 4;
    return p.x >= r.left - pad && p.x <= r.right + pad && p.y >= r.top - pad && p.y <= r.bottom + pad;
  }

  api.on('cursor', p => {
    const moved = Math.abs(p.x - cursor.x) + Math.abs(p.y - cursor.y) > 2;
    cursor = p;
    const now = hitTest(p);
    if (now !== inside) {
      inside = now;
      api.setInteractive(now);
      if (now) open();
      else { clearTimeout(closeTimer); closeTimer = setTimeout(() => close(false), 350); }
    }
    // Moving the mouse close to the strip counts as being around.
    if (moved && p.y < 260 && p.x > 0 && p.x < innerWidth) lastActivity = Date.now();
    if (!flyState && !sleeping) { M.lookToward(mini, p.x, p.y); M.lookToward(big, p.x, p.y); }
  });

  window.addEventListener('blur', () => { if (!inside) close(true); });
  api.on('open-command', () => { open(); closeSettings(); setTimeout(() => cmd.focus(), 30); });
  api.on('open-settings', () => openSettings());

  /* ---------- Sleep / wake ---------- */
  function wake() {
    lastActivity = Date.now();
    if (sleeping) { sleeping = false; setMood('sorpresa', 1200); msg.textContent = pick(['Eh? Ero sveglia, giuro!', 'Mi ero solo appisolata un attimo…', 'Eccomi!']); }
  }
  function sleep() { sleeping = true; draw(); }

  /* ---------- Timer ---------- */
  function startTimer(ms, label) { timer = { end: Date.now() + ms, total: ms, label }; renderTimer(); }
  function stopTimer() { timer = null; renderTimer(); }
  function renderTimer() {
    const t = $('timerText'), stop = $('timerStop'), prog = $('timerProg'), status = $('status');
    if (!timer) { t.textContent = 'Nessuno'; stop.hidden = true; prog.style.width = '0'; status.textContent = ''; return; }
    const left = timer.end - Date.now();
    const label = timer.label === 'Timer' ? '' : timer.label + ' ';
    t.textContent = label + C.formatClock(left);
    status.textContent = '⏱ ' + C.formatClock(left);
    stop.hidden = false;
    prog.style.width = (100 - left / timer.total * 100).toFixed(1) + '%';
  }

  /* ---------- Reminders ---------- */
  function renderReminders() {
    const ul = $('remList');
    reminders.sort((a, b) => a.at - b.at);
    if (!reminders.length) { ul.innerHTML = '<li class="empty">Nessun promemoria. Prova «ricordami di chiamare Luca alle 18».</li>'; return; }
    ul.textContent = '';
    reminders.forEach(r => {
      const li = document.createElement('li');
      const s = document.createElement('span'); s.textContent = r.text;
      const t = document.createElement('time'); t.textContent = when(r.at);
      const x = document.createElement('button'); x.textContent = '✕'; x.title = 'Elimina';
      x.onclick = () => { reminders = reminders.filter(q => q.id !== r.id); saveReminders(); };
      li.append(s, t, x); ul.appendChild(li);
    });
  }
  function saveReminders() { api.save('reminders', reminders); renderReminders(); }

  /* ---------- Water ---------- */
  function renderWater() {
    document.querySelectorAll('.wcount').forEach(n => { n.textContent = water.count; });
    $('waterProg').style.width = Math.min(100, water.count / 8 * 100) + '%';
  }
  function addWater(n) {
    if (water.date !== today()) water = { date: today(), count: 0 };
    water.count = Math.max(0, water.count + n);
    lastWater = Date.now();
    api.save('water', water); renderWater();
    if (water.count === 8) say('8 bicchieri! Obiettivo di oggi raggiunto 🎉', 'emozionata');
    else if (water.count > 8) say('Wow, ' + water.count + ' bicchieri. Idratazione livello pro 💧', 'ride');
    else say(pick(['Glu glu! 💧', 'Brava/o! Ancora ' + (8 - water.count) + ' e ci siamo.', 'Segnato: ' + water.count + ' su 8.']), 'ride', 3000);
  }

  /* ---------- Commands ---------- */
  const JOKES = [
    'Perché il computer è andato dal dottore? Aveva un virus… ma non voleva fare il backup!',
    'Sai qual è il colmo per un\'assistente digitale? Perdere il filo del discorso… senza Wi-Fi!',
    'Ho provato a contare le stelle, ma alla terza sono andata in risparmio energetico.',
    'Il mio cursore preferito? Quello che fa sempre "clic" con me. 😄'
  ];
  function password(len) {
    const cs = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*?';
    const a = new Uint32Array(len); crypto.getRandomValues(a);
    return Array.from(a, v => cs[v % cs.length]).join('');
  }
  function greeting() { const h = new Date().getHours(); return h < 13 ? 'Buongiorno' : h < 18 ? 'Buon pomeriggio' : 'Buonasera'; }

  function run(text) {
    const it = C.parse(text, Date.now());
    wake();
    switch (it.type) {
      case 'empty': return;
      case 'timer':
        startTimer(it.ms, it.label);
        return say((it.label === 'Focus' ? 'Modalità focus: ' : 'Timer di ') + C.formatDuration(it.ms) + '. Ti avviso io ⏱️', it.label === 'Focus' ? 'pensierosa' : 'occhiolino');
      case 'timer-incomplete': return say('Di quanto? Per esempio «timer 10 minuti».', 'confusa');
      case 'timer-cancel':
        if (!timer) return say('Non c\'è nessun timer attivo.', 'pensierosa');
        stopTimer(); return say('Timer annullato.', 'contenta');
      case 'reminder':
        reminders.push({ id: Date.now() + Math.random(), text: it.text, at: it.at }); saveReminders();
        return say('Segnato! ' + when(it.at) + ' ti ricordo: ' + it.text + ' 📌', 'occhiolino');
      case 'reminder-incomplete': return say('Quando te lo ricordo? Per esempio «… alle 18» o «… tra 20 minuti».', 'confusa');
      case 'reminder-clear': reminders = []; saveReminders(); return say('Ho cancellato tutti i promemoria.', 'contenta');
      case 'calc': return say(it.expr + ' = ' + it.value.toLocaleString('it-IT', { maximumFractionDigits: 6 }), 'pensierosa');
      case 'water': return addWater(it.delta);
      case 'password': {
        const pw = password(it.length); api.copy(pw);
        return say('Fatto, l\'ho copiata negli appunti 🔐 ' + pw, 'occhiolino', 9000);
      }
      case 'time': return say('Sono le ' + hhmm(Date.now()) + '.', 'contenta');
      case 'date': return say('Oggi è ' + new Date().toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long' }) + '.', 'contenta');
      case 'coin': return say(pick(['Testa!', 'Croce!']) + ' 🪙', 'emozionata');
      case 'dice': return say('È uscito ' + (1 + Math.floor(Math.random() * 6)) + '! 🎲', 'emozionata');
      case 'joke': return say(pick(JOKES), 'ride', 9000);
      case 'settings': return openSettings();
      case 'sleep': say('Buonanotte… 💤', 'assonnata', 1500); setTimeout(sleep, 1500); return;
      case 'whoami': return say('Sono ' + settings.name + ', la tua amica in cima allo schermo!', 'innamorata');
      case 'help': return say('So fare timer e focus, promemoria, contare l\'acqua, calcoli, password, testa o croce e barzellette. La voce e l\'IA arrivano presto!', 'felice', 9000);
      case 'thanks': return say(pick(['Figurati! 💜', 'Quando vuoi!', 'Per te questo e altro.']), 'innamorata');
      case 'comfort': return say('Fai una pausa di 5 minuti: alzati, bevi un po\' d\'acqua e guarda lontano dallo schermo. Io resto qui 💜', 'triste', 8000);
      case 'greet': return say(greeting() + '! Cosa facciamo?', 'ride', 3000);
      default: return say('Non ho capito… L\'IA arriva nella prossima versione! Intanto prova «cosa sai fare».', 'confusa');
    }
  }

  $('cmdForm').addEventListener('submit', e => { e.preventDefault(); const v = cmd.value; cmd.value = ''; run(v); });
  cmd.addEventListener('keydown', e => {
    if (e.key === 'Escape') { cmd.value = ''; cmd.blur(); close(true); api.release(); }
  });
  panel.addEventListener('click', e => { const b = e.target.closest('[data-cmd]'); if (b) run(b.dataset.cmd); });
  $('timerStop').addEventListener('click', () => run('stop timer'));
  $('gearBtn').addEventListener('click', () => (settingsEl.hidden ? openSettings() : closeSettings()));
  $('closeSettings').addEventListener('click', closeSettings);
  $('quitBtn').addEventListener('click', () => api.quit());
  mini.addEventListener('click', () => { setMood(pick(['ride', 'occhiolino', 'innamorata']), 1500); bounce(); });
  big.addEventListener('click', () => { setMood(pick(['ride', 'occhiolino', 'innamorata', 'emozionata']), 1500); msg.textContent = pick(['Ehi, mi fai il solletico! 😆', 'Sono qui!', 'Che si fa?']); });

  /* ---------- Settings ---------- */
  function saveSettings() { api.save('settings', settings); draw(); }
  function buildSettings() {
    const mark = (box, btn) => box.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === btn));
    const color = $('optColor'), eyes = $('optEyes'), acc = $('optAcc');
    M.COLORS.forEach(c => {
      const b = document.createElement('button'); b.className = 'sw' + (c === settings.color ? ' on' : '');
      b.style.background = c; b.title = c; b.onclick = () => { settings.color = c; mark(color, b); saveSettings(); };
      color.appendChild(b);
    });
    M.EYE_STYLES.forEach(k => {
      const b = document.createElement('button'); b.className = 'opt' + (k === settings.eyes ? ' on' : '');
      b.textContent = k; b.onclick = () => { settings.eyes = k; mark(eyes, b); saveSettings(); };
      eyes.appendChild(b);
    });
    M.ACCESSORIES.forEach(k => {
      const b = document.createElement('button'); b.className = 'opt' + (k === settings.acc ? ' on' : '');
      b.textContent = k; b.onclick = () => { settings.acc = k; mark(acc, b); saveSettings(); };
      acc.appendChild(b);
    });
    const ni = $('nameInput'); ni.value = settings.name;
    ni.addEventListener('input', () => { settings.name = ni.value.trim() || 'ZOE'; api.save('settings', settings); });
    ni.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === 'Escape') ni.blur(); });
    const wl = $('optWellness'); wl.checked = settings.wellness !== false;
    wl.addEventListener('change', () => { settings.wellness = wl.checked; api.save('settings', settings); });
  }

  /* ---------- The fly ---------- */
  function startFly() {
    flyState = { t0: performance.now(), dur: 11000, seed: Math.random() * 10 };
    fly.hidden = false;
  }
  function stepFly(now) {
    if (!flyState) return;
    const t = (now - flyState.t0) / 1000, s = flyState.seed;
    const x = innerWidth / 2 + Math.sin(t * 1.3 + s) * 220 + Math.sin(t * 5.1) * 16;
    const y = 90 + Math.sin(t * 2.1 + s) * 34 + Math.cos(t * 6.3) * 8 + (isOpen() ? 260 - 90 : 0);
    fly.style.transform = `translate(${x.toFixed(1)}px, ${y.toFixed(1)}px)`;
    M.lookToward(mini, x, y); M.lookToward(big, x, y);
    if (now - flyState.t0 > flyState.dur) {
      flyState = null; fly.hidden = true;
      say(pick(['Presa! 🪰', 'Uffa, è scappata…', 'Quella mosca mi sfida ogni giorno.']), pick(['ride', 'arrabbiata', 'emozionata']), 3500);
      nextFly = Date.now() + rand(5, 10) * MIN;
    }
  }

  /* ---------- Loops ---------- */
  function tick() {
    const now = Date.now();
    $('clock').textContent = hhmm(now);
    if (water.date !== today()) { water = { date: today(), count: 0 }; api.save('water', water); renderWater(); }

    if (timer) {
      if (now >= timer.end) {
        const label = timer.label; stopTimer();
        api.notify('⏰ ' + (label === 'Timer' ? 'Timer finito' : label), label === 'Focus' ? 'Sessione finita! Ti meriti 5 minuti di pausa.' : 'Il tempo è scaduto!');
        wake(); say(label === 'Focus' ? 'Focus finito! Pausa di 5 minuti? ☕' : 'Tempo scaduto! ⏰', 'emozionata', 10000);
      } else renderTimer();
    }

    const due = reminders.filter(r => r.at <= now);
    if (due.length) {
      reminders = reminders.filter(r => r.at > now); saveReminders();
      due.forEach(r => api.notify('📌 Promemoria', r.text));
      wake(); say('Ehi! Ricordati: ' + due.map(r => r.text).join(', '), 'sorpresa', 12000);
    }

    const h = new Date(now).getHours();
    if (settings.wellness !== false && h >= 9 && h < 22 && water.count < 8 && now - lastWater > HOUR && now - lastNudge > HOUR) {
      lastNudge = now; say('Un bicchiere d\'acqua? 💧 Dimmi «ho bevuto» quando hai fatto.', 'occhiolino', 9000);
    }

    if (!sleeping && !timer && !isOpen() && now - lastActivity > SLEEP_AFTER) sleep();
    if (!flyState && !sleeping && !isOpen() && now > nextFly) startFly();
  }
  function frame(now) { stepFly(now); requestAnimationFrame(frame); }

  /* ---------- Start ---------- */
  api.load().then(data => {
    if (data.settings) settings = { ...settings, ...data.settings };
    if (data.water && data.water.date === today()) water = data.water;
    if (Array.isArray(data.reminders)) reminders = data.reminders.filter(r => r && typeof r.at === 'number' && r.text);
    buildSettings(); draw(); renderWater(); renderReminders(); renderTimer(); tick();
    setInterval(tick, 500);
    requestAnimationFrame(frame);
    say(greeting() + '! Sono ' + settings.name + ' 👋 Passa qui sopra o premi Ctrl+Shift+Spazio.', 'ride', 7000);
  });

  // Hooks for automated checks (harmless in normal use).
  window.ZOE_DEBUG = { run, open, close, openSettings, startFly, sleep, wake, get state() { return { settings, water, reminders, timer, sleeping }; } };
})();
