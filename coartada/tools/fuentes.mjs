// Incrusta las tipografías en www/fonts.css como datos en base64.
// Un WebView que abre archivos locales no puede cargar fuentes por ruta (lo bloquea CORS).
import fs from "node:fs";
const b64 = (p) => fs.readFileSync(new URL(p, import.meta.url)).toString("base64");
const css = `/* Generado por tools/fuentes.mjs. Lilita One y Nunito: SIL Open Font License 1.1. */
@font-face { font-family: "Lilita"; src: url(data:font/woff2;base64,${b64("../node_modules/@fontsource/lilita-one/files/lilita-one-latin-400-normal.woff2")}) format("woff2"); font-display: swap; }
@font-face { font-family: "Nunito"; src: url(data:font/woff2;base64,${b64("../node_modules/@fontsource-variable/nunito/files/nunito-latin-wght-normal.woff2")}) format("woff2"); font-weight: 200 1000; font-display: swap; }
`;
fs.writeFileSync(new URL("../www/fonts.css", import.meta.url), css);
