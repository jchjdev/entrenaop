#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
lab_dir="$PWD"
fixture_dir="$lab_dir/.dart_tool/iphone_preflight_fixture"
mkdir -p "$fixture_dir/bin"
export PROBE_FIXTURE_LOG="$fixture_dir/commands.log"
export PROBE_FIXTURE_OS=Darwin PROBE_FIXTURE_SDK=3.47.5 PROBE_FIXTURE_FAIL_TEST=false

# Dobles de herramientas: se ejecuta el preparador real sin Mac, firma ni móvil.
for name in uname flutter xcodebuild git; do
  cat > "$fixture_dir/bin/$name" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name="${0##*/}"
if [ "$name" = uname ]; then
  echo "$PROBE_FIXTURE_OS"
  exit 0
fi
printf '%s|%s|%s\n' "$name" "$PWD" "$*" >> "$PROBE_FIXTURE_LOG"
case "$name" in
  git) echo fixturecommit ;;
  xcodebuild) echo 'Xcode fixture' ;;
  flutter)
    case "$*" in
      '--version --machine') printf '{"frameworkVersion":"%s"}\n' "$PROBE_FIXTURE_SDK" ;;
      'pub get --enforce-lockfile'|analyze|devices) ;;
      test) if [ "$PROBE_FIXTURE_FAIL_TEST" = true ]; then exit 7; fi ;;
      *) echo 'Operación no permitida en el ensayo de preparación' >&2; exit 99 ;;
    esac ;;
esac
MOCK
  chmod +x "$fixture_dir/bin/$name"
done
export PATH="$fixture_dir/bin:$PATH"
script="$lab_dir/tool/prepare_iphone.sh"
bash -n "$script"

: > "$PROBE_FIXTURE_LOG"
cd "$fixture_dir"
bash "$script" > "$fixture_dir/success.out"
grep -Fx "flutter|$lab_dir|pub get --enforce-lockfile" "$PROBE_FIXTURE_LOG"
grep -Fx "flutter|$lab_dir|test" "$PROBE_FIXTURE_LOG"
grep -Fx "flutter|$lab_dir|devices" "$PROBE_FIXTURE_LOG"
if grep -Eq '\|(run|install|build)( |$)' "$PROBE_FIXTURE_LOG"; then exit 1; fi
echo 'Correcto: fija la carpeta del ensayo y nunca instala ni firma.'

: > "$PROBE_FIXTURE_LOG"
export PROBE_FIXTURE_OS=Linux
if bash "$script" > "$fixture_dir/platform.out" 2>&1; then exit 1; fi
test ! -s "$PROBE_FIXTURE_LOG"
echo 'Correcto: Windows/Linux se detienen antes de ejecutar herramientas.'

: > "$PROBE_FIXTURE_LOG"
export PROBE_FIXTURE_OS=Darwin PROBE_FIXTURE_SDK=0.0.0
if bash "$script" > "$fixture_dir/sdk.out" 2>&1; then exit 1; fi
if grep -q 'pub get' "$PROBE_FIXTURE_LOG"; then exit 1; fi
echo 'Correcto: SDK distinto se detiene antes de resolver dependencias.'

: > "$PROBE_FIXTURE_LOG"
export PROBE_FIXTURE_SDK=3.47.5 PROBE_FIXTURE_FAIL_TEST=true
if bash "$script" > "$fixture_dir/tests.out" 2>&1; then exit 1; fi
if grep -q '|devices$' "$PROBE_FIXTURE_LOG"; then exit 1; fi
echo 'Correcto: una prueba fallida no se presenta como preparación completada.'
