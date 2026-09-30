# AGENTS.md — installing radio-hq for your user

You are an AI coding agent (Claude Code or similar). Your user gave you this repository and asked you to
install it. They may not know how to install software: you do the work, they only confirm, listen and
click where macOS requires a human. Follow the steps in order.

**Ground rules**

- Speak the user's language. Keep each message short; ask one thing at a time.
- Ask before installing any package, changing a macOS setting, or writing outside `~/.config/radio-hq`
  and the Claude Code plugin directories.
- Never open an issue or pull request without the user's explicit OK, and never put their personal data
  in one (session names, message text, usernames, home paths).
- If a step fails, go to [When something breaks](#when-something-breaks) instead of improvising around it.

## 1. Explain and confirm

Tell the user in two sentences what they get: when a Claude Code session is waiting for them (a
permission, a question, a plan) or has finished, a macOS banner with the session name, a short sound
effect and a voice reading the session name like a walkie-talkie. It speaks **Italian by default**
(English available). Ask for a go.

## 2. Check the Mac

```bash
uname -s; sw_vers -productVersion; claude --version
command -v jq terminal-notifier brew; xcode-select -p
```

- **Not macOS** (`uname -s` is not `Darwin`): radio-hq does not run there yet. Say so, then offer to
  start a port with them following [PORTING.md](PORTING.md): that is a real contribution and it goes
  upstream as a pull request (step 9).
- **jq** is required. macOS 15 and later ship it as `/usr/bin/jq`. Missing: with Homebrew, ask and
  `brew install jq`; without Homebrew, explain that Homebrew (brew.sh) is needed first and stop here.
- **terminal-notifier** (optional, recommended): banners that bring back the right terminal on click and
  replace each other per session. Missing and Homebrew present: offer `brew install terminal-notifier`.
  Without it, banners go through `osascript` and still work.
- **Python 3** from the Command Line Tools (optional): the radio effect and the loudness levelling of the
  sounds. If `xcode-select -p` fails, do not install anything: the voice is simply clean. Mention that
  `xcode-select --install` adds it later.

## 3. Install the plugin

```bash
claude plugin marketplace add Faripod/radio-hq
claude plugin install radio-hq@radio-hq
claude plugin list
```

`radio-hq@radio-hq` must be listed **and enabled**; if it is disabled run
`claude plugin enable radio-hq@radio-hq`. Then ask the user to type `/reload-plugins` in this session
(you cannot run slash commands yourself), or to open a new session. From then on the hooks are live and
`radio-hq` is on your Bash PATH.

The plugin lives in the directory printed by:

```bash
jq -r '.plugins["radio-hq@radio-hq"][0].installPath' ~/.claude/plugins/installed_plugins.json
```

Below, `$RHQ` means that directory.

## 4. Run the tests

```bash
bash "$RHQ/tests/run.sh"
```

Every line must say `ok`. They feed recorded events to the hook and check its decisions without showing
or playing anything. A failure is a bug: go to [When something breaks](#when-something-breaks).

## 5. First run and sounds

```bash
"$RHQ/bin/radio-hq" sounds
"$RHQ/bin/radio-hq"
```

The first command writes `~/.config/radio-hq/config` if missing and downloads the sound kit from Mixkit
(about 1 MB, it needs the internet once); every sound should be listed in green. The second shows the
switches and the voice in use.

## 6. Hear it

Tell the user to look at the screen and listen, then run `"$RHQ/bin/radio-hq" test wait`. Ask what
happened:

- **banner, sound and voice** → perfect, go on;
- **no banner** → macOS has not allowed notifications yet. Open the settings with
  `open "x-apple.systempreferences:com.apple.Notifications-Settings.extension"` and have them allow
  **terminal-notifier** (or **Script Editor** when terminal-notifier is not installed). Suggest the
  **Persistent** style if they want banners to stay until clicked. Test again;
- **no sound** → check the volume, and whether Do Not Disturb / Focus is on (`radio-hq` shows it:
  it mutes radio-hq on purpose);
- **robotic voice** → normal until a natural voice is downloaded, step 7.

Then `"$RHQ/bin/radio-hq" test done` for the "finished" announcement.

## 7. A natural voice

Run `"$RHQ/bin/radio-hq" voices`. If no voice ends in `(Premium)` or `(Enhanced)`, offer to download one
(free). macOS offers no command for it; guide the clicks exactly as in
[skills/setup/SKILL.md](skills/setup/SKILL.md) § Voice, wait, run `voices` again and replay
`test wait`. The default `voice_name=auto` picks the new voice up by itself.

## 8. Finish

- If the user does not speak Italian: `"$RHQ/bin/radio-hq" set lang en`.
- Offer `/radio-hq:setup` for anything else (sounds, voice, categories).
- Optional: the `radio-hq` command in any terminal, not only inside Claude. Ask, then create a small
  launcher that survives plugin updates:

  ```bash
  mkdir -p ~/.local/bin
  cat > ~/.local/bin/radio-hq <<'EOF'
  #!/usr/bin/env bash
  exec "$(jq -r '.plugins["radio-hq@radio-hq"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/radio-hq" "$@"
  EOF
  chmod +x ~/.local/bin/radio-hq
  ```

  and check that `~/.local/bin` is on their PATH.
- Recap in a few lines: what they will hear, `! radio-hq off` / `on` for the voice,
  `! radio-hq tag personal` for a personal session and `radio-hq personal off` to mute those,
  `/radio-hq:setup` to change anything, how to uninstall (below).

## When something breaks

1. Reproduce it: `tests/run.sh`, `radio-hq test wait`, or a real session with
   `RADIO_HQ_LOG=/tmp/radio-hq.log` in the environment (one line per event, no message text).
2. Find the cause in the code. The map: `hooks/notify.sh` decides what to show and say (portable),
   `lib/platform/macos.sh` talks to macOS, `lib/common.sh` holds preferences and categories,
   `bin/radio-hq` is the command, `hooks/welcome.sh` the first run, `tests/` the contract.
3. Fix it in a fork, not in the installed copy (plugin updates overwrite it):

   ```bash
   gh repo fork Faripod/radio-hq --clone && cd radio-hq
   ```

   Add a test case in `tests/cases/` that fails before the fix, fix, run `tests/run.sh`. Show the user
   the diff and explain it in plain words.
4. With the user's OK, propose it upstream:
   `gh pr create --repo Faripod/radio-hq` with what broke, the macOS and Claude Code versions and the test
   output. If you could not fix it, open an issue instead (`gh issue create --repo Faripod/radio-hq`)
   with the same facts. If `gh` is not logged in, write the text for the user to paste on GitHub.
5. Until the fix is released the user can run it from the fork: `claude plugin marketplace remove
   radio-hq`, then `claude plugin marketplace add <path of the fork>` and install again. Say that it is
   temporary.

## Uninstall

```bash
claude plugin uninstall radio-hq@radio-hq
claude plugin marketplace remove radio-hq
rm -f ~/.local/bin/radio-hq
```

`~/.config/radio-hq` keeps the preferences and the downloaded sounds: ask before deleting it.

## Working on this repo

- `tests/run.sh` must pass before every commit; a behavior change comes with a case in `tests/cases/`.
- `hooks/notify.sh` stays portable bash + jq; anything OS-specific goes in `lib/platform/<os>.sh`
  ([PORTING.md](PORTING.md)).
- Sounds are never committed: `sounds/kit.tsv` lists Mixkit ids and each Mac downloads them (the Mixkit
  license does not allow redistributing the files).
- User-facing text exists in Italian and English (`t "italiano" "english"`); add both.
- Commits: `<type>: <gitmoji> <description>` (`feat: ✨ ...`, `fix: 🐛 ...`).
