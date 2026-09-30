---
name: setup
description: Personalize radio-hq, the Claude Code voice announcements — language, voice (including downloading a natural macOS voice), sound effects, radio effect, work/personal categories. Use when the user runs /radio-hq:setup or asks to change the radio-hq voice, sounds, language or categories.
---

# radio-hq setup

Walk the user through the radio-hq preferences in their language. Change a preference only with
`radio-hq set <key> <value>`, never by editing files, and let them hear every choice before moving on.

`radio-hq` is on the Bash tool's PATH while the plugin is enabled. If it is not found, call it by path:
`"$(jq -r '.plugins["radio-hq@radio-hq"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/radio-hq"`.

## 1. Where we are

Run `radio-hq` (the switches) and read `~/.config/radio-hq/config` (the preferences, with comments).
Sum them up in two lines, then ask what to change (AskUserQuestion, multiSelect): language, voice, sounds,
radio effect, categories. Skip whatever they do not pick.

## 2. Language

`it` (the default) or `en`: `radio-hq set lang en`. It switches the banners, the spoken phrases and the
`radio-hq` output. Other languages are not translated yet: offer to add one (the phrases live in
`hooks/notify.sh`, the rest in `bin/radio-hq`) and propose it upstream as in AGENTS.md.

## 3. Voice

- `radio-hq voices` lists the installed voices for the language, best first; `←` marks the one in use.
- Let them hear candidates: `say -v "<name>" "<a short sentence in their language>"`.
- Choose: `radio-hq set voice_name "<exact name>"`, or `auto` to always take the best installed one.
- No `(Premium)` or `(Enhanced)` voice in the list? Offer to download one: free, 100–300 MB, much more
  natural. macOS has no command for it, so the user clicks while you guide:
  1. run `open -a "VoiceOver Utility"` (opening it does not turn VoiceOver on);
  2. **Speech** in the sidebar, then the **Voices** tab;
  3. open the voice pop-up menu (for example on the **Default** row) and pick **Customize…** or
     **Manage Voices…** at the bottom;
  4. find the language and tick a voice: Luca (Enhanced), Federica or Paola for Italian; Ava, Zoe or
     Evan for English. Confirm and wait for the download.

  Then run `radio-hq voices` again: with `voice_name=auto` the new voice is used right away.
  On macOS 14 and earlier the same list is in System Settings › Accessibility › Spoken Content ›
  System Voice › Manage Voices.

## 4. Sounds

- `radio-hq sounds` lists the kit (downloading what is missing); `←` marks the current choices.
- Play candidates one at a time with `radio-hq play <name>` and ask which fits "waiting for you"
  (`sound_wait`) and "finished" (`sound_done`).
- Any audio file works too (wav, aiff, mp3, m4a): `radio-hq set sound_done ~/Sounds/bell.wav`.

## 5. Radio effect

On by default: squelch, band-limited voice, roger beep. `radio-hq set radio off` for a clean voice.
It needs Python 3 from the Command Line Tools; without them the voice is always clean.

## 6. Categories

- Every session is `work` unless tagged. Inside a session: `! radio-hq tag personal` (or `work`, `none`).
- `radio-hq personal off` / `radio-hq work off` mutes the sound and voice of that category; the banner stays.
- `default_category` (`work` or `personal`) is the category of untagged sessions.
- `always_on_dirs`: folders whose sessions have no category and always sound, separated by `:`
  (`radio-hq set always_on_dirs "~/notes"`).
- macOS Do Not Disturb / Focus mutes everything on its own.

## 7. Wrap up

Run `radio-hq test wait` and `radio-hq test done` and ask if they are happy. Close with the final
preferences and the everyday switches: `! radio-hq off` / `on` for the voice, `! radio-hq personal off`
for a category, `! radio-hq tag personal` for the current session.
