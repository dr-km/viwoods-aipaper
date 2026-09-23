# Disabled apps

Device: viwoods AiPaper Reader (model `AiPaper_Reader`, Android 16, MediaTek).
Method: `pm disable-user --user 0 <package>` over adb shell — reversible with `pm enable --user 0 <package>`.
68 packages disabled total.

## Google / GMS

| Package | Reason |
|---|---|
| `com.google.android.gms` | Google Play Services — background telemetry/battery drain, not needed for core reading/notes |
| `com.google.android.gsf` | Google Services Framework — only supports gms/vending |
| `com.android.vending` | Play Store |
| `com.google.android.apps.wellbeing` | Digital Wellbeing — dead without gms |
| `com.google.android.apps.turbo` | Adaptive Battery — dead without gms |
| `com.google.android.onetimeinitializer` | First-boot-only init, no ongoing function |
| `com.google.android.configupdater` | GMS config updater — dead without gms |
| `com.google.android.syncadapters.calendar` | GMS calendar sync — dead without gms |
| `com.google.android.apps.restore` | GMS device-restore helper — dead without gms |
| `com.google.android.apps.docs` | Google Drive — dead without gms |
| `com.google.android.ext.shared` | GMS support library |

## MediaTek factory/engineering tools

Should never ship to consumer devices — zero end-user function.

| Package | Reason |
|---|---|
| `com.mediatek.engineermode` | Factory test tool |
| `com.mediatek.aovtestapp` | Factory test tool |
| `com.mediatek.mdmlsample` | Factory test tool |
| `com.mediatek.mdmconfig` | Factory test tool |
| `com.debug.loggerui` | Debug logger UI |

## Android Privacy Sandbox / ad tracking

System-level ad attribution APIs, unrelated to GMS.

| Package | Reason |
|---|---|
| `com.android.adservices.api` | Ad attribution/tracking API |
| `com.android.ondevicepersonalization.services` | Ad personalization |
| `com.android.federatedcompute.services` | Ad personalization (federated learning) |
| `com.android.sdksandbox` | Supporting infra for the above three |

## viwoods first-party — redundant with sideloaded apps

| Package | Reason |
|---|---|
| `com.viwoods.vistore` | Their App Store — flagged for reading call logs/contacts unnecessarily; Aurora Store/F-Droid installed instead |
| `com.viwoods.read` | "Learning" bookshelf app — redundant with KOReader/ReadEra/Kotatsu/EinkBro |
| `com.viwoods.files` | File manager — redundant with Solid Explorer |
| `com.viwoods.viwoodsrepository` | Notes/knowledge-base sync — unused, device not used for notes |
| `com.viwoods.transfer` | viTransfer (desktop sync companion) — unused |
| `com.viwoods.lantransfer` | LAN file transfer — redundant with LocalSend |
| `com.viwoods.viwoodsai` | Their AI features app — unused |
| `com.viwoods.screencast` | Screen mirroring — unused |
| `com.amazon.kindle` | Preinstalled Kindle — redundant with existing reader apps |

## Extra input methods

Kept `com.viwoods.viwoodsime.latin` + stock `com.android.inputmethod.latin`; cut the rest.

| Package | Reason |
|---|---|
| `com.viwoods.viwoodsime` | Pinyin IME, unused |
| `com.viwoods.viwoodsime.korean` | Korean IME, unused |
| `com.viwoods.viwoodsime.mozc` | Japanese IME, unused |

## No camera on this hardware

| Package | Reason |
|---|---|
| `com.mediatek.camera` | Camera app |
| `com.android.cameraextensions` | Camera extensions framework |
| `com.android.gallery3d` | Gallery |

## No voice features used

Device has a real mic, but voice unlock/commands unused.

| Package | Reason |
|---|---|
| `com.mediatek.voicecommand` | Voice command |
| `com.mediatek.voiceunlock` | Voice unlock |

## No printing / no companion devices

| Package | Reason |
|---|---|
| `com.android.printspooler` | Print spooler |
| `com.android.bips` | Built-in print service |
| `com.android.printservice.recommendation` | Print service recommendations |
| `com.android.companiondevicemanager` | Companion device (e.g. watch) pairing framework, unused |

