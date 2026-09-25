# Bootloop after a bad `pm disable-user`

Device: viwoods AiPaper Reader, fw 1.5.10 (`p1rctb8781p164P4`), Android 16 userdebug.
Worked example: `com.android.sdksandbox`. Recovered + verified by reboot 2026-09-25.

## Symptom

- Stuck on boot logo. `adb devices` still shows `device` (adb unlock survives).
- `adb shell getprop sys.boot_completed` empty; `/proc/uptime` keeps climbing — soft loop (framework restarts), not a kernel reboot.
- `adb shell pm list packages` → `Can't find service: package`.
- `adb logcat -d -b crash` repeats every ~5 s. Example:

```
FATAL EXCEPTION IN SYSTEM PROCESS: main
java.lang.RuntimeException: There should exactly one sdk sandbox package; found 0: matches=[]
  at com.android.server.pm.PackageManagerService.getRequiredSdkSandboxPackageName
```

## Cause

- A package `system_server` / PackageManager needs at boot was disabled. Silent until the next reboot — the running system never re-checks.
- Example: PackageManager requires exactly one enabled SDK-sandbox package. `sdksandbox` disabled → 0 found → `system_server` dies → zygote restarts → loop. First reboot after the disable was an OTA; not its fault (its `system` delta was ~0.5 KB, framework unchanged).
- Other packages may be boot-critical too. This repo only records what was observed. The exception names the culprit.

## Find the culprit

```
adb logcat -d -b crash > crash.txt      # read the first "FATAL EXCEPTION IN SYSTEM PROCESS" block
```

Not obvious → re-enable everything from the last debloat pass (loop below), then re-disable in small batches, rebooting each.

## Why the obvious fix fails

- **OTA checkpoint.** After an OTA, `/data` is f2fs `checkpoint=disable` until a boot completes (`adb shell su 0 cat /proc/mounts > m.txt; grep ' /data ' m.txt`). All `/data` writes roll back on reboot. Edit + `adb reboot` = edit silently reverted. Fix live, restart the framework, don't reboot.
- **Loop rewrites the file.** `package-restrictions.xml` is rewritten every ~5 s and PackageManager is killed mid-write → 0-byte main + a complete `package-restrictions-backup.xml`. PackageManager reads the backup in preference to main. Halt the loop first; patch main **and** delete the backup.
- **`xml2abx` is lossy.** File is Android Binary XML (`ABX\0`). `abx2xml` → edit → `xml2abx` flattens typed/interned attributes to strings (66,041 → 75,695 B). Use [`abx_patch.py`](abx_patch.py): drops attributes, re-emits the token stream; unmodified re-emit is byte-exact (checked on every run).

## Recovery

Needs adb shell unlocked and `su` (userdebug). This `su` is AOSP-style: `su 0 <cmd>`, not `su -c`.
Run from the repo root (macOS; on Linux use `sha256sum` for the local hash). `stop` freezes the display until `start` — expected.

```
PKG=com.android.sdksandbox
D=/data/system/users/0
adb shell su 0 stop                                    # halt loop; adbd stays up

# base = the complete file: -backup.xml if a write was interrupted (PackageManager prefers it), else main
if adb shell "su 0 test -e $D/package-restrictions-backup.xml"; then B=package-restrictions-backup.xml; else B=package-restrictions.xml; fi
echo "base = $B"
adb exec-out "su 0 cat $D/$B" > base.abx
python3 recovery/abx_patch.py base.abx --check         # must print OK (fully parses; catches truncation)
python3 recovery/abx_patch.py base.abx $PKG enabled enabledCaller --out fixed.abx

# check with the platform decoder: only $PKG's line differs
adb push fixed.abx /data/local/tmp/fixed.abx
adb shell "abx2xml /data/local/tmp/fixed.abx -" > fixed.xml
adb shell "su 0 abx2xml $D/$B -" > base.xml
diff base.xml fixed.xml

# install in place (keeps owner/mode/SELinux label), verify, drop any stale backup
adb shell "su 0 sh -c 'cat /data/local/tmp/fixed.abx > $D/package-restrictions.xml'"
adb shell "su 0 sha256sum $D/package-restrictions.xml"; shasum -a 256 fixed.abx    # must match
adb shell "su 0 rm -f $D/package-restrictions-backup.xml"
adb shell rm /data/local/tmp/fixed.abx

adb shell su 0 start                                   # soft restart — NOT adb reboot
```

Expected diff (example):

```diff
< <pkg name="com.android.sdksandbox" enabled="3" enabledCaller="shell:1000" first-install-time="…" />
> <pkg name="com.android.sdksandbox" first-install-time="…" />
```

Several packages: run the patcher once per package, feeding each output to the next. Unknown packages are skipped, not fatal. Only list packages you disabled — the named attributes are dropped whatever their value (an explicit `enabled="1"` reverts to the package default).

```
PKGS="com.android.sdksandbox com.example.other"        # edit
cp base.abx cur.abx
for p in $PKGS; do
  python3 recovery/abx_patch.py cur.abx "$p" enabled enabledCaller --out next.abx && mv next.abx cur.abx || echo "skipped: $p"
done
cp cur.abx fixed.abx                                   # then continue from the platform-decoder check above
```

## Verify

```
adb shell getprop sys.boot_completed                   # 1 within ~30 s
adb shell pidof system_server                          # same pid over time
adb shell su 0 dmesg > dmesg.txt; grep -i checkpoint dmesg.txt   # "Checkpoint has been committed"
```

Committed = permanent. Then `adb reboot` once to confirm: booted in ~32 s, disabled-package set unchanged.

## Not tested

- No adb shell / `su`: only known path is factory reset from recovery (wipes `/data`, incl. the adb unlock → re-run `viwoods-unlock.sh`). Don't re-run an old `restore-debloat.sh` that lists `sdksandbox`.
- The Recovery block as now written: run read-only on a healthy device (up to the install step) and the multi-package loop on a real file. `stop` / install / `start` ran in the real incident as separate commands, not re-run as this exact block.
- Other causes, e.g. `pm uninstall --user 0` (`installed="false"`): patcher takes any attribute name, but this path is untried.

## Prevent

- Reboot once after any debloat pass — before any OTA. Unsure → add in small batches, reboot each.
- Known boot-breakers (observed, not exhaustive): `com.android.sdksandbox`.
- `com.android.uwb.resources` is re-enabled by the OS on boot (`enabledCaller=android`); ignore.
