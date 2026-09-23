# viwoods-aipaper

Notes on unlocking and debloating the viwoods AiPaper Reader.

## ADB unlock

Stock firmware runs a custom `adbd` that rejects every shell command (`error: not support command ...`) until a specific system property is set. `viwoods-unlock.sh` sets/unsets it:

```
./viwoods-unlock.sh                 # unlock the only/default device
./viwoods-unlock.sh -s <serial>     # unlock a specific device
./viwoods-unlock.sh -s <serial> off # re-lock
```

The property/secret was originally reverse-engineered from viwoods' own official debug-tools desktop app (`viwoods_debug_tools`) and posted to [an XDA thread](https://xdaforums.com/t/viwoods-ai-paper-reader-adb-unlock.4790758/). Independently confirmed by extracting the identical command string from the vendor binary itself.

Once unlocked, the device has full `adb shell` and — separately — genuine root (`su`) is present on-device (this firmware ships as a `userdebug` build, not `user`; root is a side effect of that, not something added). App-level access to root/Shizuku is blocked by SELinux policy regardless — only the `adb shell` (uid 2000) identity can reach `su`.

## Wireless adb keeps disconnecting

The stock "Wireless debugging" pairing port is ephemeral — it rotates (new port) whenever the screen times out and locks (10 min default), which kills the connection and requires re-reading a new port from Developer Options each time.

Fix: switch `adbd` to classic fixed-port TCP mode instead, once connected via the normal pairing flow:

```
adb tcpip 5555
adb connect <device-ip>:5555
```

This survives screen-lock cycles much better — reconnect with the same command/port instead of hunting for a new one each time.

**Security note:** `adb tcpip` mode is meaningfully less safe than paired "Wireless debugging" — fixed port reachable by any device on the network, older cleartext-ish protocol instead of TLS, and a straight line to root given this device's `su` access (see above). In practice the real exposure window is narrower than it sounds, though:

- WLAN itself powers off when the display sleeps, so the port isn't reachable at all during idle periods — only while the screen is actively on.
- Wireless debugging is only ever enabled on a trusted home network here, not taken to public/hotel/coffee-shop WiFi.

Given those two constraints, leaving it on between work sessions is a reasonable tradeoff on this setup. Worth reassessing if either constraint changes — e.g. if wireless debugging ever gets enabled away from home, revert it first (toggle "Wireless debugging" off/on in Developer Options, or `viwoods-unlock.sh off` to fully re-lock).

## debloat/

[`debloat/disabled-apps.md`](debloat/disabled-apps.md) — every package disabled on this device via `pm disable-user`, grouped by category with the reasoning, plus a caveats section on what was deliberately *not* touched and why (real telephony hardware, no physical speaker despite the OS reporting one, a GMS auto-re-enable quirk to watch for).

[`debloat/restore-debloat.sh`](debloat/restore-debloat.sh) — re-applies the full list in one shot (mirrors the doc above). Useful after a factory reset, which wipes all `pm disable-user` state along with the adb unlock property.

```
./debloat/restore-debloat.sh                 # apply to the only/default device
./debloat/restore-debloat.sh -s <serial>     # apply to a specific device
./debloat/restore-debloat.sh -s <serial> -n  # dry run — print commands, don't execute
```

## Device

- Model: viwoods AiPaper Reader (`AiPaper_Reader`)
- Android 16, MediaTek SoC
- Real SIM/cellular hardware (data-focused; no usable "phone" experience — see caveats, no built-in speaker)
- No built-in speaker — audio output is Bluetooth-only despite the OS reporting a working "speaker" route
