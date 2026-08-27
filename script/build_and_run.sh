#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="美术台"
PROJECT_PATH="美术台.xcodeproj"
SCHEME="美术台"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="build/CodexDerivedData"
BUILD_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
DESTINATION_APP="/Applications/$APP_NAME.app"
STAGED_APP="/Applications/.$APP_NAME.app.install.$$"
BACKUP_APP="/Applications/.$APP_NAME.app.backup.$$"
INSTALL_COMMITTED=0

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bundle_id() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"
}

stop_running_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -f "/$APP_NAME\\.app/Contents/MacOS/$APP_NAME$" >/dev/null 2>&1 || true
}

build_and_install() {
  stop_running_app

  cleanup_install_artifacts() {
    [[ ! -e "$STAGED_APP" ]] || rm -rf "$STAGED_APP"
    if [[ "$INSTALL_COMMITTED" -eq 1 ]]; then
      [[ ! -e "$BACKUP_APP" ]] || rm -rf "$BACKUP_APP"
    elif [[ -e "$BACKUP_APP" && ! -e "$DESTINATION_APP" ]]; then
      mv "$BACKUP_APP" "$DESTINATION_APP"
    fi
  }
  trap cleanup_install_artifacts EXIT

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

  test -d "$BUILD_APP"
  test -x "$BUILD_APP/Contents/MacOS/$APP_NAME"
  /usr/bin/codesign --verify --deep --strict "$BUILD_APP"

  local new_bundle_id
  new_bundle_id="$(bundle_id "$BUILD_APP")"
  test -n "$new_bundle_id"

  if [[ -e "$DESTINATION_APP" ]]; then
    test -d "$DESTINATION_APP"
    local installed_bundle_id
    installed_bundle_id="$(bundle_id "$DESTINATION_APP")"
    if [[ "$installed_bundle_id" != "$new_bundle_id" ]]; then
      echo "Refusing to replace $DESTINATION_APP: bundle identifier mismatch" >&2
      echo "installed: $installed_bundle_id" >&2
      echo "built:     $new_bundle_id" >&2
      exit 1
    fi
  fi

  /usr/bin/ditto "$BUILD_APP" "$STAGED_APP"
  /usr/bin/codesign --verify --deep --strict "$STAGED_APP"
  test "$(bundle_id "$STAGED_APP")" = "$new_bundle_id"

  if [[ -e "$DESTINATION_APP" ]]; then
    mv "$DESTINATION_APP" "$BACKUP_APP"
  fi
  if ! mv "$STAGED_APP" "$DESTINATION_APP"; then
    [[ ! -e "$BACKUP_APP" ]] || mv "$BACKUP_APP" "$DESTINATION_APP"
    echo "Installation failed; the previous application was restored." >&2
    exit 1
  fi
  if ! /usr/bin/codesign --verify --deep --strict "$DESTINATION_APP"; then
    rm -rf "$DESTINATION_APP"
    [[ ! -e "$BACKUP_APP" ]] || mv "$BACKUP_APP" "$DESTINATION_APP"
    echo "Installed bundle verification failed; the previous application was restored." >&2
    exit 1
  fi
  INSTALL_COMMITTED=1
}

open_app() {
  /usr/bin/open -n "$DESTINATION_APP"
}

case "$MODE" in
  run)
    build_and_install
    open_app
    ;;
  --debug|debug)
    build_and_install
    /usr/bin/lldb -- "$DESTINATION_APP/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    build_and_install
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_and_install
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$(bundle_id "$DESTINATION_APP")\""
    ;;
  --verify|verify)
    build_and_install
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
