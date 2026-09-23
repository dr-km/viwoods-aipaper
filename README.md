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

This survives screen-lock cycles much better — reconnect with the same command/port instead of hunting for a new one each time. Tradeoff: this mode doesn't use the same per-connection TLS pairing as "Wireless debugging," so it's fine on a trusted home network but slightly less locked-down. Revert by toggling "Wireless debugging" off/on in Developer Options.

## debloat/

[`debloat/disabled-apps.md`](debloat/disabled-apps.md) — every package disabled on this device via `pm disable-user`, grouped by category with the reasoning, plus a caveats section on what was deliberately *not* touched and why (real telephony hardware, no physical speaker despite the OS reporting one, a GMS auto-re-enable quirk to watch for).

## Device

- Model: viwoods AiPaper Reader (`AiPaper_Reader`)
- Android 16, MediaTek SoC
- Real SIM/cellular hardware (data-focused; no usable "phone" experience — see caveats, no built-in speaker)
- No built-in speaker — audio output is Bluetooth-only despite the OS reporting a working "speaker" route
