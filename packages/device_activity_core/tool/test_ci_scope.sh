#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p .dart_tool/ci_scope
scope_script="$PWD/.dart_tool/ci_scope/actual_scope.sh"

# Se ejecuta el script real del workflow, sin duplicar su criterio de selección.
awk '
  /^      - name: Detectar cambios compartidos$/ { step = 1; next }
  step && /^        run: \|$/ { body = 1; next }
  body && /^      - name:/ { exit }
  body { sub(/^          /, ""); print }
' ../../.github/workflows/admin-dev.yml > "$scope_script"
test -s "$scope_script"
bash -n "$scope_script"

git() {
  case "$1" in
    cat-file) test "$CASE_BASE_EXISTS" = true ;;
    diff) printf '%s\n' "$CASE_FILES" ;;
    *) return 99 ;;
  esac
}
export -f git

check_scope() {
  local name="$1" files="$2" event="$3" base_exists="$4"
  local expected_athlete="$5" expected_publish="$6"
  local output="$PWD/.dart_tool/ci_scope/$name.out"
  : > "$output"
  CASE_FILES="$files" CASE_BASE_EXISTS="$base_exists" \
    EVENT="$event" BEFORE=base GITHUB_SHA=head GITHUB_OUTPUT="$output" \
    bash -euo pipefail "$scope_script"
  grep -qx "athlete=$expected_athlete" "$output"
  grep -qx "publish_required=$expected_publish" "$output"
  printf 'Correcto: %s\n' "$name"
}

check_scope isolated-package $'packages/device_activity_core/lib/src/activity.dart' push true true false
check_scope package-docs-ci $'packages/device_activity_core/lib/src/activity.dart\ndocs/ROADMAP.md\n.github/workflows/admin-dev.yml' push true true false
check_scope mixed-admin $'packages/device_activity_core/lib/src/activity.dart\nadmin_app/lib/main.dart' push true true true
check_scope shared-editor $'packages/device_activity_core/lib/src/activity.dart\npackages/workout_editor_ui/lib/editor.dart' push true true true
check_scope admin-only 'admin_app/lib/main.dart' push true false true
check_scope workflow-only '.github/workflows/admin-dev.yml' push true false true
check_scope manual 'packages/device_activity_core/lib/src/activity.dart' workflow_dispatch true true true
check_scope unknown-base 'packages/device_activity_core/lib/src/activity.dart' push false true true
check_scope health-probe-only 'labs/health_read_probe/lib/main.dart' push true false false
check_scope health-probe-ci $'labs/health_read_probe/lib/main.dart\ndocs/DEVICE_HEALTH_READ_PROBE.md\n.github/workflows/health-read-probe.yml\n.github/workflows/admin-dev.yml' push true false false
check_scope health-probe-admin $'labs/health_read_probe/lib/main.dart\nadmin_app/lib/main.dart' push true false true
check_scope health-probe-trainer $'labs/health_read_probe/lib/main.dart\ntrainer_app/lib/main.dart' push true false true
check_scope health-plugin-only 'packages/device_health/lib/device_health.dart' push true true false
check_scope health-plugin-lab $'packages/device_health/lib/device_health.dart\nlabs/health_read_probe/lib/main.dart\n.github/workflows/health-read-probe.yml' push true true false
check_scope health-plugin-admin $'packages/device_health/lib/device_health.dart\nadmin_app/lib/main.dart' push true true true
check_scope health-plugin-editor $'packages/device_health/lib/device_health.dart\npackages/workout_editor_ui/lib/editor.dart' push true true true
