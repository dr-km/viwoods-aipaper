#!/usr/bin/env bash
#
# viwoods-unlock.sh — unlock the restricted adb shell on viwoods / AiPaper Reader devices.
#
# The device runs a customized "wisky" adbd that refuses every `shell` command
# ("error: not support command ...") until the system property
# persist.wisky.hold_enable_adb is set to a hardcoded secret. The only commands the
# locked adbd lets through are the getprop/setprop on that property itself.
#
# Secret recovered by reversing the vendor's viwoods_debug_tools (.NET) app.
# Works with ANY stock Google adb — nothing client-side is modified.
#
# Usage:
#   ./viwoods-unlock.sh                 # unlock the only/default device
#   ./viwoods-unlock.sh -s <serial>     # unlock a specific device
#   ./viwoods-unlock.sh -s <serial> off # re-lock that device
#   ADB=/path/to/adb ./viwoods-unlock.sh
#
set -euo pipefail

PROP="persist.wisky.hold_enable_adb"
SECRET='SE03znbjb@6932'
LOCKED_VALUE=' '   # a single space re-locks the shell

# Pick an adb: $ADB override > adb next to this script > adb on PATH.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${ADB:-}" ]]; then
  :
elif [[ -x "$SCRIPT_DIR/adb" ]]; then
  ADB="$SCRIPT_DIR/adb"
else
  ADB="$(command -v adb || true)"
fi
[[ -n "${ADB:-}" ]] || { echo "error: no adb found (set \$ADB or put adb on PATH)" >&2; exit 1; }

# Parse args: optional "-s <serial>" and trailing "on"|"off" (default on).
SERIAL=""
ACTION="on"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SERIAL="${2:?-s needs a serial}"; shift 2 ;;
    on|off) ACTION="$1"; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "error: unknown arg '$1'" >&2; exit 1 ;;
  esac
done

# Build the adb target args.
TARGET=()
if [[ -n "$SERIAL" ]]; then
  TARGET=(-s "$SERIAL")
else
  # No serial given: require exactly one device so we don't unlock the wrong one.
  count="$("$ADB" devices | grep -cE '\sdevice$' || true)"
  if [[ "$count" -eq 0 ]]; then
    echo "error: no device in 'device' state. Plug in / authorize, then retry." >&2
    "$ADB" devices -l >&2
    exit 1
  elif [[ "$count" -gt 1 ]]; then
    echo "error: multiple devices connected — pass -s <serial>:" >&2
    "$ADB" devices -l >&2
    exit 1
  fi
fi

run_shell() { "$ADB" ${TARGET[@]+"${TARGET[@]}"} shell "$@"; }

if [[ "$ACTION" == "on" ]]; then
  echo ">> unlocking $PROP ..."
  run_shell setprop "$PROP" "$SECRET"
  # Verify: read it back, then prove a normally-blocked command runs.
  val="$(run_shell getprop "$PROP" | tr -d '\r')"
  if [[ "$val" != "$SECRET" ]]; then
    echo "error: property did not stick (got '$val'). Unlock failed." >&2
    exit 1
  fi
  if id_out="$(run_shell id 2>&1)" && [[ "$id_out" == uid=* ]]; then
    echo ">> UNLOCKED. Full adb shell available:"
    echo "   $id_out"
  else
    echo "error: property set but shell still restricted: $id_out" >&2
    exit 1
  fi
else
  echo ">> re-locking $PROP ..."
  # The lock value is a single space. adb concatenates the shell args and the
  # device-side shell word-splits them, so the space must be quoted for the
  # REMOTE shell (matching how the vendor tool sends: setprop <prop> ' ').
  run_shell "setprop $PROP '$LOCKED_VALUE'"
  echo ">> LOCKED. (shell commands will now return 'not support command')"
fi
