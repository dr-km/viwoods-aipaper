#!/usr/bin/env bash
#
# restore-debloat.sh — re-apply the full debloat pass documented in disabled-apps.md.
#
# Reversible while the device boots: pm disable-user only, nothing uninstalled.
# A bad disable only shows on the NEXT boot — reboot once after running this.
# Requires the device to already be adb-unlocked (see ../viwoods-unlock.sh) and connected.
#
# Usage:
#   ./restore-debloat.sh                 # apply to the only/default device
#   ./restore-debloat.sh -s <serial>     # apply to a specific device
#   ./restore-debloat.sh -s <serial> -n  # dry run — print commands, don't execute
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${ADB:-}" ]]; then
  :
elif [[ -x "$SCRIPT_DIR/adb" ]]; then
  ADB="$SCRIPT_DIR/adb"
else
  ADB="$(command -v adb || true)"
fi
[[ -n "${ADB:-}" ]] || { echo "error: no adb found (set \$ADB or put adb on PATH)" >&2; exit 1; }

SERIAL=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SERIAL="${2:?-s needs a serial}"; shift 2 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "error: unknown arg '$1'" >&2; exit 1 ;;
  esac
done

TARGET=()
if [[ -n "$SERIAL" ]]; then
  TARGET=(-s "$SERIAL")
else
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

# Mirrors debloat/disabled-apps.md — keep in sync if that doc changes.
PACKAGES=(
  # Google / GMS
  com.google.android.gms
  com.google.android.gsf
  com.android.vending
  com.google.android.apps.wellbeing
  com.google.android.apps.turbo
  com.google.android.onetimeinitializer
  com.google.android.configupdater
  com.google.android.syncadapters.calendar
  com.google.android.apps.restore
  com.google.android.apps.docs
  com.google.android.ext.shared
  # MediaTek factory/engineering tools
  com.mediatek.engineermode
  com.mediatek.aovtestapp
  com.mediatek.mdmlsample
  com.mediatek.mdmconfig
  com.debug.loggerui
  # Android Privacy Sandbox / ad tracking
  com.android.adservices.api
  com.android.ondevicepersonalization.services
  com.android.federatedcompute.services
  # (com.android.sdksandbox deliberately omitted — disabling it bootloops the device; see ../recovery/)
  # viwoods first-party — redundant with sideloaded apps
  com.viwoods.vistore
  com.viwoods.read
  com.viwoods.files
  com.viwoods.viwoodsrepository
  com.viwoods.transfer
  com.viwoods.lantransfer
  com.viwoods.viwoodsai
  com.viwoods.screencast
  com.amazon.kindle
  # Extra input methods (kept viwoodsime.latin + stock inputmethod.latin)
  com.viwoods.viwoodsime
  com.viwoods.viwoodsime.korean
  com.viwoods.viwoodsime.mozc
  # No camera on this hardware
  com.mediatek.camera
  com.android.cameraextensions
  com.android.gallery3d
  # No voice features used
  com.mediatek.voicecommand
  com.mediatek.voiceunlock
  # No printing / no companion devices
  com.android.printspooler
  com.android.bips
  com.android.printservice.recommendation
  com.android.companiondevicemanager
  # Location/GPS unused
  com.mediatek.gnss.nonframeworklbs
  com.mediatek.ygps
  com.mediatek.lbs.em2.ui
  com.mediatek.location.mtkgeofence
  com.mediatek.location.lppe.main
  # Messaging / calendar / contacts / clock — unused apps (com.android.phone kept, see README caveats)
  com.android.mms
  com.android.calendar
  com.android.contacts
  com.android.deskclock
  # Enterprise / health / misc bloat
  com.android.managedprovisioning
  com.android.healthconnect.controller
  com.android.health.connect.backuprestore
  com.android.egg
  com.android.wallpaper.livepicker
  com.android.bluetoothmidiservice
  com.android.fmradio
  com.android.traceur
  com.android.dynsystem
  com.android.quicksearchbox
  com.android.musicfx
  com.android.calllogbackup
  com.android.uwb.resources
  com.android.sharedstoragebackup
  com.android.backupconfirm
  # Already disabled before this list was written (prior session)
  com.android.nfc
  com.android.virtualization.terminal
  com.android.devicelockcontroller
)

echo ">> ${#PACKAGES[@]} packages to disable$([[ $DRY_RUN -eq 1 ]] && echo ' (dry run)')"

fail=0
for pkg in "${PACKAGES[@]}"; do
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "pm disable-user --user 0 $pkg"
    continue
  fi
  if out="$("$ADB" "${TARGET[@]}" shell pm disable-user --user 0 "$pkg" 2>&1)"; then
    echo "$out"
  else
    echo "FAILED: $pkg — $out" >&2
    fail=1
  fi
done

if [[ $DRY_RUN -eq 0 ]]; then
  echo ">> done. Verify with: adb shell pm list packages -d | wc -l"
  echo ">> now reboot once (adb reboot) and confirm it boots — a bad disable only shows on the next boot"
  [[ $fail -eq 0 ]] || echo ">> one or more packages failed to disable — see above" >&2
fi
