#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = --help ]; then
  echo 'En Mac: bash tool/prepare_iphone.sh. Prepara y verifica solo el ensayo; no instala ni firma.'
  exit 0
fi
if [ "$#" -ne 0 ]; then
  echo 'Este preparador no admite parámetros de instalación.' >&2
  exit 64
fi
if [ "$(uname -s)" != Darwin ]; then
  echo 'La preparación de iPhone se ejecuta en el Mac con Xcode, desde la carpeta del ensayo.' >&2
  exit 1
fi
for dependency in flutter xcodebuild git; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Falta $dependency en el PATH del Mac." >&2
    exit 1
  fi
done

# La ruta del script fija el proyecto: nunca ejecutamos Flutter en otra app.
cd "$(dirname "$0")/.."
echo "Ensayo de Salud · revisión $(git rev-parse --short HEAD)"
xcodebuild -version
if ! flutter --version --machine | grep -Eq '"frameworkVersion"[[:space:]]*:[[:space:]]*"3\.47\.5"'; then
  echo 'Selecciona Flutter 3.47.5 antes de preparar el ensayo.' >&2
  exit 1
fi
flutter pub get --enforce-lockfile
flutter analyze
flutter test
xcodebuild -showdestinations -workspace ios/Runner.xcworkspace -scheme Runner
flutter devices

cat <<'NEXT'
Preparación técnica completada. Aún no se ha instalado ni leído Salud.
En Xcode, abre ios/Runner.xcworkspace y revisa Runner → Signing & Capabilities:
equipo propio, identificador es.entrenaop.healthReadProbe y HealthKit habilitado.
Conecta el iPhone al Mac, desbloquéalo y permite la conexión y el modo desarrollador.
Con una carrera reciente de Connect ya visible en Salud, instala desde esta carpeta:
  flutter run --release -d ID_DEL_IPHONE --no-pub
Sustituye ID_DEL_IPHONE por el identificador físico mostrado por flutter devices.
No elijas el simulador para acreditar lectura real. No hay que copiar archivos .env.
La comparación, denegación/revocación y borrado de memoria están en:
  ../../docs/DEVICE_HEALTH_READ_PROBE.md
NEXT