## Location / GPS unused

Real hardware (`android.hardware.location.gps` is genuinely present, unlike the speaker — see below), but not used on this device.

| Package | Reason |
|---|---|
| `com.mediatek.gnss.nonframeworklbs` | GNSS/location backend |
| `com.mediatek.ygps` | GPS service |
| `com.mediatek.lbs.em2.ui` | Location-based services UI |
| `com.mediatek.location.mtkgeofence` | Geofencing |
| `com.mediatek.location.lppe.main` | Location positioning engine |

## Messaging / calendar / contacts / clock — unused apps

`com.android.phone` (the actual cellular data/network/call backend) was deliberately **kept** — see Caveats below.

| Package | Reason |
|---|---|
| `com.android.mms` | SMS/MMS composer UI (unused) — pure UI, no telephony backend touched |
| `com.android.calendar` | Calendar app, unused |
| `com.android.contacts` | Contacts app, unused |
| `com.android.deskclock` | Clock app, unused |

## Enterprise / health / misc bloat

| Package | Reason |
|---|---|
| `com.android.managedprovisioning` | Enterprise/work-profile enrollment, irrelevant for personal use |
| `com.android.healthconnect.controller` | Health Connect, unused |
| `com.android.health.connect.backuprestore` | Health Connect, unused |
| `com.android.egg` | Hidden Easter egg game |
| `com.android.wallpaper.livepicker` | Live Wallpaper picker, meaningless on e-ink |
| `com.android.bluetoothmidiservice` | Bluetooth MIDI instrument support, niche |
| `com.android.fmradio` | FM Radio — no built-in speaker, needs wired headphones as antenna |
| `com.android.traceur` | Developer-only performance tracing |
| `com.android.dynsystem` | Developer-only Dynamic System Updates (GSI testing) |
| `com.android.quicksearchbox` | Google search widget, dead without GMS |
| `com.android.musicfx` | Audio equalizer UI — audio is Bluetooth-only anyway |
| `com.android.calllogbackup` | Call log backup, no cloud account |
| `com.android.uwb.resources` | Ultra-wideband radio (precision finding), unused |
| `com.android.sharedstoragebackup` | Backup agent, no cloud account |
| `com.android.backupconfirm` | Backup confirmation dialog |

## Already disabled before this pass (prior session)

| Package | Reason |
|---|---|
| `com.android.nfc` | NFC, unused |
| `com.android.virtualization.terminal` | Android VM/Linux terminal feature, dev-facing |
| `com.android.devicelockcontroller` | Enterprise device-financing lock, irrelevant |

## Caveats — deliberately NOT disabled

- **`com.android.phone`** (MtkTeleService) — looks like a dialer app by name, actually registers the real `CellularDataService`, `CellularNetworkService`, and `TelephonyConnectionService`. Disabling it breaks mobile data entirely. Confirmed via `dumpsys package`.
- **Full telephony/SIM stack** — this device has genuine cellular hardware (confirmed via `pm list features`: `android.hardware.telephony`, `.calling`, `.data`, `.gsm`, `.ims`, `.messaging`, `.radio.access`, `.subscription` are all real, unlike the speaker feature below). An earlier pass mistakenly disabled the whole stack based on a flawed `grep` check that silently returned empty; caught and reverted.
- **No built-in speaker** — despite `android.hardware.audio.output` being declared and AudioManager reporting normal routing/volume to a "speaker" device, this hardware has no physical speaker (confirmed via device reviews + a real-world test with all audio-path checks green but zero sound). Audio output is Bluetooth-only. Not a package issue — nothing to disable/enable here.
- **`com.google.android.gms` self-re-enables** — observed twice: GMS silently flips back to enabled after certain batches of `pm disable-user` calls on other packages (not exclusive to touching gms-related packages). Cause not identified — some vendor watchdog likely restores it on package-state changes. Re-check after any future debloat pass with `pm list packages -d | grep gms`.
