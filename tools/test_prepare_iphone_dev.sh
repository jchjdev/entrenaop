#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
app_dir="$PWD"
fixture_dir="$app_dir/.dart_tool/iphone-dev-fixture"
mkdir -p "$fixture_dir/bin"
export IPHONE_FIXTURE_LOG="$fixture_dir/commands.log"
export IPHONE_FIXTURE_OS=Darwin IPHONE_FIXTURE_FAIL=false

# Verifica el entorno y el corte ante fallos sin firma, Mac ni datos de cuentas.
for name in uname flutter dart git xcodebuild open; do
  cat > "$fixture_dir/bin/$name" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name="${0##*/}"
if [ "$name" = uname ]; then echo "$IPHONE_FIXTURE_OS"; exit 0; fi
printf '%s|%s|%s\n' "$name" "$PWD" "$*" >> "$IPHONE_FIXTURE_LOG"
case "$name" in
  flutter)
    if [ "$*" = '--version --machine' ]; then
      echo '{"frameworkVersion":"3.47.5"}'
    elif [ "$IPHONE_FIXTURE_FAIL" = dependencies ]; then exit 7; fi ;;
  dart) if [ "$IPHONE_FIXTURE_FAIL" = build ]; then exit 8; fi ;;
  xcodebuild) echo 'Xcode fixture' ;;
esac
MOCK
  chmod +x "$fixture_dir/bin/$name"
done
export PATH="$fixture_dir/bin:$PATH"
script="$app_dir/tools/prepare_iphone_dev.sh"
bash -n "$script"
cd "$fixture_dir"
: > "$IPHONE_FIXTURE_LOG"
bash "$script" > "$fixture_dir/success.out"
grep -Fx "flutter|$app_dir|pub get --enforce-lockfile" "$IPHONE_FIXTURE_LOG"
grep -Fx "dart|$app_dir|run tools/run_app.dart build ios --config-only --release --no-codesign --no-pub --dart-define=APP_ENV=development --dart-define=SUPABASE_URL=https://sxbxfjqgoddzhtcyhalw.supabase.co" "$IPHONE_FIXTURE_LOG"
grep -Fx "open|$app_dir|ios/Runner.xcworkspace" "$IPHONE_FIXTURE_LOG"
echo 'Correcto: app principal, Release Dev explícito, identidad y apertura de Xcode.'

: > "$IPHONE_FIXTURE_LOG"
bash "$script" --no-open > "$fixture_dir/no-open.out"
if grep -q '^open|' "$IPHONE_FIXTURE_LOG"; then exit 1; fi

: > "$IPHONE_FIXTURE_LOG"
if bash "$script" --dart-define=APP_ENV=production > "$fixture_dir/arguments.out" 2>&1; then exit 1; fi
test ! -s "$IPHONE_FIXTURE_LOG"
export IPHONE_FIXTURE_OS=Linux
if bash "$script" > "$fixture_dir/platform.out" 2>&1; then exit 1; fi
test ! -s "$IPHONE_FIXTURE_LOG"
echo 'Correcto: no permite sustituir el entorno ni ejecutarse fuera de macOS.'

export IPHONE_FIXTURE_OS=Darwin IPHONE_FIXTURE_FAIL=dependencies
if bash "$script" > "$fixture_dir/failure.out" 2>&1; then exit 1; fi
if grep -Eq '^(dart|open)\|' "$IPHONE_FIXTURE_LOG"; then exit 1; fi
echo 'Correcto: un fallo de dependencias no prepara ni abre Xcode.'

: > "$IPHONE_FIXTURE_LOG"
export IPHONE_FIXTURE_FAIL=build
if bash "$script" > "$fixture_dir/build.out" 2>&1; then exit 1; fi
if grep -q '^open|' "$IPHONE_FIXTURE_LOG"; then exit 1; fi
if grep -q 'Release Dev preparada' "$fixture_dir/build.out"; then exit 1; fi
echo 'Correcto: un fallo de preparación no se presenta como éxito ni abre Xcode.'
