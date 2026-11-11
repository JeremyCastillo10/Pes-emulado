// Cliente MQTT 3.1.1 mínimo sobre WebSocket: conectar, suscribirse y publicar con QoS 0.
// Se reconecta solo. Suficiente para las salas del juego y sin dependencias.

const enc = new TextEncoder();
const dec = new TextDecoder();

function longitud(n) {
  const out = [];
  do { let b = n % 128; n = Math.floor(n / 128); if (n > 0) b |= 0x80; out.push(b); } while (n > 0);
  return out;
}
function cadena(s) {
  const b = enc.encode(s);
  return [b.length >> 8, b.length & 0xff, ...b];
}
function paquete(cabecera, cuerpo) {
  return new Uint8Array([cabecera, ...longitud(cuerpo.length), ...cuerpo]);
}

/**
 * opciones: { url, testamento?: {tema, texto}, alConectar(), alMensaje(tema, texto), alEstado(conectado) }
 */
export function crearMqtt({ url, testamento, alConectar, alMensaje, alEstado }) {
  let ws = null, vivo = true, conectado = false, buf = new Uint8Array(0), idPaquete = 1;
  let latido = null, reintento = null, espera = 800, ultimoDato = 0;
  const temas = new Set();
  const cola = []; // publicaciones hechas mientras no hay conexión (solo la última por tema retenido)

  function enviar(bytes) {
    if (ws && ws.readyState === 1) { ws.send(bytes); return true; }
    return false;
  }
  function estado(v) { if (conectado !== v) { conectado = v; alEstado && alEstado(v); } }

  function abrir() {
    if (!vivo) return;
    clearTimeout(reintento);
    try { ws = new WebSocket(url, "mqtt"); } catch (e) { return programar(); }
    ws.binaryType = "arraybuffer";
    const propio = ws;
    const limite = setTimeout(() => { if (propio.readyState !== 1) { try { propio.close(); } catch (e) { /* ya cerrado */ } } }, 8000);
    ws.onopen = () => {
      clearTimeout(limite);
      const id = "coartada_" + Math.random().toString(36).slice(2, 12);
      let flags = 0x02; // sesión limpia
      const carga = [...cadena(id)];
      if (testamento) { flags |= 0x04 | 0x20; carga.push(...cadena(testamento.tema), ...cadena(testamento.texto)); } // testamento retenido
      propio.send(paquete(0x10, [...cadena("MQTT"), 4, flags, 0, 30, ...carga]));
    };
    ws.onmessage = (ev) => {
      if (propio !== ws) return;
      ultimoDato = Date.now();
      const nuevo = new Uint8Array(ev.data);
      const junto = new Uint8Array(buf.length + nuevo.length);
      junto.set(buf); junto.set(nuevo, buf.length); buf = junto;
      procesar();
    };
    ws.onclose = () => { clearTimeout(limite); if (propio === ws) { ws = null; cerrar(); programar(); } };
    ws.onerror = () => { /* onclose se encarga */ };
  }
  function cerrar() { clearInterval(latido); latido = null; buf = new Uint8Array(0); estado(false); }
  function programar() {
    if (!vivo) return;
    clearTimeout(reintento);
    reintento = setTimeout(abrir, espera);
    espera = Math.min(8000, espera * 1.7);
  }

  function procesar() {
    for (;;) {
      if (buf.length < 2) return;
      let mult = 1, largo = 0, i = 1, b;
      do {
        if (i >= buf.length) return; // cabecera incompleta
        b = buf[i++]; largo += (b & 0x7f) * mult; mult *= 128;
      } while (b & 0x80);
      if (buf.length < i + largo) return; // paquete incompleto
      const tipo = buf[0] >> 4, banderas = buf[0] & 0x0f, cuerpo = buf.subarray(i, i + largo);
      buf = buf.slice(i + largo);
      if (tipo === 2) { // CONNACK
        if (cuerpo[1] !== 0) { try { ws.close(); } catch (e) { /* ya cerrado */ } return; }
        espera = 800;
        estado(true);
        for (const t of temas) enviar(paquete(0x82, [idPaquete >> 8, idPaquete++ & 0xff, ...cadena(t), 0]));
        if (idPaquete > 60000) idPaquete = 1;
        clearInterval(latido);
        latido = setInterval(() => {
          if (Date.now() - ultimoDato > 50000) { try { ws.close(); } catch (e) { /* ya cerrado */ } return; }
          enviar(new Uint8Array([0xc0, 0]));
        }, 15000);
        while (cola.length) { const p = cola.shift(); publicar(p.tema, p.texto, p.retener); }
        alConectar && alConectar();
      } else if (tipo === 3) { // PUBLISH
        const lt = (cuerpo[0] << 8) | cuerpo[1];
        const tema = dec.decode(cuerpo.subarray(2, 2 + lt));
        const desde = 2 + lt + (((banderas >> 1) & 3) > 0 ? 2 : 0);
        let texto = "";
        try { texto = dec.decode(cuerpo.subarray(desde)); } catch (e) { continue; }
        try { alMensaje && alMensaje(tema, texto); } catch (e) { console.error(e); }
      }
      // SUBACK (9) y PINGRESP (13) no necesitan nada.
    }
  }

  function publicar(tema, texto, retener = false) {
    const ok = conectado && enviar(paquete(0x30 | (retener ? 1 : 0), [...cadena(tema), ...enc.encode(texto)]));
    if (!ok) {
      if (retener) { const i = cola.findIndex((p) => p.tema === tema && p.retener); if (i >= 0) cola.splice(i, 1); }
      if (cola.length < 60) cola.push({ tema, texto, retener });
    }
    return ok;
  }
  function suscribir(tema) {
    temas.add(tema);
    if (conectado) { enviar(paquete(0x82, [idPaquete >> 8, idPaquete++ & 0xff, ...cadena(tema), 0])); if (idPaquete > 60000) idPaquete = 1; }
  }
  function terminar() {
    vivo = false; clearTimeout(reintento); clearInterval(latido);
    if (ws) { try { enviar(new Uint8Array([0xe0, 0])); ws.close(); } catch (e) { /* ya cerrado */ } }
    ws = null; estado(false);
  }

  abrir();
  return { publicar, suscribir, terminar, get conectado() { return conectado; } };
}
