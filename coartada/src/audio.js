// Música y efectos generados en el momento con WebAudio (sin archivos de sonido).
// La música es un pequeño secuenciador por pasos con tres ambientes: «menu», «juego» y «final».

const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);

export function crearAudio(prefs) {
  let ctx = null, maestro, busMusica, busSfx, ruido, ambiente = null, deseado = null, temporizador = null, paso = 0, proximo = 0;
  const activo = () => ctx && ctx.state === "running";

  function iniciar() {
    if (ctx) return;
    const C = window.AudioContext || window.webkitAudioContext;
    if (!C) return;
    ctx = new C();
    maestro = ctx.createDynamicsCompressor(); maestro.threshold.value = -14; maestro.ratio.value = 6; maestro.connect(ctx.destination);
    busMusica = ctx.createGain(); busMusica.gain.value = 0; busMusica.connect(maestro);
    busSfx = ctx.createGain(); busSfx.gain.value = 0.9; busSfx.connect(maestro);
    const n = ctx.sampleRate, buf = ctx.createBuffer(1, n, n), d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    ruido = buf;
  }
  /** Los navegadores solo dejan sonar tras un toque: se llama en el primer gesto. */
  function desbloquear() {
    iniciar();
    if (!ctx) return;
    if (ctx.state === "suspended") ctx.resume();
    if (deseado && deseado !== ambiente) musica(deseado);
  }

  // ---------- Instrumentos ----------
  function env(g, t, a, pico, d) { g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(pico, t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); }
  function tono(bus, tipo, f, t, a, pico, d, { corte = 0, hasta = 0, desafina = 0 } = {}) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = tipo; o.frequency.setValueAtTime(f, t); o.detune.value = desafina;
    if (hasta) o.frequency.exponentialRampToValueAtTime(hasta, t + a + d);
    env(g, t, a, pico, d);
    if (corte) { const fl = ctx.createBiquadFilter(); fl.type = "lowpass"; fl.frequency.value = corte; o.connect(fl); fl.connect(g); } else o.connect(g);
    g.connect(bus); o.start(t); o.stop(t + a + d + 0.05);
  }
  function soplo(bus, t, dur, pico, tipo, f, { hasta = 0, a = 0.005 } = {}) {
    const s = ctx.createBufferSource(), fl = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = ruido; s.loop = true; fl.type = tipo; fl.frequency.setValueAtTime(f, t);
    if (hasta) fl.frequency.exponentialRampToValueAtTime(hasta, t + dur);
    env(g, t, a, pico, dur);
    s.connect(fl); fl.connect(g); g.connect(bus); s.start(t, Math.random()); s.stop(t + a + dur + 0.05);
  }
  const bajo = (m, t, d = 0.32, v = 0.5) => { tono(busMusica, "triangle", hz(m), t, 0.012, v, d, { corte: 700 }); tono(busMusica, "sine", hz(m - 12), t, 0.012, v * 0.6, d); };
  const teclas = (notas, t, d = 0.5, v = 0.11) => notas.forEach((m) => { tono(busMusica, "sine", hz(m), t, 0.012, v, d, { desafina: 5 }); tono(busMusica, "triangle", hz(m), t, 0.012, v * 0.45, d * 0.7, { desafina: -6, corte: 1800 }); });
  const vibra = (m, t, v = 0.13) => { tono(busMusica, "sine", hz(m), t, 0.004, v, 1.1); tono(busMusica, "sine", hz(m + 24), t, 0.004, v * 0.18, 0.35); };
  const plato = (t, v = 0.05) => soplo(busMusica, t, 0.05, v, "highpass", 7500);
  const escoba = (t, v = 0.07) => soplo(busMusica, t, 0.14, v, "bandpass", 2600);
  const bombo = (t, v = 0.5) => tono(busMusica, "sine", 130, t, 0.004, v, 0.16, { hasta: 42 });
  const tic = (t, v = 0.05) => tono(busMusica, "square", 1900, t, 0.002, v, 0.025, { corte: 4000 });

  // ---------- Ambientes: fn(paso de semicorchea, tiempo, duración del paso) ----------
  const AMB = {
    // Jazz de detective relajado: Dm9 | G13 | Cmaj9 | A7
    menu: { bpm: 96, swing: 0.16, vol: 0.5, fn(p, t, d) {
      const compas = Math.floor(p / 16) % 4, s = p % 16;
      const acordes = [[62, 65, 69, 72, 76], [55, 59, 65, 69, 76], [60, 64, 67, 71, 74], [57, 61, 67, 70, 76]][compas];
      const caminos = [[38, 41, 45, 44], [43, 47, 50, 49], [36, 40, 43, 44], [45, 49, 52, 39]][compas];
      if (s % 4 === 0) bajo(caminos[s / 4], t, d * 3.4);
      if (s % 2 === 0) plato(t, s % 4 === 0 ? 0.045 : 0.028);
      if (s === 4 || s === 12) escoba(t);
      if (s === 3 || s === 10) teclas(acordes.slice(1), t, d * 3, 0.085);
      if (s === 0 && compas % 2 === 0) vibra(acordes[4] + 12, t);
      if ((s === 6 || s === 14) && Math.random() < 0.45) vibra(acordes[1 + Math.floor(Math.random() * 3)] + 12, t, 0.09);
    } },
    // Tensión: pedal en La menor, tic-tac y un motivo que sube
    juego: { bpm: 108, swing: 0, vol: 0.42, fn(p, t, d) {
      const compas = Math.floor(p / 16) % 4, s = p % 16;
      const raiz = [45, 45, 41, 43][compas];
      if (s % 2 === 0) bajo(raiz + [0, 0, 12, 0, 7, 0, 10, 0][s / 2], t, d * 1.6, 0.36);
      if (s % 4 === 0) tic(t, 0.06); else if (s % 4 === 2) tic(t, 0.025);
      if (s === 0) { bombo(t, 0.4); teclas([raiz + 24, raiz + 27, raiz + 31], t, d * 14, 0.04); }
      if (s === 8) bombo(t, 0.28);
      if (compas === 3 && s >= 8 && s % 2 === 0) vibra(69 + [0, 3, 7, 12][(s - 8) / 2], t, 0.08);
      if (compas === 1 && (s === 6 || s === 14)) vibra(s === 6 ? 76 : 75, t, 0.07);
    } },
    // Fiesta: Do – Fa – Sol – Do con arpegios
    final: { bpm: 126, swing: 0.1, vol: 0.5, fn(p, t, d) {
      const compas = Math.floor(p / 16) % 4, s = p % 16;
      const raiz = [48, 53, 55, 48][compas], tri = [0, 4, 7, 12];
      if (s % 4 === 0) { bajo(raiz - 12 + (s === 8 ? 7 : 0), t, d * 3); bombo(t, 0.42); }
      if (s % 4 === 2) plato(t, 0.05);
      if (s === 4 || s === 12) escoba(t, 0.1);
      if (s % 2 === 0) vibra(raiz + 12 + tri[(s / 2) % 4], t, 0.09);
      if (s === 0) teclas([raiz + 12, raiz + 16, raiz + 19], t, d * 6, 0.07);
    } },
  };

  function planificar() {
    if (!activo() || !ambiente) return;
    const a = AMB[ambiente], dur = 60 / a.bpm / 4;
    if (proximo < ctx.currentTime) proximo = ctx.currentTime + 0.05; // tras una pausa larga no se acumulan notas
    while (proximo < ctx.currentTime + 0.22) {
      a.fn(paso, proximo + (paso % 2 ? dur * a.swing : 0), dur);
      paso++; proximo += dur;
    }
  }
  /** Cambia el ambiente musical («menu», «juego», «final») o lo apaga con null. */
  function musica(nombre) {
    deseado = nombre;
    if (!ctx) return;
    const quiere = prefs().musica && nombre ? nombre : null;
    if (quiere === ambiente) { if (quiere) busMusica.gain.setTargetAtTime(AMB[quiere].vol, ctx.currentTime, 0.3); return; }
    const t = ctx.currentTime;
    busMusica.gain.cancelScheduledValues(t);
    busMusica.gain.setTargetAtTime(0, t, 0.12);
    clearInterval(temporizador); temporizador = null;
    ambiente = quiere;
    if (!quiere) return;
    paso = 0; proximo = t + 0.45;
    busMusica.gain.setTargetAtTime(AMB[quiere].vol, t + 0.45, 0.4);
    temporizador = setInterval(planificar, 60);
  }

  // ---------- Efectos ----------
  const SFX = {
    toque: (t) => tono(busSfx, "sine", 520, t, 0.004, 0.18, 0.07, { hasta: 880 }),
    elegir: (t) => { tono(busSfx, "triangle", 660, t, 0.004, 0.2, 0.08); tono(busSfx, "triangle", 990, t + 0.06, 0.004, 0.16, 0.1); },
    pop: (t) => tono(busSfx, "sine", 300, t, 0.004, 0.25, 0.09, { hasta: 900 }),
    carta: (t) => { soplo(busSfx, t, 0.28, 0.22, "bandpass", 600, { hasta: 4200, a: 0.03 }); tono(busSfx, "sine", 440, t + 0.2, 0.004, 0.12, 0.2, { hasta: 880 }); },
    sello: (t) => { tono(busSfx, "sine", 150, t, 0.003, 0.9, 0.2, { hasta: 38 }); soplo(busSfx, t, 0.12, 0.4, "lowpass", 900); },
    choque: (t) => { tono(busSfx, "sawtooth", 196, t, 0.005, 0.2, 0.32, { corte: 1500 }); tono(busSfx, "sawtooth", 208, t, 0.005, 0.2, 0.32, { corte: 1500 }); soplo(busSfx, t, 0.1, 0.25, "highpass", 3000); },
    bien: (t) => [72, 76, 79, 84].forEach((m, i) => tono(busSfx, "triangle", hz(m), t + i * 0.08, 0.004, 0.2, 0.3)),
    mal: (t) => [63, 59, 55].forEach((m, i) => tono(busSfx, "sawtooth", hz(m), t + i * 0.16, 0.01, 0.16, 0.3, { corte: 1200 })),
    turno: (t) => { tono(busSfx, "sine", hz(79), t, 0.004, 0.2, 0.25); tono(busSfx, "sine", hz(84), t + 0.14, 0.004, 0.2, 0.4); },
    mensaje: (t) => tono(busSfx, "sine", 700, t, 0.004, 0.12, 0.06, { hasta: 1100 }),
    voto: (t) => { tono(busSfx, "sine", 220, t, 0.004, 0.35, 0.12, { hasta: 110 }); },
    redoble: (t) => { for (let i = 0; i < 22; i++) soplo(busSfx, t + i * 0.06, 0.05, 0.08 + i * 0.012, "bandpass", 1800); },
    revelar: (t) => { soplo(busSfx, t, 0.9, 0.3, "highpass", 5000, { a: 0.02 }); [57, 64, 69, 73].forEach((m) => tono(busSfx, "sawtooth", hz(m), t, 0.01, 0.13, 0.9, { corte: 2200 })); tono(busSfx, "sine", 110, t, 0.004, 0.7, 0.3, { hasta: 40 }); },
    fanfarria: (t) => [[60, 0], [64, 0.12], [67, 0.24], [72, 0.36], [67, 0.56], [72, 0.68]].forEach(([m, d]) => { tono(busSfx, "sawtooth", hz(m), t + d, 0.01, 0.16, d > 0.6 ? 0.7 : 0.16, { corte: 2600 }); tono(busSfx, "square", hz(m + 12), t + d, 0.01, 0.04, 0.14, { corte: 3000 }); }),
    tic: (t) => tono(busSfx, "square", 1500, t, 0.002, 0.1, 0.03, { corte: 3500 }),
  };
  /** Reproduce un efecto, opcionalmente con retraso en segundos. */
  function sfx(nombre, retraso = 0) {
    if (!activo() || !prefs().sonido || !SFX[nombre]) return;
    try { SFX[nombre](ctx.currentTime + 0.01 + retraso); } catch (e) { /* el audio nunca debe romper el juego */ }
  }

  if (typeof document !== "undefined") {
    document.addEventListener("visibilitychange", () => {
      if (!ctx) return;
      if (document.hidden) ctx.suspend(); else if (prefs().musica || prefs().sonido) ctx.resume();
    });
  }
  return { desbloquear, musica, sfx, refrescar: () => musica(deseado) };
}
