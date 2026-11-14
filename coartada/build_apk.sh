#!/usr/bin/env bash
# Compila releases/Coartada.apk con el SDK oficial de Android, sin Gradle.
# Requisitos: JDK 17+, Node 18+ y el SDK de Android (ANDROID_HOME) con
#   build-tools;35.0.0 y platforms;android-34
#   sdkmanager "build-tools;35.0.0" "platforms;android-34"
set -euo pipefail
cd "$(dirname "$0")"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$SDK" ] || { echo "Define ANDROID_HOME con la ruta del SDK de Android." >&2; exit 1; }
BT="$SDK/build-tools/${BUILD_TOOLS:-35.0.0}"
PLAT="$SDK/platforms/${PLATFORM:-android-34}/android.jar"
[ -x "$BT/aapt2" ] && [ -f "$PLAT" ] || { echo "Faltan build-tools o la plataforma en $SDK." >&2; exit 1; }

OUT=build
SALIDA="${1:-../releases/Coartada.apk}"
KS="${KEYSTORE:-firma-local.keystore}"
KS_PASS="${KEYSTORE_PASS:-coartada}"

echo "1/6 Empaquetando el juego (esbuild)"
[ -d node_modules ] || npm ci --no-audit --no-fund
npm run --silent build

echo "2/6 Recursos"
rm -rf "$OUT" && mkdir -p "$OUT/classes" "$OUT/dex" "$OUT/assets/www"
cp www/index.html www/style.css www/fonts.css www/app.js "$OUT/assets/www/"
"$BT/aapt2" compile --dir apk-src/res -o "$OUT/res.zip"
"$BT/aapt2" link -o "$OUT/base.apk" -I "$PLAT" --manifest apk-src/AndroidManifest.xml -A "$OUT/assets" "$OUT/res.zip"

echo "3/6 Código Java"
javac -nowarn -Xlint:-options --release 8 -cp "$PLAT" -d "$OUT/classes" $(find apk-src/java -name '*.java')

echo "4/6 DEX"
"$BT/d8" --release --min-api 23 --lib "$PLAT" --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
(cd "$OUT/dex" && zip -q -j ../base.apk classes.dex)

echo "5/6 Alineado"
"$BT/zipalign" -f -p 4 "$OUT/base.apk" "$OUT/alineado.apk"

echo "6/6 Firma"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias coartada \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Coartada, O=Uso personal" >/dev/null 2>&1
  echo "   Se creó una firma nueva en $KS (no se sube al repositorio)."
fi
mkdir -p "$(dirname "$SALIDA")"
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" --out "$SALIDA" "$OUT/alineado.apk"
"$BT/apksigner" verify --min-sdk-version 23 "$SALIDA"
rm -f "$SALIDA.idsig"
echo "Listo: $SALIDA ($(du -h "$SALIDA" | cut -f1))"
