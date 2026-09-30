# Porting radio-hq to another OS

radio-hq is split so that a port touches one file.

- `hooks/notify.sh` decides everything: which event, the session name, the category, what the banner
  says, which sound, which sentence. It is bash + jq and shared by every OS.
- `lib/platform/<os>.sh` does the talking to the OS. `lib/common.sh` picks the file from `uname -s`
  (`rhq_platform`): add your OS there.
- `tests/run.sh` is the contract. It runs the shared logic in dry-run mode, so it must pass unchanged on
  your OS before you start, and again when you are done.

## The functions a platform file provides

| Function | Does | macOS |
|---|---|---|
| `rhq_is_headless` | success when the nearest `claude` ancestor process runs with `-p`/`--print` | `ps` walk |
| `rhq_dnd` | success when Do Not Disturb / Focus is on | `~/Library/DoNotDisturb/DB/Assertions.json` |
| `rhq_banner title subtitle message group` | shows a notification; `group` lets a newer one replace the older | `terminal-notifier`, else `osascript` |
| `rhq_play file [seconds]` | plays an audio file, cut at `seconds` when not 0 | `afplay -t` |
| `rhq_fallback_sound wait\|done` | path of a system sound for when the kit is not downloaded | `/System/Library/Sounds` |
| `rhq_to_wav in out` | converts the downloaded mp3 to mono 16-bit WAV | `afconvert` |
| `rhq_voices lang` | `locale<TAB>name` of installed voices for `it`/`en`, best first | `say -v '?'` |
| `rhq_voice lang configured` | the configured voice if installed, else the best one | |
| `rhq_say_to_file voice text out.wav` | speech to a mono 16-bit WAV (input of `lib/radio.py`) | `say -o` |
| `rhq_say voice text` | speech straight to the speakers | `say` |
| `rhq_python` | prints a usable `python3`, fails if there is none | |

`lib/radio.py` and `lib/normalize.py` are plain Python and work anywhere.

## Pointers

**Windows.** Claude Code on Windows relies on Git for Windows. First make sure the hooks run under Git
Bash (a hook entry in `hooks/hooks.json` accepts `"shell": "bash"`): then `uname -s` starts with `MINGW`
or `MSYS` and the same `notify.sh` runs. jq comes from `winget install jqlang.jq`. The platform file can
call PowerShell:

- banner: a toast through `Windows.UI.Notifications` (no module needed) or the BurntToast module;
- sound: `(New-Object Media.SoundPlayer $file).PlaySync()` for WAV;
- voice: `System.Speech.Synthesis.SpeechSynthesizer` (`SetOutputToWaveFile` for the radio effect);
  the natural voices of Windows 11 are reachable through `Windows.Media.SpeechSynthesis`;
- headless: walk parent processes with `Get-CimInstance Win32_Process` looking for `claude` with `-p`;
- Focus Assist has no stable public API: returning failure (never muted) is acceptable at first.

**Linux.** `notify-send` for banners (`-h string:x-canonical-private-synchronous:<group>` to replace),
`paplay`/`aplay` for sound, `espeak-ng` or Piper for voices, `ffmpeg` for `rhq_to_wav`, `ps` like macOS,
Do Not Disturb from `gsettings get org.gnome.desktop.notifications show-banners` on GNOME.

## Done means

1. `tests/run.sh` passes on the new OS.
2. `radio-hq test wait` and `radio-hq test done` show a banner and play sound and voice.
3. A real session: a permission prompt and the end of a turn are announced; `claude -p` stays silent.
4. README and AGENTS.md say the OS is supported and list its requirements.

Then open a pull request (AGENTS.md, "When something breaks", step 4 shows how).
