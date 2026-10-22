#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = --help ]; then
  echo 'En el Mac: bash tools/prepare_iphone_dev.sh [--no-open]'
  echo 'Prepara EntrenaOP Release con Supabase Dev y abre Xcode para instalar en el iPhone.'
  exit 0
fi
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --no-open ]; }; then
  echo 'Solo se admite --no-open; este flujo utiliza exclusivamente desarrollo.' >&2
  exit 64
fi
if [ "$(uname -s)" != Darwin ]; then
  echo 'Ejecuta este comando en el Mac con Xcode.' >&2
  exit 1
fi
for dependency in flutter dart git xcodebuild; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Falta $dependency en el PATH del Mac." >&2
    exit 1
  fi
done

# Fijar la app principal aunque se lance desde otra carpeta o desde el ensayo.
cd "$(dirname "$0")/.."
xcodebuild -version
if ! flutter --version --machine | grep -Eq '"frameworkVersion"[[:space:]]*:[[:space:]]*"3\.47\.5"'; then
  echo 'Selecciona Flutter 3.47.5 antes de preparar la app.' >&2
  exit 1
fi
flutter pub get --enforce-lockfile

# Sobrescribe Generated.xcconfig: no heredar producción ni el JSON de compras.
# La firma interactiva queda en Xcode; no trasladar claves privadas al proyecto.
dart run tools/run_app.dart build ios --config-only --release --no-codesign --no-pub \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://sxbxfjqgoddzhtcyhalw.supabase.co

cat <<'NEXT'
EntrenaOP Release Dev preparada. Todavía falta compilar e instalar desde Xcode.
1. Conecta y desbloquea el iPhone.
2. En Xcode selecciona el esquema «Runner iPhone» y tu iPhone físico.
3. Pulsa ▶︎ (Cmd+R). Si se solicita, permite a codesign usar el llavero.
Después podrás abrir EntrenaOP desde su icono y desconectar el cable.
Perfil → Versión de la app permite comprobar la revisión instalada.
Perfil → Conexión con Garmin → Conectar Garmin → Enviar una carrera.
Tras autorizar en Safari, vuelve a EntrenaOP y pulsa Actualizar estado si hace falta.
No hay que copiar credenciales ni archivos .env para Garmin.
NEXT
if [ "${1:-}" != --no-open ]; then
  open ios/Runner.xcworkspace
fi
