# Cómo generar el .apk paso a paso

El proyecto ya trae `export_presets.cfg` con un preset llamado **Android**: APK (sin Gradle),
arm64-v8a + armeabi-v7a, horizontal, pantalla completa y permiso de vibración.

## 1. Instalar lo necesario (una sola vez)

1. **Godot 4.3 estable** (versión normal, no la de .NET):
   https://godotengine.org/download/archive/4.3-stable/
2. **JDK 17** (OpenJDK). Sirve Eclipse Temurin 17: https://adoptium.net/
3. **Android SDK**. La forma más fácil es instalar **Android Studio**
   (https://developer.android.com/studio). Después, en *SDK Manager*, instala:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools **34.0.0**
   - Android SDK Platform **34**
   - Android SDK Command-line Tools (latest)
   - NDK **23.2.8568313** (solo si algún día usas "Gradle build"; para este APK no hace falta)

   Si no quieres Android Studio: descarga las *command line tools* y ejecuta
   `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmdline-tools;latest"`.

## 2. Plantillas de exportación de Godot

Abre el proyecto en Godot → menú **Editor → Administrar plantillas de exportación** →
**Descargar e instalar** (versión 4.3.stable). Son ~1 GB.

## 3. Keystore (firma)

Para un APK de depuración, Godot crea uno solo la primera vez. Si quieres hacerlo a mano:

```bash
keytool -genkeypair -v -keystore debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
  -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Para una versión "release" (opcional, más ligera y rápida), crea tu propio keystore y **no lo
subas al repositorio** (el `.gitignore` ya ignora `*.keystore` y `*.jks`):

```bash
keytool -genkeypair -v -keystore golazo-release.keystore -alias golazo \
  -keyalg RSA -keysize 2048 -validity 10000
```

## 4. Configurar Godot

**Editor → Configuración del editor → Exportar → Android**:

| Campo | Valor (ejemplo en Windows) |
|---|---|
| Java SDK Path | `C:\Program Files\Eclipse Adoptium\jdk-17...` |
| Android SDK Path | `C:\Users\TU_USUARIO\AppData\Local\Android\Sdk` |
| Debug Keystore | ruta a `debug.keystore` |
| Debug Keystore User / Pass | `androiddebugkey` / `android` |

Para release: **Proyecto → Exportar → Android → Keystore → Release** (ruta, usuario y contraseña
de tu keystore). Esos datos se guardan en `.godot/export_credentials.cfg`, que no se sube.

## 5. Exportar

- Desde el editor: **Proyecto → Exportar… → Android → Exportar proyecto**, desmarca
  "Exportar con depuración" para release, y guarda como `build/GolazoPro3D.apk`.
- Desde la terminal:

```bash
godot --headless --path . --export-debug "Android" build/GolazoPro3D.apk
# o, con keystore de release configurado:
godot --headless --path . --export-release "Android" build/GolazoPro3D.apk
```

## 6. Instalar en el teléfono

- Copia el `.apk` al teléfono y ábrelo (activa "Instalar apps de origen desconocido"), o
- con cable USB y depuración USB activada: `adb install -r build/GolazoPro3D.apk`.

## Problemas frecuentes

- *"Unable to find Android SDK build-tools' apksigner"*: falta Build-Tools 34 en el SDK.
- *Pantalla negra al abrir en un móvil antiguo*: el teléfono no tiene Vulkan. El proyecto tiene
  activado `rendering_device/fallback_to_opengl3`, que usa OpenGL ES 3 automáticamente; si
  aun así falla, cambia en *Proyecto → Configuración → Renderizado → Renderer* a
  "gl_compatibility" y vuelve a exportar.
- *El APK pesa mucho*: desmarca `armeabi-v7a` en el preset si tu teléfono es de 64 bits
  (casi todos desde 2017); el APK baja a la mitad.

## Comprobación automática (para desarrollo)

```bash
# Partido IA contra IA sin pantalla (2 minutos reales por tiempo); imprime goles y estadísticas
godot --headless --fixed-fps 60 --path . -- --autotest
# Igual, con tiempos de 10 minutos
godot --headless --fixed-fps 60 --path . -- --autotest --half=10
# Simula entradas de un jugador humano (pases, presión, tiro, cambio de jugador)
godot --headless --fixed-fps 60 --path . -- --humantest
```
